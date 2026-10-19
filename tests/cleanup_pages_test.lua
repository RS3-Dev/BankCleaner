package.path = "./?.lua;" .. package.path

-- Encode categories as Bank Core pages and the Cleanup tab: a standard label above each
-- category's slots, section labels in order with empty sections left out, explicit copies,
-- status labels for empty and scanning pages, the tab's folders and their rows, counts, and
-- change signatures

local Categories = require("bankcleaner/cleanup/categories")
local Pages = require("bankcleaner/cleanup/pages")
local Sidebar = require("bankcleaner/cleanup/sidebar")

local metal = Categories.Definition("metal_bank")
local focus = Categories.Definition("focus_storage")

-- A category without sections is its label and one row of exact copies
local page = Pages.Page(metal, { { objectID = 102, copy = 1 }, { objectID = 102, copy = 3 } }, false)
assert(page.title == "Metal Bank" and page.key == "cleanup:metal_bank" and page.heading == nil)
assert(Pages.Signature(page.layout) == "LMetal Bank\nS102:1,102:3", Pages.Signature(page.layout))
assert(page.layout[2].slots[2].item == 102 and page.layout[2].slots[2].copy == 3)

-- Sections follow the definition's order whatever the bank order, and an empty one is left out
local layout = Pages.Layout(focus, {
    { objectID = 103, copy = 1, section = "optional" },
    { objectID = 102, copy = 1, section = "recommended" },
    { objectID = 104, copy = 2, section = "optional" },
}, false)
assert(Pages.Signature(layout) == "LFocus: Recommended\nS102:1\nLFocus: Optional\nS103:1,104:2", Pages.Signature(layout))
layout = Pages.Layout(focus, { { objectID = 103, copy = 1, section = "optional" } }, false)
assert(Pages.Signature(layout) == "LFocus: Optional\nS103:1")

-- An empty category says so; while scanning it says the bank is being scanned
assert(Pages.Signature(Pages.Layout(metal, {}, false)) == "L" .. Pages.EMPTY)
assert(Pages.Signature(Pages.Layout(metal, {}, true)) == "L" .. Pages.SCANNING)
-- Known members show while scanning
assert(Pages.Signature(Pages.Layout(metal, { { objectID = 1, copy = 1 } }, true)) == "LMetal Bank\nS1:1")

-- The tab's folders are the three groups in order, each with its categories and counts
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
-- While scanning every count is a busy mark
local busy = Pages.Folders(members, true)
assert(busy[1].categories[1].detail == Pages.BUSY)
assert(Pages.FoldersSignature(busy) ~= Pages.FoldersSignature(folders))
assert(Pages.FoldersSignature(Pages.Folders(members, false)) == Pages.FoldersSignature(folders))
-- Counts never exceed six characters
for _, folder in ipairs(folders) do
    for _, category in ipairs(folder.categories) do assert(#category.detail <= 6) end
end
-- The tab is drawn by the mount callbacks it is given
local mount = { mount = function() end }
local tab = Pages.Tab(mount)
assert(tab.label == "Cleanup" and tab.icon == "ERASER" and tab.mount == mount and tab.rows == nil)

-- Rows: each folder with its number of categories, then its categories while open. The shown
-- category is selected; a collapsed folder holding it carries the outline instead
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
-- A collapsed folder without the shown category has no outline, and no page selects nothing
entries = Sidebar.Entries(folders, { Review = true }, nil)
assert(describe(entries):sub(1, 33) == "#Review (1) #Utility storage (5) ", describe(entries))
for _, entry in ipairs(entries) do assert(not entry.selected) end

print("cleanup_pages_test: ok")
