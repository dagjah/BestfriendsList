#!/usr/bin/env bash
# Run from a normal WSL terminal with GitHub authentication configured.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
repository='https://github.com/dagjah/BestfriendsList.git'
transport=''
case "${1:-}" in
    '') ;;
    --ssh) repository='git@github.com:dagjah/BestfriendsList.git'; transport=ssh ;;
    --https) transport=https ;;
    *) echo 'Usage: bash scripts/connect-github.sh [--ssh|--https]' >&2; exit 2 ;;
esac
if [[ $# -gt 1 ]]; then
    echo 'Usage: bash scripts/connect-github.sh [--ssh|--https]' >&2
    exit 2
fi
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    git init -b main
fi
if ! git var GIT_AUTHOR_IDENT >/dev/null 2>&1; then
    echo 'Set your preferred Git user.name and user.email, then run this script again.' >&2
    exit 1
fi
if git remote get-url origin >/dev/null 2>&1; then
    remote_url="$(git remote get-url origin)"
    case "$remote_url" in
        https://github.com/dagjah/BestfriendsList|https://github.com/dagjah/BestfriendsList.git|git@github.com:dagjah/BestfriendsList.git) ;;
        *) echo 'Origin points elsewhere. Review git remote -v before proceeding.' >&2; exit 1 ;;
    esac
    if [[ -n "$transport" ]]; then
        git remote set-url origin "$repository"
    fi
else
    git remote add origin "$repository"
fi
branch="$(git symbolic-ref --short HEAD)"
if [[ "$branch" != main ]]; then
    echo 'Expected branch main. Review the current branch before proceeding.' >&2
    exit 1
fi
# Read remote history first. Never overwrite an initialized GitHub repository.
if ! remote_main="$(git ls-remote --heads origin main)"; then
    echo 'Could not access GitHub. For SSH, verify your WSL key is added to GitHub and run ssh -T git@github.com.' >&2
    echo 'For HTTPS, use a credential manager or personal access token, not your account password.' >&2
    exit 1
fi
if [[ -n "$remote_main" ]]; then
    git fetch origin main
    if ! git rev-parse --verify HEAD >/dev/null 2>&1 || ! git merge-base --is-ancestor origin/main HEAD; then
        echo 'GitHub already has commits absent locally. Integrate origin/main before retrying; do not force-push.' >&2
        exit 1
    fi
fi
# Stage only project sources and development files; no credentials or ZIPs.
git add -- .github .gitattributes .gitignore AGENTS.md BestfriendsList.lua BestfriendsList.toc KillList.toc Lists.lua Factions.lua PartySync.lua README.md CHANGELOG.md LICENSE assets docs scripts tests
# Reject previously staged unrelated files instead of committing them silently.
while IFS= read -r -d '' staged; do
    case "$staged" in
        .github/*|.gitattributes|.gitignore|AGENTS.md|BestfriendsList.lua|BestfriendsList.toc|KillList.toc|Lists.lua|Factions.lua|PartySync.lua|README.md|CHANGELOG.md|LICENSE|assets/*|docs/*|scripts/*|tests/*) ;;
        *) echo 'Unrelated staged files found. Review git diff --cached before retrying.' >&2; exit 1 ;;
    esac
done < <(git diff --cached --name-only -z)
if ! git diff --cached --quiet; then
    git commit -m 'Prepare BestfriendsList and release automation'
fi
git push -u origin main
echo 'Source pushed. Check https://github.com/dagjah/BestfriendsList/actions'
echo 'No release tag was created, and this script does not upload to CurseForge.'
