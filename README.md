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

## Setup

### 1. Prepare the host

```bash
./setup_host.sh
```

Installs Node.js (via nvm) and microsandbox globally. Run once.

### 2. Provision a sandbox

```bash
./sandbox.sh provision my-dev-agent
```

Creates a persistent sandbox with pi and the llama.cpp extension configured.

### 3. Sync code into/out of the sandbox

```bash
./sandbox.sh sync-in my-dev-agent    # host → sandbox ~/sync
./sandbox.sh sync-out my-dev-agent   # sandbox ~/sync → host
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
| `IMAGE` | `debian` | Base image |
| `CPUS` | `2` | CPU count |
| `MEMORY` | `2G` | Memory limit |
| `PACKAGES` | `neovim git curl jq` | APT packages to install |
| `GIT_USER_NAME` | `ChumpChief-bot` | Git user name |
| `GIT_USER_EMAIL` | `chump.chief.bot@gmail.com` | Git user email |
