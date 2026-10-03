# Personal preferences (apply to every project)

Project-level instructions (a repo's own CLAUDE.md / AGENTS.md) take precedence where they conflict.

## Git

- **Conventional Commits for every commit:** `type(scope)!: summary`
  - Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.
  - Summary in the imperative mood, lower case, no trailing period, 72 characters or fewer.
  - The body explains *why*. Mark breaking changes with `!` and a `BREAKING CHANGE:` footer.
- **Branch names:** `<type>/<ticket>-<short-name>`, kebab-case.
  - Types: `feature`, `fix`, `hotfix`, `chore`, `docs`, `refactor`.
  - Ticket from the project's tracker: Jira style `feature/ABC-123-add-login`, or a GitHub
    issue number `fix/42-null-check`. For GitHub issues, create the branch with
    `gh issue develop <number> --name <branch>` so it's linked to the issue.
  - If you don't know the ticket, ask. Don't invent one.
- **Work is tracked in GitHub Issues and Projects** (one project per repo, e.g.
  https://github.com/users/l3rady/projects/1 for homelab). When asked to pick up work, start
  from the repo's open issues (`gh issue list`), move the item to In Progress, and reference the
  issue in the branch name and the PR (`Closes #<n>`).
- **Keep history linear: rebase, never merge the mainline into a branch.**
  - Bring a feature branch up to date with `git fetch` then `git rebase origin/main`
    (or `master`). Never merge `main`/`master` into a feature branch, not even to resolve
    conflicts: resolve them during the rebase.
  - `git pull` already rebases (`pull.rebase=true`).
  - After rebasing a branch that's already pushed, use `git push --force-with-lease`, never
    plain `--force`. Never force-push `main`/`master` or a branch someone else is working on.
  - Merge a PR by **fast-forwarding locally** so the signed commits land on the mainline
    unchanged: rebase the branch onto `origin/main`, then
    `git checkout main && git merge --ff-only <branch> && git push`. GitHub marks the PR merged.
    Don't use GitHub's "Rebase and merge" or "Squash and merge" buttons: GitHub rewrites the
    commits and they lose their signatures.
- Commits are SSH-signed automatically. Don't turn signing off (`--no-gpg-sign`,
  `-c commit.gpgsign=false`) and don't skip hooks (`--no-verify`) unless I ask.

## Environment

- Ubuntu on WSL2 (Windows host). Shell: zsh with oh-my-zsh and starship.
- Install software with **Homebrew first**; use apt only for what Homebrew doesn't have.
- Dotfiles are managed by **chezmoi** (public repo `l3rady/dotfiles`, source at
  `~/.local/share/chezmoi`). Change managed files in the chezmoi source (`chezmoi edit`, or
  edit the source and `chezmoi apply`), never only the target file. Package lists live in
  `home/.chezmoidata/packages.yaml`.

## Secrets

- Secrets live in **Bitwarden**. Never commit them, and never print secret values to the
  terminal or into a conversation (filter commands so only names, counts or yes/no reach
  the output).
- Secrets inside repos are encrypted with **sops + age** (key at
  `~/.config/sops/age/keys.txt`). Decrypt to a file or pipe, never to the screen.

## Working style

- For changes to running infrastructure (the Talos/Kubernetes homelab and anything like it):
  plan first, agree the plan, prefer dry runs, keep a rollback, and change one node or
  component at a time with health checks in between.
- Before anything destructive or hard to undo, say what will happen and wait for my go-ahead.
