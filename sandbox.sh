#!/usr/bin/env bash
#
# sandbox.sh — Provision a persistent Debian development sandbox
#              using Microsandbox (msb CLI).
#
# Usage:
#   ./sandbox.sh provision          Create the sandbox and run initial setup (interactive)
#   ./sandbox.sh sync-in <name>     Sync files from current dir into ~/sync in sandbox
#   ./sandbox.sh sync-out <name>    Sync files from ~/sync in sandbox to current dir
#
# All other operations use msb directly, e.g.:
#   msb ssh dev-sandbox
#   msb exec dev-sandbox -- nvim
#   msb stop dev-sandbox
#
set -euo pipefail

# ──────────────────────────────────────────────────────────────
# Configuration — tweak these to suit your setup
# ──────────────────────────────────────────────────────────────


IMAGE="${IMAGE:-debian}"
CPUS="${CPUS:-2}"
MEMORY="${MEMORY:-2G}"
OCI_UPPER_SIZE="${OCI_UPPER_SIZE:-8G}"

# Base network rules (llama.cpp rule added dynamically)
BASE_NET_RULES=("allow@host" "allow@public")

# Packages to install during provisioning (space-separated)
PACKAGES="${PACKAGES:-neovim git curl jq tmux}"

# Shell to use for interactive sessions
SHELL="${SHELL:-/bin/bash}"

# ──────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

info()    { echo -e "${GREEN}[sandbox]${NC} $*"; }
error()   { echo -e "${RED}[sandbox]${NC} $*" >&2; }
die()     { error "$@"; exit 1; }

# Check if sandbox exists (running or stopped)
sandbox_exists() {
    local name="${1:-${SANDBOX_NAME}}"
    msb list -q 2>/dev/null | grep -q "^${name}$"
}

# Wait for the sandbox to be fully booted and responsive
wait_for_ready() {
    local retries=30
    while [ $retries -gt 0 ]; do
        if msb exec "${SANDBOX_NAME}" -- echo ready &>/dev/null; then
            return 0
        fi
        retries=$((retries - 1))
        sleep 1
    done
    die "Sandbox did not become responsive in 30 seconds"
}

# Build the common msb create/run argument list from config
build_create_args() {
    local args=()
    args+=(-n "${SANDBOX_NAME}")
    args+=(-c "${CPUS}")
    args+=(-m "${MEMORY}")
    args+=(--oci-upper-size "${OCI_UPPER_SIZE}")
    args+=(--shell "${SHELL}")

    # Base network rules
    for rule in "${BASE_NET_RULES[@]}"; do
        args+=(--net-rule "${rule}")
    done

    # Llama.cpp server rule (format: allow@host:tcp:port)
    if [[ -n "${LLAMA_HOST:-}" ]]; then
        args+=(--net-rule "allow@${LLAMA_HOST}:tcp:${LLAMA_PORT}")
    fi

    # GitHub token secret (if provided)
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        args+=(--secret "GITHUB_TOKEN=ENV@api.github.com")
    fi

    printf '%s\n' "${args[@]}"
}

# Prompt user for provisioning values
prompt_config() {
    info "=== Provisioning ==="
    read -rp "[sandbox] Enter sandbox name: " SANDBOX_NAME
    [[ -z "${SANDBOX_NAME}" ]] && die "Sandbox name is required."

    info "=== AI Server ==="
    read -rp "[sandbox] Enter llama.cpp server host (e.g. example-server-name): " LLAMA_HOST
    read -rp "[sandbox] Enter llama.cpp server port (e.g. 8080): " LLAMA_PORT
    if [[ -n "${LLAMA_HOST:-}" ]]; then
        [[ -z "${LLAMA_PORT:-}" ]] && die "Server port is required when host is provided."
    fi

    info "=== GitHub Token (optional) ==="
    info "Enter GitHub classic PAT for the bot account (scopes: repo, workflow)"
    info "(leave blank to skip, Ctrl+C to abort)"
    read -rsp "[sandbox] Token: " GITHUB_TOKEN
    echo

    if [[ -n "${GITHUB_TOKEN}" ]]; then
        info "GITHUB_TOKEN set -> api.github.com, *.githubusercontent.com"
    fi
}

# ──────────────────────────────────────────────────────────────
# Commands
# ──────────────────────────────────────────────────────────────

cmd_provision() {
    # Collect configuration interactively
    prompt_config

    info "Provisioning sandbox '${SANDBOX_NAME}'..."

    # Ensure image is available
    info "Ensuring image '${IMAGE}' is cached..."
    msb image pull "${IMAGE}" -q 2>/dev/null || true

    # Guard against accidental destruction of an existing sandbox
    if sandbox_exists; then
        error "Sandbox '${SANDBOX_NAME}' already exists."
        error ""
        error "Options:"
        error "  msb remove ${SANDBOX_NAME}               # delete the existing sandbox"
        error "  ./sandbox.sh provision                    # create with a different name"
        exit 1
    fi

    # Build the create command with network rules
    local create_args=()
    while IFS= read -r arg; do
        create_args+=("$arg")
    done < <(build_create_args)

    # Create the sandbox (background mode = persistent)
    info "Creating sandbox (image=${IMAGE}, cpus=${CPUS}, mem=${MEMORY})..."
    msb create "${create_args[@]}" "${IMAGE}"

    # Wait for the sandbox agent to be ready
    info "Waiting for sandbox to boot..."
    wait_for_ready

    # Run initialization: apt update, upgrade, install packages
    info "Running apt update..."
    msb exec "${SANDBOX_NAME}" -- bash -c "apt-get update -y"

    info "Running apt upgrade..."
    msb exec "${SANDBOX_NAME}" -- bash -c "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y"

    if [[ -n "${PACKAGES}" ]]; then
        info "Installing packages: ${PACKAGES}"
        msb exec "${SANDBOX_NAME}" -- bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y ${PACKAGES}"
    fi

    # Install nvm (latest stable)
    info "Installing nvm..."
    msb exec "${SANDBOX_NAME}" -- bash -c '
      NVM_VERSION=$(curl -s https://api.github.com/repos/nvm-sh/nvm/tags | jq -r '.[0].name')
      curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
    '

    # Install Node.js LTS via nvm
    info "Installing Node.js LTS..."
    msb exec "${SANDBOX_NAME}" -- bash -l -c 'nvm install --lts'

    # Install pi
    info "Installing pi..."
    msb exec "${SANDBOX_NAME}" -- bash -l -c 'npm install -g --ignore-scripts @earendil-works/pi-coding-agent'

    # Install pi-llama-cpp extension
    info "Installing pi-llama-cpp..."
    msb exec "${SANDBOX_NAME}" -- bash -l -c 'pi install npm:pi-llama-cpp'

    # Configure git user identity
    info "Configuring git user identity..."
    msb exec "${SANDBOX_NAME}" -- bash -l -c 'git config --global user.name "${GIT_USER_NAME:-ChumpChief-bot}" && git config --global user.email "${GIT_USER_EMAIL:-chump.chief.bot@gmail.com}"'

    # Configure llama.cpp server URL in pi settings
    if [[ -n "${LLAMA_HOST:-}" ]]; then
        local LLAMA_URL="${LLAMA_HOST}:${LLAMA_PORT}"
        info "Configuring llama.cpp server URL..."
        msb exec "${SANDBOX_NAME}" -- bash -l -c "
          LLM_URL='http://${LLAMA_URL}'
          jq '.llamaServerUrl = \$url' --arg url \"\$LLM_URL\" ~/.pi/agent/settings.json > ~/.pi/agent/settings.json.tmp \\
            && mv ~/.pi/agent/settings.json.tmp ~/.pi/agent/settings.json
        "
    fi

    info "Sandbox '${SANDBOX_NAME}' provisioned successfully!"
}

cmd_sync_in() {
    local name="$1"
    info "Syncing current directory into ~/sync in sandbox '${name}'..."

    if ! sandbox_exists "$name"; then
        die "Sandbox '${name}' not found."
    fi

    msb exec -q "$name" -- bash -c 'mkdir -p ~/sync'
    tar cf - . | msb exec -q "$name" -- bash -c 'tar xf - -C ~/sync'
    info "Sync complete."
}

cmd_sync_out() {
    local name="$1"
    info "Syncing ~/sync from sandbox '${name}' into current directory..."

    if ! sandbox_exists "$name"; then
        die "Sandbox '${name}' not found."
    fi

    local home
    home=$(msb exec -q "$name" -- bash -c 'echo $HOME' | tr -d '\r\n')
    msb cp -q "$name:${home}/sync/." . 2>/dev/null
    info "Sync complete."
}

# ──────────────────────────────────────────────────────────────
# Main dispatch
# ──────────────────────────────────────────────────────────────

main() {
    local cmd="${1:-help}"
    shift || true

    if [[ "$cmd" == "provision" ]]; then
        if [[ $# -ne 0 ]]; then
            die "Usage: ./sandbox.sh provision"
        fi
    fi

    case "${cmd}" in
        provision)  cmd_provision ;;
        sync-in)    cmd_sync_in "$@" ;;
        sync-out)   cmd_sync_out "$@" ;;
        help|--help|-h)
            sed -n '2,15p' "$0" | sed 's/^# \?//'
            ;;
        *)
            die "Unknown command: ${cmd}"
            ;;
    esac
}

main "$@"
