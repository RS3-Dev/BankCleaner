# Bank Cleaner contract

This describes what Bank Cleaner uses from Bank Core and the host. Bank Cleaner offers no API to other plugins. Like Bank Core's API it has no version number: nothing has shipped, so a change updates this document and the tests.

## Plugin identity

- Plugin name `bankcleaner`. PrettyUI is required; `bankcore` is an optional dependency.
- The entry returns nothing. The running session is `_G.__bankcleaner_session`; a new load shuts it down first, and it is cleared only while it still holds this load's value.
- Event names start with `bankcleaner_`: `bankcleaner_scan` (the classification scan, subscribed only while it runs). The manifest sets `hasRibbonIcon` to `false`, and Bank Cleaner does not subscribe to `Event.ContentLayerReady`.
- Bank Cleaner saves only the collapsed Cleanup folders, under `bankcleaner_folders`.

## What Bank Cleaner uses from Bank Core

Only Bank Core's launch API (`docs/LAUNCH_API_SPEC.md` in Bank Core):

- `Register{ id = "bankcleaner", name = "Bank Cleaner", icon = "ERASER", column, onClose, onBankItems, onBankClose }`, on the API read from `bankcore or rawget(_G, "__bankcore_api")`, when Bank Cleaner loads and whenever `PluginDependencyUpdate` reports `bankcore` enabled; each registration disposes Bank Cleaner's previous one first. `Dispose` when `bankcore` is disabled and on shutdown.
- The extension's `SetPage`, `Open`, `Close`, `IsOpen`, `GetBankItems`, and `Dispose`.
- One rail icon with its column. `mount(ctx)` builds a PrettyUI `List` in `ctx.parent` of a folder row per group and, under an open folder, a row per category with its count (at most six characters); `resize(ctx)` fits the list to `ctx.width` and `ctx.height`; `unmount` destroys it. A folder row opens or collapses and leaves the page alone.
- A category row whose category is shown calls `Close`. Any other row chooses that category, calls `SetPage` with its page, then `Open`; a refused `Open` (`not_all_items`, `preset_open`, `busy`, ...) shows no message and outlines no row. The shown category is the one whose page Bank Cleaner last set, while `IsOpen()` says it is shown; `onClose` redraws the rows so the outline goes. The chosen category survives a reconnect, which shows nothing until a row is clicked; a reload starts on Quest Items.
- No settings, menus, drops, or highlights.

## Page contents

- A page is `{ title = <Label>, rows }`; Bank Core draws the title as the heading. Rows are `{ label = text }` and `{ slots = { objectID, ... } }`.
- A category lists an object once per present stack it matches, in bank order. Bank Core shows an object's stocked stacks first, so the slots show exactly the present stacks; placeholders are never listed, so no ghost is drawn unless the bank changes before the next read.
- A category without sections is one slots row. Focus Storage, Spirits, Storage Chest, Diango Reclaimable, and Storm Barn list each non-empty section's label and slots in the definition's order; Diango's and Storm Barn's sections come from their catalogs. An object in several of a category's sections is shown in the first.
- A category with no members is one label: "Scanning bank..." until the first scan since the bank opened or the column was mounted has finished, then "None of these items are in your bank."

## Bank reads and scanning

- `onBankItems` is followed by `GetBankItems` only while the Cleanup column is mounted or the category page is shown; otherwise the bank is read when they come into view. While `GetBankItems` answers `not_all_items` or `busy`, the last snapshot stays; `bank_closed` or `onBankClose` drops it.
- Each object's categories are cached. A new snapshot rebuilds every page at once from the cache; objects not yet classified are evaluated 25 per logic tick, while in view, and the pages are rebuilt once when they are all done. A snapshot that arrives mid-scan becomes the scan's target and keeps finished work.
- Mounting the column clears the cache and the quest results.
- Registering, reading the bank, and scanning never open a page. After a scan or bank change, the chosen category's page goes to `SetPage` only when it changed: Bank Core redraws it in place, keeping scroll, while it is shown, and otherwise keeps it until a row opens it, so a result never takes the bank from another plugin or from the native view. Opening a category is a new view that starts at the top. The column's rows are redrawn only when a count, the shown category, or a folder changed. Every category is classified on each scan, so counts cover all 18 while only the chosen one is a page.

## Host behavior Bank Cleaner relies on

Checked with Bank Core's stand-in host only: `config.Quest.FromID(id).hasFinishedQuest` for quest completion (any error, missing config, or unfinished quest leaves the item out; the Quest Items and Storage Chest rules share it), `PluginDependencyUpdate` on loads and reloads, `Event.Logic`, PrettyUI's `List` in the column, `PersistentDB:GetStructuredData` and `SetStructuredData` for the collapsed folders, and the folder chevron's `id.Sprite.BANK_ARROW_UP_0` turned through the same sprite rotation fields Bank Tags sets.
