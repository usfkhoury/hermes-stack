# Hermes Stack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy Hermes Agent (manager) + Claude Code CLI (worker) as a Dockerized stack, managed in a GitHub repo that deploys identically on any machine with `docker compose up`.

**Architecture:** Two Docker Compose services on a shared bridge network. `hermes-gateway` and `hermes-dashboard` use the pre-built `nousresearch/hermes-agent:latest` image. `claude-worker` is a custom Node.js image with Claude Code CLI installed. Hermes communicates with Claude Code via `docker exec claude-worker claude -p "..."` using the mounted Docker socket. A single `docker-compose.yml` handles both local and cloud via `${REPOS_MOUNT:-repos-data}`: set it to a host path for local (bind mount), leave it empty for cloud (named volume). All state persists in named volumes.

**Tech Stack:** Docker Compose, `nousresearch/hermes-agent:latest`, Node.js 22 (slim), `@anthropic-ai/claude-code` npm package, GitHub REST API

---

## File Map

| File | Purpose |
|---|---|
| `.gitignore` | Exclude `.env` from git |
| `.env.example` | Template — `REPOS_MOUNT` is the only variable |
| `claude/Dockerfile` | Node 22-slim + git + Claude Code CLI, kept alive with `tail -f /dev/null` |
| `docker-compose.yml` | Single orchestration file; handles local (bind mount) and cloud (named volume) via env var |
| `README.md` | Deploy-anywhere guide covering local (WSL) and cloud |

---

## Task 1: Enable Docker Desktop WSL2 Integration

**Files:** none — one-time manual setup

- [ ] **Step 1: Open Docker Desktop on Windows**

  In the Windows system tray, right-click the Docker whale icon → "Dashboard"

- [ ] **Step 2: Enable WSL integration**

  Settings → Resources → WSL Integration → toggle on your WSL distro (e.g. Ubuntu) → "Apply & Restart"

- [ ] **Step 3: Verify Docker is accessible in WSL**

  ```bash
  docker ps
  ```
  Expected: an empty table (no error). If you still see "command not found", run `wsl --shutdown` in PowerShell, then reopen WSL.

---

## Task 2: Create .gitignore and .env.example

**Files:**
- Create: `.gitignore`
- Create: `.env.example`

- [ ] **Step 1: Write .gitignore**

  Create `hermes-stack/.gitignore`:
  ```
  .env
  ```

- [ ] **Step 2: Write .env.example**

  Create `hermes-stack/.env.example`:
  ```bash
  # Path to your repos folder on the host machine.
  # Local WSL: set to absolute path, e.g.:
  #   REPOS_MOUNT=/mnt/c/Users/Youssef EL KHOURY/OneDrive/Documents/Git
  # Cloud: leave empty — falls back to a named Docker volume.
  #   Populate after startup: docker exec claude-worker git clone <url> /repos/<name>
  REPOS_MOUNT=
  ```

- [ ] **Step 3: Commit**

  ```bash
  cd "/mnt/c/Users/Youssef EL KHOURY/OneDrive/Documents/Git/hermes-stack"
  git add .gitignore .env.example
  git commit -m "feat: add .gitignore and .env.example"
  ```

---

## Task 3: Create Claude Code Dockerfile

**Files:**
- Create: `claude/Dockerfile`

- [ ] **Step 1: Write the Dockerfile**

  Create `hermes-stack/claude/Dockerfile`:
  ```dockerfile
  FROM node:22-slim

  RUN apt-get update && apt-get install -y \
      git \
      ca-certificates \
      && rm -rf /var/lib/apt/lists/*

  RUN npm install -g @anthropic-ai/claude-code

  WORKDIR /repos

  CMD ["tail", "-f", "/dev/null"]
  ```

  **Why `tail -f /dev/null`:** Keeps the container alive so Hermes can `docker exec` into it at any time. Claude Code is invoked on demand, not as a long-running process.

- [ ] **Step 2: Commit**

  ```bash
  cd "/mnt/c/Users/Youssef EL KHOURY/OneDrive/Documents/Git/hermes-stack"
  git add claude/Dockerfile
  git commit -m "feat: add Claude Code worker Dockerfile"
  ```

---

## Task 4: Create docker-compose.yml

**Files:**
- Create: `docker-compose.yml`

- [ ] **Step 1: Write docker-compose.yml**

  Create `hermes-stack/docker-compose.yml`:
  ```yaml
  networks:
    hermes-net:
      driver: bridge

  volumes:
    hermes-data:
    claude-auth:
    repos-data:

  services:
    hermes-gateway:
      image: nousresearch/hermes-agent:latest
      container_name: hermes-gateway
      command: gateway run
      restart: unless-stopped
      networks:
        - hermes-net
      volumes:
        - hermes-data:/opt/data
        - /var/run/docker.sock:/var/run/docker.sock
      environment:
        HERMES_UID: "10000"
        HERMES_GID: "10000"

    hermes-dashboard:
      image: nousresearch/hermes-agent:latest
      container_name: hermes-dashboard
      command: dashboard --host 127.0.0.1 --no-open --insecure
      restart: unless-stopped
      depends_on:
        - hermes-gateway
      networks:
        - hermes-net
      ports:
        - "127.0.0.1:9119:9119"
      volumes:
        - hermes-data:/opt/data
      environment:
        HERMES_UID: "10000"
        HERMES_GID: "10000"

    claude-worker:
      build: ./claude
      container_name: claude-worker
      restart: unless-stopped
      networks:
        - hermes-net
      volumes:
        - claude-auth:/root/.claude
        - ${REPOS_MOUNT:-repos-data}:/repos
  ```

  **Key notes:**
  - `${REPOS_MOUNT:-repos-data}`: if `REPOS_MOUNT` is set to a host path → bind mount; if empty or unset → uses the `repos-data` named volume. This single file handles both local and cloud.
  - `hermes-gateway` gets the Docker socket so it can `docker exec claude-worker` when delegating tasks.
  - `container_name: claude-worker` must stay stable — Hermes targets this name.
  - `HERMES_UID/GID: 10000` matches the non-root `hermes` user in the official image.
  - No `network_mode: host` — not supported on Docker Desktop for Windows.

- [ ] **Step 2: Commit**

  ```bash
  cd "/mnt/c/Users/Youssef EL KHOURY/OneDrive/Documents/Git/hermes-stack"
  git add docker-compose.yml
  git commit -m "feat: add docker-compose.yml"
  ```

---

## Task 5: Create README.md

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README.md**

  Create `hermes-stack/README.md`:
  ```markdown
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
  ```

- [ ] **Step 2: Commit**

  ```bash
  cd "/mnt/c/Users/Youssef EL KHOURY/OneDrive/Documents/Git/hermes-stack"
  git add README.md
  git commit -m "feat: add README with local and cloud deployment guide"
  ```

---

## Task 6: Build and smoke-test the stack

**Prerequisite:** Task 1 (Docker Desktop WSL integration) must be complete — `docker ps` must work in WSL before running any step here.

- [ ] **Step 1: Set REPOS_MOUNT in .env**

  ```bash
  echo 'REPOS_MOUNT=/mnt/c/Users/Youssef EL KHOURY/OneDrive/Documents/Git' \
    > "/mnt/c/Users/Youssef EL KHOURY/OneDrive/Documents/Git/hermes-stack/.env"
  ```

- [ ] **Step 2: Build the claude-worker image**

  ```bash
  cd "/mnt/c/Users/Youssef EL KHOURY/OneDrive/Documents/Git/hermes-stack"
  docker compose build claude-worker
  ```
  Expected: `Successfully built` with no errors. Takes ~2 min on first run (pulls node:22-slim, installs Claude Code).

- [ ] **Step 3: Pull the Hermes image**

  ```bash
  docker compose pull hermes-gateway hermes-dashboard
  ```
  Expected: `nousresearch/hermes-agent:latest` pulled with no errors.

- [ ] **Step 4: Start the stack**

  ```bash
  docker compose up -d
  ```
  Expected:
  ```
  ✔ Container hermes-gateway    Started
  ✔ Container claude-worker     Started
  ✔ Container hermes-dashboard  Started
  ```

- [ ] **Step 5: Verify all containers are running**

  ```bash
  docker compose ps
  ```
  Expected: all three containers show `running` status.

- [ ] **Step 6: Verify Claude Code is installed in the worker**

  ```bash
  docker exec claude-worker claude --version
  ```
  Expected: a version string like `1.x.x`.

- [ ] **Step 7: Verify Hermes gateway is alive**

  ```bash
  docker compose logs hermes-gateway --tail 20
  ```
  Expected: startup logs, no crash or immediate exit.

---

## Task 7: Create GitHub repo and push

- [ ] **Step 1: Create the repo via GitHub API**

  ```bash
  curl -s -X POST \
    -H "Authorization: token YOUR_GITHUB_PAT" \
    -H "Content-Type: application/json" \
    -d '{"name":"hermes-stack","description":"Hermes Agent + Claude Code worker, Dockerized","private":false}' \
    https://api.github.com/user/repos \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('html_url', d.get('message','')))"
  ```
  Expected: `https://github.com/usfkhoury/hermes-stack`

- [ ] **Step 2: Add remote and push**

  ```bash
  cd "/mnt/c/Users/Youssef EL KHOURY/OneDrive/Documents/Git/hermes-stack"
  git remote add origin https://usfkhoury:YOUR_GITHUB_PAT@github.com/usfkhoury/hermes-stack.git
  git push -u origin main
  ```
  Expected: `Branch 'main' set up to track remote branch 'main' from 'origin'.`

- [ ] **Step 3: Remove the token from the remote URL**

  ```bash
  git remote set-url origin https://github.com/usfkhoury/hermes-stack.git
  ```

- [ ] **Step 4: Verify**

  Open https://github.com/usfkhoury/hermes-stack — all files should be visible.
