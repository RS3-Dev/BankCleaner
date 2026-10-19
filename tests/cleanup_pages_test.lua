package.path = "./?.lua;" .. package.path

-- Encode categories as Bank Core pages and the Cleanup tab: a standard label above each
-- category's slots, section labels in order with empty sections left out, explicit copies,
-- status labels for empty and scanning pages, counts, and change signatures

local Categories = require("bankcleaner/cleanup/categories")
local Pages = require("bankcleaner/cleanup/pages")

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

-- The tab lists the three groups' headings and every category with its count
local members = {}
for _, definition in ipairs(Categories.DEFINITIONS) do members[definition.id] = {} end
members.metal_bank = { { objectID = 102, copy = 1 }, { objectID = 102, copy = 2 } }
local tab = Pages.Tab(members, false)
assert(tab.label == "Cleanup" and tab.icon == "ERASER" and tab.mount == nil)
assert(#tab.rows == 16)
local order = {}
for index, row in ipairs(tab.rows) do order[index] = row.heading or (row.page .. ":" .. row.detail) end
assert(table.concat(order, " ") == table.concat({ "Review", "quest_items:0", "Utility storage", "metal_bank:2",
    "clue_carrier:0", "tool_leprechaun:0", "focus_storage:0", "spirits:0", "Player-owned house",
    "treasure_chest:0", "armour_case:0", "magic_wardrobe:0", "cape_store:0", "toy_box:0",
    "fancy_dress_box:0", "bookcase:0" }, " "), table.concat(order, " "))
-- While scanning every count is a busy mark
local busy = Pages.Tab(members, true)
assert(busy.rows[2].detail == Pages.BUSY and Pages.TabSignature(busy) ~= Pages.TabSignature(tab))
assert(Pages.TabSignature(Pages.Tab(members, false)) == Pages.TabSignature(tab))
-- Counts never exceed Bank Core's six-character detail
for _, row in ipairs(tab.rows) do assert(row.detail == nil or #row.detail <= 6) end

print("cleanup_pages_test: ok")
