package.path = "./?.lua;./?/init.lua;" .. package.path

-- Drive the built Bank Cleaner through the real Bank Core
-- FAKE HOST: stand-in loader, components, and widgets, not the game client

local Harness = require("tools/test_support/cleaner_harness")

local BRONZE_BAR, IRON_BAR = 2349, 2351
local MEMENTO, SILK_HOOD = 55623, 25835
local QUEST_ITEM, EGG = 271, 1944
local h = Harness.new("cleanup_app")
local host = h.bankHost
-- Bank order: two bars, a placeholder, focus items, a quest item,
-- an egg, and a second iron bar stack
host:SetItems({ { IRON_BAR, 5, "Iron bar" }, { BRONZE_BAR, 2, "Bronze bar" }, { BRONZE_BAR, 0 },
    { SILK_HOOD, 1, "Spider silk hood" }, { MEMENTO, 1, "Broken memento" }, { QUEST_ITEM, 1, "Quest item" },
    { EGG, 3, "Egg" }, { IRON_BAR, 7 } })

local core = h:LoadCore()
-- Another extension's icon sorts first, so the bank opens on its column
local other = assert(core.result.Register({ id = "a.other", name = "Other", icon = "STAR",
    column = { mount = function() end } }))
h:LoadCleaner()
local app = h:App()
local Sidebar = h.cleaner.env.package.loaded["bankcleaner/cleanup/sidebar"]
assert(app.ext ~= nil)
local session, layout = h:OpenBank()
local service = session.pluginPages

-- Count the pages Bank Cleaner gives Bank Core
local updates, redraws = 0, 0
local setPage = service.SetPage
service.SetPage = function(pages, owner, page)
    if owner.id == "bankcleaner" then updates = updates + 1 end
    return setPage(pages, owner, page)
end
local function takeUpdates()
    local result = updates
    updates = 0
    return result
end
-- Count how often the mounted rows are redrawn, across mounts
local setEntries = Sidebar.SetEntries
Sidebar.SetEntries = function(sidebar, entries)
    redraws = redraws + 1
    return setEntries(sidebar, entries)
end
local function takeRedraws()
    local result = redraws
    redraws = 0
    return result
end

-- Describe the column's drawn rows: folders and "label=count"
local function columnRows()
    local parts = {}
    for _, row in ipairs(app.sidebar.list.rows) do
        local entry = row.entry
        parts[#parts + 1] = Sidebar.FolderOf(entry.id) ~= nil and ("#" .. entry.label)
            or (entry.label .. "=" .. row.count.content)
    end
    return table.concat(parts, " ")
end

-- Describe the shown page's headings and stacks as object=quantity
local function shown()
    local entries = {}
    for _, heading in ipairs(layout.pageState:GetLayoutSections()) do
        entries[#entries + 1] = { y = heading.y, x = -1, text = "[" .. heading.label .. "]" }
    end
    for _, entry in ipairs(layout:BuildPageItems()) do
        entries[#entries + 1] = { y = entry.y, x = entry.x, text = entry.objectID .. "=" .. entry.quantity }
    end
    table.sort(entries, function(a, b)
        if a.y == b.y then return a.x < b.x end
        return a.y < b.y
    end)
    local parts = {}
    for index, entry in ipairs(entries) do parts[index] = entry.text end
    return table.concat(parts, " ")
end

-- Open a category's page from its row
local function openRow(categoryID)
    if app:ShownCategory() ~= categoryID then assert(app.sidebar.list:Click(categoryID), categoryID) end
    h:Tick(2)
end

-- Nothing scans before the icon is chosen
h:Tick(3)
assert(not app.scanning and not app.categories:HasSnapshot() and app.sidebar == nil)
-- Choosing it mounts the column and reads the bank at once
h:ChooseIcon("bankcleaner")
assert(app.sidebar ~= nil and app.categories:IsScanning() and app.scanning)
assert(string.find(columnRows(), "Metal Bank=...", 1, true), columnRows())
-- Eight objects fit one batch, so the scan sends results once
h:Tick(3)
assert(not app.scanning and not app:IsBusy())
assert(columnRows() == table.concat({ "#Review (3)", "Quest Items=0", "Storage Chest=0", "Diango Reclaimable=0",
    "#Utility storage (6)", "Metal Bank=3", "Clue Carrier=0", "Tool Leprechaun=0", "Focus Storage=2", "Spirits=0",
    "Storm Barn=0", "#Player-owned house (7)", "Treasure Chest=0", "Armour Case=0", "Magic Wardrobe=0",
    "Cape Store=0", "Toy Box=0", "Fancy Dress Box=0", "Bookcase=0", "#Archaeology (2)",
    "Archaeologist's Workbench=0", "Material Storage=0" }, " "), columnRows())
-- Choosing the icon and scanning set pages but show none
assert(not app.ext:IsOpen() and layout.shownPage == nil and takeUpdates() > 0)

-- Metal Bank: the title as the heading, then present stacks in bank order
-- An object listed twice shows its stocked stacks in View All order
openRow("metal_bank")
assert(app.ext:IsOpen() and app.category == "metal_bank" and layout.shownPage.title == "Metal Bank")
assert(shown() == "[Metal Bank] 2351=5 2349=2 2351=7", shown())
local metalKey = layout.shownPage.key

-- Focus Storage: sections in definition order, opened as a new view
openRow("focus_storage")
assert(shown() == "[Focus Storage] [Focus: Recommended] 55623=1 [Focus: Optional] 25835=1", shown())
assert(layout.shownPage.key ~= metalKey)

-- Quest Items: the quest is unfinished, so the page is empty
openRow("quest_items")
assert(shown() == "[Quest Items] [None of these items are in your bank.]", shown())
takeUpdates()
takeRedraws()

-- A change outside every category sends nothing and keeps rows
host:Rebuild(function(specs) specs[7][2] = 9 end)
layout:HandleInventoryUpdate()
h:Tick(4)
assert(not app.categories:IsScanning() and takeUpdates() == 0 and takeRedraws() == 0)

-- Withdrawing a stack drops it at once without a scan, redrawn in place
openRow("metal_bank")
local key = layout.shownPage.key
takeUpdates()
host:Rebuild(function(specs)
    table.remove(specs, 1)
    return specs
end)
layout:HandleInventoryUpdate()
h:Tick(4)
assert(not app.scanning and #app.categories.snapshot == 7)
assert(shown() == "[Metal Bank] 2349=2 2351=7", shown())
assert(takeUpdates() == 1 and string.find(columnRows(), "Metal Bank=2", 1, true))
assert(layout.shownPage.key == key)

-- A new object shows busy counts until the batch finishes
-- Known members show at once, then the page and column are sent again
host:Rebuild(function(specs)
    specs[#specs + 1] = { 44799, 1 }
    return specs
end)
layout:HandleInventoryUpdate()
takeUpdates()
local ticks = 0
while not app.categories:IsScanning() and ticks < 4 do
    h:Tick()
    ticks = ticks + 1
end
assert(app.categories:IsScanning() and string.find(columnRows(), "Spirits=...", 1, true), columnRows())
assert(string.find(columnRows(), "Metal Bank=...", 1, true))
-- Known members are already shown; only busy counts redraw
assert(shown() == "[Metal Bank] 2349=2 2351=7" and takeUpdates() == 0, shown())
h:Tick(4)
assert(not app:IsBusy() and string.find(columnRows(), "Spirits=1", 1, true), columnRows())
openRow("spirits")
assert(shown() == "[Spirits] [Stone Spirits (ore box)] 44799=1", shown())

-- A large batch takes several ticks and sends results once
-- Only the chosen category's page is sent, so choose one the batch changes
openRow("metal_bank")
local specs = {}
for index = 1, 60 do specs[index] = { 30000 + index, 1 } end
specs[#specs + 1] = { BRONZE_BAR, 2 }
host:SetItems(specs)
layout:HandleInventoryUpdate()
takeUpdates()
h:Tick(2)
assert(app.categories:IsScanning() and app.scanning)
local afterRead = takeUpdates()
h:Tick()
assert(app.categories:IsScanning() and takeUpdates() == 0)
-- The scan follows the latest bank change, keeping what it classified
local classified = 0
for _ in pairs(app.categories.classes) do classified = classified + 1 end
host:Rebuild(function(changed)
    changed[#changed] = { 2353, 1 }
    return changed
end)
layout:HandleInventoryUpdate()
host:Rebuild(function(changed)
    changed[#changed + 1] = { 2355, 1 }
    return changed
end)
layout:HandleInventoryUpdate()
h:Tick(6)
assert(not app.categories:IsScanning() and not app.scanning and #app.categories.snapshot == 62)
local classes = app.categories.classes
assert(classified >= 25 and classes[30001] ~= nil and classes[30060] ~= nil and classes[2355] ~= nil)
assert(afterRead > 0 and takeUpdates() > 0)
openRow("metal_bank")
assert(shown() == "[Metal Bank] 2353=1 2355=1", shown())

-- Leaving the column and the page stops the scan
assert(app.ext:Close())
h:Tick(2)
local before = app.categories.snapshot
h:ChooseIcon("a.other")
h:Tick(2)
assert(app.sidebar == nil and app:ShownCategory() == nil)
host:SetItems({ { BRONZE_BAR, 2 }, { 44800, 1 } })
layout:HandleInventoryUpdate()
h:Tick(3)
assert(app.categories.snapshot == before and not app.scanning)

-- Choosing the icon forgets classifications, so the quest counts
h.quests[15] = { hasFinishedQuest = true }
host:SetItems({ { QUEST_ITEM, 1 }, { BRONZE_BAR, 2 } })
layout:HandleInventoryUpdate()
h:Tick(2)
h:ChooseIcon("bankcleaner")
assert(app.categories:IsScanning())
h:Tick(3)
assert(string.find(columnRows(), "Quest Items=1", 1, true), columnRows())
openRow("quest_items")
assert(shown() == "[Quest Items] 271=1", shown())

-- A tall category keeps its scroll while it is rescanned
local Diango = h.cleaner.env.package.loaded["bankcleaner/data/diango_objects"]
local tall = {}
for objectID in pairs(Diango.objects) do tall[#tall + 1] = objectID end
table.sort(tall)
specs = {}
for index = 1, 120 do specs[index] = { tall[index], 1 } end
specs[#specs + 1] = { BRONZE_BAR, 2 }
host:SetItems(specs)
layout:HandleInventoryUpdate()
h:Tick(8)
assert(not app:IsBusy() and string.find(columnRows(), "Diango Reclaimable=120", 1, true), columnRows())
openRow("diango")
assert(app:ShownCategory() == "diango" and layout.shownPage.title == "Diango Reclaimable")
key = layout.shownPage.key
assert(layout.pageDisplay:SetScrollPosition(200) and layout.pageDisplay.scrollY == 200)
host:Rebuild(function(changed)
    table.remove(changed, 1)
    return changed
end)
layout:HandleInventoryUpdate()
h:Tick(4)
assert(string.find(columnRows(), "Diango Reclaimable=119", 1, true), columnRows())
assert(layout.shownPage.key == key and layout.pageDisplay.scrollY == 200, layout.pageDisplay.scrollY)

-- Choosing another category opens a new view, starting at the top
openRow("metal_bank")
assert(app:ShownCategory() == "metal_bank" and layout.shownPage.key ~= key)
assert(layout.pageDisplay.scrollY == 0 and shown() == "[Metal Bank] 2349=2", shown())
-- Choosing the shown category closes the page, and choosing again opens it
assert(app.sidebar.list:Click("metal_bank"))
h:Tick(2)
assert(app:ShownCategory() == nil and layout.shownPage == nil and app.category == "metal_bank")
openRow("diango")
assert(app:ShownCategory() == "diango" and layout.shownPage.title == "Diango Reclaimable")
assert(layout.pageDisplay.scrollY == 0)

-- Another extension's page replaces Bank Cleaner's; a scan that ends then shows nothing,
-- and a row click shows the category again
takeUpdates()
host:Rebuild(function(changed)
    changed[#changed + 1] = { 999990, 1 }
    return changed
end)
layout:HandleInventoryUpdate()
local waited = 0
while not app.scanning and waited < 4 do
    h:Tick()
    waited = waited + 1
end
assert(app.scanning and takeUpdates() == 0)
assert(other:SetPage({ title = "Eggs", rows = { { slots = { EGG } } } }) and other:Open())
takeRedraws()
h:Tick(6)
assert(not app.scanning and app:ShownCategory() == nil and app.sidebar ~= nil)
-- The closed page is no longer outlined
assert(takeRedraws() > 0 and not app.sidebar.entriesByID.diango.selected)
assert(layout.shownPage.title == "Eggs" and takeUpdates() == 0)
openRow("diango")
assert(app:ShownCategory() == "diango" and app.sidebar.entriesByID.diango.selected)
assert(layout.shownPage.title == "Diango Reclaimable")
-- After the player picks a native tab, a late scan result shows nothing
host:Rebuild(function(changed)
    changed[#changed + 1] = { 999991, 1 }
    return changed
end)
layout:HandleInventoryUpdate()
waited = 0
while not app.scanning and waited < 4 do
    h:Tick()
    waited = waited + 1
end
assert(app.scanning)
layout:SetNativeViewAll(false)
h:Tick(6)
assert(not app.scanning and layout.shownPage == nil and app:ShownCategory() == nil)
layout:SetNativeViewAll(true)
openRow("diango")
assert(layout.shownPage.title == "Diango Reclaimable")

-- Closing the bank drops the snapshot until it is read again, and shows nothing
session:CloseBank()
h:Tick(2)
assert(not app.categories:HasSnapshot() and not app.scanning and not app.ext:IsOpen())

h.host:Unload("bankcleaner")
h.host:Unload("bankcore")
print("cleanup_app_test: ok")
