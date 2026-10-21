# Bank Cleaner

Bank Cleaner (`bankcleaner`) is a standalone plugin that shows which bank items belong in other storage: the metal bank, tool leprechaun, clue carrier, focus storage, ore and wood boxes, storm barn, player-owned house storage, Archaeology's workbench and material storage, and finished quests' items, including what May's Storage Chest and Diango can return. It runs on [Bank Utilities Core](https://github.com/RS3-Dev/bank-utilities) (`bankcore`) and reaches the bank only through Bank Core's public extension API: no private Core module or native bank component is used. What it uses from Bank Core is in [CONTRACT.md](CONTRACT.md); the plan it was built from is in [docs/STANDALONE_PLAN.md](docs/STANDALONE_PLAN.md).

Everything here is checked against Bank Core's stand-in host only. Nothing in this repository has been verified in the live client yet; see [Not yet verified live](#not-yet-verified-live).

## Features

- **Cleanup tab.** A sidebar tab of folders, as in Bank Tags: Review (Quest Items, Storage Chest, Diango Reclaimable), Utility storage (Metal Bank, Clue Carrier, Tool Leprechaun, Focus Storage, Spirits, Storm Barn), Player-owned house (seven house storage categories), and Archaeology (Archaeologist's Workbench, Material Storage), each with its number of categories. Clicking a folder collapses or expands it; every folder starts open. Inside a folder, one row per category with the number of matching stacks in the bank, or `...` while new items are being checked. The shown category's row is outlined, or its folder while that is collapsed.
- **Category pages.** Choosing a category shows that category's items (choosing it again returns to the bank; choosing another switches the shown page to it) through one Bank Core page that every category shares: the category's name as a label, then exactly the stacks the bank holds now, in bank order. A sectioned category shows each section under its own label, leaving out an empty section: Focus Storage (Focus: Recommended, Focus: Optional), Spirits (Stone Spirits (ore box), Wood Spirits (wood box)), Storage Chest (Non-reclaimable, Reclaimable (chest unlock needed)), Diango Reclaimable (one section per table on the wiki page), and Storm Barn (Manor Farm, Anachronia Dinosaur Farm). An empty category says "None of these items are in your bank."
- **Quest items** appear only when every quest the item belongs to is confirmed finished; anything the client cannot confirm stays out.
- **Storage Chest** splits finished quests' items by whether May's Storage Chest can return them. Reclaimable lists the chest's own items once their quests are confirmed finished. Non-reclaimable lists Quest Items' items the chest does not list: they cannot be reclaimed there. Showing an item does not mean the player can use the chest: it is members only and needs 150 quest points allocated to the caravan's Hub Track. Quest Items stays as its own category: it is the plain list of finished quests' items with no chest involved, and Storage Chest also finds chest items Quest Items has no quest data for.
- **Diango Reclaimable** lists the items Diango's Item Retrieval lists, one section per wiki table. Reclaiming is not always free: entries the wiki marks "Requires return fee" and items with combat stats above tier 1 cost a fee, several outfits can be reclaimed only if they were not combined or upgraded, and an add-on only if it was not installed.
- **Storm Barn** lists checked farm animals; unchecked and tutorial animals cannot go in the barn. **Archaeologist's Workbench** lists damaged artefacts only, which need the workbench storage upgrade from the Archaeology Guild Shop; **Material Storage** lists the materials the material storage container takes, not the tutorial-only ones.
- **Live pages.** A withdrawn item leaves its page as soon as Bank Core reports the bank changed; a deposited item joins once it has been checked. Choosing the Cleanup tab checks every item and quest again.
- **No plugin window entry.** Bank Cleaner has no ribbon icon or panel in the Plugins window; everything it shows is in the bank.

## Requirements and load order

- **PrettyUI** is a required dependency.
- **Bank Core** (`bankcore`) is needed for anything in the bank. It is declared as an optional dependency only because the host reports changes for optional dependencies. Without it, Bank Cleaner loads and waits, showing nothing.

Any load order works: Bank Cleaner connects when Bank Core loads, reconnects when Bank Core reloads, and lets go when Bank Core unloads, through the host's `PluginDependencyUpdate`. Reloading Bank Cleaner shuts down the previous copy in the same Lua state first; a copy whose owner ID a newer load took stays idle.

**Old installs.** The old integrated `bankutils` plugin (and the older `bankutilities`) also had a Cleanup tab. They are not expected to work against this Bank Core, whose private bridge they used was removed; disable them so the cleanup views are not loaded twice.

## Saved data

Bank Cleaner saves only which Cleanup folders are collapsed, under `bankcleaner_folders` as `{ collapsed = { <group>, ... } }`; names that are not current groups are ignored on load. If the client refuses the save, the folder stays as the player left it until Bank Cleaner reloads. It has no preferences, so it adds no section to Bank Core's settings window.

## Changes from the old integrated plugin

- Pages show only the stacks the bank holds, from the same bank snapshot, and follow every bank change; the old plugin kept withdrawn items as ghosts until the category was scanned again.
- Each category is introduced by Bank Core's standard label row, as Bank Tags' labels are; the old custom page heading is gone.
- Placeholders never appear.
- The Cleanup tab has no search box; its 18 categories fit without one.
- All categories share one Bank Core page whose key names the category, so the 18 categories fit Bank Core's 16-page limit. Its groups are folders that collapse, drawn by Bank Cleaner in its own column rather than as Bank Core's plain rows.
- Items are checked once each and remembered until the Cleanup tab is chosen again, so a bank change rechecks only new items.

## Layout

- `plugins/bankcleaner/`: the entry (`main.lua`) and manifest.
- `bankcleaner/`: every runtime module. All require paths start with `bankcleaner/`. The catalogs in `bankcleaner/data/` are unchanged from Bank Utilities, except five generated from the RuneScape Wiki: `storage_chest_objects`, `diango_objects`, `storm_barn_objects`, `workbench_artefact_objects`, and `material_storage_objects`. Their sources, revisions, counts, and every unresolved or excluded entry are in [docs/CATALOG_SOURCES.md](docs/CATALOG_SOURCES.md).
- `tools/`: the build and check tools, adapted from Bank Tags', and the test harness that loads Bank Core beside Bank Cleaner. `tools/catalogs/` holds the Node script that regenerates the five wiki catalogs (`node tools/catalogs/generate_catalogs.mjs`); it reads the wiki's public API and is not part of the build or check.
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
- Quest completion as `config.Quest.FromID(id).hasFinishedQuest` reports it, unchanged from the old plugin, including for the quest IDs the Storage Chest catalog takes from the wiki.
- The five wiki catalogs against the live client: item IDs come from wiki item infoboxes, not the game cache.
