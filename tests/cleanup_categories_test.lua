package.path = "./?.lua;" .. package.path

-- Classify objects using stand-in catalogs and quests

local quests = {
    [1] = { hasFinishedQuest = true },
    [2] = { hasFinishedQuest = false },
    [3] = { hasFinishedQuest = true },
}
local questReads = 0
config = {
    Quest = {
        FromID = function(questID)
            questReads = questReads + 1
            if questID == 4 then error("quest config is still loading") end
            return quests[questID]
        end,
    },
}

local Categories = require("bankcleaner/cleanup/categories")

local CATALOGS = {
    objectQuests = { [100] = { 1 }, [101] = { 1, 2 }, [103] = { 1, 3 }, [105] = { 4 }, [106] = {} },
    metalBankObjects = { [102] = true },
    treasureChestObjects = { [101] = true },
    clueCarrierObjects = { [103] = true },
    armourCaseObjects = { [102] = true },
    magicWardrobeObjects = { [100] = true },
    capeStoreObjects = { [101] = true },
    toolLeprechaunObjects = { [102] = true },
    toyBoxObjects = { [103] = true },
    fancyDressBoxObjects = { [100] = true },
    bookcaseObjects = { [101] = true },
    focusRecommendedObjects = { [102] = true },
    focusOptionalObjects = { [103] = true },
    stoneSpiritObjects = { [100] = true },
    woodSpiritObjects = { [101] = true },
    -- 103 is a chest item and a quest item; 107 is only in the chest; 108's quest is unfinished
    -- 109 has no quest to confirm, 114 needs no quest, and 101 is a quest item whose quest 2 is unfinished
    storageChestObjects = { [103] = { 1, 3 }, [107] = { 1 }, [108] = { 2 }, [109] = {}, [114] = true },
    diangoObjects = { sections = {}, objects = { [104] = "s02", [110] = "s01" } },
    stormBarnObjects = { sections = {}, objects = { [111] = "anachronia" } },
    workbenchArtefactObjects = { [112] = true },
    materialStorageObjects = { [113] = true },
    seedBagObjects = { [103] = true },
}

-- Build a snapshot from { objectID, quantity } pairs, as GetBankItems returns it
local function snapshot(specs)
    local items = {}
    for index, spec in ipairs(specs) do items[index] = { objectID = spec[1], quantity = spec[2] } end
    return items
end

-- Describe members as object IDs, with sections
local function listed(members, categoryID)
    local parts = {}
    for index, member in ipairs(members[categoryID]) do
        parts[index] = member.objectID .. (member.section and ("/" .. member.section) or "")
    end
    return table.concat(parts, " ")
end

-- Definitions keep their label, group, and order
local labels = {}
for index, definition in ipairs(Categories.DEFINITIONS) do
    labels[index] = definition.id .. "=" .. definition.label .. "@" .. definition.group
    assert(string.match(definition.id, "^[%w][%w_]*$"), definition.id)
end
assert(table.concat(labels, ";") == table.concat({
    "quest_items=Quest Items@Review", "metal_bank=Metal Bank@Utility storage",
    "treasure_chest=Treasure Chest@Player-owned house", "clue_carrier=Clue Carrier@Utility storage",
    "armour_case=Armour Case@Player-owned house", "magic_wardrobe=Magic Wardrobe@Player-owned house",
    "cape_store=Cape Store@Player-owned house", "tool_leprechaun=Tool Leprechaun@Utility storage",
    "toy_box=Toy Box@Player-owned house", "fancy_dress_box=Fancy Dress Box@Player-owned house",
    "bookcase=Bookcase@Player-owned house", "focus_storage=Focus Storage@Utility storage",
    "spirits=Spirits@Utility storage", "storage_chest=Storage Chest@Review", "diango=Diango Reclaimable@Review",
    "storm_barn=Storm Barn@Utility storage", "seed_bag=Seed Bag@Utility storage", "workbench=Archaeologist's Workbench@Archaeology",
    "material_storage=Material Storage@Archaeology" }, ";"), table.concat(labels, ";"))
-- Every category's group is a folder
local groups = {}
for _, group in ipairs(Categories.GROUPS) do groups[group] = true end
for _, definition in ipairs(Categories.DEFINITIONS) do assert(groups[definition.group], definition.id) end
assert(#Categories.GROUPS == 4 and Categories.GROUPS[4] == "Archaeology")

local cleanup = Categories.new(CATALOGS)
-- Nothing observed: nothing to scan and no members
assert(not cleanup:IsScanning() and not cleanup:HasSnapshot() and not cleanup:HasScanned())
assert(cleanup:Step() == true)
assert(listed(cleanup:Members(), "quest_items") == "")

-- 100's second stack is a placeholder; bank order decides members
cleanup:Observe(snapshot({ { 100, 1 }, { 101, 1 }, { 103, 4 }, { 102, 1 }, { 100, 0 } }))
assert(cleanup:IsScanning() and not cleanup:HasScanned())
-- Until classified, objects are in no category
assert(listed(cleanup:Members(), "metal_bank") == "")
assert(cleanup:Step() == true and not cleanup:IsScanning() and cleanup:HasScanned())
local members = cleanup:Members()

-- Quest items need every quest finished: 101 needs quest 2, which is not
assert(listed(members, "quest_items") == "100 103", listed(members, "quest_items"))
assert(listed(members, "metal_bank") == "102")
assert(listed(members, "treasure_chest") == "101")
assert(listed(members, "clue_carrier") == "103")
assert(listed(members, "armour_case") == "102")
assert(listed(members, "magic_wardrobe") == "100")
assert(listed(members, "cape_store") == "101")
assert(listed(members, "tool_leprechaun") == "102")
assert(listed(members, "toy_box") == "103")
assert(listed(members, "fancy_dress_box") == "100")
assert(listed(members, "bookcase") == "101")
assert(listed(members, "seed_bag") == "103")
-- Members record sections; pages order them by definition
assert(listed(members, "focus_storage") == "103/optional 102/recommended", listed(members, "focus_storage"))
assert(listed(members, "spirits") == "100/stone 101/wood")
local focus = Categories.Definition("focus_storage")
assert(focus.sections[1].id == "recommended" and focus.sections[2].label == "Focus: Optional")
assert(Categories.Definition("spirits").sections[1].label == "Stone Spirits (ore box)")
assert(Categories.Definition("metal_bank").sections == nil and Categories.Definition("missing") == nil)
local chest = Categories.Definition("storage_chest")
assert(chest.sections[1].id == "non_reclaimable" and chest.sections[2].id == "reclaimable")

-- Storage Chest: finished quest items the chest does not list are non-reclaimable
-- Chest items need their own quests finished, or none when marked so; unfinished or unknown quests stay out
local storage = Categories.new(CATALOGS)
storage:Observe(snapshot({ { 100, 1 }, { 101, 1 }, { 103, 1 }, { 107, 2 }, { 108, 1 }, { 109, 1 }, { 114, 1 }, { 107, 0 } }))
storage:Step()
members = storage:Members()
assert(listed(members, "storage_chest") == "100/non_reclaimable 103/reclaimable 107/reclaimable 114/reclaimable",
    listed(members, "storage_chest"))
-- Quest Items keeps its own rule: chest-only items are not quest items
assert(listed(members, "quest_items") == "100 103", listed(members, "quest_items"))

-- Sectioned catalogs give their section; others give none
storage:Observe(snapshot({ { 110, 1 }, { 104, 3 }, { 111, 1 }, { 112, 1 }, { 113, 1 }, { 113, 0 } }))
storage:Step()
members = storage:Members()
assert(listed(members, "diango") == "110/s01 104/s02", listed(members, "diango"))
assert(listed(members, "storm_barn") == "111/anachronia")
assert(listed(members, "workbench") == "112" and listed(members, "material_storage") == "113")
assert(listed(members, "metal_bank") == "" and listed(members, "storage_chest") == "")

-- Known objects need no scan when the bank changes
local reads = questReads
cleanup:Observe(snapshot({ { 100, 1 }, { 103, 4 }, { 102, 0 }, { 103, 2 } }))
assert(not cleanup:IsScanning() and questReads == reads)
members = cleanup:Members()
assert(listed(members, "metal_bank") == "")
-- An object is listed once per present stack
assert(listed(members, "quest_items") == "100 103 103")
assert(listed(members, "toy_box") == "103 103")

-- The quest rule leaves items out without quest data
-- A later scan only adds new objects
cleanup:Observe(snapshot({ { 105, 1 }, { 106, 1 } }))
assert(cleanup:IsScanning() and cleanup:HasScanned())
assert(cleanup:Step() == true)
assert(listed(cleanup:Members(), "quest_items") == "")
local saved = config
config = nil
local closed = Categories.new(CATALOGS)
closed:Observe(snapshot({ { 100, 1 } }))
closed:Step()
assert(listed(closed:Members(), "quest_items") == "" and listed(closed:Members(), "magic_wardrobe") == "100")
config = saved

-- Only new objects are evaluated, at most a batch per step
-- A replaced scan keeps what it already classified
local counted = {}
local calls = 0
for objectID = 1000, 1059 do counted[objectID] = true end
local batched = Categories.new({ metalBankObjects = setmetatable({}, { __index = function(_, objectID)
    if counted[objectID] then calls = calls + 1 end
    return objectID == 1001 or nil
end }) })
local specs = {}
for objectID = 1000, 1059 do specs[#specs + 1] = { objectID, 1 } end
batched:Observe(snapshot(specs))
assert(batched:Step(Categories.BATCH) == false and calls == 25)
specs[#specs + 1] = { 1000, 3 }
batched:Observe(snapshot(specs))
assert(batched:Step(Categories.BATCH) == false and calls == 50)
assert(batched:Step(Categories.BATCH) == true and calls == 60)
assert(listed(batched:Members(), "metal_bank") == "1001")
batched:Observe(snapshot(specs))
assert(not batched:IsScanning() and calls == 60)

-- Forgetting reads every object and quest again
quests[2].hasFinishedQuest = true
cleanup:Observe(snapshot({ { 101, 1 }, { 100, 1 } }))
assert(not cleanup:IsScanning() and listed(cleanup:Members(), "quest_items") == "100")
cleanup:Forget()
assert(cleanup:IsScanning() and not cleanup:HasScanned() and listed(cleanup:Members(), "quest_items") == "")
cleanup:Step()
assert(listed(cleanup:Members(), "quest_items") == "101 100")

-- Clearing drops the snapshot and its scan but keeps classifications
cleanup:Clear()
assert(not cleanup:HasSnapshot() and not cleanup:IsScanning() and not cleanup:HasScanned())
assert(listed(cleanup:Members(), "quest_items") == "")
-- A snapshot of objects already classified needs no scan at all
cleanup:Observe(snapshot({ { 101, 1 } }))
assert(not cleanup:IsScanning() and cleanup:HasScanned() and listed(cleanup:Members(), "quest_items") == "101")

print("cleanup_categories_test: ok")
