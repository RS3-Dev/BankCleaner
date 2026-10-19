package.path = "./?.lua;" .. package.path

-- Classify objects with stand-in catalogs and quests: every category's membership, present
-- stacks only, sections in their definition's order, the quest rule failing closed, the batch
-- limit, the object cache across snapshots, and forgetting it

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
}

-- Build a snapshot as GetBankItems gives it from { objectID, quantity } pairs in bank order
local function snapshot(generation, specs)
    local items, copies = {}, {}
    for index, spec in ipairs(specs) do
        local copy = (copies[spec[1]] or 0) + 1
        copies[spec[1]] = copy
        items[index] = { objectID = spec[1], copy = copy, quantity = spec[2], placeholder = spec[2] <= 0 }
    end
    return { generation = generation, items = items }
end

-- Describe a category's members as "object:copy" in order, with each member's section
local function listed(members, categoryID)
    local parts = {}
    for index, member in ipairs(members[categoryID]) do
        parts[index] = member.objectID .. ":" .. member.copy .. (member.section and ("/" .. member.section) or "")
    end
    return table.concat(parts, " ")
end

-- Every definition keeps its label, group, and order; ids are plain page IDs
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
    "spirits=Spirits@Utility storage" }, ";"), table.concat(labels, ";"))

local cleanup = Categories.new(CATALOGS)
-- Nothing observed: nothing to scan and no members
assert(not cleanup:IsScanning() and not cleanup:HasSnapshot() and not cleanup:HasScanned())
assert(cleanup:Step() == true)
assert(listed(cleanup:Members(), "quest_items") == "")

-- 100's second stack is a placeholder; 103 sits before 102, so bank order decides members
cleanup:Observe(snapshot(1, { { 100, 1 }, { 101, 1 }, { 103, 4 }, { 102, 1 }, { 100, 0 } }))
assert(cleanup:IsScanning() and not cleanup:HasScanned())
-- Until classified, objects are in no category
assert(listed(cleanup:Members(), "metal_bank") == "")
assert(cleanup:Step() == true and not cleanup:IsScanning() and cleanup:HasScanned())
local members = cleanup:Members()

-- Quest items need every quest finished: 101 needs quest 2, which is not
assert(listed(members, "quest_items") == "100:1 103:1", listed(members, "quest_items"))
assert(listed(members, "metal_bank") == "102:1")
assert(listed(members, "treasure_chest") == "101:1")
assert(listed(members, "clue_carrier") == "103:1")
assert(listed(members, "armour_case") == "102:1")
assert(listed(members, "magic_wardrobe") == "100:1")
assert(listed(members, "cape_store") == "101:1")
assert(listed(members, "tool_leprechaun") == "102:1")
assert(listed(members, "toy_box") == "103:1")
assert(listed(members, "fancy_dress_box") == "100:1")
assert(listed(members, "bookcase") == "101:1")
-- Sections are recorded per member; the page lays them out in the definition's order
assert(listed(members, "focus_storage") == "103:1/optional 102:1/recommended", listed(members, "focus_storage"))
assert(listed(members, "spirits") == "100:1/stone 101:1/wood")
local focus = Categories.Definition("focus_storage")
assert(focus.sections[1].id == "recommended" and focus.sections[2].label == "Focus: Optional")
assert(Categories.Definition("spirits").sections[1].label == "Stone Spirits (ore box)")
assert(Categories.Definition("metal_bank").sections == nil and Categories.Definition("missing") == nil)

-- A new generation of known objects needs no scan: a withdrawn stack leaves at once, and a
-- second stack of a known object joins with its own copy
local reads = questReads
cleanup:Observe(snapshot(2, { { 100, 1 }, { 103, 4 }, { 102, 0 }, { 103, 2 } }))
assert(not cleanup:IsScanning() and questReads == reads)
members = cleanup:Members()
assert(listed(members, "metal_bank") == "")
assert(listed(members, "quest_items") == "100:1 103:1 103:2")
assert(listed(members, "toy_box") == "103:1 103:2")

-- The quest rule fails closed: no quests, an unreadable quest, or no quest config
-- A later scan only adds new objects; the first scan stays finished
cleanup:Observe(snapshot(3, { { 105, 1 }, { 106, 1 } }))
assert(cleanup:IsScanning() and cleanup:HasScanned())
assert(cleanup:Step() == true)
assert(listed(cleanup:Members(), "quest_items") == "")
local saved = config
config = nil
local closed = Categories.new(CATALOGS)
closed:Observe(snapshot(1, { { 100, 1 } }))
closed:Step()
assert(listed(closed:Members(), "quest_items") == "" and listed(closed:Members(), "magic_wardrobe") == "100:1")
config = saved

-- Only new objects are evaluated, at most a batch per step, and a scan that is replaced by a
-- newer snapshot keeps what it already classified
local counted = {}
local calls = 0
for objectID = 1000, 1059 do counted[objectID] = true end
local batched = Categories.new({ metalBankObjects = setmetatable({}, { __index = function(_, objectID)
    if counted[objectID] then calls = calls + 1 end
    return objectID == 1001 or nil
end }) })
local specs = {}
for objectID = 1000, 1059 do specs[#specs + 1] = { objectID, 1 } end
batched:Observe(snapshot(1, specs))
assert(batched:Step(Categories.BATCH) == false and calls == 25)
specs[#specs + 1] = { 1000, 3 }
batched:Observe(snapshot(2, specs))
assert(batched:Step(Categories.BATCH) == false and calls == 50)
assert(batched:Step(Categories.BATCH) == true and calls == 60)
assert(listed(batched:Members(), "metal_bank") == "1001:1")
batched:Observe(snapshot(3, specs))
assert(not batched:IsScanning() and calls == 60)

-- Forgetting reads every object and quest again, as switching to the tab does
quests[2].hasFinishedQuest = true
cleanup:Observe(snapshot(4, { { 101, 1 }, { 100, 1 } }))
assert(not cleanup:IsScanning() and listed(cleanup:Members(), "quest_items") == "100:1")
cleanup:Forget()
assert(cleanup:IsScanning() and not cleanup:HasScanned() and listed(cleanup:Members(), "quest_items") == "")
cleanup:Step()
assert(listed(cleanup:Members(), "quest_items") == "101:1 100:1")

-- Clearing drops the snapshot and its scan but keeps classifications
cleanup:Clear()
assert(not cleanup:HasSnapshot() and not cleanup:IsScanning() and not cleanup:HasScanned())
assert(listed(cleanup:Members(), "quest_items") == "")
-- A snapshot of objects already classified needs no scan at all
cleanup:Observe(snapshot(5, { { 101, 1 } }))
assert(not cleanup:IsScanning() and cleanup:HasScanned() and listed(cleanup:Members(), "quest_items") == "101:1")

print("cleanup_categories_test: ok")
