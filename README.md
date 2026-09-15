# hermes-stack

[Hermes Agent](https://hermes-agent.nousresearch.com/) in Docker, running on a
Claude Pro/Max subscription. One container, one compose file.

## Prerequisites

- Docker Desktop installed and running
- **Windows/WSL2:** Docker Desktop → Settings → Resources → WSL Integration →
  enable your distro → Apply & Restart

## Setup

Clone it alongside your other repos — the folder it lands in becomes `/repos`
inside the container, so there is nothing to configure:

```bash
cd ~/your/repos/folder
git clone https://github.com/usfkhoury/hermes-stack
cd hermes-stack
docker compose up -d
```

If your repos live somewhere else, set `REPOS_MOUNT` in a `.env` file
(`cp .env.example .env`). Otherwise you don't need one.

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

## Hermes desktop app

The desktop app treats this container as a remote gateway — the same 9119 web
server the dashboard uses. In the app: **Settings → Gateways** (`Ctrl+,`), add

| Field | Value |
|---|---|
| Gateway URL | `http://localhost:9119` |
| Sign in | the `DASHBOARD_USER` / `DASHBOARD_PASSWORD` from `.env` |

The app probes both an HTTP and a WebSocket leg; a "Reachable" toast means
chat will actually work. If it connects but a session won't open, something is
blocking `/api/ws`.

`DASHBOARD_SECRET` is what keeps you signed in — without a stable value the
signing key is regenerated on every start and each restart logs the app out.

To connect the desktop app from **another machine**, publish the port beyond
loopback by changing the `ports` entry to `"9119:9119"`. Only do that on a
trusted LAN or a VPN such as Tailscale — username/password is not meant for
direct public-internet exposure. For a public host, use OAuth instead
(`hermes dashboard register`).

## Cloud deploy

Identical — clone `hermes-stack` into the folder that holds your repos and
`docker compose up -d`. To add repos later, clone them as siblings:

```bash
git clone https://github.com/user/my-project ../my-project
```

## Volumes

One volume: `hermes-data`, holding Hermes's config, Claude credentials,
memory and skills. `docker compose down` keeps it, so restarts are safe.

Your repos are a bind mount, not a volume — nothing here can delete them.

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

Then run the three setup commands again. Your repos are untouched.

## Notes

- Hermes does the coding itself, in this container, against `/repos`. There is
  no separate worker container and no Docker socket mount.
- The dashboard runs inside the same container and is published on
  `127.0.0.1:9119`, so it is reachable from this machine only. It stores
  credentials — to reach it remotely, tunnel with
  `ssh -L 9119:localhost:9119`, don't publish the port more widely.
