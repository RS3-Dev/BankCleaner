# Bank Cleaner

Bank Cleaner helps you find bank items that may belong in other storage, or that another service may let you reclaim later. It **lists candidates**; it does not automatically store, destroy, or reclaim anything.

## Before you start

Enable **PrettyUI**, **Bank Core**, and **Bank Cleaner** in the client's plugin manager. Open a bank, then click the eraser icon (**Bank Cleaner**) on the left rail to show the Cleanup folders. There is no separate ribbon panel.

## Find items to move

1. Expand a folder in Cleanup.
2. Click a category to show matching items from your bank.
3. Hover or inspect the items, then withdraw the ones you want to move.
4. Visit the appropriate storage location and store them through the game's normal interface.

Click the selected category again to return to the normal bank view. A category with no matches says so. Counts refer to matching bank stacks, not individual item quantities. An ellipsis (`...`) means items are still being checked.

## Choose a category

| Folder | What it helps you find |
| --- | --- |
| Review | Finished-quest items, May's Storage Chest items, and Diango reclaimables |
| Utility storage | Items for the Metal Bank, Clue Carrier, Tool Leprechaun, Focus Storage, spirit storage, Storm Barn, and Seed Bag |
| Player-owned house | Items supported by the house's storage categories |
| Archaeology | Damaged artefacts for workbench storage and materials for material storage |

Use the search field above the folders to search item names within cleanup pages. Search ignores capitalization. Folders and categories keep their structure, and their counts reflect the matching items. Clear the search to show all cleanup items again.

Click a folder to collapse or expand it. The plugin remembers your collapsed folders. Folder counts add up the matching bank stacks on their category pages, including when collapsed. A stack appearing on two pages contributes to both page counts.
Folder and category icons use the same item images, spacing and indentation as Bank Tags.

## Read reclaimable results carefully

**A match is not permission to destroy an item. Verify that you can reclaim it in-game first.**

- **Quest Items** lists items whose associated quests are confirmed finished. Quest completion alone does not mean an item is safe to discard.
- **Storage Chest → Reclaimable** lists items May's chest can return, subject to its unlocks. The chest is members-only and needs 150 quest points allocated to the caravan's Hub Track. The cat training medal has a known reclaim bug for some players.
- **Storage Chest → Non-reclaimable** means those listed quest items are not in the chest's catalog. It does not mean no other reclaim source exists.
- **Diango Reclaimable** is grouped by the wiki's tables. Some returns cost a fee or depend on whether an outfit was combined, upgraded, or an add-on installed.

The plugin cannot verify every reclaim condition for your account. Catalog data comes from the RuneScape Wiki.

## Storage restrictions

Storm Barn lists checked farm animals, not unchecked or tutorial animals. Workbench storage lists **damaged** artefacts and needs the storage upgrade from the Archaeology Guild Shop. Material Storage excludes tutorial-only materials.

## Refresh and troubleshoot

Item slots stay in place while a category is open, so withdrawing a stack leaves an empty slot instead of shifting the page. Close and reopen the category to refresh its layout. Changing the cleanup search also refreshes the layout. Quantities and sidebar counts still follow bank changes. Choosing the eraser icon checks items and quest status again.

- **No eraser icon:** check that Bank Core and PrettyUI are enabled.
- **No matching items:** the category only shows held stacks; bank placeholders are excluded.
- **Page closes or a category cannot open:** follow the message above the bank: close the preset selector, clear the bank's search or filter, or select All Items. Then choose the category again. Cleaner's own search field remains available.
- **Unexpected reclaim match:** verify the item with the reclaim service and report the item's name and category. Do not discard it to test the plugin.

Disable the older integrated `bankutils` or `bankutilities` plugin if you still have one installed.

## Development

The repository is the runtime: `main.lua`, `app.lua`, `plugin.json`, and supporting Lua modules in `resources/cleanup/` and `resources/data/`. No build step is needed.

Lua tests and their helpers live in `tests/`. See [test instructions](tests/README.md).

For a runtime ZIP, include only `main.lua`, `app.lua`, `plugin.json`, and `resources/` directly at the archive root. Exclude `tests/` and this README.

Automated tests use a simulated host and do not replace live-client checks.
