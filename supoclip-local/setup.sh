#!/usr/bin/env bash
# Sets up SupoClip fully local (Whisper + Ollama, no paid API keys) with Docker,
# following https://www.supoclip.com/blog/self-host-supoclip-docker#local
# (option "Ollama in its own container").
#
# Usage:
#   ./setup.sh            # only this computer: http://localhost:3107
#   ./setup.sh --phone    # also reachable from a phone on the same Wi-Fi
#
# Optional environment variables:
#   SUPOCLIP_DIR   where to clone SupoClip (default: ./supoclip)
#   OLLAMA_MODEL   Ollama model for clip selection (default: gpt-oss:20b, needs ~16 GB RAM;
#                  use qwen2.5:7b or qwen2.5:3b on smaller machines)
#   WHISPER_SIZE   tiny | base | small | medium | large | large-v3 (default: small)
#   LAN_IP         this computer's Wi-Fi IP for --phone (auto-detected if empty)
#   SKIP_START=1   write the configuration without starting Docker
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SUPOCLIP_DIR="${SUPOCLIP_DIR:-$PWD/supoclip}"
OLLAMA_MODEL="${OLLAMA_MODEL:-gpt-oss:20b}"
WHISPER_SIZE="${WHISPER_SIZE:-small}"
PHONE=false
[ "${1:-}" = "--phone" ] && PHONE=true

# Replace KEY=... in .env, or append it when missing (portable across GNU/BSD).
set_env() {
  local key="$1" value="$2" file="$SUPOCLIP_DIR/.env"
  awk -v k="$key" -v v="$value" '
    BEGIN { done = 0 }
    index($0, k "=") == 1 { print k "=" v; done = 1; next }
    { print }
    END { if (!done) print k "=" v }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

random_secret() {
  if command -v openssl >/dev/null 2>&1; then openssl rand -hex 32
  else head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'; fi
}

detect_lan_ip() {
  if [ "$(uname)" = "Darwin" ]; then
    ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null
  else
    ip route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "src") print $(i + 1)}' \
      || hostname -I 2>/dev/null | awk '{print $1}'
  fi
}

if [ ! -d "$SUPOCLIP_DIR/.git" ]; then
  git clone https://github.com/FujiwaraChoki/supoclip "$SUPOCLIP_DIR"
fi

if [ ! -f "$SUPOCLIP_DIR/.env" ]; then
  cp "$SUPOCLIP_DIR/.env.example" "$SUPOCLIP_DIR/.env"
  # The tutorial says to replace every placeholder secret, even for local use.
  set_env BETTER_AUTH_SECRET "$(random_secret)"
  set_env BACKEND_AUTH_SECRET "$(random_secret)"
  set_env APP_SETTINGS_ENCRYPTION_KEY "$(random_secret)"
fi

# Fully local: Whisper for transcription, Ollama (in its own container) for clip selection.
set_env TRANSCRIPTION_PROVIDER whisper
set_env WHISPER_MODEL_SIZE "$WHISPER_SIZE"
set_env BACKEND_CPU_ONLY true
set_env LLM "ollama:$OLLAMA_MODEL"
set_env OLLAMA_BASE_URL http://ollama:11434/v1
set_env FRONTEND_PORT 3107

if $PHONE; then
  LAN_IP="${LAN_IP:-$(detect_lan_ip)}"
  if [ -z "$LAN_IP" ]; then
    echo "Could not detect this computer's Wi-Fi IP. Run again with LAN_IP=192.168.x.y ./setup.sh --phone" >&2
    exit 1
  fi
  # The phone's browser talks to the frontend and, for uploads, directly to the backend,
  # so both URLs must use the LAN IP instead of localhost.
  set_env NEXT_PUBLIC_APP_URL "http://$LAN_IP:3107"
  set_env BETTER_AUTH_URL "http://$LAN_IP:3107"
  set_env BETTER_AUTH_TRUSTED_ORIGINS "http://localhost:3107"
  set_env NEXT_PUBLIC_API_URL "http://$LAN_IP:8000"
  set_env CORS_ORIGINS "http://$LAN_IP:3107,http://localhost:3107"
  # Next's dev server rejects dev assets requested from other hosts; serve the production build.
  set_env FRONTEND_BUILD_TARGET production
  set_env NODE_ENV production
  cp "$HERE/docker-compose.phone.yml" "$SUPOCLIP_DIR/docker-compose.override.yml"
else
  cp "$HERE/docker-compose.ollama.yml" "$SUPOCLIP_DIR/docker-compose.override.yml"
fi

if [ "${SKIP_START:-}" = "1" ]; then
  echo "Configuration written to $SUPOCLIP_DIR (.env and docker-compose.override.yml)."
  exit 0
fi

cd "$SUPOCLIP_DIR"
docker compose up -d ollama
docker compose exec ollama ollama pull "$OLLAMA_MODEL"
docker compose up -d --build

echo
echo "SupoClip is starting (the first build takes a while). Check with: docker compose ps"
echo "  On this computer: http://localhost:3107"
if $PHONE; then
  echo "  On your phone (same Wi-Fi): http://$LAN_IP:3107"
fi
