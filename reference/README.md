# Reference archive

Preserved source from Bank Utilities `beba274b57853d444c7017eaa9c813273f222475`, kept for history and comparison. Nothing here is built, loaded, or tested; the build refuses to ship it.

- `integration/`: the old integrated app, feature glue (including the cleanup scan driver in `bank_features.lua`), sidebar, menus, settings, and plugin entry.
- `preserved/lib/`: preserved modules the standalone plugin no longer loads: the cleanup page descriptor for Core's removed private page state, and the text helpers only it used.
- `tests/`: the old integration tests, which need the original repository's harness.
- `HOST_CONTRACT.md`: the host and API assumptions at the source revision, superseded by Bank Core's `HOST_CONTRACT.md` and this repository's `CONTRACT.md`.

`EXTRACTION_MANIFEST.json` at the repository root records each preserved file's original path and hash. Files that became runtime modules moved to `bankcleaner/` and were adapted there; their history is in git.
