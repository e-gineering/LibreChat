#!/usr/bin/env bash
# Clean re-apply of the fork's customizations onto a new upstream version.
#
# Resets dev to <upstream-ref> and lays the fork's NET changes back on top as a 3-way patch,
# instead of replaying messy historical fork commits. Creates a backup branch first and stops
# on conflicts for manual resolution.
#
# Usage: bash clean-reapply.sh [upstream-ref]   (default: upstream/main)
set -euo pipefail

UPSTREAM_REF="${1:-upstream/main}"

# 1. Safety: must be on a branch with no uncommitted *tracked* changes (untracked junk is fine).
branch="$(git rev-parse --abbrev-ref HEAD)"
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: you have uncommitted tracked changes. Commit or stash them first." >&2
  exit 1
fi
echo "On branch: $branch"

git fetch --all --quiet

merge_base="$(git merge-base "$UPSTREAM_REF" HEAD)"
echo "Merge-base with $UPSTREAM_REF: $(git log --oneline -1 "$merge_base")"

# 2. Backup branch (timestamped so re-runs don't collide).
backup="${branch}-backup-pre-reapply-$(date +%Y%m%d-%H%M%S)"
git branch "$backup" HEAD
echo "Backup branch created: $backup -> $(git rev-parse --short HEAD)"

# 3. Capture the fork's net change (binary-safe), then reset onto upstream.
patch="$(git rev-parse --git-dir)/fork-reapply.patch"
git diff --binary "$merge_base" HEAD > "$patch"
echo "Fork patch: $(wc -l < "$patch") lines -> $patch"

echo "Resetting $branch to $UPSTREAM_REF ..."
git reset --hard "$UPSTREAM_REF"

# 4. Re-apply with 3-way merge. Don't exit on conflicts — we want to report them.
set +e
git apply --3way --whitespace=nowarn "$patch"
apply_status=$?
set -e

echo ""
echo "=================================================================="
if [ "$apply_status" -eq 0 ]; then
  echo "Patch applied cleanly. Now run verify.sh and review the diff."
else
  echo "Patch applied WITH CONFLICTS. Resolve the files below, then verify.sh."
fi
conflicts="$(git diff --name-only --diff-filter=U || true)"
if [ -n "$conflicts" ]; then
  echo ""
  echo "Conflicted files:"
  echo "$conflicts" | sed 's/^/  - /'
fi
echo ""
echo "Fork footprint so far ($(git diff "$UPSTREAM_REF" --name-only | wc -l) files):"
git diff "$UPSTREAM_REF" --stat | tail -40
echo "=================================================================="
echo "Backup: $backup   |   Restore with: git reset --hard $backup"
