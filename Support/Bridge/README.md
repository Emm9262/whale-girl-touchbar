# PC2005 Touch Bar host adapter

This Cordis bundle loads only the host of `dsh-pet@0.3.8`. It has no `dsh.client` entry. The native Touch Bar consumes the upstream `web` surface; the original browser pet is not mounted.

## Install

Node.js 22.19+ or 24+ and a compatible DSH installation are required. The tested host is DSH 0.2.1-rc.2; later versions need their own compatibility check.

From the project root:

```sh
node scripts/setup-dsh.mjs --dry-run
node scripts/setup-dsh.mjs --apply
```

The script detects the official desktop CLI or `dsh` on `PATH`. Set `--dsh-cli PATH`, `--profile NAME` (default `desktop`), and `--dsh-home PATH` when needed. Existing credentials are never inspected. Setup does not restart DSH: reopen it normally after current tasks have finished.

Setup creates a new, private `main-config.jsonc` only when no pet configuration already exists. The initial settings contain one `main` pet with `display: web`; automatic whispers, balance polling and system notifications are off. Chat and balance still work when explicitly requested by the native app. No Electron desktop helper is requested.

Existing safe configuration is kept byte-for-byte. Existing incompatible settings, legacy configuration or additional pet packs stop installation. They are not overwritten. Generate a separate example with `node scripts/setup-dsh.mjs --write-example PATH`, compare it locally, and decide how to configure an existing installation yourself. Do not upload your DSH data directory.

The bridge performs the same read-only safety check before calling the upstream host. Installing the package directly without preparing safe configuration leaves the bridge disabled, rather than inheriting automatic model calls from upstream defaults.

Non-sensitive profile package/lock metadata is copied into a private directory under `$DSH_HOME/touchbar-setup-backups/` before the official CLI changes it. `--backup-dir PATH` selects a new backup destination. These runtime backups do not belong in the source repository.

## Remove

```sh
node scripts/remove-dsh.mjs --dry-run
node scripts/remove-dsh.mjs --apply
```

Only the bridge package is removed through the official CLI. DSH accounts, pet configuration, conversation memory and other plugins remain. The adapter removes only its own runtime endpoint on normal disposal. No full DSH cleanup is performed.

## Runtime endpoint

On launch, the adapter writes `{schemaVersion, provider, version, renderer, baseURL, processId}` into `~/Library/Application Support/WhaleGirlTouchBar/pc2005-runtime.json`. This contains only a loopback endpoint, not authentication, prompts or replies. Native requests remain subject to the host's normal access checks.

Upstream: https://github.com/PC2005-cloud/dsh-pet (`v0.3.8`, commit `593b9b0785f883630243ef6213542f4603ef69ad`). Upstream code and artwork have different license terms; see the project third-party notices.
