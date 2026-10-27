#!/usr/bin/env bash
# Publishes a folder of CI evidence to the ci-evidence branch under <sha>/<name>/,
# so it can be fetched with plain git (artifact storage is not reachable everywhere).
# usage: publish-evidence.sh <source-dir> <name>
set -euo pipefail
src=$(cd "$1" && pwd)
name=$2
sha=${GITHUB_SHA::7}
work=$(mktemp -d)

git config --global user.name "void-ci"
git config --global user.email "void-ci@users.noreply.github.com"

for attempt in 1 2 3 4 5; do
  rm -rf "$work" && mkdir -p "$work"
  if git ls-remote --exit-code origin ci-evidence >/dev/null 2>&1; then
    git fetch -q --depth 1 origin ci-evidence
    git worktree add -q --detach "$work" FETCH_HEAD
  else
    git worktree add -q --orphan -b "ci-evidence-$attempt" "$work"
  fi
  mkdir -p "$work/$sha/$name"
  cp -R "$src"/. "$work/$sha/$name/"
  (
    cd "$work"
    git add -A
    git commit -q -m "evidence: $sha $name (${GITHUB_REF_NAME})" || exit 0
    git push -q origin HEAD:ci-evidence
  ) && { echo "published $sha/$name"; git worktree remove --force "$work"; exit 0; }
  git worktree remove --force "$work" || true
  sleep $((attempt * 3))
done
echo "could not publish evidence" >&2
exit 1
