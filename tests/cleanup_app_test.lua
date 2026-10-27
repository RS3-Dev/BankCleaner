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
-- Another tab sorts first, so the bank opens on it
local other = assert(core.result.RegisterExtension("a.other", "Other"))
assert(other:RegisterTab("main", { label = "Other", icon = "STAR", mount = { mount = function() end } }))
h:LoadCleaner()
local app = h:App()
local Sidebar = h.cleaner.env.package.loaded["bankcleaner/cleanup/sidebar"]
assert(app:IsConnected())
local session, layout = h:OpenBank()
local service = session.pluginPages

-- Count the pages and tabs Bank Cleaner gives Bank Core
local updates, tabUpdates, redraws = {}, 0, 0
local createPage, updateTab = service.CreatePage, service.UpdateTab
service.CreatePage = function(pages, owner, page)
    if owner.id == "bankcleaner" then updates[#updates + 1] = page.key end
    return createPage(pages, owner, page)
end
service.UpdateTab = function(pages, owner, tabID, tab)
    tabUpdates = tabUpdates + 1
    return updateTab(pages, owner, tabID, tab)
end
local function takeUpdates()
    local result = #updates .. "/" .. tabUpdates
    updates, tabUpdates = {}, 0
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

-- Describe the Cleanup tab's drawn rows: folders and "label=count"
local function tabRows()
    local parts = {}
    for _, row in ipairs(app.sidebar.list.rows) do
        local entry = row.entry
        parts[#parts + 1] = Sidebar.FolderOf(entry.id) ~= nil and ("#" .. entry.label)
            or (entry.label .. "=" .. row.count.content)
    end
    return table.concat(parts, " ")
end

-- Describe the shown page's labels and stacks as object:copy
local function shown()
    local entries = {}
    for _, heading in ipairs(layout.pageState:GetLayoutSections()) do
        entries[#entries + 1] = { y = heading.y, x = -1, text = "[" .. heading.label .. "]" }
    end
    for _, entry in ipairs(layout:BuildPageItems()) do
        entries[#entries + 1] = { y = entry.y, x = entry.x,
            text = string.gsub(entry.layoutKey, "^object:", "") .. (entry.placeholder and "?" or "") }
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
    if app.shownCategory ~= categoryID then assert(app.sidebar.list:Click(categoryID), categoryID) end
    h:Tick(2)
end

-- Nothing scans before the tab is chosen; rows show a busy mark
h:Tick(3)
assert(not app.scanning and not app.categories:HasSnapshot())
h:ChooseTab("bankcleaner", "cleanup")
h:Tick()
assert(app.tabActive and app.categories:IsScanning() and app.scanning)
-- Eight objects fit one batch, so the scan sends results once
h:Tick(3)
assert(not app.scanning and not app:IsBusy())
assert(tabRows() == table.concat({ "#Review (3)", "Quest Items=0", "Storage Chest=0", "Diango Reclaimable=0",
    "#Utility storage (6)", "Metal Bank=3", "Clue Carrier=0", "Tool Leprechaun=0", "Focus Storage=2", "Spirits=0",
    "Storm Barn=0", "#Player-owned house (7)", "Treasure Chest=0", "Armour Case=0", "Magic Wardrobe=0",
    "Cape Store=0", "Toy Box=0", "Fancy Dress Box=0", "Bookcase=0", "#Archaeology (2)",
    "Archaeologist's Workbench=0", "Material Storage=0" }, " "), tabRows())
-- Choosing the tab and scanning show no page
assert(not app.handle:GetState().pageVisible and layout.shownPage == nil and takeUpdates() == "0/0")

-- Metal Bank: a label row, then present stacks in bank order
openRow("metal_bank")
assert(layout.shownPage.key == "cleanup:metal_bank" and app.category == "metal_bank")
assert(shown() == "[Metal Bank] 2351:1 2349:1 2351:2", shown())
assert(layout.shownPage.heading == nil and layout.shownPage.title == "Metal Bank")

-- Focus Storage: sections in definition order, shown with a new key
openRow("focus_storage")
assert(shown() == "[Focus: Recommended] 55623:1 [Focus: Optional] 25835:1", shown())
assert(layout.shownPage.key == "cleanup:focus_storage")
assert(layout.shownPage.title == "Focus Storage")

-- Quest Items: the quest is unfinished, so the page is empty
openRow("quest_items")
assert(shown() == "[None of these items are in your bank.]", shown())
takeUpdates()
takeRedraws()

-- A change outside every category sends nothing and keeps rows
host:Rebuild(function(specs) specs[7][2] = 9 end)
layout:HandleInventoryUpdate()
h:Tick(4)
assert(not app.categories:IsScanning() and takeUpdates() == "0/0" and takeRedraws() == 0)

-- Withdrawing a stack drops it at once without a scan
-- The second stack becomes copy 1 after the change
openRow("metal_bank")
takeUpdates()
host:Rebuild(function(specs)
    table.remove(specs, 1)
    return specs
end)
layout:HandleInventoryUpdate()
h:Tick(4)
assert(not app.scanning and app.categories.snapshot.generation == layout.itemsGeneration)
assert(shown() == "[Metal Bank] 2349:1 2351:1", shown())
assert(takeUpdates() == "1/0" and string.find(tabRows(), "Metal Bank=2", 1, true))
-- The page key is unchanged, so the scroll position stays
assert(layout.shownPage.key == "cleanup:metal_bank")

-- A new object shows busy counts until the batch finishes
-- Known members show at once, then the page and tab are resent
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
assert(app.categories:IsScanning() and string.find(tabRows(), "Spirits=...", 1, true), tabRows())
assert(string.find(tabRows(), "Metal Bank=...", 1, true))
-- Known members are already shown; only busy counts redraw
assert(shown() == "[Metal Bank] 2349:1 2351:1" and takeUpdates() == "0/0", shown())
h:Tick(4)
assert(not app:IsBusy() and string.find(tabRows(), "Spirits=1", 1, true), tabRows())
openRow("spirits")
assert(shown() == "[Stone Spirits (ore box)] 44799:1", shown())

-- A large batch takes several ticks and sends results once
-- Only the shown category's page is sent, so hold one the batch changes
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
assert(app.categories:IsScanning() and takeUpdates() == "0/0")
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
assert(not app.categories:IsScanning() and not app.scanning)
assert(app.categories.snapshot.generation == layout.itemsGeneration)
local classes = app.categories.classes
assert(classified >= 25 and classes[30001] ~= nil and classes[30060] ~= nil and classes[2355] ~= nil)
assert(afterRead ~= "0/0" and takeUpdates() ~= "0/0")
openRow("metal_bank")
assert(shown() == "[Metal Bank] 2353:1 2355:1", shown())

-- Leaving the tab and its pages stops the scan
assert(app.handle:LeavePage())
h:ChooseTab("bankcleaner", "cleanup")
h:Tick(2)
local before = app.categories.snapshot.generation
h:ChooseTab("a.other", "main")
h:Tick(2)
assert(not app.tabActive and app.shownCategory == nil)
host:SetItems({ { BRONZE_BAR, 2 }, { 44800, 1 } })
layout:HandleInventoryUpdate()
h:Tick(3)
assert(app.categories.snapshot.generation == before and not app.scanning)

-- Choosing the tab forgets classifications, so the quest counts
h.quests[15] = { hasFinishedQuest = true }
host:SetItems({ { QUEST_ITEM, 1 }, { BRONZE_BAR, 2 } })
layout:HandleInventoryUpdate()
h:Tick(2)
h:ChooseTab("bankcleaner", "cleanup")
h:Tick()
assert(app.categories:IsScanning())
h:Tick(3)
assert(string.find(tabRows(), "Quest Items=1", 1, true), tabRows())
openRow("quest_items")
assert(shown() == "[Quest Items] 271:1", shown())

-- A tall category keeps its scroll while the same key is rescanned
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
assert(not app:IsBusy() and string.find(tabRows(), "Diango Reclaimable=120", 1, true), tabRows())
openRow("diango")
assert(app.shownCategory == "diango" and layout.shownPage.key == "cleanup:diango")
assert(layout.pageDisplay:SetScrollPosition(200) and layout.pageDisplay.scrollY == 200)
host:Rebuild(function(changed)
    table.remove(changed, 1)
    return changed
end)
layout:HandleInventoryUpdate()
h:Tick(4)
assert(string.find(tabRows(), "Diango Reclaimable=119", 1, true), tabRows())
assert(layout.shownPage.key == "cleanup:diango" and layout.pageDisplay.scrollY == 200, layout.pageDisplay.scrollY)

-- Choosing another category changes the shown page's key, starting at the top
openRow("metal_bank")
assert(app.shownCategory == "metal_bank" and layout.shownPage.key == "cleanup:metal_bank")
assert(layout.pageDisplay.scrollY == 0 and shown() == "[Metal Bank] 2349:1", shown())
assert(app.handle:GetState().pageKey == "cleanup:metal_bank")
-- Choosing the shown category leaves the page, and choosing again opens it
assert(app.sidebar.list:Click("metal_bank"))
h:Tick(2)
assert(app.shownCategory == nil and layout.shownPage == nil and app.category == "metal_bank")
openRow("diango")
assert(app.shownCategory == "diango" and layout.shownPage.key == "cleanup:diango")
assert(layout.pageDisplay.scrollY == 0)

-- Another plugin's page replaces Bank Cleaner's; a scan that ends then shows nothing,
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
assert(app.scanning and takeUpdates() == "0/0")
assert(other:CreatePage({ title = "Eggs", key = "eggs", layout = { { slots = { EGG } } } }))
h:Tick(6)
assert(not app.scanning and app.shownCategory == nil and app.tabActive)
assert(layout.shownPage.title == "Eggs" and takeUpdates() == "0/0")
openRow("diango")
assert(app.shownCategory == "diango" and layout.shownPage.key == "cleanup:diango")
assert(takeUpdates() == "1/0")
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
assert(not app.scanning and layout.shownPage == nil and app.shownCategory == nil)
assert(takeUpdates() == "0/0")
layout:SetNativeViewAll(true)
openRow("diango")
assert(takeUpdates() == "1/0" and layout.shownPage.key == "cleanup:diango")

-- Closing the bank drops the snapshot until it is read again, and shows nothing
local lastShown = app.publishedPage
session.layout:Restore()
h:Tick(2)
assert(not app.categories:HasSnapshot() and not app.scanning)
assert(app.publishedPage == lastShown and takeUpdates() == "0/0", app.publishedPage)

h.host:Unload("bankcleaner")
h.host:Unload("bankcore")
print("cleanup_app_test: ok")
