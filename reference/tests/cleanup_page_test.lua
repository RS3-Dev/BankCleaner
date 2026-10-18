package.path = "./?.lua;./?/init.lua;" .. package.path

-- Check that a cleanup page is selected, refused, built, and refreshed through its page
-- description at the same points as before, and that its batched scans still finish or stop
-- Run all tests with Lua 5.4: lua54 tools/check.lua (toolchain notes in STAGE0_BASELINE.md)

local FakeBankHost = require("tools/test_support/fake_bank_host")
local host = FakeBankHost.install()
local TagStore = require("lib/features/tags/tag_store")
local CleanupPage = require("lib/features/cleanup/cleanup_page")

local METAL = "__bankutils_cleanup:metal_bank"
local CHEST = "__bankutils_cleanup:treasure_chest"

-- Thirty stacks take two 25-item scan batches
local bank = {}
for objectID = 101, 130 do bank[#bank + 1] = { objectID, 5 } end
host:SetItems(bank)

local store = TagStore.new()
store:SetLayoutPlacement(false)
local layout, features = host:NewLayout(store, {})

-- The cleanup scan runs while the features' sidebar content is shown
features.list = {}
local cleanup = features.cleanupCategories
cleanup.metalBankObjects = { [101] = true, [102] = true }
cleanup.treasureChestObjects = { [103] = true, [131] = true }

-- Record page builds, warnings, scans, and the main selection steps in order
local events = {}
local function record(name) events[#events + 1] = name end
local cleanupApply = CleanupPage.Apply
CleanupPage.Apply = function(owner, categoryID)
    assert(owner == layout)
    record("apply " .. categoryID .. (cleanup:IsRefreshing(categoryID) and " refreshing" or ""))
    return cleanupApply(owner, categoryID)
end
for _, method in ipairs({ "DetectNativeViewAll", "ShowViewAllWarning", "ShowPresetWarning" }) do
    local original = layout[method]
    layout[method] = function(...)
        record(method)
        return original(...)
    end
end
features.BeginCleanupRefresh = function(owner, categoryID)
    record("scan " .. tostring(categoryID))
    return getmetatable(owner).BeginCleanupRefresh(owner, categoryID)
end
local createInput = layout.nativeLease.CreateInteractionLayer
layout.nativeLease.CreateInteractionLayer = function(...)
    record("input")
    return createInput(...)
end
layout.RefreshTags = function() record("sidebar") end
features.RefreshTags = function() record("sidebar") end

-- Return and clear the recorded events
local function take()
    local result = table.concat(events, ", ")
    events = {}
    return result
end

-- Describe the drawn page: selection, headings, and item positions
local function page()
    local parts = { tostring(layout.selectedTag) }
    for _, header in ipairs(layout.listEngine.headers) do
        parts[#parts + 1] = header.root.children[1].options.text .. "@" .. header.root.y
    end
    for _, entry in ipairs(layout:VisibleMirrorEntries()) do
        parts[#parts + 1] = tostring(entry.objectID) .. "@" .. entry.x .. "," .. entry.y
    end
    return table.concat(parts, " ")
end

-- Report whether a scan listener is waiting for the next tick
local function scanning() return host:Listener("_cleanup_build") ~= nil end

-- Entering Cleanup starts a full scan; every category is refused until it finishes,
-- before the All Items check or any warning runs
layout:SetSidebarMode("cleanup")
assert(scanning() and cleanup:IsRefreshing(METAL))
take()
assert(layout:SetSelectedTag(METAL) == false)
assert(layout.selectedTag == nil and take() == "")
host:Tick()
assert(scanning() and cleanup:IsRefreshing(METAL), "one batch finished the scan")
host:Tick()
assert(not scanning() and not cleanup:IsRefreshing(METAL))
assert(take() == "sidebar", "a scan with no selection rebuilt a page")

-- A ready category is selected and built once, without another scan
assert(layout:SetSelectedTag(METAL))
assert(take() == "apply " .. METAL .. ", input, sidebar")
assert(not scanning())
local metalPage = page()
assert(metalPage == METAL .. " Metal Bank@0 101@8,32 102@52,32", metalPage)

-- A category that is still scanning is refused and the current page keeps its
-- headings, positions, and input targets
assert(features:BeginCleanupRefresh(CHEST))
take()
local hitLayer = layout.nativeLease.interactionHitLayer
local inputCount = #layout.nativeLease.interactionEntries
assert(hitLayer ~= nil and inputCount == 2)
assert(layout:SetSelectedTag(CHEST) == false)
assert(take() == "", "a refused category had effects")
assert(page() == metalPage and layout.nativeLease.interactionHitLayer == hitLayer)
assert(not hitLayer.destroyed and #layout.nativeLease.interactionEntries == inputCount)
-- Finishing another category's scan leaves the selected page alone
host:Tick()
host:Tick()
assert(not scanning() and take() == "sidebar")
assert(page() == metalPage)

-- A stale category shows its last results first, then scans after the sidebar updates
assert(layout:SetSelectedTag(nil))
host:Rebuild(function(specs)
    specs[#specs + 1] = { 131, 5 }
    return specs
end)
assert(layout:HandleInventoryUpdate() == false)
assert(cleanup:IsDirty(CHEST) and cleanup:IsDirty(METAL))
take()
assert(layout:SetSelectedTag(CHEST))
assert(take() == "apply " .. CHEST .. ", input, sidebar, scan " .. CHEST .. ", sidebar")
assert(page() == CHEST .. " Treasure Chest@0 103@8,32", page())
assert(scanning() and cleanup:IsRefreshing(CHEST) and not cleanup:IsRefreshing(METAL))
-- The scan continues in batches, then rebuilds the same selected page once
host:Tick()
assert(scanning() and take() == "")
host:Tick()
assert(not scanning() and not cleanup:IsDirty(CHEST) and cleanup:IsDirty(METAL))
assert(take() == "sidebar, apply " .. CHEST .. ", input")
assert(page() == CHEST .. " Treasure Chest@0 103@8,32 131@52,32", page())

-- Leaving Cleanup stops an unfinished scan without rebuilding a page
take()
assert(layout:SetSelectedTag(METAL))
assert(take() == "apply " .. METAL .. ", input, sidebar, scan " .. METAL .. ", sidebar")
host:Tick()
assert(scanning())
layout:SetSidebarMode("tags")
assert(layout.selectedTag == nil and not scanning() and not cleanup:IsRefreshing(METAL))
for _ = 1, 3 do host:Tick() end
assert(not string.find(take(), "apply", 1, true))
assert(cleanup:IsDirty(METAL))

-- Outside All Items, a scanning category is refused before the All Items check,
-- and a stale one is refused by that check without starting a scan
layout:SetSidebarMode("cleanup")
host:Tick()
host:Tick()
assert(not scanning())
layout.nativeViewAll = false
assert(features:BeginCleanupRefresh(METAL))
take()
assert(layout:SetSelectedTag(METAL) == false and take() == "")
host:Tick()
host:Tick()
cleanup:MarkDirty(METAL)
take()
assert(layout:SetSelectedTag(METAL) == false)
local refused = take()
assert(refused == "DetectNativeViewAll, ShowViewAllWarning, DetectNativeViewAll, sidebar", refused)
assert(layout.selectedTag == nil and not scanning() and cleanup:IsDirty(METAL))

-- The preset selector still answers first, even for a scanning category
layout.IsPresetViewOpen = function() return true end
assert(features:BeginCleanupRefresh(METAL))
take()
assert(layout:SetSelectedTag(METAL) == false)
assert(take() == "ShowPresetWarning, sidebar")
layout.IsPresetViewOpen = nil
layout:SetSidebarMode("tags")

CleanupPage.Apply = cleanupApply
print("cleanup_page_test: ok")
