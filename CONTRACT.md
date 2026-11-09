# Bank Cleaner contract

This describes what Bank Cleaner uses from Bank Core and the host. Bank Cleaner offers no API to other plugins. Like Bank Core's API it has no version number: nothing has shipped, so a change updates this document and the tests.

## Plugin identity

- Plugin name `bankcleaner`. PrettyUI and Bank Utilities Core (`bankcore`) are declared in `requiredDependencies`. Core uses the local development folder string `"bankcore"` until it has a published mod.io ID.
- The entry returns nothing. The running session is `_G.__bankcleaner_session`; a new load shuts it down first, and it is cleared only while it still holds this load's value.
- Event names start with `bankcleaner_`: `bankcleaner_scan` (the classification scan, subscribed only while it runs). The manifest sets `hasRibbonIcon` to `false`, and Bank Cleaner does not subscribe to `Event.ContentLayerReady`.
- Bank Cleaner saves only the collapsed Cleanup folders, under `bankcleaner_folders`.

## What Bank Cleaner uses from Bank Core

Only Bank Core's public API (`docs/API.md` in Bank Core), requiring Core 1.5.0 or later:

- `Register{ id = "bankcleaner", name = "Bank Cleaner", icon = "ERASER", column, onClose, onBankItems, onBankClose, onBankStateChanged }`, on the API read from `bankcore or rawget(_G, "__bankcore_api")`, when Bank Cleaner loads and whenever `PluginDependencyUpdate` reports `bankcore` enabled; each registration disposes Bank Cleaner's previous one first. `Dispose` when `bankcore` is disabled and on shutdown.
- The extension's `SetPage`, `Open`, `Close`, `IsOpen`, `GetBankItems`, `GetBankState`, and `Dispose`.
- One rail icon with its column. `mount(ctx)` builds a PrettyUI `List` in `ctx.parent` of a folder row per group and, under an open folder, a row per category with its count (at most six characters); `resize(ctx)` fits the list to `ctx.width` and `ctx.height`; `unmount` destroys it. A folder row opens or collapses and leaves the page alone.
- A category row whose category is shown calls `Close`. Any other row chooses that category, calls `SetPage` with its page, then `Open`; refusals show an actionable error over the bank title in `ctx.overlay` and outline no row. A successful opening clears the error. The shown category is the one whose page Bank Cleaner last set, while `IsOpen()` says it is shown; `onClose` redraws the rows so the outline goes. The chosen category survives a reconnect, which shows nothing until a row is clicked; a reload starts on Quest Items.
- Cleaner reads `GetBankState()` after registration and before reads and category clicks, and receives `onBankStateChanged(state)`. Pages require `bankOpen` and `viewAll`, with `presetOpen`, `searchActive`, and `filterActive` false. A restriction closes only Cleaner's page, stops scanning, clears its selection, and explains the restriction in the banner. Recovery clears the banner and refreshes visible counts, but never reopens a page. Native search and filters do not include Cleaner's own search field. Core owns state callback delivery and disposal.
- No settings, menus, drops, or highlights.

## Page contents

- A page is `{ title = <optional Label>, rows }`; Bank Core draws a heading only when a title is supplied. Bank Cleaner omits the title when the first row already supplies a section or status label. Rows are `{ label = text }` and `{ slots = { objectID, ... } }`.
- A category lists an object once per present stack it matches, in bank order. Bank Core shows an object's stocked stacks first. After the initial scan finishes, the open page's slot list is held fixed; withdrawn stacks become empty slots through Core's normal item rendering. Reopening a category or changing cleanup search rebuilds it from present stacks, excluding existing placeholders.
- A category without sections is one slots row. Focus Storage, Spirits, Storage Chest, Diango Reclaimable, and Storm Barn list each non-empty section's label and slots in the definition's order; Diango's and Storm Barn's sections come from their catalogs. An object in several of a category's sections is shown in the first.
- A category with no members is one label: "Scanning bank..." until the first scan since the bank opened or the column was mounted has finished, then "None of these items are in your bank."

## Bank reads and scanning

- `onBankItems` is followed by `GetBankItems` only while the Cleanup column is mounted or the category page is shown; otherwise the bank is read when they come into view. While `GetBankItems` answers `not_all_items` or `busy`, the last snapshot stays; `bank_closed` or `onBankClose` drops it.
- Each object's categories are cached. A new snapshot rebuilds every page at once from the cache; objects not yet classified are evaluated 25 per logic tick, while in view, and the pages are rebuilt once when they are all done. A snapshot that arrives mid-scan becomes the scan's target and keeps finished work.
- Mounting the column clears the cache and the quest results.
- Registering, reading the bank, and scanning never open a page. After a scan or bank change, the chosen category's page goes to `SetPage` only when it changed and is not frozen. A page opened during a scan freezes once that scan completes; later bank updates change counts without resending its layout. Closing the page releases the freeze, and opening another category or changing cleanup search builds a fresh layout. Results never open a page themselves. Opening a category is a new view that starts at the top. The column's rows are redrawn only when a count, the shown category, or a folder changed. Every category is classified on each scan, so counts cover all categories while only the chosen one is a page.

## Host behavior Bank Cleaner relies on

Checked with Bank Core's stand-in host only: `config.Quest.FromID(id).hasFinishedQuest` for quest completion (any error, missing config, or unfinished quest leaves the item out; the Quest Items and Storage Chest rules share it), required dependencies available before startup, `Event.Logic`, PrettyUI's `List` in the column, `PersistentDB:GetStructuredData` and `SetStructuredData` for the collapsed folders, and the folder chevron's `id.Sprite.BANK_ARROW_UP_0` turned through the same sprite rotation fields Bank Tags sets. Required dependency change notifications are not documented; reload Bank Cleaner after reloading Core. The defensive `PluginDependencyUpdate` handler is tested with an optional-dependency fixture.
