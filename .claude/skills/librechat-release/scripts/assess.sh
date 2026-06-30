#!/usr/bin/env bash
# Decide rebase vs clean re-apply BEFORE touching anything.
#
# Intersects "files the fork changed" with "files upstream changed since our last base".
# Little/no overlap -> a plain rebase will be clean (the default). Heavy overlap -> the fork's
# files collide with refactored upstream code, so clean re-apply is the saner path.
#
# Usage: bash assess.sh [upstream-ref]   (default: upstream/main)
set -uo pipefail

UPSTREAM_REF="${1:-upstream/main}"
git fetch upstream --quiet 2>/dev/null || true

merge_base="$(git merge-base "$UPSTREAM_REF" HEAD)"
echo "Last common base: $(git log --oneline -1 "$merge_base")"
echo "Target upstream:  $(git log --oneline -1 "$UPSTREAM_REF")"
echo ""

tmp_fork="$(mktemp)"; tmp_up="$(mktemp)"
trap 'rm -f "$tmp_fork" "$tmp_up"' EXIT
git diff --name-only "$merge_base" HEAD          | sort > "$tmp_fork"
git diff --name-only "$merge_base" "$UPSTREAM_REF" | sort > "$tmp_up"

overlap="$(comm -12 "$tmp_fork" "$tmp_up")"
n_fork=$(wc -l < "$tmp_fork" | tr -d ' ')
n_up=$(wc -l < "$tmp_up" | tr -d ' ')
n_overlap=$(printf '%s\n' "$overlap" | grep -c . || true)

echo "Fork changed $n_fork file(s); upstream changed $n_up file(s) since the base."
echo "Files touched by BOTH (the conflict surface): $n_overlap"
if [ "$n_overlap" -gt 0 ]; then printf '%s\n' "$overlap" | sed 's/^/    - /'; fi
echo ""

echo "=================================================================="
if [ "$n_overlap" -eq 0 ]; then
  echo "RECOMMENDATION: REBASE. Upstream didn't touch any fork file — replay should be conflict-free."
elif [ "$n_overlap" -le 4 ]; then
  echo "RECOMMENDATION: REBASE. Only $n_overlap overlapping file(s) — expect a few easy conflicts."
  echo "  If a single overlapping file was refactored across many fork commits, you may still"
  echo "  prefer clean re-apply. Abort the rebase and switch if it gets messy."
else
  echo "RECOMMENDATION: CLEAN RE-APPLY. $n_overlap fork files overlap heavily-changed upstream code —"
  echo "  replaying every fork commit against the refactor will be painful. Use clean-reapply.sh."
fi
echo "=================================================================="
