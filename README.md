# hermes-stack

[Hermes Agent](https://hermes-agent.nousresearch.com/) in Docker, running on a
Claude Pro/Max subscription. One container, one compose file.

## Prerequisites

- Docker Desktop installed and running
- **Windows/WSL2:** Docker Desktop → Settings → Resources → WSL Integration →
  enable your distro → Apply & Restart

## Setup

```bash
git clone https://github.com/usfkhoury/hermes-stack
cd hermes-stack
cp .env.example .env
# Edit .env: REPOS_MOUNT = absolute path of your repos folder, in the form
# matching the shell you run compose from — C:/Users/... from Windows,
# /mnt/c/Users/... from WSL. Leave it empty to use the named repos-data
# volume instead (cloud deploys).
docker compose up -d
```

Then, once:

```bash
# 1. Log in with your Claude Pro/Max subscription.
#    Prints a claude.ai link; authorize, then paste the code back.
docker exec -it hermes hermes auth add anthropic --type oauth

# 2. Pick Anthropic + your Claude model as the default.
docker exec -it hermes hermes model

# 3. Configure messaging platforms (Discord, Telegram, ...) — optional.
docker exec -it hermes hermes setup
```

Dashboard: http://localhost:9119

Everything persists in the `hermes-data` volume across `docker compose
down / up`.

## Cloud deploy

Same steps, but leave `REPOS_MOUNT` empty so repos live in the `repos-data`
volume, and clone into it after startup:

```bash
docker exec hermes git clone https://github.com/user/my-project /repos/my-project
```

## Volumes

| Volume | Contents | Safe to `down -v`? |
|---|---|---|
| `hermes-data` | Hermes config, Claude credentials, memory, skills | No — wipes config and forces re-login |
| `repos-data` | Repos (only when `REPOS_MOUNT` is empty) | No — wipes cloned repos |

`docker compose down` on its own keeps both, so restarts are safe.

## Updating

```bash
docker compose pull && docker compose up -d
```

## Reset to a clean slate

Wipes Hermes's config, memory, and every stored credential — the Claude
subscription login, any API keys, any messaging tokens. Not reversible, so
copy anything you still want out of the volume first.

```bash
docker compose down -v
docker compose up -d
```

Then run the three setup commands again. Repos are untouched when
`REPOS_MOUNT` points at a host folder; they live outside the volumes.

## Notes

- Hermes does the coding itself, in this container, against `/repos`. There is
  no separate worker container and no Docker socket mount.
- The dashboard runs inside the same container and is published on
  `127.0.0.1:9119`, so it is reachable from this machine only. It stores
  credentials — to reach it remotely, tunnel with
  `ssh -L 9119:localhost:9119`, don't publish the port more widely.
