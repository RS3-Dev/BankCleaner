# Bank Cleaner tests

Run every test, the build, and the compile and globals check from the repository root:

```text
set BANKCORE_ROOT=C:\path\to\bank-utilities
lua54 tools/check.lua
```

Tests that load Bank Core read it, unchanged, from the checkout `BANKCORE_ROOT` names; there is no default, so a stale sibling checkout is never tested against by accident, and a checkout without the launch API in its `docs/LAUNCH_API_SPEC.md` is refused. They use Bank Core's own stand-in host (`tools/test_support/fake_bank_host.lua` and `fake_plugin_host.lua` in that checkout) and load Bank Core's `plugins/bankcore/main.lua` with its own module cache, beside the Bank Cleaner folder the build writes under `dist/test/`. Nothing from Bank Core is copied into Bank Cleaner or its package.

`cleanup_catalogs_test.lua` checks the five wiki-generated catalogs against known items and the counts in `docs/CATALOG_SOURCES.md`; regenerating them with `node tools/catalogs/generate_catalogs.mjs` may change those counts, so update the test and the document together.

The stand-in host is not the game client: these tests show Bank Cleaner's behavior against Bank Core's public API under that model, not how the live client draws, scrolls, or delivers input.

The Cleaner harness adapts `requiredDependencies` for Core's older stand-in loader and rejects startup when a required export is missing. Reload tests cover required Core startup and reloading Cleaner after Core, plus an optional-Core fixture to exercise the defensive dependency-update handler.

`bank_state_test.lua` uses Core 1.5.0's state snapshots and native control signals to check page removal, error banners, refusal before callback delivery, explicit reopening after recovery, other plugins' pages, and disposal. The harness refuses Core versions lacking this API.
