# SupoClip 100% local (Whisper + Ollama) com Docker

Roda o [SupoClip](https://github.com/FujiwaraChoki/supoclip) no seu computador sem chaves de API pagas,
seguindo o tutorial oficial: <https://www.supoclip.com/blog/self-host-supoclip-docker#local>
(opção "Ollama in its own container").

- **Transcrição:** Whisper local (`TRANSCRIPTION_PROVIDER=whisper`)
- **Seleção dos clipes:** modelo local do Ollama (`LLM=ollama:<modelo>`)
- **Banco e filas:** Postgres e Redis, tudo no Docker Compose do próprio SupoClip

## Requisitos

- Docker (Docker Desktop no Windows/macOS, Docker Engine no Linux)
- Git e um terminal bash. No Windows, use o **Git Bash** ou o **WSL**.
- RAM: cerca de 16 GB para o modelo padrão `gpt-oss:20b`. Com menos memória, use
  `OLLAMA_MODEL=qwen2.5:7b` (8 GB) ou `OLLAMA_MODEL=qwen2.5:3b` (4 GB).
- Internet na primeira execução, para baixar as imagens, o modelo do Ollama e o do Whisper.

## Usar só no computador

```bash
git clone https://github.com/jxffz-dev/edita-ai
cd edita-ai/supoclip-local
./setup.sh
```

Abra <http://localhost:3107> e crie sua conta. O primeiro build demora alguns minutos.

## Testar no celular (mesma rede Wi-Fi)

```bash
./setup.sh --phone
```

No final, o script mostra o endereço para abrir no celular, algo como `http://192.168.0.50:3107`.
Se o IP não for detectado, informe manualmente:

```bash
LAN_IP=192.168.0.50 ./setup.sh --phone
```

O modo `--phone`:

- publica o frontend (3107) e o backend (8000) em todas as interfaces de rede. Por padrão, o
  SupoClip só aceita conexões do próprio computador;
- troca `localhost` pelo IP do computador nas URLs que o navegador do celular usa: `NEXT_PUBLIC_APP_URL`,
  `BETTER_AUTH_URL`, `NEXT_PUBLIC_API_URL` (os uploads vão direto para o backend) e `CORS_ORIGINS`;
- usa o build de produção do frontend, porque o servidor de desenvolvimento do Next recusa
  arquivos pedidos por outro host.

Ollama, Postgres e Redis continuam acessíveis só dentro da rede do Docker.

Se o celular não abrir a página:

- confirme que o celular e o computador estão na mesma rede Wi-Fi;
- libere as portas **3107** e **8000** no firewall. No Windows, aceite o aviso do Firewall do
  Windows para o Docker ou crie uma regra de entrada para essas portas;
- se o IP do computador mudar, rode `./setup.sh --phone` de novo.

> Use o modo `--phone` só em redes confiáveis: qualquer aparelho da rede consegue abrir o SupoClip.
> Para voltar ao modo só local, rode `./setup.sh` e depois `docker compose up -d --build` na pasta `supoclip`.

## Variáveis opcionais

| Variável | Padrão | Para que serve |
| --- | --- | --- |
| `OLLAMA_MODEL` | `gpt-oss:20b` | Modelo do Ollama que escolhe os clipes |
| `WHISPER_SIZE` | `small` | Tamanho do Whisper: `tiny`, `base`, `small`, `medium`, `large`, `large-v3` |
| `SUPOCLIP_DIR` | `./supoclip` | Pasta onde o SupoClip é clonado |
| `LAN_IP` | detectado | IP do computador na rede Wi-Fi, usado pelo `--phone` |
| `SKIP_START` | vazio | Com `1`, só grava a configuração, sem subir o Docker |

O script não sobrescreve um `.env` que já existe: ele só ajusta as chaves acima e gera segredos
aleatórios na primeira execução.

## Verificar se está tudo funcionando

Dentro da pasta `supoclip`:

```bash
docker compose ps                                  # todos os serviços "healthy"
curl -f http://localhost:8000/health/db            # backend conectado ao Postgres
docker compose exec worker curl -s http://ollama:11434/api/tags   # o worker vê o modelo do Ollama
```

## Arquivos

- `setup.sh`: clona o SupoClip, configura o `.env` e sobe os contêineres
- `docker-compose.ollama.yml`: override que adiciona o contêiner do Ollama (modo só local)
- `docker-compose.phone.yml`: o mesmo override, mais as portas abertas para a rede (modo celular)
