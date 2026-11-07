#!/usr/bin/env bash
# Claude Code PreToolUse hook (Bash): before a `git push`, block it if a commit
# being pushed has a first line over 72 characters, the limit commitlint's
# header-max-length enforces in CI. Exit 2 blocks the call and shows the reason
# to Claude; anything else lets it run.
#
# The commits checked are the ones the remote does not have yet: upstream..HEAD
# when the branch has an upstream, otherwise origin/HEAD..HEAD. A push that
# names other refs is not inspected beyond that; CI still checks everything.
set -uo pipefail

max=72
input=$(cat)
command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')

# Only git push, as a command of its own (not inside an echo or a commit message).
printf '%s' "$command" | grep -Eq '(^|[;&|(]|&&)[[:space:]]*git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+push\b' || exit 0

# Follow a leading `cd <dir> &&` or `git -C <dir>`, as the push runs there.
dir=$(printf '%s' "$command" | sed -nE 's/^[[:space:]]*cd[[:space:]]+([^;&|[:space:]]+).*/\1/p')
[ -n "$dir" ] || dir=$(printf '%s' "$command" | sed -nE 's/.*git[[:space:]]+-C[[:space:]]+([^[:space:]]+)[[:space:]]+push.*/\1/p')
dir=${dir:-$cwd}
dir=${dir/#\~/$HOME}
cd "$dir" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

if base=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null); then
	:
elif base=$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null); then
	:
else
	exit 0
fi

bad=$(git log --format='%h %s' "$base..HEAD" 2>/dev/null | awk -v max="$max" '{ line = substr($0, index($0, " ") + 1); if (length(line) > max) printf "  %s (%d characters): %s\n", $1, length(line), line }')
[ -z "$bad" ] && exit 0

{
	echo "Push blocked: these commits have a first line over $max characters, which commitlint rejects in CI:"
	echo "$bad"
	echo "Reword them (the whole line, type and scope included, must be $max characters or fewer), then push again."
} >&2
exit 2
