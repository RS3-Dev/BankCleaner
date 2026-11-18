# Tests

Run from the repository root with Lua 5.4. Integration tests need a Bank Core 1.5.0 or later checkout with its test host helpers:

```powershell
$env:BANKCORE_ROOT = "C:/path/to/bank-utilities"
lua54 tests/run.lua
```

Each test runs in a separate process. Tests load Bank Cleaner directly from this repository, with no build step. Helpers and catalog ID fixtures live in `tests/support/`.

The integration harness checks Bank Core's `docs/API.md`, then uses its `tools/test_support/fake_bank_host.lua`, `fake_plugin_host.lua`, and `tools/json.lua`. Bank Core is an external test dependency and is not copied into this repository.

The layout, catalog, category, and page tests can also run individually without `BANKCORE_ROOT`.

Integration tests cover app behavior, sidebar interaction, bank state, dependency updates, and reloads in a simulated client. They do not verify live-client rendering or input delivery.
