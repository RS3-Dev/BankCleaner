# Catalog sources

Generated 2026-10-21 by `node tools/catalogs/generate_catalogs.mjs` from the RuneScape Wiki's public API (`action=query` revisions, `action=parse` for rendered tables, and the `infobox_item` bucket for item IDs). Item IDs come only from item infoboxes: an entry naming a set (an `Infobox Set`) lists its pieces, and an entry naming neither is listed as unresolved rather than guessed.

## Source revisions

| Page | Section | Revision |
| --- | --- | --- |
| [Storage Chest](https://runescape.wiki/w/Storage_Chest#Reclaimable_items) | Reclaimable items | 37213365 (2026-10-19T13:52:11Z) |
| [Diango's Item Retrieval](https://runescape.wiki/w/Diango's_Item_Retrieval#Storable_rewards) | Storable rewards | 37051936 (2026-05-22T18:57:42Z) |
| [Player-owned farm](https://runescape.wiki/w/Player-owned_farm#Animals) | Animals | 37110514 (2026-07-21T01:24:08Z) |
| [Storm barn](https://runescape.wiki/w/Storm_barn) |  | 37058437 (2026-06-01T08:41:13Z) |
| [Template:Player-owned farm](https://runescape.wiki/w/Template:Player-owned_farm) |  | 37058430 (2026-06-01T08:29:02Z) |
| [Template:Anachronia Dinosaur Farm](https://runescape.wiki/w/Template:Anachronia_Dinosaur_Farm) |  | 36950198 (2026-03-02T05:57:10Z) |
| [Archaeologist's workbench](https://runescape.wiki/w/Archaeologist's_workbench#Products) | Products (rendered) | 37210198 |
| [Materials (Archaeology)](https://runescape.wiki/w/Materials_(Archaeology)#List_of_materials) | List of materials | 37072742 (2026-06-17T05:04:24Z) |

## Storage Chest

`storage_chest_objects.lua`: 105 objects from 97 named items (each table row, plus an alternative it names, such as the engrammeter or the ring of charos (a)). The wiki lists only reclaimable items. Each object carries the quests that must be confirmed finished before it shows: Bank Utilities' `object_quests` when it has the object (39), otherwise the quest links in the item's infobox mapped to quest IDs through the `infobox_quest` bucket (66); an object with neither (6) is listed with no quests and never shows. Of the objects `object_quests` covers, the infobox links every one of its quests for 25, links no quest for 14, and conflicts for 0. The chest is members only and needs 150 quest points allocated to the caravan's Hub Track.

- Unresolved entries: 6
  - 88 Boots of lightness (Inventory): no quest to confirm, so never shown
  - 89 Boots of lightness (worn): no quest to confirm, so never shown
  - 1575 Cat training medal: no quest to confirm, so never shown
  - 30994 Distorted engrammeter: no quest to confirm, so never shown
  - 39241 Shard of Mah: no quest to confirm, so never shown
  - 56771 Zorgoth's soul ring: no quest to confirm, so never shown
- Excluded: 0
- Notes: 4
  - Blank observation: unless used to upgrade Pontifex observation ring
  - Bob's collar: unless returned to Bob
  - Hazeel's mark: if supported Hazeel's cultists
  - Old necklace: unless used to upgrade to Necklace of Charos

## Diango's Item Retrieval

`diango_objects.lua`: 1604 objects in 35 sections, one per wiki table, from 665 entries. An entry naming a set (`Infobox Set`) or a list page (such as an outfit whose page lists its pieces, keeping only linked item pages that link back) counts a piece only when the piece's page is in [Category:Reclaimable from Diango](https://runescape.wiki/w/Category:Reclaimable_from_Diango) (1539 pages) or names Diango; a pet entry uses its pet infobox's item ID. An object in several tables is shown in the first. Fees: the wiki marks some entries "Requires return fee", and items with combat stats above tier 1 cost a fee to reclaim; several outfits are reclaimable only if not combined or upgraded, and add-ons only if not installed.

| Section | Entries | Fee entries | Objects |
| --- | --- | --- | --- |
| Holiday Items | 36 | 0 | 64 |
| Christmas | 61 | 0 | 77 |
| Halloween | 26 | 0 | 40 |
| Mental Health Awareness Week | 4 | 0 | 4 |
| Summer Beach Party & The Beach | 11 | 0 | 11 |
| Easter | 13 | 0 | 16 |
| RuneFest | 5 | 0 | 5 |
| Golden Gnome Awards | 10 | 0 | 10 |
| Cryptic Clue Fest | 7 | 0 | 11 |
| Treasure Hunter items | 47 | 9 | 179 |
| Ghostweave outfits | 15 | 0 | 75 |
| Valentine's Day (Treasure Hunter items) | 15 | 6 | 45 |
| Clover necklaces | 9 | 0 | 18 |
| Zodiac Training | 5 | 0 | 5 |
| Astromancer | 5 | 0 | 13 |
| Talk Like a Pirate | 5 | 2 | 7 |
| Desert Treasure warrior outfits | 4 | 0 | 20 |
| New Year's Resolutions | 3 | 0 | 12 |
| Squeal of Fortune Items | 51 | 7 | 101 |
| Luchador masks | 10 | 0 | 10 |
| Tattoos | 6 | 0 | 6 |
| Horns | 5 | 0 | 5 |
| Outfits of seasons | 4 | 0 | 20 |
| Valentine's Day (Squeal of Fortune items) | 5 | 3 | 24 |
| Starfire Items | 4 | 4 | 44 |
| Starfury Items | 4 | 4 | 60 |
| Slayer Masks | 23 | 23 | 23 |
| Slayer Helms | 23 | 23 | 23 |
| Skilling Outfits | 67 | 0 | 303 |
| Miscellaneous Skilling Items | 13 | 0 | 14 |
| Lucky and Golden items | 49 | 0 | 151 |
| Treasure Hunter items (Other reclaimable items) | 80 | 2 | 131 |
| Parcels from the Hedge | 33 | 0 | 33 |
| Gielinor Games | 3 | 0 | 36 |
| Beyond the Arc | 4 | 4 | 8 |

- Objects also in a later table: 2
  - 31612 Spring cleaner: shown in Treasure Hunter items, also Miscellaneous Skilling Items
  - 56630 Power Flower Basket: shown in Holiday Items, also Treasure Hunter items (Other reclaimable items)
- Entries read from a list or pet page: 13
  - San'tar spawnling (pet): San'tar spawnling
  - Chic scarf (list): Chic scarf
  - Exquisite equipment (list): Exquisite 2h sword (40), Exquisite 2h sword (10), Exquisite battleaxe (40), Exquisite battleaxe (10), Off-hand exquisite battleaxe (40), Off-hand exquisite battleaxe (10), Exquisite claw (40), Exquisite claw (10), Off-hand exquisite claw (40), Off-hand exquisite claw (10), Exquisite crossbow (40), Exquisite crossbow (10), Off-hand exquisite crossbow (40), Off-hand exquisite crossbow (10), Exquisite halberd (40), Exquisite halberd (10), Exquisite longsword (40), Exquisite longsword (10), Off-hand exquisite longsword (40), Off-hand exquisite longsword (10), Exquisite mace (40), Exquisite mace (10), Off-hand exquisite mace (40), Off-hand exquisite mace (10), Exquisite wand (40), Exquisite wand (10), Exquisite orb (40), Exquisite orb (10), Exquisite shield (40), Exquisite shield (10), Exquisite shortbow (40), Exquisite shortbow (10), Exquisite spear (40), Exquisite spear (10), Exquisite staff (40), Exquisite staff (10), Exquisite sword (40), Exquisite sword (10), Off-hand exquisite sword (40), Off-hand exquisite sword (10), Exquisite whip (40), Exquisite whip (10)
  - Sunglasses (list): Sunglasses
  - Disco outfit (list): Disco top, Disco legs, Disco hands, Disco feet
  - Cool disco outfit (list): Cool disco top, Cool disco legs, Cool disco hands, Cool disco feet
  - Super disco outfit (list): Super disco top, Super disco legs, Super disco hands, Super disco feet
  - Beta scientist outfit (list): Beta scientist head, Beta scientist torso, Beta scientist legs, Beta scientist backpack, Beta scientist gloves, Beta scientist feet
  - Capoeira outfit (list): Capoeira dreadlocks, Capoeira top, Capoeira legs
  - Death Lotus Disciple Mask (list): Death Lotus Disciple Mask
  - Death Lotus Disciple Torso (list): Death Lotus Disciple Torso
  - Flaming skull (list): Flaming skull
  - Crown of Loyalty (list): Crown of Loyalty I, Crown of Loyalty II, Crown of Loyalty III, Crown of Loyalty IV, Crown of Loyalty V, Crown of Loyalty VI, Crown of Loyalty VII, Crown of Loyalty VIII, Crown of Loyalty IX, Crown of Loyalty X, Crown of Loyalty XI, Crown of Loyalty XII, Crown of Loyalty XIII, Crown of Loyalty XIV, Crown of Loyalty XV
- Unresolved entries: 1
  - Green skin (Treasure Hunter items (Other reclaimable items)): not an item
- Excluded: 0

## Storm barn

`storm_barn_objects.lua`: 102 checked animal items from the Animals groups of the Player-owned farm and Anachronia Dinosaur Farm navboxes. The barn stores checked animals only, so unchecked and tutorial animals are left out; eggs and babies are growth stages of the checked item, and shiny breeds without their own item show as their base breed. Produce, pets, and unchecked eggs are not listed.

| Section | Entries | Objects |
| --- | --- | --- |
| Manor Farm | 59 | 51 |
| Anachronia Dinosaur Farm | 65 | 51 |

- Checked animal items found by the wiki search `insource:"for your player owned farm"` but not in a navbox: 2
  - 3947 Human (checked female) (Human (player-owned farm))
  - 3951 Human (checked male) (Human (player-owned farm))
- Unresolved entries: 0
- Excluded: 19
  - Chicken egg (unchecked): unchecked animal; the barn takes checked only
  - Jackalope (player-owned farm): no item of its own; as an item it appears as one of its normal breeds
  - Lizard chicken: no item of its own; as an item it appears as one of its normal breeds
  - Golden chinchompa (player-owned farm): no item of its own; as an item it appears as one of its normal breeds
  - Golden ewe: no item of its own; as an item it appears as one of its normal breeds
  - Golden ram: no item of its own; as an item it appears as one of its normal breeds
  - Magical zygomite: no item of its own; as an item it appears as one of its normal breeds
  - Harlequin cow: no item of its own; as an item it appears as one of its normal breeds
  - Sacred yak: no item of its own; as an item it appears as one of its normal breeds
  - Wytchfire salamander: no item of its own; as an item it appears as one of its normal breeds
  - Luminous jadinko: no item of its own; as an item it appears as one of its normal breeds
  - Hypnotic dinosaur: no item of its own; as an item it appears as one of its normal breeds
  - Magnificent dinosaur: no item of its own; as an item it appears as one of its normal breeds
  - Spicati apoterrasaur lucidum: no item of its own; as an item it appears as one of its normal breeds
  - Oculi apoterrasaur lucidum: no item of its own; as an item it appears as one of its normal breeds
  - Scimitops lucidum: no item of its own; as an item it appears as one of its normal breeds
  - Malletops lucidum: no item of its own; as an item it appears as one of its normal breeds
  - Corbicula lucidum: no item of its own; as an item it appears as one of its normal breeds
  - Pavosaurus lucidum: no item of its own; as an item it appears as one of its normal breeds

## Archaeologist's workbench

`workbench_artefact_objects.lua`: 235 objects from 235 damaged artefacts in the rendered Products table (245 products). Only the damaged artefacts count; restored artefacts and materials do not. Storage needs a workbench upgrade from the Archaeology Guild Shop.

- Unresolved entries: 0
- Excluded: 0

## Material storage

`material_storage_objects.lua`: 45 objects from the 45 materials in the List of materials table; the tutorial-only table is left out.

- Unresolved entries: 0
- Excluded: 2
  - Imperial iron: tutorial only; not storable
  - Purpleheart wood: tutorial only; not storable
