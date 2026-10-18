# Bank Cleaner

Preservation snapshot extracted from [Bank Utilities](https://github.com/RS3-Dev/bank-utilities/tree/beba274b57853d444c7017eaa9c813273f222475) at commit `beba274b57853d444c7017eaa9c813273f222475`.

**This is not yet an installable standalone plugin.** No production entry point or plugin manifest has been invented. Original source bytes, module paths, function names, and storage keys are preserved.

## Contents

- `lib/` and, where required, `data/`: feature modules and the complete transitive closure of their literal Lua `require` dependencies.
- `tests/`: existing tests that run independently against these modules.
- `reference/integration/`: unchanged copies of the mixed application, feature lifecycle, sidebar, menu, settings, and original entry/manifest. These preserve behavior that cannot yet be separated without implementation. They are reference material, not a second runnable application.
- `reference/tests/`: original integration tests to port when Core contracts are ready. They still need the original repository's harness and are not standalone checks.
- `reference/HOST_CONTRACT.md`: host and API assumptions at the source revision.
- `EXTRACTION_MANIFEST.json`: source revision, original paths, extraction roles, byte lengths, and SHA-256 hashes for every copied file.

## Remaining integration work

- Preserves Cleanup classification, sections, quest checks, and all statically required data catalogs; it has no RuneQL dependency.
- The original Cleanup object forwards ordinary tag lookups to its userStore. That mixed facade has not been removed.
- Its page descriptor expects the legacy layout.features.cleanupCategories and page-state methods, not a standalone public extension adapter.
- The batched scan driver, activation, and inventory-change wiring remain in the mixed integration references. There is no standalone event loop yet.

No user saves, credentials, client files, build output, or external dependency source were copied. The original Bank Utilities source is intact. API wiring, migration, naming, and shared settings are future work.

## Checks

Every copied file was verified against its committed source bytes, and all copied Lua files were syntax-checked with Lua 5.4. These isolated tests were also run:

```text
lua54 tests/cleanup_categories_test.lua
```

These checks establish preservation and the listed isolated behaviors, not live or standalone plugin functionality. Reference integration tests must be ported before claiming behavior parity.
