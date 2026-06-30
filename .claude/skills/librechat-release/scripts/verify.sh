#!/usr/bin/env bash
# Read-only pre-commit / pre-tag verification for a LibreChat fork release.
# Checks the working tree is in a sane state and suggests the next EG tag. Changes nothing.
#
# Usage: bash verify.sh [upstream-ref]   (default: upstream/main)
set -uo pipefail

UPSTREAM_REF="${1:-upstream/main}"
problems=0
note() { printf '  %s\n' "$1"; }
fail() { printf '  [X] %s\n' "$1"; problems=$((problems+1)); }
ok()   { printf '  [OK] %s\n' "$1"; }

echo "== Conflict markers =="
markers="$(git grep -nE '^(<<<<<<<|=======|>>>>>>>)' -- . ':(exclude)*.pdf' ':(exclude).claude/skills/*' 2>/dev/null)"
if [ -n "$markers" ]; then fail "leftover conflict markers:"; echo "$markers" | sed 's/^/      /'; else ok "none"; fi

echo "== Fork footprint vs $UPSTREAM_REF =="
count="$(git diff "$UPSTREAM_REF" --name-only 2>/dev/null | wc -l | tr -d ' ')"
note "$count files changed (expected ~27-30)"
git diff "$UPSTREAM_REF" --stat 2>/dev/null | tail -40 | sed 's/^/      /'

echo "== eg-startup.sh executable bit =="
mode="$(git ls-files -s eg-startup.sh 2>/dev/null | awk '{print $1}')"
if [ "$mode" = "100755" ]; then ok "100755"; else fail "mode is '$mode' (want 100755): git update-index --chmod=+x eg-startup.sh"; fi

echo "== Local junk not staged =="
junk="$(git diff --cached --name-only 2>/dev/null | grep -iE '\.pdf$|^backup/|\.bson$' || true)"
if [ -n "$junk" ]; then fail "junk staged for commit:"; echo "$junk" | sed 's/^/      /'; else ok "none staged"; fi

echo "== Stale backup branches =="
backups="$(git branch --list 'dev-backup-*' | sed 's/^[* ] *//')"
n_backups=$(printf '%s\n' "$backups" | grep -c . || true)
if [ "$n_backups" -ge 3 ]; then
  note "$n_backups backup branches present — prune old ones after this release:"
  printf '%s\n' "$backups" | sed 's/^/      /'
  note "  git branch --list 'dev-backup-*' | xargs -r git branch -D"
elif [ "$n_backups" -gt 0 ]; then
  ok "$n_backups backup branch(es) (fine; clean up post-release)"
else
  note "no backup branches (make one before rewriting/force-pushing)"
fi

echo "== Next EG tag suggestion =="
# Target upstream version = latest clean vX.Y.Z tag reachable from the upstream ref.
ver="$(git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' "$UPSTREAM_REF" 2>/dev/null | grep -oE '^v[0-9]+\.[0-9]+\.[0-9]+')"
if [ -z "$ver" ]; then
  note "couldn't auto-detect upstream version; pick vX.Y.Z.EGN by hand"
else
  highest="$(git tag --list "${ver}.EG*" | grep -oE 'EG[0-9]+$' | grep -oE '[0-9]+' | sort -n | tail -1)"
  next=$(( ${highest:-0} + 1 ))
  note "upstream version: $ver"
  note "existing EG tags: $(git tag --list "${ver}.EG*" | tr '\n' ' ')"
  note "suggested next tag: ${ver}.EG${next}"
fi

echo ""
if [ "$problems" -eq 0 ]; then echo "RESULT: clean — safe to commit, push, and tag."; else echo "RESULT: $problems issue(s) above — fix before releasing."; exit 1; fi
