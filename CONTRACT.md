# Bank Cleaner contract

This describes what Bank Cleaner uses from Bank Core and the host. Bank Cleaner offers no API to other plugins. Like Bank Core's API it has no version number: nothing has shipped, so a change updates this document and the tests.

## Plugin identity

- Plugin name `bankcleaner`. PrettyUI is required; `bankcore` is an optional dependency.
- The entry returns nothing. The running session is `_G.__bankcleaner_session`; a new load shuts it down first, and it is cleared only while it still holds this load's value.
- Event names start with `bankcleaner_`: `bankcleaner_scan` (the classification scan, subscribed only while it runs). The manifest sets `hasRibbonIcon` to `false`, and Bank Cleaner does not subscribe to `Event.ContentLayerReady`.
- Bank Cleaner saves only the collapsed Cleanup folders, under `bankcleaner_folders`.

## What Bank Cleaner uses from Bank Core

Only the public owner API in Bank Core's `HOST_CONTRACT.md`:

- `RegisterExtension("bankcleaner", "Bank Cleaner")`, found through the injected `bankcore` or `__bankcore_api`; a copy whose owner ID a newer load took never registers again. A Bank Core whose handle has no `CreatePage` is too old: Bank Cleaner disposes the handle and writes to the host log that Bank Core needs updating.
- Each of the 18 categories has its own page, built when it is shown and passed to `CreatePage`: `{ title = <Label>, key = "cleanup:<id>", layout = rows }`. Bank Core keeps only the page it shows. Rows are Bank Core's standard `{ label = text }` rows and `{ slots = { { item = objectID, copy = n }, ... } }` rows. No page has a `heading`. Rescans of the same category keep its key, so they keep the scroll position; switching category changes the key, so the page starts at the top.
- One mounted tab `cleanup` ("Cleanup", icon `ERASER`), registered once with callbacks that never change, so count changes redraw its rows in place and never call `UpdateTab`. `mount` builds a PrettyUI `List` in `ctx.parent` of a folder row per group and, under an open folder, a row per category with its count (at most six characters); `resize` fits the list to `ctx:GetBounds()`; `unmount` destroys it. A category row calls `ctx:LeavePage()` when its category is shown; otherwise it chooses that category and calls `ctx:CreatePage` with its page, which shows the bank's View All or preset guidance on refusal. A folder row opens and leaves nothing. The shown category comes from `onPage(visible, key)`: the category the key names while Bank Cleaner's page is shown, otherwise none, so a refused page outlines no row. The chosen category survives a reconnect, which shows nothing until a row is clicked; a reload starts on Quest Items.
- `SetListener` with `onState`, `onPage`, and `onBankItems`; `GetBankItems`, `CreatePage`, `RegisterTab`, `GetState`, and `Dispose`; mount context `GetBounds`, `CreatePage`, and `LeavePage`.
- No mounted pages, settings section, menus, launchers, drops, or highlights.

## Page contents

- A slot names a stack of the `GetBankItems` generation the page was built from, with quantity above zero. Placeholders and objects the bank does not hold are never listed, so Bank Core draws no ghost. Bank Core numbers copies by position, so after a reorder a copy number can be stale until the next generation is read.
- A category without sections is `{ label = <Label> }` and one slots row. Focus Storage, Spirits, Storage Chest, Diango Reclaimable, and Storm Barn list each non-empty section's label and slots in the definition's order; Diango's and Storm Barn's sections come from their catalogs. An object in several of a category's sections is shown in the first.
- A category with no members is one label: "Scanning bank..." until the first scan since the bank opened or the tab was chosen has finished, then "None of these items are in your bank."

## Bank reads and scanning

- `onBankItems` is followed by `GetBankItems` only while the Cleanup tab is active with the bank open or the category page is shown; otherwise the bank is read when they come into view. While `GetBankItems` answers `building` or `not_all_items`, the last snapshot stays; `bank_closed`, or an `onState` reason of `bank_closed`, `not_ready`, or `stale_api`, drops it.
- Each object's categories are cached. A new snapshot rebuilds every page at once from the cache; objects not yet classified are evaluated 25 per logic tick, while in view, and the pages are rebuilt once when they are all done. A snapshot that arrives mid-scan becomes the scan's target and keeps finished work.
- `onState` reporting `activeTab == "cleanup"` with the bank open, after it was not, clears the cache and the quest results.
- Registering the tab, reading the bank, and scanning never show a page. After a scan or bank change, `CreatePage` draws the chosen category again only while `GetState().pageVisible` says Bank Core still shows Bank Cleaner's page and its rows changed, so a result never takes the bank from another plugin or from the native view. The tab's rows are redrawn only when a count, the shown category, or a folder changed. Every category is classified on each scan, so counts cover all 18 while only the shown one is drawn as a page.

## Host behavior Bank Cleaner relies on

Checked with Bank Core's stand-in host only: `config.Quest.FromID(id).hasFinishedQuest` for quest completion (any error, missing config, or unfinished quest leaves the item out; the Quest Items and Storage Chest rules share it), `PluginDependencyUpdate` on loads and reloads, `Event.Logic`, PrettyUI's `List` in the tab, `PersistentDB:GetStructuredData` and `SetStructuredData` for the collapsed folders, and the folder chevron's `id.Sprite.BANK_ARROW_UP_0` turned through the same sprite rotation fields Bank Tags sets.
