---
name: librechat-release
description: >-
  Update the e-gineering LibreChat fork from upstream (danny-avila/LibreChat) and ship a new
  client image: rebase/re-apply the fork's customizations onto a new upstream version, tag it
  vX.Y.Z.EGN, push the tag to trigger the GitHub Actions image build, then deploy to Azure.
  Use this skill whenever the user mentions updating, rebasing, or syncing the LibreChat fork
  from upstream, cutting a new EG / e-gineering LibreChat release, bumping to a new LibreChat
  version (e.g. "release v0.8.6", "update the fork to the new upstream"), building/pushing a
  LibreChat image on a tag, or deploying LibreChat to the Azure staging/production slots — even
  if they don't say the word "release". Do NOT use it for routine work on fork files that isn't a
  release — e.g. adding an MCP server or onboarding a client in a librechat.<client>.yaml, writing
  client theme CSS, debugging the local dev server, or deploying a non-LibreChat app.
---

# LibreChat fork release

This skill drives the full release of e-gineering's LibreChat fork: take a new upstream version,
carry the fork's customizations onto it, build an image, and deploy it to Azure.

The fork (`origin` → `e-gineering/LibreChat`) tracks upstream (`upstream` → `danny-avila/LibreChat`)
and adds a small, well-defined set of customizations (per-client theming, per-client YAML configs,
deployment plumbing). The whole job is: **move those customizations onto the new upstream cleanly,
without dragging in upstream churn or losing fork behavior.**

## Before you start

Confirm the basics (read-only — don't change anything yet):

- On the `dev` branch of the fork, working tree has no uncommitted *tracked* changes.
- Remotes exist: `origin` = e-gineering fork, `upstream` = danny-avila. If `upstream` is missing:
  `git remote add upstream https://github.com/danny-avila/LibreChat.git`
- `gh` CLI is authenticated (`gh auth status`) — needed to watch the build.
- The user has Azure Portal access for the deploy step (you can't do that part for them).

The release commands are run from the repo root. On Windows, run the git/`gh`/bash steps through the
Bash tool (git-bash); use PowerShell only if the user prefers it. **Docker commands, if any, use
PowerShell** (CRLF issues bite bash here).

## The workflow

Work through these in order. Steps 1–7 you can do; step 8 (Azure) is the user's.

### 1. Fetch and pick the version + tag

```bash
git fetch --all
```

Decide the target upstream version. It's whatever clean upstream tag you're releasing onto — usually
the latest `v<semver>` on `upstream/main` (e.g. `v0.8.6`). Confirm `upstream/main` is at that release
commit: `git log --oneline -1 upstream/main` and `git rev-parse v0.8.6^{commit}` should match (or main
is just ahead of it).

Pick the EG tag. **Format is `vX.Y.Z.EGN`** — dots, no dash, no dot before the number
(e.g. `v0.8.6.EG1`, `v0.8.5.EG1`, `v0.8.4.EG2`). `N` is the EG build number for that upstream
version: start at `EG1`, bump if you're re-releasing the same upstream version. `scripts/verify.sh`
suggests the next tag from existing ones.

> **Do not** adopt a tag format upstream's own workflow would accept — see the tag-images trap in
> `references/customizations.md`. We keep the fork's own workflow precisely so `.EGN` tags build.

### 2. Make a safety backup

Branch rewriting + force-push is involved, so always create a restore point first:

```bash
git branch dev-backup-pre-<version> dev   # e.g. dev-backup-pre-0.8.6
```

### 3. Move the fork onto the new upstream

First, **measure how much the new upstream overlaps the fork's files** so you pick the right strategy
instead of discovering it mid-rebase:

```bash
bash .claude/skills/librechat-release/scripts/assess.sh upstream/main
```

It intersects "files the fork changed" with "files upstream changed since our last base" and prints a
recommendation. Most releases don't touch our ~27 files, so the usual answer is **rebase**.

**Rebase — the default.** When the overlap is zero or just a couple of files, replay the fork's commits
straight onto the new upstream. It's conflict-free or nearly so, and preserves the fork's history:

```bash
git rebase upstream/main
```

Resolve the handful of conflicts (if any) per `references/customizations.md`, then continue. If conflicts
turn out to be widespread — many commits each fighting refactored upstream code — don't grind through it:
abort and switch to clean re-apply.

```bash
git rebase --abort
```

**Clean re-apply — the fallback for heavy releases** (what v0.8.6 needed). Reset `dev` to the new upstream
and lay the fork's *net* change back on top as a single 3-way patch, skipping the messy commit-by-commit
replay:

```bash
bash .claude/skills/librechat-release/scripts/clean-reapply.sh upstream/main
```

The script verifies the tree, creates a backup branch, diffs the fork's net change from the merge-base,
resets `dev` to `upstream/main`, and re-applies with `git apply --3way`, stopping to report the (usually
1–3) conflicts for you to resolve by hand. Trade-off: you lose the granular fork history in favor of a
clean diff against upstream — fine for a heavy release, overkill for a light one.

### 4. Resolve conflicts — preserve fork intent, drop upstream churn

This is the only part needing judgment. **Read `references/customizations.md` before resolving** — it
inventories exactly what the fork changes, the known traps (the tag-images workflow, the `config.js`
theming fields, the `TStartupConfig` type, executable bits, local junk files), and how to resolve each.

The guiding rule: keep the fork's *behavior* (theming payload fields, per-client YAML + `eg-startup.sh`,
deployment config, rate-limiter notes); take upstream's *structure*; and drop anything that looks like
stale leftover context rather than an intentional fork addition.

### 5. Verify before committing

```bash
bash .claude/skills/librechat-release/scripts/verify.sh
```

This checks: no leftover conflict markers, the diff vs `upstream/main` is only the expected fork
footprint (~27–28 files), `eg-startup.sh` is still executable (`100755`), and no local junk
(`*.pdf`, `backup/`, DB dumps) got staged. Fix anything it flags.

The local build can't always run right after a reset (the lockfile jumped many commits, so
`node_modules` is stale and `rimraf`/etc. may be missing). That's fine — the **GitHub Actions Docker
build is the real build gate**. Don't block the release on a local `npm run build` unless you've
reinstalled deps.

### 6. Commit and force-push

Commit in a few logical groups (theming / deployment config / misc) so the diff reads cleanly. **Stage
with explicit paths, never `git add -A`** — the working tree often has untracked local junk. Then:

```bash
git push --force origin dev
```

### 7. Tag and push → trigger the build, then watch it

```bash
git tag v0.8.6.EG1
git push origin v0.8.6.EG1
```

Pushing the tag fires the **"Docker Images Build on Tag"** workflow. Watch it to completion (prior EG
builds run ~55–60 min) rather than polling:

```bash
RUN_ID=$(gh run list --repo e-gineering/LibreChat --workflow tag-images.yml --limit 1 --json databaseId -q '.[0].databaseId')
gh run watch "$RUN_ID" --repo e-gineering/LibreChat --exit-status   # run in background
```

If it fails, pull logs (`gh run view "$RUN_ID" --repo e-gineering/LibreChat --log-failed`) and fix
forward. Don't tell the user to deploy until the build is green.

### 8. Deploy to Azure (user-driven)

You can't operate the Azure Portal — hand the user the exact steps from
`references/azure-deploy.md` (app resource, staging slot, set the image tag, test, swap to production,
re-apply any env-var changes).

## After a successful release — clean up backups

Backup branches are a safety net for the rewrite/force-push, not permanent. They accumulate otherwise
(step 2's `dev-backup-pre-<version>`, plus any timestamped `dev-backup-pre-reapply-*` the re-apply script
made). Once the user confirms **production is healthy**, clear them out:

```bash
git branch --list 'dev-backup-*'                       # review what's there
git branch -D dev-backup-pre-<version>                 # delete this release's backup(s)
# or prune them all at once after a clean release:
git branch --list 'dev-backup-*' | xargs -r git branch -D
```

Keep the current release's backup until production is verified; delete older ones freely (the pushed
`origin/dev` and the reflog are additional safety nets). `verify.sh` warns when several stale backups
have piled up. Also update the `reference_deployment` memory if anything about the process changed.
