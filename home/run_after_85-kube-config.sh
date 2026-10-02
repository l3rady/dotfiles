#!/usr/bin/env bash
# Create ~/.kube/config for the Talos cluster when it's missing, by asking the
# cluster for an admin kubeconfig. Nothing is stored in the repo, and each
# machine gets its own client certificate. Never fails the apply.
set -uo pipefail

kubeconfig="$HOME/.kube/config"
talosconfig="$HOME/.talos/config"
talosctl="$HOME/.local/bin/talosctl"

[ -f "$kubeconfig" ] && exit 0
if [ ! -f "$talosconfig" ] || [ ! -x "$talosctl" ]; then
  echo "kubeconfig: skipped, needs ~/.talos/config (unlock Bitwarden, then chezmoi apply)"
  exit 0
fi

node=$("$talosctl" --talosconfig "$talosconfig" config info -o json 2>/dev/null \
  | python3 -c 'import json,sys; e=json.load(sys.stdin).get("endpoints") or []; print(e[0] if e else "")')
if [ -z "$node" ]; then
  echo "kubeconfig: skipped, no endpoints in ~/.talos/config"
  exit 0
fi

if timeout 30 "$talosctl" --talosconfig "$talosconfig" --nodes "$node" kubeconfig "$kubeconfig" >/dev/null 2>&1; then
  chmod 600 "$kubeconfig"
  echo "kubeconfig: created ~/.kube/config from $node"
else
  echo "kubeconfig: skipped, cluster not reachable at $node (re-run chezmoi apply on the home network)"
fi
exit 0
