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
| Utility storage | Items for the Metal Bank, Clue Carrier, Tool Leprechaun, Focus Storage, spirit storage, and Storm Barn |
| Player-owned house | Items supported by the house's storage categories |
| Archaeology | Damaged artefacts for workbench storage and materials for material storage |

Click a folder to collapse or expand it. The plugin remembers your collapsed folders.
Folder and category icons use the same item images, spacing and indentation as Bank Tags.

## Read reclaimable results carefully

**A match is not permission to destroy an item. Verify that you can reclaim it in-game first.**

- **Quest Items** lists items whose associated quests are confirmed finished. Quest completion alone does not mean an item is safe to discard.
- **Storage Chest → Reclaimable** lists items May's chest can return, subject to its unlocks. The chest is members-only and needs 150 quest points allocated to the caravan's Hub Track. The cat training medal has a known reclaim bug for some players.
- **Storage Chest → Non-reclaimable** means those listed quest items are not in the chest's catalog. It does not mean no other reclaim source exists.
- **Diango Reclaimable** is grouped by the wiki's tables. Some returns cost a fee or depend on whether an outfit was combined, upgraded, or an add-on installed.

The plugin cannot verify every reclaim condition for your account. The catalogs and their exceptions are documented in [catalog sources](docs/CATALOG_SOURCES.md).

## Storage restrictions

Storm Barn lists checked farm animals, not unchecked or tutorial animals. Workbench storage lists **damaged** artefacts and needs the storage upgrade from the Archaeology Guild Shop. Material Storage excludes tutorial-only materials.

## Refresh and troubleshoot

The displayed page follows bank changes reported by Bank Core. Choosing the eraser icon checks items and quest status again.

- **No eraser icon:** check that Bank Core and PrettyUI are enabled.
- **No matching items:** the category only shows held stacks; bank placeholders are excluded.
- **Cannot open a category:** close the preset selector, switch to the bank's All Items tab, and try again.
- **Unexpected reclaim match:** verify the item with the reclaim service and report the item's name and category. Do not discard it to test the plugin.

Disable the older integrated `bankutils` or `bankutilities` plugin if you still have one installed.

## For reviewers and developers

[Build, saved data, architecture, and validation limits](docs/DEVELOPMENT.md) · [Core contract](CONTRACT.md) · [catalog sources and exclusions](docs/CATALOG_SOURCES.md) · [code style](STYLE_GUIDE.md).

The catalogs are sourced data, not a guarantee of account-specific reclaim eligibility. Automated tests do not replace live-client checks.
