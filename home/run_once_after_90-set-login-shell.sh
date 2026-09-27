#!/usr/bin/env bash
# Make apt's zsh the login shell (brew's zsh isn't in /etc/shells).
set -euo pipefail
if [ "$(getent passwd "$USER" | cut -d: -f7)" != /usr/bin/zsh ]; then
  sudo chsh -s /usr/bin/zsh "$USER"
fi
