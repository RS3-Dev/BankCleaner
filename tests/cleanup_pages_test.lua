package.path = "./?.lua;" .. package.path
id = require("tests/support/catalog_ids")

-- Encode categories as Bank Core pages and Cleanup column rows

local Categories = require("resources/cleanup/categories")
local Pages = require("resources/cleanup/pages")
local Sidebar = require("resources/cleanup/sidebar")

local metal = Categories.Definition("metal_bank")
local focus = Categories.Definition("focus_storage")

-- A category without sections is one row under its title, an object once per stack
local page = Pages.Page(metal, { { objectID = 102 }, { objectID = 102 } }, false)
assert(page.title == "Metal Bank" and page.key == nil and page.heading == nil)
assert(Pages.Signature(page) == "Metal Bank\nS102,102", Pages.Signature(page))
assert(#page.rows == 1 and page.rows[1].slots[2] == 102)
for _, definition in ipairs(Categories.DEFINITIONS) do assert(#definition.label <= 80) end

-- Describe a category's rows without its title
local function rowsOf(definition, members, scanning)
    return Pages.Signature({ title = "", rows = Pages.Rows(definition, members, scanning) })
end

-- Sections follow definition order; empty ones are left out
local rows = rowsOf(focus, {
    { objectID = 103, section = "optional" },
    { objectID = 102, section = "recommended" },
    { objectID = 104, section = "optional" },
}, false)
assert(rows == "\nLFocus: Recommended\nS102\nLFocus: Optional\nS103,104", rows)
assert(rowsOf(focus, { { objectID = 103, section = "optional" } }, false) == "\nLFocus: Optional\nS103")

-- Empty categories say so, or say the bank is being scanned
assert(rowsOf(metal, {}, false) == "\nL" .. Pages.EMPTY)
assert(rowsOf(metal, {}, true) == "\nL" .. Pages.SCANNING)
-- Known members show while scanning
assert(rowsOf(metal, { { objectID = 1 } }, true) == "\nS1")

-- Section and status labels replace the page heading
for _, categoryID in ipairs({ "quest_items", "clue_carrier", "tool_leprechaun", "seed_bag" }) do
    local definition = Categories.Definition(categoryID)
    assert(Pages.Page(definition, { { objectID = 1 } }, false).title == definition.label)
end
assert(Pages.Page(metal, {}, false).title == nil)
assert(Pages.Page(metal, {}, true).title == nil)
assert(Pages.Page(metal, {}, false, true).title == nil)
local sectioned = Pages.Page(focus, { { objectID = 102, section = "recommended" } }, false)
assert(sectioned.title == nil and sectioned.rows[1].label == "Focus: Recommended")
assert(Pages.Signature(sectioned) == "\nLFocus: Recommended\nS102")
assert(Pages.Signature(Pages.Page(metal, {}, false)) == "\nL" .. Pages.EMPTY)

-- A catalog's sections lay out in its order, each under its own label
local diango = Categories.Definition("diango")
rows = rowsOf(diango, {
    { objectID = 5, section = diango.sections[3].id },
    { objectID = 6, section = diango.sections[1].id },
}, false)
assert(rows == "\nL" .. diango.sections[1].label .. "\nS6\nL" .. diango.sections[3].label .. "\nS5", rows)

-- The column shows the four groups in order, with counts
local members = {}
for _, definition in ipairs(Categories.DEFINITIONS) do members[definition.id] = {} end
members.metal_bank = { { objectID = 102 }, { objectID = 102 } }
local folders = Pages.Folders(members, false)
local order = {}
for _, folder in ipairs(folders) do
    order[#order + 1] = folder.label
    for _, category in ipairs(folder.categories) do order[#order + 1] = category.id .. ":" .. category.detail end
end
assert(table.concat(order, " ") == table.concat({ "Review", "quest_items:0", "storage_chest:0", "diango:0",
    "Utility storage", "metal_bank:2", "clue_carrier:0", "tool_leprechaun:0", "focus_storage:0", "spirits:0",
    "storm_barn:0", "seed_bag:0", "Player-owned house", "treasure_chest:0", "armour_case:0", "magic_wardrobe:0", "cape_store:0",
    "toy_box:0", "fancy_dress_box:0", "bookcase:0", "Archaeology", "workbench:0", "material_storage:0" }, " "),
    table.concat(order, " "))
-- Every count is a busy mark while scanning
local busy = Pages.Folders(members, true)
assert(busy[1].categories[1].detail == Pages.BUSY)
assert(Pages.FoldersSignature(busy) ~= Pages.FoldersSignature(folders))
assert(Pages.FoldersSignature(Pages.Folders(members, false)) == Pages.FoldersSignature(folders))
-- Counts never exceed six characters
for _, folder in ipairs(folders) do
    for _, category in ipairs(folder.categories) do assert(#category.detail <= 6) end
end

-- Folders, then open folders' categories
-- A collapsed folder holding the shown category gets the outline
local function describe(entries)
    local parts = {}
    for index, entry in ipairs(entries) do
        local folder = Sidebar.FolderOf(entry.id)
        parts[index] = (folder ~= nil and "#" .. entry.label or entry.label .. "=" .. entry.detail)
            .. (entry.selected and "*" or "")
    end
    return table.concat(parts, " ")
end
local entries = Sidebar.Entries(folders, {}, "metal_bank")
assert(#entries == 23 and Sidebar.FolderOf(entries[1].id) == "Review" and entries[1].expanded)
assert(describe(entries) == table.concat({ "#Review (0)", "Quest Items=0", "Storage Chest=0",
    "Diango Reclaimable=0", "#Utility storage (2)", "Metal Bank=2*", "Clue Carrier=0", "Tool Leprechaun=0",
    "Focus Storage=0", "Spirits=0", "Storm Barn=0", "Seed Bag=0", "#Player-owned house (0)", "Treasure Chest=0", "Armour Case=0",
    "Magic Wardrobe=0", "Cape Store=0", "Toy Box=0", "Fancy Dress Box=0", "Bookcase=0", "#Archaeology (0)",
    "Archaeologist's Workbench=0", "Material Storage=0" }, " "), describe(entries))
entries = Sidebar.Entries(folders, { Review = true, ["Utility storage"] = true, ["Player-owned house"] = true },
    "metal_bank")
assert(describe(entries) == "#Review (0) #Utility storage (2)* #Player-owned house (0) #Archaeology (0) "
    .. "Archaeologist's Workbench=0 Material Storage=0", describe(entries))
assert(not entries[2].expanded and Sidebar.FolderOf(entries[2].id) == "Utility storage")
-- Only the shown category is outlined, even in another folder
entries = Sidebar.Entries(folders, {}, "material_storage")
local outlined = {}
for _, entry in ipairs(entries) do
    if entry.selected then outlined[#outlined + 1] = entry.id end
end
assert(#outlined == 1 and outlined[1] == "material_storage")
-- No outline without the shown category, and no page selects nothing
entries = Sidebar.Entries(folders, { Review = true }, nil)
local prefix = "#Review (0) #Utility storage (2) "
assert(describe(entries):sub(1, #prefix) == prefix, describe(entries))
for _, entry in ipairs(entries) do assert(not entry.selected) end

-- Folder totals add page stacks, including overlaps across pages
for _, categoryID in ipairs({ "quest_items", "storage_chest", "diango" }) do
    for index = 1, 10 do members[categoryID][index] = { objectID = index } end
end
folders = Pages.Folders(members, false)
assert(folders[1].detail == "30")
assert(Sidebar.Entries(folders, { Review = true }, nil)[1].label == "Review (30)")
assert(Pages.Folders(members, true)[1].detail == Pages.BUSY)

-- Empty search results explain why the category is blank
assert(Pages.Page(metal, {}, false, true).rows[1].label == Pages.NO_MATCHES)
assert(Pages.Page(metal, {}, true, true).rows[1].label == Pages.SCANNING)

print("cleanup_pages_test: ok")
