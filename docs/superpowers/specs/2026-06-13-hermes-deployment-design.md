# Hermes Stack Deployment Design

**Date:** 2026-06-13  
**Status:** Approved

## Overview

A Dockerized deployment of [Hermes Agent](https://hermes-agent.nousresearch.com/) (manager) + Claude Code CLI (worker), managed in a single GitHub repo (`hermes-stack`) that can be deployed identically on any machine or cloud provider with `docker compose up`.

The user manually configures Hermes on first startup — no model, channel, or API credentials are preconfigured in the repo.

---

## Architecture

Two Docker Compose services communicating via the Docker socket:

```
┌──────────────────┐     Docker socket     ┌───────────────────┐
│  hermes-manager  │ ───────────────────→  │  claude-worker    │
│                  │  docker exec          │                   │
│  Hermes Agent    │  claude -p "task"     │  Claude Code CLI  │
│  ← user runs     │                       │  ← user runs      │
│    hermes setup  │                       │    claude login   │
└──────────────────┘                       └───────────────────┘
       │                                          │
  hermes-data/ volume                        repos/ volume
  (persists config,                          (git repos bind-mounted
   memory, skills)                           from host or git-cloned)
```

**hermes-manager:**
- Runs the Hermes Agent process
- Has Docker socket access to exec into `claude-worker`
- All configuration done interactively via `hermes setup` on first startup
- Config and memory persisted in `hermes-data` named volume

**claude-worker:**
- Node.js container with Claude Code CLI installed
- Authenticates via browser OAuth (`claude login`) on first startup
- OAuth token persisted in `claude-auth` named volume
- User repos accessible at `/repos` inside the container

---

## Setup Flow

On any machine:

```bash
git clone https://github.com/<your-username>/hermes-stack
cd hermes-stack
cp .env.example .env
# Edit .env: set REPOS_PATH to absolute path of your repos folder
docker compose up -d

# One-time manual setup:
docker exec -it hermes-manager hermes setup   # configure model, channels, etc.
docker exec -it claude-worker claude login    # OAuth into Claude Pro
```

Cloud deploy uses a second compose file to swap bind-mount for git-clone:

```bash
docker compose -f docker-compose.yml -f docker-compose.cloud.yml up -d
```

---

## Configuration & Secrets

**`.env` (never committed):**

```bash
# Absolute path to repos folder on the host
# Local WSL: /mnt/c/Users/Youssef EL KHOURY/OneDrive/Documents/Git
# Cloud:     /home/ubuntu/repos
REPOS_PATH=
```

All other credentials (model API keys, channel tokens) are configured inside the container via `hermes setup` and stored in the `hermes-data` volume — they never touch the repo.

**Volume map:**

| Volume | Mount point | Contents |
|---|---|---|
| `hermes-data` (named) | `/root/.hermes` | Hermes config, memory, skills, logs |
| `claude-auth` (named) | `/root/.claude` | Claude Code OAuth token |
| `repos` (bind) | `/repos` | Git repos from `REPOS_PATH` |

---

## Repository Structure

```
hermes-stack/
├── docker-compose.yml          # base orchestration (local)
├── docker-compose.cloud.yml    # cloud overrides (git-clone repos)
├── .env.example                # template — REPOS_PATH only
├── .gitignore                  # excludes .env, volumes
├── README.md                   # deploy-anywhere guide
├── hermes/
│   └── Dockerfile              # Hermes Agent image
└── claude/
    └── Dockerfile              # Node + Claude Code CLI + git
```

---

## Data Flow

1. User sends a task to Hermes (via configured channel — Telegram, Discord, CLI, etc.)
2. Hermes decomposes and plans the task using its configured model
3. Hermes delegates implementation to Claude Code via:
   ```bash
   docker exec claude-worker claude -p "implement X in /repos/repo-name"
   ```
   The container name `claude-worker` is set via `container_name` in `docker-compose.yml` — this must stay stable for Hermes to target it reliably.
4. Claude Code executes against the repo using OAuth credentials
5. Results returned to Hermes, reported back to user via channel

---

## Error Handling

- If `claude-worker` is not running, Hermes exec will fail with a clear Docker error — user restarts with `docker compose up -d`
- If OAuth token expires, `claude login` must be re-run inside `claude-worker`
- Named volumes survive `docker compose down`; data is only lost with `docker compose down -v` (documented in README)

---

## Cloud Migration

Switching from local to cloud:
1. Push `hermes-stack` repo to new machine
2. Set `REPOS_PATH` in `.env` to cloud repos location (or use `docker-compose.cloud.yml` to git-clone instead)
3. `docker compose up -d`
4. Re-run `hermes setup` and `claude login` (or restore named volumes from backup)

The `docker-compose.cloud.yml` override replaces the bind-mount with a named volume + an init container that clones repos from GitHub on startup.

---

## Out of Scope

- Hermes model selection (user's choice at setup time)
- Channel configuration (Telegram, Discord, etc. — user's choice at setup time)
- Backup/restore of named volumes
- CI/CD pipeline for the stack itself
