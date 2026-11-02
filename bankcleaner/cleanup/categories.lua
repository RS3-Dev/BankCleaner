-- Sort bank objects into cleanup categories, a batch at a time

local Categories = {}
Categories.__index = Categories

local DefaultObjectQuests = require("bankcleaner/data/object_quests")
local DefaultMetalBankObjects = require("bankcleaner/data/metal_bank_objects")
local DefaultTreasureChestObjects = require("bankcleaner/data/treasure_chest_objects")
local DefaultClueCarrierObjects = require("bankcleaner/data/clue_carrier_objects")
local DefaultArmourCaseObjects = require("bankcleaner/data/armour_case_objects")
local DefaultMagicWardrobeObjects = require("bankcleaner/data/magic_wardrobe_objects")
local DefaultCapeStoreObjects = require("bankcleaner/data/cape_store_objects")
local DefaultToolLeprechaunObjects = require("bankcleaner/data/tool_leprechaun_objects")
local DefaultToyBoxObjects = require("bankcleaner/data/toy_box_objects")
local DefaultFancyDressBoxObjects = require("bankcleaner/data/fancy_dress_box_objects")
local DefaultBookcaseObjects = require("bankcleaner/data/bookcase_objects")
local DefaultFocusRecommendedObjects = require(
    "bankcleaner/data/focus_storage_recommended_objects"
)
local DefaultFocusOptionalObjects = require("bankcleaner/data/focus_storage_optional_objects")
local DefaultStoneSpiritObjects = require("bankcleaner/data/stone_spirit_objects")
local DefaultWoodSpiritObjects = require("bankcleaner/data/wood_spirit_objects")
local DefaultStorageChestObjects = require("bankcleaner/data/storage_chest_objects")
local DefaultDiangoObjects = require("bankcleaner/data/diango_objects")
local DefaultStormBarnObjects = require("bankcleaner/data/storm_barn_objects")
local DefaultWorkbenchArtefactObjects = require("bankcleaner/data/workbench_artefact_objects")
local DefaultMaterialStorageObjects = require("bankcleaner/data/material_storage_objects")

-- Read a host field that can be unavailable while configuration loads
local function read(value, field)
    if value == nil then return nil end
    local ok, result = pcall(function() return value[field] end)
    return ok and result or nil
end

-- Confirm every listed quest is finished, remembering each answer
local function questsFinished(questIDs, context)
    if type(questIDs) ~= "table" or #questIDs == 0 then
        return false, "no_quests"
    end

    for _, questID in ipairs(questIDs) do
        local finished = context.questStatus[questID]
        if finished == nil then
            if config == nil or config.Quest == nil or config.Quest.FromID == nil then
                context.questStatus[questID] = false
                return false, "quest_config_unavailable"
            end
            local ok, quest = pcall(function() return config.Quest.FromID(questID) end)
            if not ok or quest == nil then
                context.questStatus[questID] = false
                return false, "quest_config_unavailable"
            end
            finished = read(quest, "hasFinishedQuest") == true
            context.questStatus[questID] = finished
        end
        -- Leave the item out if anything is missing or a quest is unfinished
        if finished ~= true then
            return false, "quest_incomplete_or_unknown"
        end
    end
    return true, "all_quests_complete"
end

-- Include quest items only when every associated quest is confirmed complete
local function questItems(objectID, _, context)
    return questsFinished(context.objectQuests[objectID], context)
end

-- Split finished quests' items by whether the Storage Chest can return them
-- A chest item needs its own quests finished, or none when its entry is true; any other needs the quest item rule
local function storageChestItems(objectID, _, context)
    local chestQuests = context.storageChestObjects[objectID]
    if chestQuests == true then return true, "storage_chest_reclaimable", "reclaimable" end
    if chestQuests ~= nil then
        local finished, reason = questsFinished(chestQuests, context)
        if finished then return true, "storage_chest_reclaimable", "reclaimable" end
        return false, reason
    end
    local finished, reason = questItems(objectID, nil, context)
    if finished then return true, "storage_chest_not_reclaimable", "non_reclaimable" end
    return false, reason
end

-- Create a rule that finds an object's section in a sectioned catalog
local function sectionedItems(catalogField, reason)
    local absentReason = "not_" .. reason
    return function(objectID, _, context)
        local section = context[catalogField].objects[objectID]
        if section ~= nil then return true, reason, section end
        return false, absentReason
    end
end

-- Create a rule that checks a generated item list
local function catalogItems(catalogField, reason)
    local absentReason = "not_" .. reason
    return function(objectID, _, context)
        if context[catalogField][objectID] == true then
            return true, reason
        end
        return false, absentReason
    end
end

-- Group focus-storage items into recommended and optional sections
local function focusStorageItems(objectID, _, context)
    if context.focusRecommendedObjects[objectID] == true then
        return true, "focus_recommended_storable", "recommended"
    end
    if context.focusOptionalObjects[objectID] == true then
        return true, "focus_optional_storable", "optional"
    end
    return false, "not_focus_storage_storable"
end

-- Group stone and wood spirits by the storage box that accepts them
local function spiritStorageItems(objectID, _, context)
    if context.stoneSpiritObjects[objectID] == true then
        return true, "ore_box_storable", "stone"
    end
    if context.woodSpiritObjects[objectID] == true then
        return true, "wood_box_storable", "wood"
    end
    return false, "not_spirit_storage_storable"
end

local DEFINITIONS = {
    {
        id = "quest_items",
        label = "Quest Items",
        group = "Review",
        evaluate = questItems,
    },
    {
        id = "metal_bank",
        label = "Metal Bank",
        group = "Utility storage",
        evaluate = catalogItems("metalBankObjects", "metal_bank_storable"),
    },
    {
        id = "treasure_chest",
        label = "Treasure Chest",
        group = "Player-owned house",
        evaluate = catalogItems("treasureChestObjects", "treasure_chest_storable"),
    },
    {
        id = "clue_carrier",
        label = "Clue Carrier",
        group = "Utility storage",
        evaluate = catalogItems("clueCarrierObjects", "clue_carrier_storable"),
    },
    {
        id = "armour_case",
        label = "Armour Case",
        group = "Player-owned house",
        evaluate = catalogItems("armourCaseObjects", "armour_case_storable"),
    },
    {
        id = "magic_wardrobe",
        label = "Magic Wardrobe",
        group = "Player-owned house",
        evaluate = catalogItems("magicWardrobeObjects", "magic_wardrobe_storable"),
    },
    {
        id = "cape_store",
        label = "Cape Store",
        group = "Player-owned house",
        evaluate = catalogItems("capeStoreObjects", "cape_store_storable"),
    },
    {
        id = "tool_leprechaun",
        label = "Tool Leprechaun",
        group = "Utility storage",
        evaluate = catalogItems("toolLeprechaunObjects", "tool_leprechaun_storable"),
    },
    {
        id = "toy_box",
        label = "Toy Box",
        group = "Player-owned house",
        evaluate = catalogItems("toyBoxObjects", "toy_box_storable"),
    },
    {
        id = "fancy_dress_box",
        label = "Fancy Dress Box",
        group = "Player-owned house",
        evaluate = catalogItems("fancyDressBoxObjects", "fancy_dress_box_storable"),
    },
    {
        id = "bookcase",
        label = "Bookcase",
        group = "Player-owned house",
        evaluate = catalogItems("bookcaseObjects", "bookcase_storable"),
    },
    {
        id = "focus_storage",
        label = "Focus Storage",
        group = "Utility storage",
        evaluate = focusStorageItems,
        sections = {
            { id = "recommended", label = "Focus: Recommended" },
            { id = "optional", label = "Focus: Optional" },
        },
    },
    {
        id = "spirits",
        label = "Spirits",
        group = "Utility storage",
        evaluate = spiritStorageItems,
        sections = {
            { id = "stone", label = "Stone Spirits (ore box)" },
            { id = "wood", label = "Wood Spirits (wood box)" },
        },
    },
    {
        id = "storage_chest",
        label = "Storage Chest",
        group = "Review",
        evaluate = storageChestItems,
        sections = {
            { id = "non_reclaimable", label = "Non-reclaimable" },
            { id = "reclaimable", label = "Reclaimable (chest unlock needed)" },
        },
    },
    {
        id = "diango",
        label = "Diango Reclaimable",
        group = "Review",
        evaluate = sectionedItems("diangoObjects", "diango_reclaimable"),
        sections = DefaultDiangoObjects.sections,
    },
    {
        id = "storm_barn",
        label = "Storm Barn",
        group = "Utility storage",
        evaluate = sectionedItems("stormBarnObjects", "storm_barn_storable"),
        sections = DefaultStormBarnObjects.sections,
    },
    {
        id = "workbench",
        label = "Archaeologist's Workbench",
        group = "Archaeology",
        evaluate = catalogItems("workbenchArtefactObjects", "workbench_storable"),
    },
    {
        id = "material_storage",
        label = "Material Storage",
        group = "Archaeology",
        evaluate = catalogItems("materialStorageObjects", "material_storage_storable"),
    },
}

-- The categories' group headings, in the order the column shows them
Categories.GROUPS = { "Review", "Utility storage", "Player-owned house", "Archaeology" }
Categories.DEFINITIONS = DEFINITIONS
-- Objects classified per logic tick
Categories.BATCH = 25

local CATALOGS = {
    objectQuests = DefaultObjectQuests,
    metalBankObjects = DefaultMetalBankObjects,
    treasureChestObjects = DefaultTreasureChestObjects,
    clueCarrierObjects = DefaultClueCarrierObjects,
    armourCaseObjects = DefaultArmourCaseObjects,
    magicWardrobeObjects = DefaultMagicWardrobeObjects,
    capeStoreObjects = DefaultCapeStoreObjects,
    toolLeprechaunObjects = DefaultToolLeprechaunObjects,
    toyBoxObjects = DefaultToyBoxObjects,
    fancyDressBoxObjects = DefaultFancyDressBoxObjects,
    bookcaseObjects = DefaultBookcaseObjects,
    focusRecommendedObjects = DefaultFocusRecommendedObjects,
    focusOptionalObjects = DefaultFocusOptionalObjects,
    stoneSpiritObjects = DefaultStoneSpiritObjects,
    woodSpiritObjects = DefaultWoodSpiritObjects,
    storageChestObjects = DefaultStorageChestObjects,
    diangoObjects = DefaultDiangoObjects,
    stormBarnObjects = DefaultStormBarnObjects,
    workbenchArtefactObjects = DefaultWorkbenchArtefactObjects,
    materialStorageObjects = DefaultMaterialStorageObjects,
}

-- Load the catalogs, with optional test overrides
function Categories.new(options)
    options = options or {}
    local context = { questStatus = {} }
    for name, catalog in pairs(CATALOGS) do context[name] = options[name] or catalog end
    return setmetatable({
        context = context,
        -- Category ID to section, or true, per classified object
        classes = {},
        -- Current bank snapshot and its unclassified objects
        snapshot = nil,
        pending = nil,
        -- Whether a full scan finished since the last reset
        scanned = false,
    }, Categories)
end

-- Find a category's definition by its ID
function Categories.Definition(categoryID)
    for _, definition in ipairs(DEFINITIONS) do
        if definition.id == categoryID then return definition end
    end
    return nil
end

-- Report whether a stack is in the bank rather than a placeholder
local function present(item)
    return item.quantity > 0
end

-- List the snapshot's present objects not yet classified, in bank order
local function unclassified(self)
    local pending, seen = {}, {}
    for _, item in ipairs(self.snapshot or {}) do
        local objectID = item.objectID
        if present(item) and self.classes[objectID] == nil and not seen[objectID] then
            seen[objectID] = true
            pending[#pending + 1] = objectID
        end
    end
    return #pending > 0 and { objects = pending, index = 1 } or nil
end

-- Use a new bank snapshot of { objectID, quantity } stacks
-- Known objects count at once; the rest wait for Step
function Categories:Observe(snapshot)
    self.snapshot = snapshot
    self.pending = unclassified(self)
    if self.pending == nil then self.scanned = true end
end

-- Drop the snapshot and scan, keeping classifications
function Categories:Clear()
    self.snapshot, self.pending, self.scanned = nil, nil, false
end

-- Forget every classification and quest status so the next scan reads them again
function Categories:Forget()
    self.classes = {}
    self.context.questStatus = {}
    self.pending = unclassified(self)
    self.scanned = self.snapshot ~= nil and self.pending == nil
end

-- Report whether the snapshot has objects still to classify
function Categories:IsScanning()
    return self.pending ~= nil
end

-- Report whether a snapshot has been observed
function Categories:HasSnapshot()
    return self.snapshot ~= nil
end

-- Report whether a full scan finished since the last reset
function Categories:HasScanned()
    return self.scanned
end

-- Check every category's rule for one object and remember the result
local function classify(self, objectID)
    local result = {}
    for _, definition in ipairs(DEFINITIONS) do
        local eligible, _, section = definition.evaluate(objectID, nil, self.context)
        if eligible == true then result[definition.id] = section or true end
    end
    self.classes[objectID] = result
end

-- Classify at most limit pending objects; returns true once none are left
function Categories:Step(limit)
    local pending = self.pending
    if pending == nil then return true end
    local last = math.min(#pending.objects, pending.index + math.max(1, limit or Categories.BATCH) - 1)
    for index = pending.index, last do classify(self, pending.objects[index]) end
    pending.index = last + 1
    if pending.index <= #pending.objects then return false end
    self.pending, self.scanned = nil, true
    return true
end

-- List each category's present classified stacks in bank order, an object once per stack
-- Members are { objectID, section }, keyed by category ID
function Categories:Members()
    local members = {}
    for _, definition in ipairs(DEFINITIONS) do members[definition.id] = {} end
    for _, item in ipairs(self.snapshot or {}) do
        local classes = present(item) and self.classes[item.objectID] or nil
        for categoryID, section in pairs(classes or {}) do
            local list = members[categoryID]
            list[#list + 1] = { objectID = item.objectID, section = section ~= true and section or nil }
        end
    end
    return members
end

return Categories
