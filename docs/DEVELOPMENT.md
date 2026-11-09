# Developer reference

These are implementation, build, migration, and validation notes. For first-time player instructions, read the [player guide](../README.md). Historical implementation notes are not a statement of release readiness.

# Bank Cleaner

Bank Cleaner (`bankcleaner`) is a standalone plugin that shows which bank items belong in other storage: the metal bank, tool leprechaun, clue carrier, focus storage, ore and wood boxes, storm barn, seed bag, player-owned house storage, Archaeology's workbench and material storage, and finished quests' items, including what May's Storage Chest and Diango can return. It runs on [Bank Utilities Core](https://github.com/RS3-Dev/bank-utilities) (`bankcore`) and reaches the bank only through Bank Core's public extension API: no private Core module or native bank component is used. What it uses from Bank Core is in [CONTRACT.md](../CONTRACT.md); the plan it was built from is in [docs/STANDALONE_PLAN.md](../docs/STANDALONE_PLAN.md).

Everything here is checked against Bank Core's stand-in host only. Nothing in this repository has been verified in the live client yet; see [Not yet verified live](#not-yet-verified-live).

## Features

- **Cleanup column.** One rail icon (an eraser, named Bank Cleaner) whose column holds folders, as in Bank Tags: Review (Quest Items, Storage Chest, Diango Reclaimable), Utility storage (Metal Bank, Clue Carrier, Tool Leprechaun, Focus Storage, Spirits, Storm Barn, Seed Bag), Player-owned house (seven house storage categories), and Archaeology (Archaeologist's Workbench, Material Storage), each with the sum of its category stack counts. Clicking a folder collapses or expands it; every folder starts open. Inside a folder, one row per category with the number of matching stacks in the bank, or `...` while new items are being checked. The shown category's row is outlined, or its folder while that is collapsed.
- **Category pages.** Choosing a category shows that category's items (choosing it again returns to the bank; choosing another switches the shown page to it) through Bank Cleaner's one Bank Core page: the category's name as the page heading only when the content has no section or status label, then the stacks held when the page is opened, in bank order, an object once per stack. The initial scan may finish populating the page; afterward its slots stay fixed until it is closed or cleanup search changes. A sectioned category shows each section under its own label, leaving out an empty section: Focus Storage (Focus: Recommended, Focus: Optional), Spirits (Stone Spirits (ore box), Wood Spirits (wood box)), Storage Chest (Non-reclaimable, Reclaimable (chest unlock needed)), Diango Reclaimable (one section per table on the wiki page), and Storm Barn (Manor Farm, Anachronia Dinosaur Farm). An empty category says "None of these items are in your bank."
- **Quest items** appear only when every quest the item belongs to is confirmed finished; anything the client cannot confirm stays out.
- **Storage Chest** splits finished quests' items by whether May's Storage Chest can return them. Reclaimable lists the chest's own items once their quests are confirmed finished; the few that need no quest (boots of lightness, the cat training medal) show without one. The wiki notes a known bug: for some players the chest does not return the cat training medal, though it is listed here. Non-reclaimable lists Quest Items' items the chest does not list: they cannot be reclaimed there. Showing an item does not mean the player can use the chest: it is members only and needs 150 quest points allocated to the caravan's Hub Track. Quest Items stays as its own category: it is the plain list of finished quests' items with no chest involved, and Storage Chest also finds chest items Quest Items has no quest data for.
- **Diango Reclaimable** lists the items Diango's Item Retrieval lists, one section per wiki table. Reclaiming is not always free: entries the wiki marks "Requires return fee" and items with combat stats above tier 1 cost a fee, several outfits can be reclaimed only if they were not combined or upgraded, and an add-on only if it was not installed.
- **Storm Barn** lists checked farm animals; unchecked and tutorial animals cannot go in the barn. **Archaeologist's Workbench** lists damaged artefacts only, which need the workbench storage upgrade from the Archaeology Guild Shop; **Material Storage** lists the materials the material storage container takes, not the tutorial-only ones.
- **Stable pages.** Withdrawing items keeps their slots in place, with quantities and empty slots rendered by Bank Core. Newly deposited items appear when the category is reopened or cleanup search changes. Sidebar counts continue to reflect the current bank. Opening the Cleanup column checks every item and quest again.
- **No plugin window entry.** Bank Cleaner has no ribbon icon or panel in the Plugins window; everything it shows is in the bank.

## Requirements and load order

- **PrettyUI** is a required dependency.
- **Bank Utilities Core 1.5.0 or later** (`bankcore`) is a required dependency for `GetBankState` and separate native search/filter state. The source manifest and local builds use `"bankcore": "bankcore"`. Release builds use `"bankcore": 6464293` for mod.io installation; the source manifest is never rewritten.

The host loads required dependencies before Bank Cleaner. Required dependency change notifications are not documented, so reload Bank Cleaner after reloading Bank Core. The defensive `PluginDependencyUpdate` handler remains for hosts that send those notifications. Reloading Bank Cleaner shuts down the previous copy in the same Lua state first; each registration replaces any earlier one of `bankcleaner`.

Cleaner follows Core's native bank-state notifications and checks the current snapshot before reading items or opening a category. A closed bank, another native tab, an open preset selector, native search, or native filter stops scanning and closes Cleaner's page. Clicking a category while restricted shows a banner over the bank title explaining how to recover. Entering a restricted state does not show a warning; clearing the restriction refreshes visible counts but waits for a category click to reopen a page. Cleaner's search field does not trigger native search state.

**Old installs.** The old integrated `bankutils` plugin (and the older `bankutilities`) also had a Cleanup tab. They are not expected to work against this Bank Core, whose private bridge they used was removed; disable them so the cleanup views are not loaded twice.

## Saved data

Bank Cleaner saves only which Cleanup folders are collapsed, under `bankcleaner_folders` as `{ collapsed = { <group>, ... } }`; names that are not current groups are ignored on load. If the client refuses the save, the folder stays as the player left it until Bank Cleaner reloads. It has no preferences.

## Changes from the old integrated plugin

- Pages start from the current bank snapshot and keep their slots stable while open. Reopening a category rebuilds it from the latest snapshot.
- Populated, unsectioned categories supply their name as Core's page title. Pages beginning with section labels or an empty, scanning, or search status omit the title to avoid redundant headings.
- Existing placeholders are excluded when a page is built; withdrawn stacks remain as empty slots until that page is refreshed.
- The Cleanup column has a search field above its folders, using Advanced Bank Search's field style. Search filters item names in every category page and its counts, preserving folder structure, category sections, bank order, duplicate stacks, and saved collapsed folders.
- All categories share Bank Cleaner's one Bank Core page, set to the chosen category. Its groups are folders that collapse, drawn by Bank Cleaner in its own column.
- Items are checked once each and remembered until the Cleanup column opens again, so a bank change rechecks only new items.

## Layout

- `plugins/bankcleaner/`: the entry (`main.lua`) and manifest.
- `bankcleaner/`: every runtime module. All require paths start with `bankcleaner/`. The catalogs in `bankcleaner/data/` are unchanged from Bank Utilities, except five generated from the RuneScape Wiki: `storage_chest_objects`, `diango_objects`, `storm_barn_objects`, `workbench_artefact_objects`, and `material_storage_objects`. Their sources, revisions, counts, and every unresolved or excluded entry are in [docs/CATALOG_SOURCES.md](../docs/CATALOG_SOURCES.md).
- `tools/`: the build and check tools, adapted from Bank Tags', and the test harness that loads Bank Core beside Bank Cleaner. `tools/catalogs/` holds the Node script that regenerates the five wiki catalogs (`node tools/catalogs/generate_catalogs.mjs`); it reads the wiki's public API and is not part of the build or check. Seed Bag has its own generator (`node tools/catalogs/generate_seeds.mjs`) and [source notes](SEED_CATALOG_SOURCES.md).
- `tests/`: the tests; see [tests/README.md](../tests/README.md).
- `reference/`: the preserved source from Bank Utilities `beba274`, kept as an archive; see [reference/README.md](../reference/README.md). `EXTRACTION_MANIFEST.json` records where each preserved file came from.

## Build and check

```text
lua54 tools/build.lua
lua54 tools/check.lua
```

The build writes only `dist/release/bankcleaner/`: `main.lua`, `plugin.json`, and a `resources/` directory containing every supporting runtime module. It rewrites the packaged module paths and generated module eviction list to `resources/bankcleaner/...`; source paths stay unchanged. Release ZIPs wrap these three entries in a single `bankcleaner/` directory. The builder refuses output paths inside the source tree and removes only what its previous build wrote. The check builds into `dist/check`, runs every test, compiles every built file, and fails on unexpected globals, a runtime source the entry never loads, or anything from `reference/`, `tests/`, or `tools/` in the package. Tests that load Bank Core read it from `BANKCORE_ROOT`, which must be set.

To install, copy `dist/release/bankcleaner/` into the client's plugins folder as `bankcleaner`.

## Not yet verified live

- When the host calls `PluginDependencyUpdate` on reloads, whether it re-injects the global, how it clones exports, and whether module caches are scoped per plugin.
- How Bank Core's page heading, label rows, and the `...` row detail look in the live bank, and how fast a large category page draws.
- Quest completion as `config.Quest.FromID(id).hasFinishedQuest` reports it, unchanged from the old plugin, including for the quest IDs the Storage Chest catalog takes from the wiki.
- The five wiki catalogs against the live client: item IDs come from wiki item infoboxes, not the game cache.
