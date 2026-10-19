package.path = "./?.lua;" .. package.path

local quests = {
    [1] = { hasFinishedQuest = true },
    [2] = { hasFinishedQuest = false },
    [3] = { hasFinishedQuest = true },
}

config = {
    Quest = {
        FromID = function(questID) return quests[questID] end,
    },
}

local userStore = {
    HasTag = function() return false end,
    GetLayout = function() return {} end,
}

local CleanupCategories = require("bankcleaner/cleanup/categories")
local cleanup = CleanupCategories.new(userStore, {
    objectQuests = {
        [100] = { 1 },
        [101] = { 1, 2 },
        [103] = { 1, 3 },
    },
    metalBankObjects = {
        [102] = true,
    },
    treasureChestObjects = {
        [101] = true,
    },
    clueCarrierObjects = {
        [103] = true,
    },
    armourCaseObjects = {
        [102] = true,
    },
    magicWardrobeObjects = {
        [100] = true,
    },
    capeStoreObjects = {
        [101] = true,
    },
    toolLeprechaunObjects = {
        [102] = true,
    },
    toyBoxObjects = {
        [103] = true,
    },
    fancyDressBoxObjects = {
        [100] = true,
    },
    bookcaseObjects = {
        [101] = true,
    },
    focusRecommendedObjects = {
        [102] = true,
    },
    focusOptionalObjects = {
        [103] = true,
    },
    stoneSpiritObjects = {
        [100] = true,
    },
    woodSpiritObjects = {
        [101] = true,
    },
})
cleanup:Refresh({
    { objectID = 100, quantity = 1, layoutKey = "object:100:1" },
    { objectID = 101, quantity = 1, layoutKey = "object:101:1" },
    { objectID = 102, quantity = 1, layoutKey = "object:102:1" },
    { objectID = 103, quantity = 1, layoutKey = "object:103:1" },
    { objectID = 100, quantity = 0, layoutKey = "object:100:2" },
})

local category = cleanup:Entries()[1]
assert(category.label == "Quest Items (2)")
assert(cleanup:Label(category.id) == "Quest Items")
assert(cleanup:HasTag(category.id, "object:100:1") == true)
assert(cleanup:HasTag(category.id, "object:103:1") == true)
assert(cleanup:HasTag(category.id, "object:101:1") == false)
assert(cleanup:HasTag(category.id, "object:102:1") == false)
assert(cleanup:HasTag(category.id, "object:100:2") == false)

local layout = cleanup:GetLayout(category.id, {
    { objectID = 103, layoutKey = "object:103:1" },
    { objectID = 100, layoutKey = "object:100:1" },
})
-- Generated layouts come from the refresh snapshot (native bank order), not
-- from the order of the reconciliation argument.
assert(#layout == 2)
assert(layout[1].layoutKey == "object:100:1")
assert(layout[2].layoutKey == "object:103:1")

local metalBank = cleanup:Entries()[2]
assert(metalBank.label == "Metal Bank (1)")
assert(cleanup:Label(metalBank.id) == "Metal Bank")
assert(cleanup:HasTag(metalBank.id, "object:102:1") == true)
assert(cleanup:HasTag(metalBank.id, "object:100:1") == false)

local treasureChest = cleanup:Entries()[3]
assert(treasureChest.label == "Treasure Chest (1)")
assert(cleanup:Label(treasureChest.id) == "Treasure Chest")
assert(cleanup:HasTag(treasureChest.id, "object:101:1") == true)
assert(cleanup:HasTag(treasureChest.id, "object:103:1") == false)

local clueCarrier = cleanup:Entries()[4]
assert(clueCarrier.label == "Clue Carrier (1)")
assert(cleanup:Label(clueCarrier.id) == "Clue Carrier")
assert(cleanup:HasTag(clueCarrier.id, "object:103:1") == true)
assert(cleanup:HasTag(clueCarrier.id, "object:101:1") == false)

local armourCase = cleanup:Entries()[5]
assert(armourCase.label == "Armour Case (1)")
assert(cleanup:Label(armourCase.id) == "Armour Case")
assert(cleanup:HasTag(armourCase.id, "object:102:1") == true)
assert(cleanup:HasTag(armourCase.id, "object:101:1") == false)

local magicWardrobe = cleanup:Entries()[6]
assert(magicWardrobe.label == "Magic Wardrobe (1)")
assert(cleanup:Label(magicWardrobe.id) == "Magic Wardrobe")
assert(cleanup:HasTag(magicWardrobe.id, "object:100:1") == true)
assert(cleanup:HasTag(magicWardrobe.id, "object:101:1") == false)

local capeStore = cleanup:Entries()[7]
assert(capeStore.label == "Cape Store (1)")
assert(cleanup:Label(capeStore.id) == "Cape Store")
assert(cleanup:HasTag(capeStore.id, "object:101:1") == true)
assert(cleanup:HasTag(capeStore.id, "object:100:1") == false)

local toolLeprechaun = cleanup:Entries()[8]
assert(toolLeprechaun.label == "Tool Leprechaun (1)")
assert(cleanup:Label(toolLeprechaun.id) == "Tool Leprechaun")
assert(cleanup:HasTag(toolLeprechaun.id, "object:102:1") == true)
assert(cleanup:HasTag(toolLeprechaun.id, "object:100:1") == false)

local toyBox = cleanup:Entries()[9]
assert(toyBox.label == "Toy Box (1)")
assert(cleanup:Label(toyBox.id) == "Toy Box")
assert(cleanup:HasTag(toyBox.id, "object:103:1") == true)
assert(cleanup:HasTag(toyBox.id, "object:100:1") == false)

local fancyDressBox = cleanup:Entries()[10]
assert(fancyDressBox.label == "Fancy Dress Box (1)")
assert(cleanup:Label(fancyDressBox.id) == "Fancy Dress Box")
assert(cleanup:HasTag(fancyDressBox.id, "object:100:1") == true)
assert(cleanup:HasTag(fancyDressBox.id, "object:101:1") == false)

local bookcase = cleanup:Entries()[11]
assert(bookcase.label == "Bookcase (1)")
assert(cleanup:Label(bookcase.id) == "Bookcase")
assert(cleanup:HasTag(bookcase.id, "object:101:1") == true)
assert(cleanup:HasTag(bookcase.id, "object:100:1") == false)

local focusStorage = cleanup:Entries()[12]
assert(focusStorage.label == "Focus Storage (2)")
assert(cleanup:Label(focusStorage.id) == "Focus Storage")
assert(cleanup:HasTag(focusStorage.id, "object:102:1") == true)
assert(cleanup:HasTag(focusStorage.id, "object:103:1") == true)
assert(cleanup:HasTag(focusStorage.id, "object:100:1") == false)
local focusSections = cleanup:GetSections(focusStorage.id)
assert(#focusSections == 2)
assert(focusSections[1].label == "Focus: Recommended")
assert(focusSections[2].label == "Focus: Optional")
local focusLayout = cleanup:GetLayout(focusStorage.id)
assert(#focusLayout == 2)
assert(focusLayout[1].section == "recommended")
assert(focusLayout[2].section == "optional")

local spirits = cleanup:Entries()[13]
assert(spirits.label == "Spirits (2)")
assert(cleanup:Label(spirits.id) == "Spirits")
assert(cleanup:HasTag(spirits.id, "object:100:1") == true)
assert(cleanup:HasTag(spirits.id, "object:101:1") == true)
assert(cleanup:HasTag(spirits.id, "object:102:1") == false)
local spiritSections = cleanup:GetSections(spirits.id)
assert(#spiritSections == 2)
assert(spiritSections[1].label == "Stone Spirits (ore box)")
assert(spiritSections[2].label == "Wood Spirits (wood box)")
local spiritLayout = cleanup:GetLayout(spirits.id)
assert(#spiritLayout == 2)
assert(spiritLayout[1].section == "stone")
assert(spiritLayout[2].section == "wood")

-- Native bank component rebuilds can change iteration and component order
-- without changing bank contents. Those UI-only events must not invalidate
-- generated snapshots or make every category switch scan again.
assert(cleanup:ObserveItems({
    { objectID = 103, quantity = 1 },
    { objectID = 100, quantity = 0 },
    { objectID = 102, quantity = 1 },
    { objectID = 100, quantity = 1 },
    { objectID = 101, quantity = 1 },
}) == false)
assert(cleanup:IsDirty(category.id) == false)
assert(cleanup:IsDirty(metalBank.id) == false)

-- A real quantity change still invalidates every generated snapshot. The
-- same-object quantities are treated as a multiset so augmented copies remain
-- distinguishable by count without depending on unstable native components.
assert(cleanup:ObserveItems({
    { objectID = 103, quantity = 1 },
    { objectID = 100, quantity = 0 },
    { objectID = 102, quantity = 2 },
    { objectID = 100, quantity = 1 },
    { objectID = 101, quantity = 1 },
}) == true)
assert(cleanup:IsDirty(category.id) == true)
assert(cleanup:IsDirty(metalBank.id) == true)
cleanup:Refresh({
    { objectID = 100, quantity = 1, layoutKey = "object:100:1" },
    { objectID = 101, quantity = 1, layoutKey = "object:101:1" },
    { objectID = 102, quantity = 1, layoutKey = "object:102:1" },
    { objectID = 103, quantity = 1, layoutKey = "object:103:1" },
    { objectID = 100, quantity = 0, layoutKey = "object:100:2" },
})

-- Inventory changes only mark generated snapshots stale. Their in-memory
-- layouts remain available so a withdrawn object renders as a placeholder
-- until that specific category is deliberately refreshed.
cleanup:MarkDirty()
assert(cleanup:IsDirty(category.id) == true)
assert(cleanup:IsDirty(metalBank.id) == true)
assert(#cleanup:GetLayout(category.id) == 2)

cleanup:Refresh({
    { objectID = 102, quantity = 1, layoutKey = "object:102:1" },
    { objectID = 103, quantity = 1, layoutKey = "object:103:1" },
}, category.id)
assert(cleanup:IsDirty(category.id) == false)
assert(cleanup:IsDirty(metalBank.id) == true)
assert(cleanup:Entries()[1].label == "Quest Items (1)")
assert(#cleanup:GetLayout(category.id) == 1)
assert(cleanup:Entries()[2].label == "Metal Bank (1)")
assert(cleanup:HasTag(metalBank.id, "object:102:1") == true)

cleanup:BeginRefresh({}, category.id)
assert(cleanup:Entries()[1].label == "Quest Items...")
cleanup:CancelRefresh()

print("cleanup_categories_test: ok")
