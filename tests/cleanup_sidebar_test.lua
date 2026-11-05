package.path = "./?.lua;./?/init.lua;" .. package.path

-- Drive the Cleanup column's folders through the real Bank Core
-- FAKE HOST: stand-in loader, components, and widgets, not the game client

local Harness = require("tools/test_support/cleaner_harness")

local BRONZE_BAR, IRON_BAR, EGG = 2349, 2351, 1944
local h = Harness.new("cleanup_sidebar")
local host = h.bankHost
host:SetItems({ { IRON_BAR, 5, "Iron bar" }, { EGG, 3, "Egg" } })
h:LoadCore()
h:LoadCleaner()
local session, layout = h:OpenBank()
h:ChooseIcon("bankcleaner")
h:Tick(4)
local app = h:App()
local Sidebar = h.cleaner.env.package.loaded["bankcleaner/cleanup/sidebar"]

-- Find a drawn row by its entry ID
local function row(entryID)
    for _, value in ipairs(app.sidebar.list.rows) do
        if value.entry.id == entryID then return value end
    end
    return nil
end

-- Report whether a row carries the gold selection frame
local function framed(value)
    for _, child in ipairs(value.root.children) do
        if child.outlineThickness == 1 and not child.destroyed then return true end
    end
    return false
end

-- Describe rows: "#" folders, "label=count" categories, "*" framed
local function rows()
    local parts = {}
    for _, value in ipairs(app.sidebar.list.rows) do
        local entry = value.entry
        parts[#parts + 1] = (Sidebar.FolderOf(entry.id) ~= nil and "#" .. entry.label
            or entry.label .. "=" .. value.count.content) .. (framed(value) and "*" or "")
    end
    return table.concat(parts, " ")
end

-- Click a row, then let Bank Core settle
local function click(entryID)
    assert(app.sidebar.list:Click(entryID), entryID)
    h:Tick(2)
end

-- Every folder starts open, in group order, in Core's column
assert(layout.tabMount ~= nil and app.sidebar ~= nil and app.sidebar.list.root.parent == app.sidebar.ctx.parent)
assert(#app.sidebar.list.rows == 22)
assert(string.find(rows(), "#Review (0) Quest Items=0 Storage Chest=0 Diango Reclaimable=0 "
    .. "#Utility storage (1) Metal Bank=1 ", 1, true) == 1, rows())
assert(string.find(rows(), "Storm Barn=0 #Player-owned house (0)", 1, true), rows())
local archaeology = "#Archaeology (0) Archaeologist's Workbench=0 Material Storage=0"
assert(string.sub(rows(), -#archaeology) == archaeology, rows())
-- Icons and indents match Bank Tags, with counts kept at the right
local folder, category = row("folder:Utility storage"), row("metal_bank")
assert(folder.label.x == 34 and category.label.x == 54)
local expectedIcons = {
    ["folder:Review"] = 1586, quest_items = 9813, storage_chest = 6759, diango = 13663,
    ["folder:Utility storage"] = 40248, metal_bank = 438, clue_carrier = 47836,
    tool_leprechaun = 676, focus_storage = 55336, spirits = 44789, storm_barn = 3243,
    ["folder:Player-owned house"] = 8013, treasure_chest = 47434, armour_case = 9828,
    magic_wardrobe = 9834, cape_store = 9822, toy_box = 9838, fancy_dress_box = 9825, bookcase = 50924,
    ["folder:Archaeology"] = 49429, workbench = 49923, material_storage = 49512,
}
local function rowIcon(value)
    local icon
    for _, child in ipairs(value.root.children) do
        if child.associatedObjectID ~= nil then
            assert(icon == nil, "a row drew more than one item icon")
            icon = child
        end
    end
    return assert(icon, value.entry.id .. " has no icon")
end
for entryID, objectID in pairs(expectedIcons) do
    local value = row(entryID)
    local icon = rowIcon(value)
    assert(icon.associatedObjectID == objectID, entryID)
    assert(icon.width == 24 and icon.height == 24 and icon.y == 3 and icon.clickthrough)
    assert(icon.associatedObjectQuantityMode == ui.ObjectQuantityDisplayMode.NEVER)
    assert(icon.x == (Sidebar.FolderOf(entryID) ~= nil and 6 or 26))
    assert(value.label.x == icon.x + icon.width + 4)
end
assert(app.sidebar.entriesByID["folder:Utility storage"].backgroundColour == 0x3B352DFF)
local chevron
for _, child in ipairs(folder.root.children) do
    if child.spriteID == id.Sprite.BANK_ARROW_UP_0 then chevron = child end
end
assert(chevron ~= nil and chevron.rotation == math.pi and chevron.clickthrough)
assert(category.count.content == "1" and category.count.clickthrough)

-- A folder click collapses it, saves, and keeps the page
click("folder:Utility storage")
assert(layout.shownPage == nil and app:ShownCategory() == nil)
assert(rowIcon(row("folder:Utility storage")).associatedObjectID == 40248)
assert(rows() == "#Review (0) Quest Items=0 Storage Chest=0 Diango Reclaimable=0 #Utility storage (1) "
    .. "#Player-owned house (0) Treasure Chest=0 Armour Case=0 Magic Wardrobe=0 Cape Store=0 Toy Box=0 "
    .. "Fancy Dress Box=0 Bookcase=0 #Archaeology (0) Archaeologist's Workbench=0 Material Storage=0", rows())
local saved = h.databases.bankcleaner.bankcleaner_folders
assert(#saved.collapsed == 1 and saved.collapsed[1] == "Utility storage")
for _, child in ipairs(row("folder:Utility storage").root.children) do
    if child.spriteID == id.Sprite.BANK_ARROW_UP_0 then assert(child.rotation == math.pi * 1.5) end
end
click("folder:Utility storage")
assert(#app.sidebar.list.rows == 22 and #h.databases.bankcleaner.bankcleaner_folders.collapsed == 0)

-- A category click opens and frames it; a second click closes it
click("metal_bank")
assert(app:ShownCategory() == "metal_bank" and layout.shownPage.title == "Metal Bank")
assert(framed(row("metal_bank")) and not framed(row("folder:Utility storage")))
-- Collapsing the shown category's folder moves the frame to it
click("folder:Utility storage")
assert(app:ShownCategory() == "metal_bank" and framed(row("folder:Utility storage")), rows())
assert(not framed(row("folder:Review")))

-- Collapsed counts stay current
host:Rebuild(function(specs)
    specs[#specs + 1] = { BRONZE_BAR, 2, "Bronze bar" }
    return specs
end)
layout:HandleInventoryUpdate()
h:Tick(6)
assert(not app:IsBusy())
assert(row("folder:Utility storage").entry.label == "Utility storage (2)")
click("folder:Utility storage")
assert(row("metal_bank").count.content == "2" and framed(row("metal_bank")), rows())
click("metal_bank")
assert(app:ShownCategory() == nil and layout.shownPage == nil and not framed(row("metal_bank")))

-- A page refused outside View All or with the preset selector open selects no row
layout.nativeViewAll = false
click("spirits")
assert(app:ShownCategory() == nil and layout.shownPage == nil and not framed(row("spirits")))
for _, value in ipairs(app.sidebar.list.rows) do assert(not framed(value), value.entry.id) end
layout.nativeViewAll = true
local presetOpen = layout.IsPresetViewOpen
layout.IsPresetViewOpen = function() return true end
click("spirits")
assert(app:ShownCategory() == nil and layout.shownPage == nil and not framed(row("spirits")))
layout.IsPresetViewOpen = presetOpen
-- Once View All allows it, the same row opens the page
click("spirits")
assert(app:ShownCategory() == "spirits" and layout.shownPage.title == "" and framed(row("spirits")))
click("spirits")
assert(app:ShownCategory() == nil and layout.shownPage == nil)

-- Typing filters page items, keeping folders and the field
click("metal_bank")
click("folder:Utility storage")
local field = app.sidebar.search
local function search(text)
    field.root.content = text
    field.root.hooks[ui.Hook.ONCONTENTCHANGED](field.root, "change", text)
    h:Tick(2)
end
search("  IrOn  ")
assert(#app.sidebar.list.rows == 16 and row("metal_bank") == nil)
assert(app:ShownCategory() == "metal_bank" and app.collapsed["Utility storage"])
assert(row("folder:Utility storage").entry.label == "Utility storage (1)")
assert(#layout:BuildPageItems() == 1 and layout:BuildPageItems()[1].objectID == IRON_BAR)
search("nonexistent")
assert(#app.sidebar.list.rows == 16 and app:ShownCategory() == "metal_bank")
assert(#layout:BuildPageItems() == 0)
assert(layout.pageState:GetLayoutSections()[1].label == "No cleanup items match your search.")
assert(row("folder:Utility storage").entry.label == "Utility storage (0)")
search("")
assert(row("metal_bank") == nil and framed(row("folder:Utility storage")))
assert(row("folder:Utility storage").entry.label == "Utility storage (2)")
assert(#layout:BuildPageItems() == 2 and app.sidebar.search == field)
click("folder:Utility storage")
click("metal_bank")

-- A taller bank refits the list once Core notices
local list = app.sidebar.list
local height = host.window.content.height + 60
host.window.content:SetSize(host.window.content.width, height)
h:Tick(12)
assert(app.sidebar.list == list and list.root.height == app.sidebar.ctx.height - 48)
assert(app.sidebar.search == field and field.root.y == 8 and field.root.height == 26)
assert(list.root.y == 40 and field.root.width == list.root.width)
assert(rowIcon(row("metal_bank")).associatedObjectID == 438)

-- Closing the bank drops the rows; reopening keeps them collapsed
click("folder:Player-owned house")
local parent = app.sidebar.ctx.parent
session:CloseBank()
h:Tick(2)
assert(app.sidebar == nil and parent.destroyed)
assert(field.root.destroyed)
h:OpenBank()
h:ChooseIcon("bankcleaner")
h:Tick(4)
assert(app.sidebar ~= nil and app.sidebar.list ~= list)
assert(string.find(rows(), "#Player-owned house (0) #Archaeology (0)", 1, true) and #app.sidebar.list.rows == 15, rows())

-- A reload reads the saved folders back
h.host:Reload("bankcleaner", { freshEnvironment = true })
h:Tick(4)
app = h:App()
assert(app.collapsed["Player-owned house"] and app.collapsed.Review == nil)
assert(#app.sidebar.list.rows == 15, rows())
assert(rowIcon(row("folder:Player-owned house")).associatedObjectID == 8013)
-- Saved values that are not group names are ignored
h.databases.bankcleaner.bankcleaner_folders = { collapsed = { "Bogus", 5, "Review" } }
h.host:Reload("bankcleaner", { freshEnvironment = true })
h:Tick(4)
app = h:App()
assert(app.collapsed.Review and app.collapsed.Bogus == nil and next(app.collapsed, next(app.collapsed)) == nil)
h.databases.bankcleaner.bankcleaner_folders = "broken"
h.host:Reload("bankcleaner", { freshEnvironment = true })
assert(next(h:App().collapsed) == nil)
h:Tick(4)
app = h:App()

-- A refused save still keeps the folder as shown
h.host.rejectWrites = true
click("folder:Review")
assert(app.collapsed.Review and #app.sidebar.list.rows == 19)
h.host.rejectWrites = false
click("folder:Review")
assert(app.collapsed.Review == nil)

h.host:Unload("bankcleaner")
h.host:Unload("bankcore")
print("cleanup_sidebar_test: ok")
