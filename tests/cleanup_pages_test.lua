package.path = "./?.lua;" .. package.path

-- Encode categories as Bank Core pages and Cleanup tab rows

local Categories = require("bankcleaner/cleanup/categories")
local Pages = require("bankcleaner/cleanup/pages")
local Sidebar = require("bankcleaner/cleanup/sidebar")

local metal = Categories.Definition("metal_bank")
local focus = Categories.Definition("focus_storage")

-- A category without sections is a label and one row
local page = Pages.Page(metal, { { objectID = 102, copy = 1 }, { objectID = 102, copy = 3 } }, false)
assert(page.title == "Metal Bank" and page.key == "cleanup:metal_bank" and page.heading == nil)
assert(Pages.Signature(page.layout) == "LMetal Bank\nS102:1,102:3", Pages.Signature(page.layout))
assert(page.layout[2].slots[2].item == 102 and page.layout[2].slots[2].copy == 3)

-- Sections follow definition order; empty ones are left out
local layout = Pages.Layout(focus, {
    { objectID = 103, copy = 1, section = "optional" },
    { objectID = 102, copy = 1, section = "recommended" },
    { objectID = 104, copy = 2, section = "optional" },
}, false)
assert(Pages.Signature(layout) == "LFocus: Recommended\nS102:1\nLFocus: Optional\nS103:1,104:2", Pages.Signature(layout))
layout = Pages.Layout(focus, { { objectID = 103, copy = 1, section = "optional" } }, false)
assert(Pages.Signature(layout) == "LFocus: Optional\nS103:1")

-- Empty categories say so, or say the bank is being scanned
assert(Pages.Signature(Pages.Layout(metal, {}, false)) == "L" .. Pages.EMPTY)
assert(Pages.Signature(Pages.Layout(metal, {}, true)) == "L" .. Pages.SCANNING)
-- Known members show while scanning
assert(Pages.Signature(Pages.Layout(metal, { { objectID = 1, copy = 1 } }, true)) == "LMetal Bank\nS1:1")

-- The tab shows the three groups in order, with counts
local members = {}
for _, definition in ipairs(Categories.DEFINITIONS) do members[definition.id] = {} end
members.metal_bank = { { objectID = 102, copy = 1 }, { objectID = 102, copy = 2 } }
local folders = Pages.Folders(members, false)
local order = {}
for _, folder in ipairs(folders) do
    order[#order + 1] = folder.label
    for _, category in ipairs(folder.categories) do order[#order + 1] = category.id .. ":" .. category.detail end
end
assert(table.concat(order, " ") == table.concat({ "Review", "quest_items:0", "Utility storage", "metal_bank:2",
    "clue_carrier:0", "tool_leprechaun:0", "focus_storage:0", "spirits:0", "Player-owned house",
    "treasure_chest:0", "armour_case:0", "magic_wardrobe:0", "cape_store:0", "toy_box:0",
    "fancy_dress_box:0", "bookcase:0" }, " "), table.concat(order, " "))
-- Every count is a busy mark while scanning
local busy = Pages.Folders(members, true)
assert(busy[1].categories[1].detail == Pages.BUSY)
assert(Pages.FoldersSignature(busy) ~= Pages.FoldersSignature(folders))
assert(Pages.FoldersSignature(Pages.Folders(members, false)) == Pages.FoldersSignature(folders))
-- Counts never exceed six characters
for _, folder in ipairs(folders) do
    for _, category in ipairs(folder.categories) do assert(#category.detail <= 6) end
end
-- The tab is drawn by its mount callbacks
local mount = { mount = function() end }
local tab = Pages.Tab(mount)
assert(tab.label == "Cleanup" and tab.icon == "ERASER" and tab.mount == mount and tab.rows == nil)

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
assert(#entries == 16 and Sidebar.FolderOf(entries[1].id) == "Review" and entries[1].expanded)
assert(describe(entries) == table.concat({ "#Review (1)", "Quest Items=0", "#Utility storage (5)", "Metal Bank=2*",
    "Clue Carrier=0", "Tool Leprechaun=0", "Focus Storage=0", "Spirits=0", "#Player-owned house (7)",
    "Treasure Chest=0", "Armour Case=0", "Magic Wardrobe=0", "Cape Store=0", "Toy Box=0", "Fancy Dress Box=0",
    "Bookcase=0" }, " "), describe(entries))
entries = Sidebar.Entries(folders, { ["Utility storage"] = true, ["Player-owned house"] = true }, "metal_bank")
assert(describe(entries) == "#Review (1) Quest Items=0 #Utility storage (5)* #Player-owned house (7)", describe(entries))
assert(not entries[3].expanded and Sidebar.FolderOf(entries[3].id) == "Utility storage")
-- No outline without the shown category, and no page selects nothing
entries = Sidebar.Entries(folders, { Review = true }, nil)
assert(describe(entries):sub(1, 33) == "#Review (1) #Utility storage (5) ", describe(entries))
for _, entry in ipairs(entries) do assert(not entry.selected) end

print("cleanup_pages_test: ok")
