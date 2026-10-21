package.path = "./?.lua;" .. package.path

-- Check the generated storage catalogs against known wiki items
-- Counts and names come from docs/CATALOG_SOURCES.md

local StorageChest = require("bankcleaner/data/storage_chest_objects")
local Diango = require("bankcleaner/data/diango_objects")
local StormBarn = require("bankcleaner/data/storm_barn_objects")
local Workbench = require("bankcleaner/data/workbench_artefact_objects")
local Materials = require("bankcleaner/data/material_storage_objects")
local ObjectQuests = require("bankcleaner/data/object_quests")
local Categories = require("bankcleaner/cleanup/categories")

local EGG = 1944

-- Count a table's keys
local function count(values)
    local total = 0
    for _ in pairs(values) do total = total + 1 end
    return total
end

-- Read a catalog's source text
local function source(name)
    local file = assert(io.open("bankcleaner/data/" .. name .. ".lua", "rb"))
    local text = file:read("a")
    file:close()
    return text
end

-- Storage Chest: reclaimable items with the quests that must be finished
assert(count(StorageChest) == 105, count(StorageChest))
-- A quest item object_quests already knows keeps those quests
assert(StorageChest[1586][1] == ObjectQuests[1586][1] and StorageChest[2402][1] == 51)
-- An item object_quests lacks takes its quest from the wiki infobox
assert(ObjectQuests[284] == nil and StorageChest[284][1] == 39)
-- Every version of a named item is listed
for objectID = 44474, 44477 do assert(StorageChest[objectID][1] == 399, objectID) end
-- An item with no quest to confirm is listed but can never show
assert(#StorageChest[30994] == 0)
-- A quest item the chest does not list is absent
assert(ObjectQuests[271] ~= nil and StorageChest[271] == nil and StorageChest[EGG] == nil)
local unconfirmed = 0
for _, quests in pairs(StorageChest) do
    if #quests == 0 then unconfirmed = unconfirmed + 1 end
end
assert(unconfirmed == 6, unconfirmed)

-- Diango: one section per wiki table, in page order, with unique IDs and short labels
assert(#Diango.sections == 35 and count(Diango.objects) == 1604, count(Diango.objects))
local sectionIDs = {}
for index, section in ipairs(Diango.sections) do
    assert(sectionIDs[section.id] == nil and #section.label <= 80, section.id)
    sectionIDs[section.id] = index
end
assert(Diango.sections[1].label == "Holiday Items" and Diango.sections[35].label == "Beyond the Arc")
assert(Diango.sections[10].label == "Treasure Hunter items")
assert(Diango.sections[32].label == "Treasure Hunter items (Other reclaimable items)")
assert(Diango.sections[12].label == "Valentine's Day (Treasure Hunter items)")
assert(Diango.sections[24].label == "Valentine's Day (Squeal of Fortune items)")
local inSection = {}
for objectID, sectionID in pairs(Diango.objects) do
    assert(sectionIDs[sectionID] ~= nil, objectID)
    inSection[sectionID] = (inSection[sectionID] or 0) + 1
end
for _, section in ipairs(Diango.sections) do assert(inSection[section.id] ~= nil, section.label) end
-- A plain item, a pet, a disambiguation entry, a list page's piece, a set's piece, and recolours
assert(Diango.objects[20113] == "s01" and Diango.objects[30380] == "s02" and Diango.objects[29108] == "s32")
assert(Diango.objects[39410] == "s18" and Diango.objects[23679] == "s31" and Diango.objects[35279] == "s27")
for objectID = 56208, 56214 do assert(Diango.objects[objectID] == "s02", objectID) end
-- An item in two tables shows in the first
assert(Diango.objects[31612] == "s10")
assert(Diango.objects[EGG] == nil)

-- Storm barn: checked animals by farm; unchecked animals are left out
assert(#StormBarn.sections == 2 and StormBarn.sections[1].id == "manor" and StormBarn.sections[2].id == "anachronia")
assert(count(StormBarn.objects) == 102)
assert(StormBarn.objects[43595] == "manor" and StormBarn.objects[43714] == "manor")
assert(StormBarn.objects[48784] == "anachronia" and StormBarn.objects[48800] == "anachronia")
assert(StormBarn.objects[43589] == nil and StormBarn.objects[EGG] == nil)
local barnText = source("storm_barn_objects")
assert(not string.find(barnText, "unchecked", 1, true) and not string.find(barnText, "tutorial", 1, true))

-- Workbench: damaged artefacts only, Moonrise's included
assert(count(Workbench) == 235 and Workbench[61715] and Workbench[49921])
for line in string.gmatch(source("workbench_artefact_objects"), "[^\n]+") do
    if string.match(line, "^%s+%[%d+%]") then assert(string.find(line, "(damaged)", 1, true), line) end
end

-- Material storage: the main table, not the tutorial-only materials
assert(count(Materials) == 45 and Materials[49460] and Materials[61707] and Materials[EGG] == nil)
local materialsText = source("material_storage_objects")
assert(not string.find(materialsText, "Imperial iron", 1, true) and not string.find(materialsText, "Purpleheart", 1, true))

-- Sectioned categories take their sections from the catalogs
assert(Categories.Definition("diango").sections == Diango.sections)
assert(Categories.Definition("storm_barn").sections == StormBarn.sections)

print("cleanup_catalogs_test: ok")
