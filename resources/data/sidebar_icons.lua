-- Item icons shown beside Cleaner folders and categories
-- Guide and furniture display items use the same catalog as Bank Tags' icon selector

return {
    folders = {
        ["Review"] = id.Obj.MISC_KEY, -- Miscellaneous key
        ["Utility storage"] = id.Obj.MENAPHOS_FACTION_WORKER_BANK_CHEST, -- Bank chest
        ["Player-owned house"] = id.Obj.POH_TABLET_TELEPORTTOHOUSE, -- Teleport to house
        ["Archaeology"] = id.Obj.ARCH_JOURNAL, -- Archaeology journal
    },
    categories = {
        quest_items = id.Obj.SKILLCAPE_QP, -- Quest Cape
        storage_chest = id.Obj.MAKINGHISTORY_CHEST, -- Chest
        diango = id.Obj.CRCS_GOLDEN_TICKET, -- Circus ticket
        metal_bank = id.Obj.TIN_ORE, -- Tin ore
        clue_carrier = id.Obj.QUEST_CHAROS_TRAIL_REWARD, -- Charos' clue carrier
        tool_leprechaun = id.Obj.TROWEL, -- Trowel
        focus_storage = id.Obj.ECTOPLASM, -- Ectoplasm
        spirits = id.Obj.MINING_OREBOX_RUNE, -- Rune ore box
        storm_barn = id.Obj.PICKPOCKET_GUIDE_FARMER, -- Farmer
        seed_bag = id.Obj.EGWD_BIK_SEED_STORAGE, -- Seed bag
        treasure_chest = id.Obj.TRH154_CHEST_GILDED, -- Gilded treasure chest
        armour_case = id.Obj.POH_COS_ROOM_ARMOUR_CASE_MAHOGANY, -- Mahogany armour case
        magic_wardrobe = id.Obj.POH_COS_ROOM_MAGIC_WARDROBE_MAHOGANY_GILDED, -- Gilded magic wardrobe
        cape_store = id.Obj.POH_COS_ROOM_CAPE_RACK_MAGIC_STONE, -- Magical cape rack
        toy_box = id.Obj.POH_COS_ROOM_TOY_BOX_MAHOGANY, -- Mahogany toy box
        fancy_dress_box = id.Obj.POH_COS_ROOM_FANCY_DRESS_BOX_MAHOGANY, -- Mahogany fancy dress box
        bookcase = id.Obj.CON_CONTRACTS_BUILD_BOOKCASE_MAHOGANY, -- Bookcase (mahogany)
        workbench = id.Obj.ARCH_RESTORATION_VENATOR_LIGHT_CROSSBOW_DAMAGED, -- Venator light crossbow (damaged)
        material_storage = id.Obj.ARCH_MATERIAL_TYRIAN_PURPLE, -- Tyrian purple
        polypore_merchant = id.Obj.POLYPORE_SPORE, -- Polypore spore
    },
}
