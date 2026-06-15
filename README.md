# hermes-stack

Hermes Agent (manager) + Claude Code (worker), fully Dockerized.
Deploy anywhere with `docker compose up`.

## What's inside

| Container | Image | Role |
|---|---|---|
| `hermes-gateway` | `nousresearch/hermes-agent:latest` | Hermes orchestrator + gateway |
| `hermes-dashboard` | `nousresearch/hermes-agent:latest` | Web UI at localhost:9119 |
| `claude-worker` | built from `./claude` | Claude Code CLI executor |

Hermes delegates coding tasks to Claude Code by spawning fresh containers from the `hermes-stack-claude-worker` image via the Docker socket. The terminal backend, image name, and volume mounts are pre-configured in `docker-compose.yml` — no manual terminal setup needed.

## Prerequisites

- Docker Desktop installed and running
- **Windows/WSL2:** Docker Desktop → Settings → Resources → WSL Integration → enable your distro → Apply & Restart

## Local setup (WSL / Linux / Mac)

```bash
git clone https://github.com/usfkhoury/hermes-stack
cd hermes-stack
cp .env.example .env
# Edit .env:
#   REPOS_MOUNT  — absolute path of your repos folder, e.g. /path/to/your/repos
#   CLAUDE_MODEL — (optional) Claude Code model the worker uses; leave empty for
#                  the default claude-sonnet-4-6 (aliases: sonnet, opus, haiku, fable)
docker compose build claude-worker
docker compose up -d
```

### First-time setup (run once after `docker compose up -d`)

**Step 1 — Configure Hermes model and messaging:**
```bash
docker exec -it hermes-gateway hermes setup
```
Configure your model (e.g. Gemini 2.5 Flash via Google AI Studio API key) and any messaging platforms (Discord, Telegram, etc.).

> **Terminal backend:** The Docker terminal backend is already pre-configured via `docker-compose.yml`. When hermes setup asks about terminal/execution environment, you can skip it or accept the defaults — the env vars in docker-compose.yml take precedence on a fresh deploy and the correct image and volumes are already set.
>
> **After hermes setup**, run this once to apply the correct volume mounts to Hermes's config (hermes setup resets them to empty):
> ```bash
> docker exec hermes-gateway python3 -c "
> import sys, os, yaml
> sys.path.insert(0, '/opt/hermes')
> from hermes_cli.config import get_hermes_home
> home = get_hermes_home()
> cfg_path = home / 'config.yaml'
> with open(cfg_path) as f:
>     cfg = yaml.safe_load(f)
> repos = os.environ.get('REPOS_MOUNT', 'hermes-stack_repos-data')
> cfg.setdefault('terminal', {})['docker_volumes'] = [
>     'hermes-stack_claude-auth:/root/.claude',
>     f'{repos}:/repos',
> ]
> with open(cfg_path, 'w') as f:
>     yaml.dump(cfg, f, default_flow_style=False, allow_unicode=True)
> print('docker_volumes configured')
> "
> docker compose restart hermes-gateway
> ```

**Step 2 — Authenticate Claude Code:**
```bash
docker exec -it claude-worker claude login
```
Copy the printed URL into your browser, complete the OAuth flow, then return here. The token is saved to the `claude-auth` volume and persists across restarts.

Everything persists across `docker compose down / up` via named volumes.

### Access the dashboard

Open http://localhost:9119

## Cloud setup

```bash
git clone https://github.com/usfkhoury/hermes-stack
cd hermes-stack
cp .env.example .env
# Leave REPOS_MOUNT empty — falls back to the named Docker volume repos-data
docker compose build claude-worker
docker compose up -d
```

Clone repos into the volume after startup:
```bash
docker exec claude-worker git clone https://github.com/user/my-project /repos/my-project
```

Then run the same first-time setup steps (hermes setup + volume fix + claude login).

## Volumes

| Volume | Contents | Safe to `down -v`? |
|---|---|---|
| `hermes-data` | Hermes config, memory, skills | No — wipes all Hermes config |
| `claude-auth` | Claude Code OAuth token | No — forces re-login |
| `repos-data` | Repos (cloud only) | No — wipes cloned repos |

> **Warning:** `docker compose down -v` deletes ALL volumes. Use it only to fully reset the stack.

## Updating

```bash
# Update Hermes
docker compose pull hermes-gateway hermes-dashboard && docker compose up -d

# Rebuild Claude Code worker (picks up new @anthropic-ai/claude-code version)
docker compose build --no-cache claude-worker && docker compose up -d claude-worker
```

## How it works

`hermes-gateway` receives tasks via Discord (or other configured channels) and uses Hermes's Docker terminal backend to spawn short-lived containers from `hermes-stack-claude-worker`. Each spawned container gets:

- `hermes-stack_claude-auth:/root/.claude` — Claude Code OAuth token
- `<REPOS_MOUNT or repos-data>:/repos` — your repos to work on

The permanent `claude-worker` container (running `tail -f /dev/null`) exists solely to keep the image built and available locally so Hermes can spawn from it instantly.
