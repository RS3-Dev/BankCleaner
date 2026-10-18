package.path = "./?.lua;./?/init.lua;" .. package.path

-- Characterize page selection, hover leasing, inventory rebinds, and scrolling
-- through the real bank modules on a stand-in host
-- Run all tests with Lua 5.4: lua54 tools/check.lua (toolchain notes in STAGE0_BASELINE.md)

local FakeBankHost = require("tools/test_support/fake_bank_host")
local host = FakeBankHost.install()
local TagStore = require("lib/features/tags/tag_store")
local QueryStore = require("lib/features/runesql/query_store")

-- Thirty stacks over three native rows; "Item 1" matches Item 1 and Item 10 to Item 19
local function stockBank()
    local specs = {}
    for slot = 0, 29 do specs[#specs + 1] = { 100 + slot, 10, "Item " .. slot } end
    return host:SetItems(specs)
end
stockBank()
host.viewport:SetSize(448, 100)

local store = TagStore.new()
store:SetLayoutPlacement(false)
assert(store:CreateTag("gear"))
for _, objectID in ipairs({ 112, 105, 101 }) do assert(store:AddTag("gear", objectID)) end
assert(store:CreateTag("food"))
assert(store:AddTag("food", 103))
assert(store:CreateTag("bulk"))
for slot = 0, 29 do assert(store:AddTag("bulk", 100 + slot)) end
local queries = QueryStore.new()
local savedQuery, record = queries:Save(nil, "Ones", "item 1")
assert(savedQuery)
local querySelection = QueryStore.SelectionID(record.id)

local layout, features = host:NewLayout(store, {
    queryStore = queries,
    settings = { enableRuneSQL = true },
})
local lease = layout.nativeLease
local engine = layout.listEngine

local reapplies = 0
local reapply = layout.ReapplySelectedTag
layout.ReapplySelectedTag = function(self, force)
    reapplies = reapplies + 1
    return reapply(self, force)
end

-- Record where every native stack rests before a page touches it
local function restingPositions()
    local positions = {}
    for _, item in ipairs(host.items) do
        positions[item.associatedObjectID] = { x = item.x, y = item.y }
    end
    return positions
end

-- Check that no native stack has been moved from its resting position
local function assertNativeAtRest(rest)
    for _, item in ipairs(host.items) do
        local position = rest[item.associatedObjectID]
        assert(item.x == position.x and item.y == position.y,
            "native item " .. item.associatedObjectID .. " is displaced")
    end
end

-- Find the displayed entry for an object on the current page
local function entryFor(objectID)
    for _, entry in ipairs(layout:VisibleMirrorEntries()) do
        if entry.objectID == objectID then return entry end
    end
    return nil
end

-- Find the rendered sprite for an object on the current page
local function spriteFor(objectID)
    for _, sprite in ipairs(engine.sprites) do
        if sprite.objectID == objectID then return sprite end
    end
    return nil
end

-- Rest the pointer over a displayed item and let one logic tick run
local function hover(objectID)
    local entry = assert(entryFor(objectID))
    host:PointAtContent(entry.x, entry.y, engine.scrollY)
    host:Tick()
    return entry
end

local rest = restingPositions()

-- Observe the two safety boundaries of a page rebuild: what the bank shows when the page
-- is computed, and what exists when item input opens. Returns the observations
local function observeRebuild(action)
    local seen = {}
    local applyView = layout.ApplySelectedBankView
    layout.ApplySelectedBankView = function(self, tag)
        local blocker = lease.interactionHitLayer
        seen.apply = {
            leased = lease:HasInteractionLease(),
            blocker = blocker,
            open = blocker ~= nil and blocker.clickthrough == true,
            fronted = blocker ~= nil and blocker.front == host.frontCount,
        }
        assertNativeAtRest(rest)
        return applyView(self, tag)
    end
    local createInput = lease.CreateInteractionLayer
    lease.CreateInteractionLayer = function(self)
        local spritesReady = engine.layer ~= nil and #engine.sprites > 0
        for index, entry in ipairs(layout:VisibleMirrorEntries()) do
            local sprite = engine.sprites[index]
            spritesReady = spritesReady and sprite ~= nil and sprite.layoutKey == entry.layoutKey
        end
        seen.input = { sprites = spritesReady, indexed = next(self.nativeItemsByKey) ~= nil }
        return createInput(self)
    end
    local ok, result = pcall(action)
    layout.ApplySelectedBankView = applyView
    lease.CreateInteractionLayer = createInput
    assert(ok, result)
    assert(result, "rebuild action failed")
    return seen
end

-- Selecting a page computes it only after input is closed and every native stack is back
-- in place, and opens item input only once sprites and the native index exist
local seen = observeRebuild(function() return layout:SetSelectedTag("gear") end)
assert(not seen.apply.leased and not seen.apply.open)
assert(seen.input.sprites and seen.input.indexed)
local blocker = assert(lease.interactionHitLayer)
assert(blocker.clickthrough == false)
assert(blocker.x == 270 and blocker.y == 80 and blocker.width == 448 and blocker.height == 100)
assert(#lease.interactionTargets == 3)
assertNativeAtRest(rest)
host:Tick()
assert(not lease:HasInteractionLease())
assertNativeAtRest(rest)

-- Hovering moves only the matching native stack under the sprite, parks the stack it
-- would overlap, holds its drag thresholds, and lets the wheel scroll the page
local gearEntry = hover(112)
local leased = host:Item(112)
local covered = host:Item(100)
assert(lease:HasInteractionLease())
assert(leased.x == gearEntry.x and leased.y == gearEntry.y)
assert(leased.clickthrough == false)
assert(leased.dragConfig.deadZone == 255 and leased.dragConfig.dragDelayTicks == 255)
assert(leased.hooks.wheel ~= nil)
assert(covered.x == -10000 and covered.y == -10000 and covered.clickthrough == true)
assert(host:Item(101).x == rest[101].x and host:Item(101).y == rest[101].y)
assert(blocker.clickthrough == true)

-- Leaving the item restores both stacks, their input, and their drag thresholds
host:PointAtContent(400, 60)
host:Tick()
assert(not lease:HasInteractionLease())
assertNativeAtRest(rest)
assert(leased.clickthrough == false and covered.clickthrough == false)
assert(leased.dragConfig.deadZone == 4 and leased.dragConfig.dragDelayTicks == 5)
assert(blocker.clickthrough == false)

-- A forced refresh while leased closes and fronts the durable blocker and returns every
-- displaced stack before the page is recomputed, then reopens input on the new sprites
gearEntry = hover(112)
assert(lease:HasInteractionLease() and leased.x == gearEntry.x)
seen = observeRebuild(function() return layout:ReapplySelectedTag(true) end)
assert(seen.apply.blocker == blocker and not seen.apply.leased)
assert(not seen.apply.open and seen.apply.fronted)
assert(seen.input.sprites and seen.input.indexed)
assert(lease.interactionHitLayer == blocker and not blocker.destroyed)
assert(lease:HasInteractionLease() and lease.interactionLease.item == leased)
gearEntry = assert(entryFor(112))
assert(spriteFor(112).root.x == gearEntry.x and spriteFor(112).root.y == gearEntry.y)
assert(leased.x == gearEntry.x and leased.y == gearEntry.y)
assert(lease.interactionLease.instanceKey == gearEntry.instanceKey)

-- Switching pages while leased releases everything before the next page is computed;
-- the new blocker then leases whatever item now sits under the stationary pointer
seen = observeRebuild(function() return layout:SetSelectedTag("food") end)
assert(not seen.apply.leased and not seen.apply.open)
assert(seen.input.sprites and seen.input.indexed)
assert(blocker.destroyed and lease.interactionHitLayer ~= blocker)
assert(lease:HasInteractionLease() and lease.interactionLease.objectID == 103)
assert(host:Item(112).x == rest[112].x and host:Item(112).y == rest[112].y)

host.mouse = nil
assert(layout:SetSelectedTag("gear"))
blocker = lease.interactionHitLayer
host:Tick()
assertNativeAtRest(rest)

-- A leased stack that becomes a placeholder closes input, returns home, and is
-- drawn as a placeholder without an input target
hover(105)
assert(lease:HasInteractionLease())
host:Item(105).associatedObjectQuantity = 0
host:Tick()
assert(not lease:HasInteractionLease())
assert(blocker.clickthrough == false)
assertNativeAtRest(rest)
assert(spriteFor(105).placeholder and spriteFor(105).root.alpha == 0.45)
assert(#lease.interactionEntries == 2)
host:Tick()
assert(not lease:HasInteractionLease())
host:Item(105).associatedObjectQuantity = 10
assert(layout:ReapplySelectedTag(true))
assert(not spriteFor(105).placeholder)

-- An unreadable quantity is not proof of a stack; input reopens only after a positive
-- quantity is observed and the pointer moves
host:Tick()
local unreadable = hover(112)
assert(lease:HasInteractionLease())
host:Item(112).associatedObjectQuantity = nil
host:Tick()
assert(not lease:HasInteractionLease())
assertNativeAtRest(rest)
for _ = 1, 3 do host:Tick() end
assert(not lease:HasInteractionLease())
host:Item(112).associatedObjectQuantity = 10
host:Tick()
assert(not lease:HasInteractionLease())
host:PointAtContent(unreadable.x + 1, unreadable.y)
host:Tick()
assert(lease:HasInteractionLease() and lease.interactionLease.objectID == 112)

-- An inventory event closes and fronts the gate before anything else changes
assert(blocker.clickthrough == true)
assert(layout:HandleInventoryUpdate())
assert(blocker.clickthrough == false and blocker.front == host.frontCount)

-- With a lease held, the next tick moves the replacement wrapper under the sprite
-- without rebuilding the page
local page = engine.layer
local before = reapplies
host:Rebuild()
host:Tick()
local replacement = host:Item(112)
assert(replacement ~= leased)
assert(lease:HasInteractionLease() and lease.interactionLease.item == replacement)
assert(replacement.x == unreadable.x and replacement.y == unreadable.y)
assert(replacement.clickthrough == false and replacement.dragConfig.deadZone == 255)
assert(host:Item(100).x == -10000)
assert(engine.layer == page and reapplies == before)

-- Without a lease, the next tick rebinds the page snapshot to the new wrappers in place
host:PointAtContent(400, 60)
host:Tick()
assertNativeAtRest(rest)
assert(not lease:HasInteractionLease())
assert(layout:HandleInventoryUpdate())
host:Rebuild()
rest = restingPositions()
host:Tick()
assert(reapplies == before + 1)
assert(engine.layer == page)
assert(entryFor(112).component == host:Item(112))
assertNativeAtRest(rest)

-- A tag page whose leased stack vanishes rebinds its snapshot and shows a placeholder
local withoutItem = function(objectID)
    return function(specs)
        local kept = {}
        for _, spec in ipairs(specs) do
            if spec[1] ~= objectID then kept[#kept + 1] = spec end
        end
        return kept
    end
end
hover(112)
assert(lease:HasInteractionLease())
before = reapplies
assert(layout:HandleInventoryUpdate())
host:Rebuild(withoutItem(112))
rest = restingPositions()
host:Tick()
assert(reapplies == before + 1)
assert(not lease:HasInteractionLease())
assert(#layout.pageState.snapshots == 29)
assert(entryFor(112).placeholder and spriteFor(112).placeholder)
assert(engine.layer == page)
assertNativeAtRest(rest)

-- A leased stack that is a placeholder after the rebuild keeps the page and its blocker
host.mouse = nil
stockBank()
rest = restingPositions()
assert(layout:ReapplySelectedTag(true))
blocker = lease.interactionHitLayer
host:Tick()
hover(105)
assert(lease:HasInteractionLease())
before = reapplies
assert(layout:HandleInventoryUpdate())
host:Rebuild(function(specs)
    for _, spec in ipairs(specs) do
        if spec[1] == 105 then spec[2] = 0 end
    end
end)
rest = restingPositions()
host:Tick()
assert(reapplies == before)
assert(not lease:HasInteractionLease())
assert(lease.interactionHitLayer == blocker and blocker.clickthrough == false)
assert(spriteFor(105).placeholder)
assertNativeAtRest(rest)

-- Saved queries rank by score, then native order, and record their match count
host.mouse = nil
stockBank()
rest = restingPositions()
assert(layout:SetSelectedTag(querySelection))
local ranked = layout:VisibleMirrorEntries()
table.sort(ranked, function(left, right)
    if left.y == right.y then return left.x < right.x end
    return left.y < right.y
end)
local order = {}
for _, entry in ipairs(ranked) do order[#order + 1] = entry.objectID end
assert(table.concat(order, ",") == "101,110,111,112,113,114,115,116,117,118,119")
assert(features.runeQueryCounts[record.id] == 11)
assert(layout:DisplayTagName(querySelection) == "Ones")
host:Tick()

-- Query-only exception: when a query page's leased stack vanishes, the page keeps its
-- membership and only rebuilds input; it does not re-run the query
hover(112)
assert(lease:HasInteractionLease())
before = reapplies
assert(layout:HandleInventoryUpdate())
host:Rebuild(withoutItem(112))
rest = restingPositions()
host:Tick()
host:Tick()
assert(reapplies == before)
assert(not lease:HasInteractionLease())
assert(#layout.pageState.snapshots == 30)
assert(entryFor(112) ~= nil and not entryFor(112).placeholder)
assert(features.runeQueryCounts[record.id] == 11)
assertNativeAtRest(rest)
assert(layout:ReapplySelectedTag(true))
assert(entryFor(112) == nil and features.runeQueryCounts[record.id] == 10)

-- A rebind closure from an earlier page generation, called after the page switch has
-- advanced the generation, does not refresh the later page. This does not show what
-- happens if a host calls the closure during Unsubscribe, before the generation advances
host.mouse = nil
stockBank()
assert(layout:SetSelectedTag("gear"))
host:Tick()
assert(layout:HandleInventoryUpdate())
local stale = assert(host:Listener("_post_rebuild_rebind"))
assert(layout:SetSelectedTag(nil))
assert(host:Listener("_post_rebuild_rebind") == nil)
assert(layout:SetSelectedTag("gear"))
host:Tick()
assert(layout:HandleInventoryUpdate())
before = reapplies
assert(host:Listener("_post_rebuild_rebind") ~= nil)
stale()
assert(reapplies == before and not lease:HasInteractionLease())
-- KNOWN ISSUE, recorded rather than endorsed: the stale closure unsubscribes before its
-- generation check, so it also cancels the later page's pending rebind. This matters only
-- if the host can call a callback after it was unsubscribed, which is unproven
assert(host:Listener("_post_rebuild_rebind") == nil)

-- The failed-rebind policy is read from the current selection. Saved-query membership
-- is recognized by its selection ID alone, as before, even without a saved record
local probe = host:NewLayout(store, { queryStore = queries })
local NAME_SEARCH = require("lib/features/search/bank_name_search").SELECTION_ID
for selection, expected in pairs({
    [querySelection] = "recreate_input",
    [QueryStore.SelectionID("999")] = "recreate_input",
    [NAME_SEARCH] = false,
    ["__bankutils_cleanup:metal"] = false,
    gear = false,
}) do
    probe.selectedTag = selection
    assert((probe:FailedRebindRecovery() or false) == expected, selection)
end
probe.selectedTag = nil
assert(probe:FailedRebindRecovery() == nil)
probe = host:NewLayout(store, {})
probe.selectedTag = querySelection
assert(probe:FailedRebindRecovery() == nil)

-- After a query page keeps itself through a failed rebind, a tag page's same failure
-- still reapplies and shows a placeholder: the query exception does not linger
host.mouse = nil
stockBank()
rest = restingPositions()
assert(layout:SetSelectedTag(querySelection))
host:Tick()
hover(112)
before = reapplies
assert(layout:HandleInventoryUpdate())
host:Rebuild(withoutItem(112))
rest = restingPositions()
host:Tick()
assert(reapplies == before and not lease:HasInteractionLease())
assert(entryFor(112) ~= nil and not entryFor(112).placeholder)
assertNativeAtRest(rest)

host.mouse = nil
stockBank()
rest = restingPositions()
assert(layout:SetSelectedTag("gear"))
host:Tick()
hover(112)
before = reapplies
assert(layout:HandleInventoryUpdate())
host:Rebuild(withoutItem(112))
rest = restingPositions()
host:Tick()
assert(reapplies == before + 1 and not lease:HasInteractionLease())
assert(entryFor(112).placeholder and spriteFor(112).placeholder)
assertNativeAtRest(rest)

-- A query page's rebind still pending when the page closes does not bring a page back
host.mouse = nil
stockBank()
assert(layout:SetSelectedTag(querySelection))
host:Tick()
hover(112)
assert(layout:HandleInventoryUpdate())
local pending = assert(host:Listener("_post_rebuild_rebind"))
assert(layout:SetSelectedTag(nil))
host:Rebuild(withoutItem(112))
rest = restingPositions()
before = reapplies
pending()
assert(reapplies == before and layout.selectedTag == nil)
assert(engine.layer == nil and lease.interactionHitLayer == nil)
assert(not lease:HasInteractionLease())
assertNativeAtRest(rest)
host.mouse = nil
stockBank()

-- Scrolling: a new page starts at the top and remembers the native offset
host.mouse = nil
assert(layout:SetSelectedTag(nil))
rest = restingPositions()
host.viewport.scrollY = 20
assert(layout:SetSelectedTag("bulk"))
assert(engine.scrollY == 0 and host.viewport.scrollY == 0)
assert(engine:ContentHeightForCurrentLayout() == 136 and engine:MaxScrollY() == 36)
host:Tick()

-- A scroll clamps to the page, releases hover, and waits exactly eight settled ticks;
-- moving the pointer during the wait does not lease
local lower = assert(entryFor(115))
host:PointAtContent(lower.x, lower.y, 0)
host:Tick()
assert(lease:HasInteractionLease())
assert(engine:SetScrollPosition(1000))
assert(engine.scrollY == 36 and host.viewport.scrollY == 36)
assert(engine.contentViewport.scrollY == 36)
assert(not lease:HasInteractionLease())
assert(engine.scrollInteractionTicks == 8)
for tick = 1, 8 do
    host:PointAtContent(lower.x + tick % 2, lower.y, engine.scrollY)
    host:Tick()
    assert(not lease:HasInteractionLease(), "leased during scroll settle tick " .. tick)
end
host:PointAtContent(lower.x + 2, lower.y, engine.scrollY)
host:Tick()
assert(lease:HasInteractionLease() and lease.interactionLease.objectID == 115)

-- A stationary pointer does not reacquire after the settle; it must move first
assert(engine:SetScrollPosition(0))
for _ = 1, 9 do host:Tick() end
assert(not lease:HasInteractionLease())

-- A native rebuild that restores an older viewport offset does not move the page
assert(engine:SetScrollPosition(36))
for _ = 1, 9 do host:Tick() end
host.viewport.scrollY = 0
host:Tick()
assert(host.viewport.scrollY == 36 and engine.scrollY == 36)
assert(engine.scrollInteractionTicks == 0)

-- The wheel moves one row through the same settle, also from a pending rebind
host:PointAtContent(lower.x + 1, lower.y, engine.scrollY)
host:Tick()
assert(lease:HasInteractionLease())
before = reapplies
assert(layout:HandleInventoryUpdate())
assert(lease.interactionHitLayer.hooks.wheel(nil, -1))
assert(engine.scrollY == 0 and engine.scrollInteractionTicks == 8)
assert(not lease:HasInteractionLease())
host:Tick()
assert(not lease:HasInteractionLease() and reapplies == before)

-- Reapplying keeps the offset; another page starts at the top again
assert(engine:SetScrollPosition(36))
assert(layout:ReapplySelectedTag(true))
assert(engine.scrollY == 36 and host.viewport.scrollY == 36)
assert(layout:SetSelectedTag("gear"))
assert(engine.scrollY == 0)
assert(layout:SetSelectedTag("bulk"))
assert(engine.scrollY == 0)

-- Leaving the page removes it and restores the native offset, stacks, and input
assert(engine:SetScrollPosition(36))
host:PointAtContent(lower.x, lower.y, engine.scrollY)
for _ = 1, 9 do host:Tick() end
host:PointAtContent(lower.x + 1, lower.y, engine.scrollY)
host:Tick()
assert(lease:HasInteractionLease())
local lastLeased = lease.interactionLease.item
assert(layout:SetSelectedTag(nil))
assert(host.viewport.scrollY == 20)
assert(engine.layer == nil and engine.scrollbarLayer == nil and #engine.sprites == 0)
assert(lease.interactionHitLayer == nil and not lease:HasInteractionLease())
assert(lastLeased.dragConfig.deadZone == 4 and lastLeased.clickthrough == false)
assertNativeAtRest(rest)
assert(host:Listener("_visual_sync") == nil and host:Listener("_post_rebuild_rebind") == nil)
assert(host:Listener("_lease_recovery") == nil)

-- Two stacks of one object are separate copies: hovering a copy leases its own native
-- stack, never its sibling, and leaving restores both
host.mouse = nil
local copies = host:SetItems({
    { 400, 10, "Filler" }, { 500, 10, "Rune" }, { 401, 10, "Filler" },
    { 402, 10, "Filler" }, { 500, 7, "Rune" },
})
local firstCopy, secondCopy = copies[2], copies[5]
-- restingPositions keys by object, so record these stacks by wrapper instead
local copyRest = {}
for _, item in ipairs(copies) do copyRest[item] = { x = item.x, y = item.y } end
local function assertCopiesAtRest()
    for item, position in pairs(copyRest) do
        assert(item.x == position.x and item.y == position.y, "stack is displaced")
        assert(item.clickthrough == false and item.dragConfig.deadZone == 4)
    end
end
local function copyEntry(layoutKey)
    for _, entry in ipairs(layout:VisibleMirrorEntries()) do
        if entry.layoutKey == layoutKey then return entry end
    end
    return nil
end
local function hoverCopy(layoutKey, own, sibling)
    local entry = assert(copyEntry(layoutKey))
    host:PointAtContent(entry.x, entry.y, engine.scrollY)
    host:Tick()
    assert(lease:HasInteractionLease() and lease.interactionLease.item == own)
    assert(own.x == entry.x and own.y == entry.y and own.dragConfig.deadZone == 255)
    assert(not (sibling.x == entry.x and sibling.y == entry.y))
    assert(sibling.dragConfig.deadZone == 4)
end
local function leaveCopies()
    host:PointAtContent(400, 60)
    host:Tick()
    assert(not lease:HasInteractionLease())
    assertCopiesAtRest()
end
assert(store:CreateTag("copies"))
assert(store:AddTag("copies", 500, "object:500:1"))
assert(store:AddTag("copies", 500, "object:500:2"))
assert(store:CreateTag("second copy"))
assert(store:AddTag("second copy", 500, "object:500:2"))

assert(layout:SetSelectedTag("copies"))
host:Tick()
hoverCopy("object:500:2", secondCopy, firstCopy)
leaveCopies()
hoverCopy("object:500:1", firstCopy, secondCopy)
leaveCopies()

-- A page showing only the second copy leases the second stack, not the first match
assert(layout:SetSelectedTag("second copy"))
host:Tick()
assert(#layout:VisibleMirrorEntries() == 1)
hoverCopy("object:500:2", secondCopy, firstCopy)
assert(layout:SetSelectedTag(nil))
assertCopiesAtRest()

print("bank_page_lifecycle_test: ok")
