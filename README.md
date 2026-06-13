# hermes-stack

Hermes Agent (manager) + Claude Code (worker), fully Dockerized.
Deploy anywhere with `docker compose up`.

## What's inside

| Container | Image | Role |
|---|---|---|
| `hermes-gateway` | `nousresearch/hermes-agent:latest` | Hermes orchestrator |
| `hermes-dashboard` | `nousresearch/hermes-agent:latest` | Web UI at localhost:9119 |
| `claude-worker` | built from `./claude` | Claude Code CLI executor |

Hermes delegates coding tasks to Claude Code via `docker exec claude-worker claude -p "..."`.
All configuration is done manually on first startup — nothing is preconfigured in this repo.

## Prerequisites

- Docker Desktop installed and running
- **Windows/WSL2:** Docker Desktop → Settings → Resources → WSL Integration → enable your distro → Apply & Restart

## Local setup (WSL / Linux / Mac)

```bash
git clone https://github.com/usfkhoury/hermes-stack
cd hermes-stack
cp .env.example .env
# Edit .env — set REPOS_MOUNT to the absolute path of your repos folder:
#   REPOS_MOUNT=/mnt/c/Users/Youssef EL KHOURY/OneDrive/Documents/Git
docker compose up -d
```

### First-time manual setup (run once after `docker compose up -d`)

```bash
# 1. Configure Hermes: model, channels, terminal backend, etc.
docker exec -it hermes-gateway hermes setup

# 2. Authenticate Claude Code with your Claude Pro account
docker exec -it claude-worker claude login
#    Copy the printed URL to your browser, complete OAuth, return here.
```

**Hermes terminal backend:** During `hermes setup`, when prompted for the terminal backend, choose **Docker** and enter container name: `claude-worker`. This routes Hermes task execution into the Claude Code container.

Everything persists across `docker compose down / up` via named volumes.

### Access the dashboard

Open http://localhost:9119

## Cloud setup

```bash
git clone https://github.com/usfkhoury/hermes-stack
cd hermes-stack
cp .env.example .env
# Leave REPOS_MOUNT empty in .env (uses named Docker volume)
docker compose up -d
```

Populate the repos volume after startup:
```bash
docker exec claude-worker git clone <repo-url> /repos/<repo-name>
# Repeat for each repo
```

Then run the same first-time setup steps as local (hermes setup + claude login).

## Volumes

| Volume | Contents | Safe to `down -v`? |
|---|---|---|
| `hermes-data` | Hermes config, memory, skills | No — wipes all Hermes config |
| `claude-auth` | Claude Code OAuth token | No — forces re-login |
| `repos-data` | Repos (cloud only) | No — wipes cloned repos |

> **Warning:** `docker compose down -v` deletes ALL volumes. Only use it to fully reset the stack.

## Updating

```bash
# Update Hermes
docker compose pull hermes-gateway hermes-dashboard && docker compose up -d

# Update Claude Code
docker compose build --no-cache claude-worker && docker compose up -d claude-worker
```
