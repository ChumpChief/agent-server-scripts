#!/usr/bin/env bash
set -euo pipefail

echo "=== Microsandbox Host Setup ==="

# 1. Install curl (needed for nvm install)
if ! command -v curl &>/dev/null; then
  echo "Installing curl..."
  sudo apt-get update -qq
  sudo apt-get install -y -qq curl
  echo "curl installed."
else
  echo "curl is already installed: $(curl --version | head -1)"
fi

# 2. Install nvm
echo "Installing nvm..."
export NVM_DIR="$HOME/.nvm"

if [ -s "$NVM_DIR/nvm.sh" ]; then
  echo "nvm is already installed at $NVM_DIR"
else
  NVM_VERSION=$(curl -s https://api.github.com/repos/nvm-sh/nvm/tags | jq -r '.[0].name')
  echo "Latest nvm version: $NVM_VERSION"
  curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
fi

# Load nvm into the current shell
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

if command -v nvm &>/dev/null; then
  echo "nvm $(nvm --version) loaded successfully."
else
  echo "ERROR: Failed to install/load nvm." >&2
  exit 1
fi

# 3. Install latest Node LTS via nvm
echo "Installing latest Node.js LTS..."
nvm install --lts
echo "Node.js $(node --version) installed."

# 4. Install microsandbox globally via npm
echo "Installing microsandbox globally..."
npm install -g microsandbox

if command -v msb &>/dev/null; then
  echo "microsandbox installed successfully: $(msb --version 2>/dev/null || echo 'unknown version')"
else
  echo "ERROR: Failed to install microsandbox (msb not found on PATH)." >&2
  exit 1
fi

echo ""
echo "=== Host setup complete ==="
echo "  Node.js:  $(node --version)"
echo "  npm:      $(npm --version)"
echo "  nvm:      $(nvm --version)"
echo ""
echo "To make these tools available in your current shell, run:"
echo "  . ~/.bashrc"
