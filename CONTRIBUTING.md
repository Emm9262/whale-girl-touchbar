# Contributing

Keep changes focused and explain the user-visible result. A useful issue includes the macOS version, CPU architecture, whether the machine has a physical Touch Bar, and whether the problem also occurs without DSH.

## Development checks

```sh
python3 scripts/audit-release.py --tree .
bash build.sh
bash scripts/test.sh
```

Use a temporary directory or mocked DSH CLI for installer tests. Do not point test scripts at a personal profile, make live model calls, alter login items, or replace a running application as part of an automated test.

For visual changes, render the app's own views and inspect them. A JSON state assertion does not prove the text or animation was drawn correctly. When changing movement, test both directions, stopping, touch interruption, task activity and hidden-time behavior.

## Information that must stay private

Never submit credentials, cookies, private keys, certificates, personal profiles, chat memory, runtime logs, local backups, installation records, or absolute personal paths. Use fabricated values in examples. Check the staged diff and any history included in a contribution. A passing scanner is additional evidence, not a guarantee that every sensitive value was found.

Reports and scanner output should show redacted locations and issue types, not the sensitive value itself. If a credential was ever published, remove access first and rotate it; deleting the latest file alone does not remove it from Git history.

## Asset changes

Every new asset needs a source, author, license and redistribution scope. Keep third-party asset notices separate from the code license. Do not replace the bundled character identity without explaining the visual and licensing implications.

Original contributions are submitted under the project MIT code license unless a file states another applicable license. This does not expand the permitted use of third-party artwork.
