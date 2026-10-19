# Bank Cleaner

Bank Cleaner (`bankcleaner`) is a standalone plugin that shows which bank items belong in other storage: the metal bank, tool leprechaun, clue carrier, focus storage, ore and wood boxes, player-owned house storage, and finished quests' items. It runs on [Bank Utilities Core](https://github.com/RS3-Dev/bank-utilities) (`bankcore`) and reaches the bank only through Bank Core's public extension API: no private Core module or native bank component is used. What it uses from Bank Core is in [CONTRACT.md](CONTRACT.md); the plan it was built from is in [docs/STANDALONE_PLAN.md](docs/STANDALONE_PLAN.md).

Everything here is checked against Bank Core's stand-in host only. Nothing in this repository has been verified in the live client yet; see [Not yet verified live](#not-yet-verified-live).

## Features

- **Cleanup tab.** A sidebar tab of folders, as in Bank Tags: Review, Utility storage, and Player-owned house, each with its number of categories. Clicking a folder collapses or expands it; every folder starts open. Inside a folder, one row per category with the number of matching stacks in the bank, or `...` while new items are being checked. The shown category's row is outlined, or its folder while that is collapsed.
- **Category pages.** Choosing a category shows that category's items (choosing it again returns to the bank) through a Bank Core page: the category's name as a label, then exactly the stacks the bank holds now, in bank order. Focus Storage and Spirits show each section under its own label (Focus: Recommended, Focus: Optional; Stone Spirits (ore box), Wood Spirits (wood box)), leaving out an empty section. An empty category says "None of these items are in your bank."
- **Quest items** appear only when every quest the item belongs to is confirmed finished; anything the client cannot confirm stays out.
- **Live pages.** A withdrawn item leaves its page as soon as Bank Core reports the bank changed; a deposited item joins once it has been checked. Choosing the Cleanup tab checks every item and quest again.
- **Plugin panel.** Says whether Bank Cleaner is in the bank, or that Bank Core is needed.

## Requirements and load order

- **PrettyUI** is a required dependency.
- **Bank Core** (`bankcore`) is needed for anything in the bank. It is declared as an optional dependency only because the host reports changes for optional dependencies. Without it, Bank Cleaner loads and its panel says Bank Core is needed.

Any load order works: Bank Cleaner connects when Bank Core loads, reconnects when Bank Core reloads, and lets go when Bank Core unloads, through the host's `PluginDependencyUpdate`. Reloading Bank Cleaner shuts down the previous copy in the same Lua state first; a copy whose owner ID a newer load took stays idle.

**Old installs.** The old integrated `bankutils` plugin (and the older `bankutilities`) also had a Cleanup tab. They are not expected to work against this Bank Core, whose private bridge they used was removed; disable them so the cleanup views are not loaded twice.

## Saved data

Bank Cleaner saves only which Cleanup folders are collapsed, under `bankcleaner_folders` as `{ collapsed = { <group>, ... } }`; names that are not current groups are ignored on load. If the client refuses the save, the folder stays as the player left it until Bank Cleaner reloads, and the plugin panel says so. It has no preferences, so it adds no section to Bank Core's settings window.

## Changes from the old integrated plugin

- Pages show only the stacks the bank holds, from the same bank snapshot, and follow every bank change; the old plugin kept withdrawn items as ghosts until the category was scanned again.
- Each category is introduced by Bank Core's standard label row, as Bank Tags' labels are; the old custom page heading is gone.
- Placeholders never appear.
- The Cleanup tab has no search box; its 13 categories fit without one. Its groups are folders that collapse, drawn by Bank Cleaner in its own column rather than as Bank Core's plain rows.
- Items are checked once each and remembered until the Cleanup tab is chosen again, so a bank change rechecks only new items.

## Layout

- `plugins/bankcleaner/`: the entry (`main.lua`) and manifest.
- `bankcleaner/`: every runtime module. All require paths start with `bankcleaner/`. The catalogs in `bankcleaner/data/` are unchanged from Bank Utilities.
- `tools/`: the build and check tools, adapted from Bank Tags', and the test harness that loads Bank Core beside Bank Cleaner.
- `tests/`: the tests; see [tests/README.md](tests/README.md).
- `reference/`: the preserved source from Bank Utilities `beba274`, kept as an archive; see [reference/README.md](reference/README.md). `EXTRACTION_MANIFEST.json` records where each preserved file came from.

## Build and check

```text
lua54 tools/build.lua
lua54 tools/check.lua
```

The build writes only `dist/release/bankcleaner/`: `main.lua`, `plugin.json`, and the modules the entry's require graph loads, with the entry's module eviction list generated from that graph. It refuses output paths inside the source tree and removes only what its previous build wrote. The check builds into `dist/check`, runs every test, compiles every built file, and fails on unexpected globals, a runtime source the entry never loads, or anything from `reference/`, `tests/`, or `tools/` in the package. Tests that load Bank Core read it from `BANKCORE_ROOT`, which must be set.

To install, copy `dist/release/bankcleaner/` into the client's plugins folder as `bankcleaner`.

## Not yet verified live

- When the host calls `PluginDependencyUpdate` on reloads, whether it re-injects the global, how it clones exports, and whether module caches are scoped per plugin.
- How Bank Core's label rows and the `...` row detail look in the live bank, and how fast a large category page draws.
- Quest completion as `config.Quest.FromID(id).hasFinishedQuest` reports it, unchanged from the old plugin.
