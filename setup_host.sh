#!/usr/bin/env bash
set -euo pipefail

echo "=== Microsandbox Host Setup ==="

# 0. Update system packages
echo "Updating system packages..."
sudo apt-get update -qq
sudo apt-get upgrade -y -qq
echo "System packages updated."

# 1. Install curl (needed for nvm install) and git
if ! command -v curl &>/dev/null || ! command -v git &>/dev/null; then
  echo "Installing curl and git..."
  sudo apt-get install -y -qq curl git
  echo "curl and git installed."
else
  echo "curl is already installed: $(curl --version | head -1)"
  echo "git is already installed: $(git --version)"
fi

# Clean up orphaned packages from upgrade and install
sudo apt-get autoremove -y -qq 2>/dev/null || true

# 2. Install / update nvm
export NVM_DIR="$HOME/.nvm"

NVM_VERSION=$(curl -s https://api.github.com/repos/nvm-sh/nvm/tags | jq -r '.[0].name')
echo "Latest nvm version: $NVM_VERSION"
curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash

# Load nvm into the current shell
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

if command -v nvm &>/dev/null; then
  echo "nvm $(nvm --version) loaded successfully."
else
  echo "ERROR: Failed to install/load nvm." >&2
  exit 1
fi

# 3. Install / update Node.js LTS and set as default
echo "Installing latest Node.js LTS..."
nvm install --lts
nvm alias default lts/*
nvm use default
echo "Node.js $(node --version) installed and set as default."

# 4. Install / update microsandbox globally via npm
echo "Installing microsandbox globally..."
npm install -g microsandbox@latest

if command -v msb &>/dev/null; then
  echo "microsandbox installed successfully: $(msb --version 2>/dev/null || echo 'unknown version')"
else
  echo "ERROR: Failed to install microsandbox (msb not found on PATH)." >&2
  exit 1
fi

# 5. Clone agent-server-scripts for local use
echo "Cloning agent-server-scripts..."
mkdir -p ~/git
cd ~/git
if [ -d "agent-server-scripts" ]; then
  echo "agent-server-scripts already exists in ~/git"
else
  git clone https://github.com/ChumpChief/agent-server-scripts.git
  echo "Cloned to ~/git/agent-server-scripts"
fi

echo ""
echo "=== Host setup complete ==="
echo "  Node.js:  $(node --version)"
echo "  npm:      $(npm --version)"
echo "  nvm:      $(nvm --version)"
echo "  Scripts:  ~/git/agent-server-scripts"
echo ""
echo "To make these tools available in your current shell, run:"
echo "  . ~/.bashrc"
