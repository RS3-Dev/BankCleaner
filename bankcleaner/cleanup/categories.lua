-- Build temporary cleanup views from generated catalogs and confirmed quest progress

local CleanupCategories = {}
CleanupCategories.__index = CleanupCategories

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

local PREFIX = "__bankutils_cleanup:"

-- Read a host field that can be unavailable while configuration loads
local function read(value, field)
    if value == nil then return nil end
    local ok, result = pcall(function() return value[field] end)
    return ok and result or nil
end

-- Include quest items only when every associated quest is confirmed complete
local function questItems(objectID, _, context)
    local questIDs = context.objectQuests[objectID]
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
        -- Completion is deliberately fail-closed. Empty Archaeology grouping
        -- records, missing runtime state, and unfinished quests all remain out
        -- of the generated cleanup view
        if finished ~= true then
            return false, "quest_incomplete_or_unknown"
        end
    end
    return true, "all_quests_complete"
end

-- Create a membership rule backed by a generated storage-item catalog
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
        id = PREFIX .. "quest_items",
        label = "Quest Items",
        group = "Review",
        ruleVersion = 2,
        evaluate = questItems,
    },
    {
        id = PREFIX .. "metal_bank",
        label = "Metal Bank",
        group = "Utility storage",
        ruleVersion = 1,
        evaluate = catalogItems("metalBankObjects", "metal_bank_storable"),
    },
    {
        id = PREFIX .. "treasure_chest",
        label = "Treasure Chest",
        group = "Player-owned house",
        ruleVersion = 1,
        evaluate = catalogItems("treasureChestObjects", "treasure_chest_storable"),
    },
    {
        id = PREFIX .. "clue_carrier",
        label = "Clue Carrier",
        group = "Utility storage",
        ruleVersion = 1,
        evaluate = catalogItems("clueCarrierObjects", "clue_carrier_storable"),
    },
    {
        id = PREFIX .. "armour_case",
        label = "Armour Case",
        group = "Player-owned house",
        ruleVersion = 1,
        evaluate = catalogItems("armourCaseObjects", "armour_case_storable"),
    },
    {
        id = PREFIX .. "magic_wardrobe",
        label = "Magic Wardrobe",
        group = "Player-owned house",
        ruleVersion = 1,
        evaluate = catalogItems("magicWardrobeObjects", "magic_wardrobe_storable"),
    },
    {
        id = PREFIX .. "cape_store",
        label = "Cape Store",
        group = "Player-owned house",
        ruleVersion = 1,
        evaluate = catalogItems("capeStoreObjects", "cape_store_storable"),
    },
    {
        id = PREFIX .. "tool_leprechaun",
        label = "Tool Leprechaun",
        group = "Utility storage",
        ruleVersion = 1,
        evaluate = catalogItems("toolLeprechaunObjects", "tool_leprechaun_storable"),
    },
    {
        id = PREFIX .. "toy_box",
        label = "Toy Box",
        group = "Player-owned house",
        ruleVersion = 1,
        evaluate = catalogItems("toyBoxObjects", "toy_box_storable"),
    },
    {
        id = PREFIX .. "fancy_dress_box",
        label = "Fancy Dress Box",
        group = "Player-owned house",
        ruleVersion = 1,
        evaluate = catalogItems("fancyDressBoxObjects", "fancy_dress_box_storable"),
    },
    {
        id = PREFIX .. "bookcase",
        label = "Bookcase",
        group = "Player-owned house",
        ruleVersion = 1,
        evaluate = catalogItems("bookcaseObjects", "bookcase_storable"),
    },
    {
        id = PREFIX .. "focus_storage",
        label = "Focus Storage",
        group = "Utility storage",
        ruleVersion = 1,
        evaluate = focusStorageItems,
        sections = {
            { id = "recommended", label = "Focus: Recommended" },
            { id = "optional", label = "Focus: Optional" },
        },
    },
    {
        id = PREFIX .. "spirits",
        label = "Spirits",
        group = "Utility storage",
        ruleVersion = 1,
        evaluate = spiritStorageItems,
        sections = {
            { id = "stone", label = "Stone Spirits (ore box)" },
            { id = "wood", label = "Wood Spirits (wood box)" },
        },
    },
}

-- Copy top-level category entries while retaining untouched published results
local function copyMap(source)
    local result = {}
    for key, value in pairs(source or {}) do result[key] = value end
    return result
end

-- Compare item IDs and quantity groups so UI-only rebuilds do not invalidate cleanup results
local function itemSignature(items)
    local quantitiesByObject = {}
    for _, item in ipairs(items or {}) do
        local objectID = math.tointeger(tonumber(item.objectID))
        if objectID ~= nil and objectID >= 0 then
            local quantities = quantitiesByObject[objectID]
            if quantities == nil then
                quantities = {}
                quantitiesByObject[objectID] = quantities
            end
            quantities[#quantities + 1] = tonumber(item.quantity) or 0
        end
    end

    local objectIDs = {}
    for objectID in pairs(quantitiesByObject) do
        objectIDs[#objectIDs + 1] = objectID
    end
    table.sort(objectIDs)

    local parts = {}
    for _, objectID in ipairs(objectIDs) do
        local quantities = quantitiesByObject[objectID]
        table.sort(quantities)
        local values = {}
        for index, quantity in ipairs(quantities) do
            values[index] = tostring(quantity)
        end
        parts[#parts + 1] = tostring(objectID) .. ":" .. table.concat(values, ",")
    end
    return table.concat(parts, ";")
end

-- Check the category ID against the supported cleanup definitions
local function knownCategory(categoryID)
    for _, definition in ipairs(DEFINITIONS) do
        if definition.id == categoryID then return true end
    end
    return false
end

-- Load cleanup catalogs and initialize the published and pending category state
function CleanupCategories.new(userStore, options)
    options = options or {}
    return setmetatable({
        userStore = userStore,
        objectQuests = options.objectQuests or DefaultObjectQuests,
        metalBankObjects = options.metalBankObjects or DefaultMetalBankObjects,
        treasureChestObjects = options.treasureChestObjects
            or DefaultTreasureChestObjects,
        clueCarrierObjects = options.clueCarrierObjects or DefaultClueCarrierObjects,
        armourCaseObjects = options.armourCaseObjects or DefaultArmourCaseObjects,
        magicWardrobeObjects = options.magicWardrobeObjects
            or DefaultMagicWardrobeObjects,
        capeStoreObjects = options.capeStoreObjects or DefaultCapeStoreObjects,
        toolLeprechaunObjects = options.toolLeprechaunObjects
            or DefaultToolLeprechaunObjects,
        toyBoxObjects = options.toyBoxObjects or DefaultToyBoxObjects,
        fancyDressBoxObjects = options.fancyDressBoxObjects
            or DefaultFancyDressBoxObjects,
        bookcaseObjects = options.bookcaseObjects or DefaultBookcaseObjects,
        focusRecommendedObjects = options.focusRecommendedObjects
            or DefaultFocusRecommendedObjects,
        focusOptionalObjects = options.focusOptionalObjects
            or DefaultFocusOptionalObjects,
        stoneSpiritObjects = options.stoneSpiritObjects
            or DefaultStoneSpiritObjects,
        woodSpiritObjects = options.woodSpiritObjects
            or DefaultWoodSpiritObjects,
        generation = 0,
        memberships = {},
        claims = {},
        counts = {},
        layouts = {},
        dirty = {},
        changeVersion = 0,
        inventorySignature = nil,
        pending = nil,
    }, CleanupCategories)
end

-- Recognize cleanup selection IDs that stay outside persistent user tags
function CleanupCategories:IsGenerated(categoryID)
    return type(categoryID) == "string"
        and string.sub(categoryID, 1, #PREFIX) == PREFIX
end

-- Find the display label for a supported cleanup category
function CleanupCategories:Label(categoryID)
    for _, definition in ipairs(DEFINITIONS) do
        if definition.id == categoryID then return definition.label end
    end
    return nil
end

-- Mark affected categories for regeneration and record that their source changed
function CleanupCategories:MarkDirty(categoryID)
    self.changeVersion = self.changeVersion + 1
    for _, definition in ipairs(DEFINITIONS) do
        if categoryID == nil or definition.id == categoryID then
            self.dirty[definition.id] = true
        end
    end
end

-- Report whether a supported category needs to be rebuilt
function CleanupCategories:IsDirty(categoryID)
    return knownCategory(categoryID) and self.dirty[categoryID] == true
end

-- Invalidate categories only when item contents change rather than native component wrappers
function CleanupCategories:ObserveItems(items)
    local signature = itemSignature(items)
    if self.inventorySignature == nil then
        self.inventorySignature = signature
        return false
    end
    if signature == self.inventorySignature then return false end

    self.inventorySignature = signature
    self:MarkDirty()
    return true
end

-- Discard generated results when leaving the bank and require a fresh category build
function CleanupCategories:Reset()
    self.generation = 0
    self.memberships = {}
    self.claims = {}
    self.counts = {}
    self.layouts = {}
    self.inventorySignature = nil
    self.pending = nil
    self:MarkDirty()
end

-- Prepare a new category generation without replacing the currently published results
function CleanupCategories:BeginRefresh(items, categoryID)
    if categoryID ~= nil and not knownCategory(categoryID) then return false end
    items = items or {}
    -- The scan itself establishes the authoritative bank state for the
    -- snapshot. Repeated UI-only inventory events after this point compare
    -- equal and therefore cannot immediately dirty the result again
    self.inventorySignature = itemSignature(items)
    local targeted = categoryID ~= nil
    local pending = {
        generation = self.generation + 1,
        items = items,
        index = 1,
        categoryID = categoryID,
        changeVersion = self.changeVersion,
        memberships = targeted and copyMap(self.memberships) or {},
        claims = targeted and copyMap(self.claims) or {},
        counts = targeted and copyMap(self.counts) or {},
        layouts = targeted and copyMap(self.layouts) or {},
        context = {
            objectQuests = self.objectQuests,
            metalBankObjects = self.metalBankObjects,
            treasureChestObjects = self.treasureChestObjects,
            clueCarrierObjects = self.clueCarrierObjects,
            armourCaseObjects = self.armourCaseObjects,
            magicWardrobeObjects = self.magicWardrobeObjects,
            capeStoreObjects = self.capeStoreObjects,
            toolLeprechaunObjects = self.toolLeprechaunObjects,
            toyBoxObjects = self.toyBoxObjects,
            fancyDressBoxObjects = self.fancyDressBoxObjects,
            bookcaseObjects = self.bookcaseObjects,
            focusRecommendedObjects = self.focusRecommendedObjects,
            focusOptionalObjects = self.focusOptionalObjects,
            stoneSpiritObjects = self.stoneSpiritObjects,
            woodSpiritObjects = self.woodSpiritObjects,
            questStatus = {},
        },
    }
    for _, definition in ipairs(DEFINITIONS) do
        if not targeted or definition.id == categoryID then
            pending.memberships[definition.id] = {}
            pending.claims[definition.id] = {}
            pending.counts[definition.id] = 0
            pending.layouts[definition.id] = {}
        end
    end
    self.pending = pending
    return true
end

-- Report whether the current batch build includes the requested category
function CleanupCategories:IsRefreshing(categoryID)
    if self.pending == nil then return false end
    return categoryID == nil
        or self.pending.categoryID == nil
        or self.pending.categoryID == categoryID
end

-- Discard an unfinished category build while keeping published results
function CleanupCategories:CancelRefresh()
    self.pending = nil
end

-- Evaluate a bounded batch and publish the complete generation when all items are processed
function CleanupCategories:StepRefresh(batchSize)
    local pending = self.pending
    if pending == nil then return true end
    batchSize = math.max(1, math.min(tonumber(batchSize) or 25, 50))
    local last = math.min(#pending.items, pending.index + batchSize - 1)
    for itemIndex = pending.index, last do
        local item = pending.items[itemIndex]
        for _, definition in ipairs(DEFINITIONS) do
            if pending.categoryID == nil or definition.id == pending.categoryID then
                local membership = pending.memberships[definition.id]
                local claims = pending.claims[definition.id]
                local quantity = tonumber(item.quantity) or 0
                if quantity > 0 and type(item.layoutKey) == "string" then
                    local eligible, reason, section = definition.evaluate(
                        item.objectID,
                        item,
                        pending.context
                    )
                    claims[item.layoutKey] = {
                        eligible = eligible == true,
                        reason = reason,
                        objectID = item.objectID,
                        layoutKey = item.layoutKey,
                        ruleVersion = definition.ruleVersion,
                        generation = pending.generation,
                        section = section,
                    }
                    if eligible == true then
                        membership[item.layoutKey] = true
                        pending.counts[definition.id] = pending.counts[definition.id] + 1
                        local layout = pending.layouts[definition.id]
                        layout[#layout + 1] = {
                            kind = "item",
                            objectID = item.objectID,
                            layoutKey = item.layoutKey,
                            section = section,
                        }
                    end
                end
            end
        end
    end
    pending.index = last + 1
    if pending.index <= #pending.items then return false end

    for _, definition in ipairs(DEFINITIONS) do
        if (pending.categoryID == nil or definition.id == pending.categoryID)
            and type(definition.sections) == "table" then
            local source = pending.layouts[definition.id] or {}
            local grouped = {}
            for _, section in ipairs(definition.sections) do
                for _, slot in ipairs(source) do
                    if slot.section == section.id then grouped[#grouped + 1] = slot end
                end
            end
            pending.layouts[definition.id] = grouped
        end
    end

    self.generation = pending.generation
    self.memberships = pending.memberships
    self.claims = pending.claims
    self.counts = pending.counts
    self.layouts = pending.layouts
    if self.changeVersion == pending.changeVersion then
        for _, definition in ipairs(DEFINITIONS) do
            if pending.categoryID == nil or definition.id == pending.categoryID then
                self.dirty[definition.id] = false
            end
        end
    end
    self.pending = nil
    return true
end

-- Complete a category build synchronously through the same batched evaluator
function CleanupCategories:Refresh(items, categoryID)
    self:BeginRefresh(items, categoryID)
    while not self:StepRefresh(50) do end
end

-- Build sidebar rows with counts and a visible in-progress indicator
function CleanupCategories:Entries()
    local entries = {}
    for _, definition in ipairs(DEFINITIONS) do
        local count = self.counts[definition.id] or 0
        entries[#entries + 1] = {
            id = definition.id,
            label = definition.label .. (self:IsRefreshing(definition.id)
                and "..." or (" (" .. tostring(count) .. ")")),
            displayLabel = definition.label,
            group = definition.group,
            count = count,
            ruleVersion = definition.ruleVersion,
            refreshing = self:IsRefreshing(definition.id),
        }
    end
    return entries
end

-- Copy the display sections configured for a generated category
function CleanupCategories:GetSections(categoryID)
    for _, definition in ipairs(DEFINITIONS) do
        if definition.id == categoryID and type(definition.sections) == "table" then
            local sections = {}
            for _, section in ipairs(definition.sections) do
                sections[#sections + 1] = {
                    id = section.id,
                    label = section.label,
                }
            end
            return sections
        end
    end
    return {}
end

-- Title a generated category whose definition has no sections of its own
function CleanupCategories:GetHeading(categoryID)
    if not self:IsGenerated(categoryID) or #self:GetSections(categoryID) > 0 then
        return nil
    end
    return self:Label(categoryID) or "Cleanup"
end

-- Read generated membership or delegate ordinary tag membership to the user store
function CleanupCategories:HasTag(tag, layoutKey)
    if not self:IsGenerated(tag) then return self.userStore:HasTag(tag, layoutKey) end
    local membership = self.memberships[tag]
    return membership ~= nil and membership[layoutKey] == true
end

-- Return page labels for ordinary tags; generated views use fixed sections
function CleanupCategories:GetLabels(tag, columnCount)
    if self:IsGenerated(tag) then return {} end
    return self.userStore:GetLabels(tag, columnCount)
end

-- Copy generated layout slots or use the user store for ordinary tags
function CleanupCategories:GetLayout(tag, columnCount)
    if not self:IsGenerated(tag) then return self.userStore:GetLayout(tag, columnCount) end
    local slots = {}
    for _, slot in ipairs(self.layouts[tag] or {}) do
        slots[#slots + 1] = {
            kind = slot.kind,
            objectID = slot.objectID,
            layoutKey = slot.layoutKey,
            section = slot.section,
        }
    end
    return slots
end

return CleanupCategories
