#!/usr/bin/env bash
# Bootstrap a fresh Ubuntu (WSL) install:
#   git clone https://github.com/<you>/dotfiles ~/.local/share/chezmoi
#   bash ~/.local/share/chezmoi/install.sh
# Safe to re-run: every step checks before it acts.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BREW_PREFIX=/home/linuxbrew/.linuxbrew

echo "==> Installing apt prerequisites for Homebrew and zsh"
sudo apt-get update
sudo apt-get install -y build-essential procps curl file git zsh

if [ ! -x "$BREW_PREFIX/bin/brew" ]; then
  echo "==> Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$("$BREW_PREFIX/bin/brew" shellenv)"

command -v chezmoi >/dev/null || brew install chezmoi

# Scan every commit to this repo for secrets (see .githooks/pre-commit)
git -C "$DOTFILES_DIR" config core.hooksPath .githooks

echo "==> Applying dotfiles from $DOTFILES_DIR"
chezmoi init --apply --source "$DOTFILES_DIR"

echo "==> Done. Open a new terminal (or run: exec zsh)."
