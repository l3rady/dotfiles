#!/usr/bin/env bash
# Install Claude Code plugins declared in ~/.claude/settings.json
# (extraKnownMarketplaces / enabledPlugins). chezmoi re-runs this whenever
# the list below changes.
set -euo pipefail

command -v claude >/dev/null || { echo "claude not installed; skipping plugins"; exit 0; }

echo "==> Claude Code plugins"
claude plugin marketplace add mksglu/context-mode
claude plugin install context-mode@context-mode
