# Agent Server Scripts

Scripts for setting up a host machine and provisioning isolated [microsandbox](https://docs.microsandbox.dev) containers that run [pi](https://github.com/earendil-works/pi-coding-agent) development agents against a local LLM.

## Architecture

```
Host Machine ──(microsandbox)──► Sandboxed Dev Agent
                                    │
                                    └──► llama.cpp (external GPU server)
```

- The host runs **microsandbox** (msb), which manages lightweight OCI containers
- Each sandbox is a Debian container with Node.js, neovim, and pi pre-installed
- An external llama.cpp server provides the LLM backend for the agent

## Quick Start

On a bare host, bootstrap everything in one line:

```bash
wget -qO- https://raw.githubusercontent.com/ChumpChief/agent-server-scripts/main/setup_host.sh | bash
```

This installs `curl`, `git`, Node.js (via nvm), microsandbox, and clones this repo into `~/git/agent-server-scripts`. After setup, `cd ~/git/agent-server-scripts` and run `./sandbox.sh provision`.

## Setup

### 1. Prepare the host

```bash
./setup_host.sh
```

Updates system packages, then installs `curl`, `git`, Node.js (via nvm, latest LTS), and microsandbox globally. Also clones this repo into `~/git/agent-server-scripts`. Re-run anytime to update.

### 2. Provision a sandbox

```bash
./sandbox.sh provision
```

Runs an interactive prompt that collects:

1. **Sandbox name** — unique identifier for the container
2. **AI server** — host and port of your llama.cpp server
3. **GitHub token** (optional) — classic PAT with `repo` and `workflow` scopes

Provisioning installs the following inside the sandbox:
- APT packages (neovim, git, curl, jq, tmux)
- nvm + Node.js (latest LTS)
- [pi](https://github.com/earendil-works/pi-coding-agent) (global npm install)
- `pi-llama-cpp` extension
- Git user identity (configurable via env vars)
- llama.cpp server URL in pi settings

### 3. Sync code into/out of the sandbox

```bash
./sandbox.sh sync-in <name>    # host current dir → sandbox ~/sync
./sandbox.sh sync-out <name>   # sandbox ~/sync → host current dir
```

## Day-to-Day

After provisioning, use `msb` directly for routine operations:

```bash
msb ssh my-dev-agent      # interactive shell
msb exec my-dev-agent -- nvim
msb stop my-dev-agent
```

## Configuration

Key settings in `sandbox.sh` are overridable via environment variables:

| Variable | Default | Description |
|---|---|---|
| `IMAGE` | `debian` | Base OCI image |
| `CPUS` | `2` | CPU count |
| `MEMORY` | `2G` | Memory limit |
| `OCI_UPPER_SIZE` | `8G` | OCI upper filesystem size |
| `PACKAGES` | `neovim git curl jq tmux` | APT packages to install |
| `SHELL` | `/bin/bash` | Default shell for interactive sessions |
| `GIT_USER_NAME` | `ChumpChief-bot` | Git user name |
| `GIT_USER_EMAIL` | `chump.chief.bot@gmail.com` | Git user email |

The `provision` command also prompts interactively for:

| Prompt | Env override | Description |
|---|---|---|
| Sandbox name | — | Unique container name |
| llama.cpp host | `LLAMA_HOST` | Hostname of the llama.cpp server |
| llama.cpp port | `LLAMA_PORT` | Port of the llama.cpp server |
| GitHub token | `GITHUB_TOKEN` | Classic PAT for repo/workflow access |
