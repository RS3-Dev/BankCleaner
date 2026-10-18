package.path = "./?.lua;./?/init.lua;" .. package.path

-- Characterize the published heading and item positions, content extent, scroll range,
-- and input targets for every page kind before heading geometry is unified

local FakeBankHost = require("tools/test_support/fake_bank_host")
local host = FakeBankHost.install()
local TagStore = require("lib/features/tags/tag_store")
local QueryStore = require("lib/features/runesql/query_store")
local BankItemIdentity = require("lib/bank/bank_item_identity")
local BankNameSearch = require("lib/features/search/bank_name_search")

-- Bank order matters: equal search scores keep it, whatever the object IDs
local bank = {
    { 300, 0, "Iron arrows" },
    { 900, 5, "Iron bar" },
    { 440, 5, "Iron ore" },
    { 436, 5, "Copper ore" },
    { 438, 5, "Tin ore" },
    { 44799, 5, "Copper stone spirit" },
    { 54915, 5, "Wood spirit" },
    { 44800, 5, "Tin stone spirit" },
}
for index = 0, 11 do bank[#bank + 1] = { 100 + index, 5, "Item " .. index } end
host:SetItems(bank)
host.viewport:SetSize(448, 100)

local store = TagStore.new()
store:SetLayoutPlacement(false)
assert(store:CreateTag("labelled"))
for index = 0, 11 do assert(store:AddTag("labelled", 100 + index)) end
assert(store:SetLabel("labelled", 0, "Top", 10))
assert(store:CreateTag("loose"))
for index = 0, 2 do assert(store:AddTag("loose", 100 + index)) end
store:SetLayoutPlacement(true)
for index = 3, 4 do assert(store:AddTag("loose", 100 + index)) end
assert(store:CreateTag("empty"))

local queries = QueryStore.new()
local _, ironQuery = queries:Save(nil, "Iron", "iron")
local _, invalidQuery = queries:Save(nil, "Broken", "invalid(")

local layout, features = host:NewLayout(store, { queryStore = queries })
local engine = layout.listEngine
local lease = layout.nativeLease
features.cleanupCategories:Refresh(BankItemIdentity.Collect(host.itemLayer))

local CLEANUP = "__bankutils_cleanup:"
local VIEWPORT_X, VIEWPORT_Y, VIEWPORT_HEIGHT = 270, 80, 100
-- Native items are 36 by 32, so input cells start this far before the sprite
local INSET_X, INSET_Y = 2, 4
local CELL = 40

-- Compare a page's rendered headings, items in bank order, extent, and input targets
local function checkPage(name, expected)
    local headers = {}
    for _, header in ipairs(engine.headers) do
        assert(header.root.x == 8, name .. " heading x")
        headers[#headers + 1] = header.root.children[1].options.text .. "@" .. header.root.y
    end
    assert(table.concat(headers, " ") == table.concat(expected.headers, " "),
        name .. " headings: " .. table.concat(headers, " "))

    local entries = layout:VisibleMirrorEntries()
    assert(#engine.sprites == #entries, name .. " sprite count")
    local items = {}
    for index, sprite in ipairs(engine.sprites) do
        local entry = entries[index]
        assert(sprite.layoutKey == entry.layoutKey)
        assert(sprite.root.x == entry.x and sprite.root.y == entry.y, name .. " sprite position")
        items[#items + 1] = sprite.objectID .. "@" .. sprite.root.x .. "," .. sprite.root.y
            .. (sprite.placeholder and "p" or "")
    end
    assert(table.concat(items, " ") == table.concat(expected.items, " "),
        name .. " items: " .. table.concat(items, " "))

    local height = engine:ContentHeightForCurrentLayout()
    assert(height == expected.height, name .. " content height " .. height)
    assert(engine.contentLayer.height == math.max(VIEWPORT_HEIGHT, height))
    assert(engine:MaxScrollY() == math.max(0, height - VIEWPORT_HEIGHT))

    -- Every non-placeholder item has one input target over its own sprite's cell
    local spritesByKey = {}
    for _, sprite in ipairs(engine.sprites) do spritesByKey[sprite.layoutKey] = sprite end
    local targets = 0
    for _, target in ipairs(lease.interactionTargets) do
        local entry = target.entry
        if entry ~= nil then
            targets = targets + 1
            assert(not entry.placeholder)
            local sprite = assert(spritesByKey[entry.layoutKey], name .. " target without sprite")
            local top = VIEWPORT_Y + sprite.root.y - INSET_Y
            assert(target.root.x == VIEWPORT_X + sprite.root.x - INSET_X, name .. " target x")
            assert(target.root.y == math.max(VIEWPORT_Y, top), name .. " target y")
            assert(target.root.width == CELL)
        end
    end
    local interactive = 0
    for _, sprite in ipairs(engine.sprites) do
        if not sprite.placeholder then interactive = interactive + 1 end
    end
    assert(targets == interactive, name .. " input targets")

    -- At the furthest scroll the last row is inside the viewport and hit-tests to its item
    assert(engine:SetScrollPosition(1000000))
    assert(engine.scrollY == engine:MaxScrollY())
    local last = nil
    for _, sprite in ipairs(engine.sprites) do
        if last == nil or sprite.root.y >= last.root.y then last = sprite end
    end
    if last ~= nil then
        local bottom = last.root.y - INSET_Y + CELL - engine.scrollY
        assert(bottom <= VIEWPORT_HEIGHT, name .. " last row unreachable")
        local hit = engine:EntryAtPosition(lease.interactionEntries, engine.geometry,
            last.root.x, last.root.y - engine.scrollY)
        assert((hit ~= nil and hit.objectID == last.objectID) == not last.placeholder,
            name .. " last row hit test")
    end
    assert(engine:SetScrollPosition(0))
    for _ = 1, 9 do host:Tick() end
end

-- A label row takes a whole grid row above the items it introduces
assert(layout:SetSelectedTag("labelled"))
checkPage("labelled", {
    headers = { "Top@20" },
    items = {
        "100@8,48", "101@52,48", "102@96,48", "103@140,48", "104@184,48",
        "105@228,48", "106@272,48", "107@316,48", "108@360,48", "109@404,48",
        "110@8,92", "111@52,92",
    },
    height = 136,
})

-- The Unsorted heading takes the row after the arranged items
assert(layout:SetSelectedTag("loose"))
checkPage("unsorted", {
    headers = { "Unsorted@64" },
    items = { "100@8,4", "101@52,4", "102@96,4", "103@8,92", "104@52,92" },
    height = 136,
})

-- Sectioned cleanup places each section's heading and items from the layout pass
assert(layout:SetSelectedTag(CLEANUP .. "spirits"))
checkPage("sectioned cleanup", {
    headers = { "Stone Spirits (ore box)@0", "Wood Spirits (wood box)@72" },
    items = { "44799@8,32", "54915@8,104", "44800@52,32" },
    height = 144,
})

-- Unsectioned cleanup puts its heading above one row of items
assert(layout:SetSelectedTag(CLEANUP .. "metal_bank"))
checkPage("unsectioned cleanup", {
    headers = { "Metal Bank@0" },
    items = { "440@8,32", "436@52,32", "438@96,32" },
    height = 76,
})
-- The heading row itself takes no item input
assert(engine:EntryAtPosition(lease.interactionEntries, engine.geometry, 10, 10) == nil)

-- Name search ranks by score, then bank order, and keeps placeholders as placeholders
features.bankSearchQuery = "iron"
assert(layout:SetSelectedTag(BankNameSearch.SELECTION_ID))
checkPage("search", {
    headers = {},
    items = { "300@96,4p", "900@8,4", "440@52,4" },
    height = 48,
})

-- A saved query uses the same ranking but leaves placeholders out of the page and count
assert(layout:SetSelectedTag(QueryStore.SelectionID(ironQuery.id)))
assert(features.runeQueryCounts[ironQuery.id] == 2)
checkPage("query", {
    headers = {},
    items = { "900@8,4", "440@52,4" },
    height = 48,
})

-- Empty pages publish no headings or items and no scroll range
assert(layout:SetSelectedTag("empty"))
checkPage("empty tag", { headers = {}, items = {}, height = 0 })
features.bankSearchQuery = "zzz"
assert(layout:SetSelectedTag(BankNameSearch.SELECTION_ID))
checkPage("search without matches", { headers = {}, items = {}, height = 0 })
assert(layout:SetSelectedTag(QueryStore.SelectionID(invalidQuery.id)))
assert(features.runeQueryCounts[invalidQuery.id] == 0)
checkPage("invalid query", { headers = {}, items = {}, height = 0 })

-- An unsectioned cleanup category with no members in a non-empty bank still shows its heading band
assert(layout:SetSelectedTag(CLEANUP .. "treasure_chest"))
checkPage("empty unsectioned cleanup", { headers = { "Treasure Chest@0" }, items = {}, height = 28 })

-- A narrow bank wraps unsectioned cleanup onto a second row below the same heading
host.itemLayer.width = 100
local narrowCleanup = {
    headers = { "Metal Bank@0" },
    items = { "440@8,32", "436@52,32", "438@8,76" },
    height = 120,
}
assert(layout:SetSelectedTag(CLEANUP .. "metal_bank"))
checkPage("narrow unsectioned cleanup", narrowCleanup)
assert(engine:EntryAtPosition(lease.interactionEntries, engine.geometry, 10, 10) == nil)

-- Rebuilding or rebinding the page keeps the heading band exactly once
assert(layout:ReapplySelectedTag(true))
assert(layout:ReapplySelectedTag(true))
checkPage("reapplied narrow cleanup", narrowCleanup)
assert(layout:RefreshSelectedSnapshot())
assert(layout:RefreshSelectedSnapshot())
checkPage("rebound narrow cleanup", narrowCleanup)

-- A withdrawn stack keeps its slot below the heading as a placeholder before the next scan
host:Rebuild(function(specs)
    local kept = {}
    for _, spec in ipairs(specs) do
        if spec[1] ~= 438 then kept[#kept + 1] = spec end
    end
    return kept
end)
assert(layout:RefreshSelectedSnapshot())
checkPage("withdrawn narrow cleanup", {
    headers = { "Metal Bank@0" },
    items = { "440@8,32", "436@52,32", "438@8,76p" },
    height = 120,
})
host.itemLayer.width = 448
host:SetItems(bank)
features.cleanupCategories:Refresh(BankItemIdentity.Collect(host.itemLayer))

-- KNOWN ISSUE, recorded rather than endorsed: when the bank empties under an active page,
-- selecting another page or forcing a reapply reports success but leaves the previous
-- page's entries, sprites, and snapshots in place. Change this deliberately when fixed
assert(layout:SetSelectedTag("labelled"))
local function pageObjects()
    local objects = {}
    for _, sprite in ipairs(engine.sprites) do objects[#objects + 1] = sprite.objectID end
    return table.concat(objects, ",") .. "/" .. #layout.pageState.snapshots
end
local labelledPage = pageObjects()
host:SetItems({})
assert(layout:SetSelectedTag("loose"))
assert(layout.pageState.active and pageObjects() == labelledPage)
assert(layout:ReapplySelectedTag(true))
assert(layout.pageState.active and pageObjects() == labelledPage)
assert(#layout:VisibleMirrorEntries() == 12)

-- One bank page is open at a time, so close the last one, freeing its scrollbar's IDs
local openPage = layout
local function newPage()
    openPage.listEngine:DestroyRuntimeSprites()
    local page, pageFeatures = host:NewLayout(store, { queryStore = queries })
    openPage = page
    return page, pageFeatures
end

-- An empty bank leaves a fresh page inactive with nothing to draw
assert(layout:SetSelectedTag(nil))
local fresh = newPage()
assert(fresh:SetSelectedTag("labelled"))
assert(not fresh.pageState.active and #fresh:VisibleMirrorEntries() == 0)
assert(#fresh.listEngine.sprites == 0 and fresh.listEngine:ContentHeightForCurrentLayout() == 0)

-- CURRENT KNOWN FAILED-APPLY BEHAVIOR, recorded rather than intended: with no bank items the
-- page pass returns before layout, so only geometry from the last successful apply is drawn.
-- These check drawn positions and extent only, not that stale native slots are safe to click
local function drawnPage(page)
    local parts = { page.pageState.active and "active" or "inactive" }
    for _, header in ipairs(page.listEngine.headers) do
        parts[#parts + 1] = header.root.children[1].options.text .. "@" .. header.root.y
    end
    for _, sprite in ipairs(page.listEngine.sprites) do
        parts[#parts + 1] = sprite.objectID .. "@" .. sprite.root.x .. "," .. sprite.root.y
    end
    parts[#parts + 1] = #page:VisibleMirrorEntries() .. " entries"
    parts[#parts + 1] = "height " .. page.listEngine:ContentHeightForCurrentLayout()
    parts[#parts + 1] = "scroll " .. page.listEngine:MaxScrollY()
    return table.concat(parts, " ")
end

-- A fresh page has no published heading, so an empty bank shows no cleanup heading
local emptyCleanup = newPage()
assert(emptyCleanup:SetSelectedTag(CLEANUP .. "metal_bank"))
assert(drawnPage(emptyCleanup) == "inactive 0 entries height 0 scroll 0")

-- Emptying the bank after Metal Bank keeps its heading and geometry under any new selection
local staleMetalBank = "active Metal Bank@0 440@8,32 436@52,32 438@96,32 3 entries height 76 scroll 0"
local function emptiedAfterMetalBank()
    host:SetItems(bank)
    local page, pageFeatures = newPage()
    pageFeatures.cleanupCategories:Refresh(BankItemIdentity.Collect(host.itemLayer))
    assert(page:SetSelectedTag(CLEANUP .. "metal_bank"))
    assert(drawnPage(page) == staleMetalBank)
    host:SetItems({})
    return page
end
local stalePage = emptiedAfterMetalBank()
assert(stalePage:SetSelectedTag("loose"))
assert(stalePage.selectedTag == "loose" and drawnPage(stalePage) == staleMetalBank)
-- The stale heading keeps the last published label rather than following the selection
stalePage = emptiedAfterMetalBank()
assert(stalePage:SetSelectedTag(CLEANUP .. "treasure_chest"))
assert(stalePage.selectedTag == CLEANUP .. "treasure_chest")
assert(drawnPage(stalePage) == staleMetalBank)

print("bank_page_geometry_test: ok")
