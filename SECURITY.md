# Privacy and security

## Data boundaries

The native companion works offline. DSH integration is optional and uses a local host adapter. The adapter publishes only a loopback endpoint and process/version metadata in the current user's application-support directory. It does not publish model keys, authenticated URLs, cookies or chat content in that endpoint file.

Chat and whisper requests use the user's DSH provider. A message deliberately sent through these controls reaches the configured model service and may incur usage charges. Automatic model-generated whispers and automatic balance polling are disabled by the first-install configuration. If an existing DSH configuration conflicts, setup refuses to replace it silently.

The app keeps its own operational state locally. Such state, conversation memory, DSH profiles, logs, runtime endpoint files and backups are not release assets and must not be added to this repository. Model credentials remain managed by DSH; the native app does not require a copied API key.

The DSH plugin routes and their outer access checks are controlled by the installed host. Do not expose the host port to an untrusted network or disable its access checks to make a connection work.

## Reporting

For a non-sensitive bug, open an issue with a minimal description and redacted reproduction. Do not post passwords, keys, account data, full profile archives, or real chat transcripts in an issue or pull request.

For a suspected security issue, use GitHub's private vulnerability reporting if the repository owner has enabled it. If it is unavailable, open an issue asking for a private contact without including exploit details or private data. No private contact address is assumed by this template.

## Release review

The publication tree is assembled from an allowlist. Run the release audit, inspect the staged diff and inspect the final archive. `.gitignore` does not remove a file already tracked by Git and does not erase an older commit. Signed builds and notarized builds are identified explicitly in release notes; ad-hoc signatures must not be advertised as Apple approval.
