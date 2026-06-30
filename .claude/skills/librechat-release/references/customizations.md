# Fork customizations & conflict resolution

What the e-gineering fork changes on top of upstream, and how to resolve each conflict during a
version bump. Read this before resolving anything in step 4.

The fork footprint is small and stable: ~27–28 files. After re-applying, `git diff upstream/main..HEAD
--stat` should show roughly the files below and nothing else. Anything outside this list is a red flag —
either upstream churn that leaked in, or stale context the patch dragged along.

## Why the fork exists

Two purposes (see also the `project_fork_purpose` and `reference_deployment` memories):

1. **Per-client UI theming** — custom logo, CSS, and welcome message surfaced from env vars in the
   startup config payload and consumed by the client.
2. **Per-client config files** — `librechat.<client>.yaml` (e.g. `librechat.img.yaml`). `eg-startup.sh`
   renames the right one to `librechat.yaml` at container boot based on `LIBRECHAT_CUSTOM_CONFIG`.

Only IMG is deployed today, but the design accommodates more clients without code changes.

## Customization inventory

### Theming / branding
- `api/server/routes/config.js` — adds **only** `customLogo`, `customCss`, `customWelcomeMessage` to
  the shared payload (upstream's `buildPostLoginPayload()`).
- `packages/data-provider/src/config.ts` — declares those three fields on `TStartupConfig` (optional
  `string`s) so the client stays type-safe.
- `client/src/components/System/CustomStyleLoader.tsx` — new; injects `customCss` at runtime.
- `client/src/App.jsx` — mounts `<CustomStyleLoader />`.
- `client/src/components/Auth/AuthLayout.tsx` — uses `customLogo` and loads `customCss` on the auth page.
- `client/src/components/Chat/Landing.tsx` — renders `customLogo` instead of the default convo icon.
- `client/src/routes/Layouts/Startup.tsx` — uses `customWelcomeMessage` for the login header.
- `client/src/locales/en/translation.json` — adds the custom welcome key.
- `client/public/assets/themes/img/` — IMG logo, favicon, and `img-overrides.css` (binary + css).

### Per-client config & startup
- `librechat.img.yaml` — IMG's config (MCP servers, allowedDomains, OCR model, web search, storage).
- `eg-startup.sh` — selects the client YAML via `LIBRECHAT_CUSTOM_CONFIG` and loads
  `GOOGLE_KEY_FILE_CONTENTS` at boot. **Must stay executable (`100755`)** — it's run as
  `./eg-startup.sh` from `package.json`'s `prebackend` script.
- `package.json` — adds the `prebackend` hook.
- `Dockerfile` — installs `curl` (used by `eg-startup.sh`).
- `docker-compose.yml` — adds local `build:`/`env_file:` wiring, comments out the upstream prebuilt image.
- `.dockerignore` / `.env.example` — the EG env vars block (`GOOGLE_KEY_FILE_CONTENTS`, `FAVICON_PATH`,
  `CUSTOM_LOGO_PATH`, `CUSTOM_WELCOME_BACK`, `CUSTOM_CSS`).
- `EG_README.md` — fork-specific readme.
- `.gitignore` — re-includes `.claude/skills/` so this skill ships with the fork.

### CI workflows
- `.github/workflows/tag-images.yml` — the fork's **own** build-on-tag workflow (see trap below).
  Builds **`linux/amd64` only** — arm64 was dropped because Azure App Service is amd64 and the
  QEMU-emulated arm64 build added ~50min and caused the tag build to hang.
- `.github/workflows/dev-images.yml` — dev-branch image build tweaks.
- `.github/workflows/i18n-unused-keys.yml` — adjusted to tolerate the fork's custom keys.
- Disabled by renaming to `*.yml.hold` (GitHub only runs `.yml`/`.yaml`):
  - `helmcharts.yml` — upstream helm chart release.
  - `dev-branch-images.yml` — always failed on `Login to Docker Hub` (no `DOCKERHUB_*` secrets);
    the fork deploys by tag, not dev image.
  - `deploy-dev.yml` (Update Test Server) — chained `workflow_run` off the dev-branch build above.
  - `gitnexus-index.yml`, `gitnexus-deploy.yml`, `gitnexus-cleanup-pr.yml`, `gitnexus-pr-command.yml`
    — unused upstream GitNexus integration that ran on every dev push/PR.

> Other upstream workflows are left untouched but are **dormant on the fork**: NPM publishes
> (`client`/`data-provider`/`data-schemas`), `dev-images`, `locize-i18n-sync`, `generate_embeddings`
> fire only on `main` pushes (the fork works on `dev`); the PR test/lint workflows never run because
> the fork rebases + force-pushes rather than opening PRs. Leave them — disabling adds rebase footprint
> for no benefit. If a new upstream workflow starts failing on `dev` pushes or tags, disable it the
> same way (rename to `.hold`).

### Backend
- `api/server/middleware/limiters/*.js` — minor rate-limiter `keyGenerator` annotations/IP-parsing notes.

## Traps (the things that broke or nearly broke)

### 1. Keep the fork's `tag-images.yml` — do not adopt upstream's
Since v0.8.6, upstream ships its own `tag-images.yml` with a **"Validate release tag" step** whose regex
`^v[0-9]+\.[0-9]+\.[0-9]+(-rc[0-9]+)?$` **rejects our `vX.Y.Z.EGN` tag format**, and it also pushes to
DockerHub via a `DOCKERHUB_USERNAME` secret the fork may not have. The fork's simpler workflow (trigger
on `*`, push to GHCR only) is what has built every EG tag. On conflict here, **take the fork's whole
file**: `git checkout dev-backup-pre-<version> -- .github/workflows/tag-images.yml`.

### 2. `config.js` theming fields — add only the three
Upstream restructured the payload into spreads (`...buildPostLoginPayload()` etc.). The fork's net
addition is *only* `customLogo` / `customCss` / `customWelcomeMessage`, placed inside
`buildPostLoginPayload()`. **`analyticsGtmId`, `customFooter`, `sharedLinksEnabled`,
`publicSharedLinksEnabled` are upstream fields, not fork additions — don't re-add them** (a 3-way merge
against the real base handles this automatically; only watch for it if resolving by hand).

### 3. `TStartupConfig` type
The three theming fields must be declared on `TStartupConfig` in `packages/data-provider/src/config.ts`,
or the client has a latent type error (the Vite build strips types so it won't fail the Docker build, but
it violates the repo's "no unresolved diagnostics" rule). Place them next to `customFooter?`.

### 4. `.env.example` — add only the EG block
When 3-way merging `.env.example`, the conflict may surface an old "Code Interpreter API" block as if the
fork added it. It didn't — that was pre-existing context upstream later moved. Add **only** the
`E-gineering custom env vars` block; drop the rest.

### 5. `eg-startup.sh` executable bit
`git apply` / commits can drop the executable bit to `100644`. Restore it before committing:
`git update-index --chmod=+x eg-startup.sh`. Verify with `git ls-tree HEAD eg-startup.sh` → `100755`.

### 6. Local junk — never `git add -A`
The working tree commonly has untracked local artifacts (`Package.pdf`, `scansmpl.pdf`, a `backup/`
MongoDB dump). Stage with explicit paths so these never get committed. `verify.sh` flags them if staged.

## Sanity check after resolving

```bash
git diff upstream/main..HEAD --stat   # ~27–28 files, all from the inventory above, nothing else
git grep -nE '^(<<<<<<<|=======|>>>>>>>)' -- . ':(exclude)*.pdf'   # no conflict markers
git ls-tree HEAD eg-startup.sh        # 100755
```
