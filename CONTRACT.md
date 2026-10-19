# Bank Cleaner contract

This describes what Bank Cleaner uses from Bank Core and the host. Bank Cleaner offers no API to other plugins. Like Bank Core's API it has no version number: nothing has shipped, so a change updates this document and the tests.

## Plugin identity

- Plugin name `bankcleaner`. PrettyUI is required; `bankcore` is an optional dependency.
- The entry returns nothing. The running session is `_G.__bankcleaner_session`; a new load shuts it down first, and it is cleared only while it still holds this load's value.
- Event names start with `bankcleaner_`: `bankcleaner_scan` (the classification scan, subscribed only while it runs) and `bankcleaner_content` (the plugin panel).
- Bank Cleaner reads and writes no saved data.

## What Bank Cleaner uses from Bank Core

Only the public owner API in Bank Core's `HOST_CONTRACT.md`:

- `RegisterExtension("bankcleaner", "Bank Cleaner")`, found through the injected `bankcore` or `__bankcore_api`; a copy whose owner ID a newer load took never registers again.
- 13 pages, one per category, with the category's ID as page ID: `{ title = <Label>, key = "cleanup:<id>", layout = rows }`. Rows are Bank Core's standard `{ label = text }` rows and `{ slots = { { item = objectID, copy = n }, ... } }` rows. No page has a `heading`. The key never changes, so updates keep the scroll position.
- One rows tab `cleanup` ("Cleanup", icon `ERASER`): `{ heading = group }` rows and `{ page = <id>, label = <Label>, detail = <count or "..."> }` rows, 16 in all. Details are at most six characters.
- `SetListener` with `onState`, `onPage`, and `onBankItems`; `GetBankItems`, `RegisterPage`, `UpdatePage`, `RegisterTab`, `UpdateTab`, `GetState`, and `Dispose`.
- No mounted content, settings section, menus, launchers, drops, or highlights.

## Page contents

- A slot names a stack of the `GetBankItems` generation the page was built from, with quantity above zero. Placeholders and objects the bank does not hold are never listed, so Bank Core draws no ghost. Bank Core numbers copies by position, so after a reorder a copy number can be stale until the next generation is read.
- A category without sections is `{ label = <Label> }` and one slots row. Focus Storage and Spirits list each non-empty section's label and slots in the definition's order.
- A category with no members is one label: "Scanning bank..." until the first scan since the bank opened or the tab was chosen has finished, then "None of these items are in your bank."

## Bank reads and scanning

- `onBankItems` is followed by `GetBankItems` only while the Cleanup tab is active with the bank open or one of the category pages is shown; otherwise the bank is read when they come into view. While `GetBankItems` answers `building` or `not_all_items`, the last snapshot stays; `bank_closed`, or an `onState` reason of `bank_closed`, `not_ready`, or `stale_api`, drops it.
- Each object's categories are cached. A new snapshot rebuilds every page at once from the cache; objects not yet classified are evaluated 25 per logic tick, while in view, and the pages are rebuilt once when they are all done. A snapshot that arrives mid-scan becomes the scan's target and keeps finished work.
- `onState` reporting `activeTab == "cleanup"` with the bank open, after it was not, clears the cache and the quest results.
- `UpdatePage` and `UpdateTab` are called only when a page's rows or the tab's details changed.

## Host behavior Bank Cleaner relies on

Checked with Bank Core's stand-in host only: `config.Quest.FromID(id).hasFinishedQuest` for quest completion (any error, missing config, or unfinished quest leaves the item out), `PluginDependencyUpdate` on loads and reloads, `Event.Logic` and `Event.ContentLayerReady`, and PrettyUI's `Text` on the plugin panel.
