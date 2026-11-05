package.path = "./?.lua;./?/init.lua;" .. package.path

-- Drive native restrictions through Core's public API and cloned plugin exports.
local Harness = require("tools/test_support/cleaner_harness")
local h = Harness.new("bank_state", { separateGlobals = true, cloneExports = true })
h.bankHost:SetItems({ { 2349, 3, "Bronze bar" } })
local core = h:LoadCore()
local register = core.result.Register
local listener, notices = nil, 0
core.result.Register = function(spec)
    if spec.id == "bankcleaner" then
        local changed = assert(spec.onBankStateChanged)
        spec.onBankStateChanged = function(state)
            notices = notices + 1
            changed(state)
        end
        listener = spec.onBankStateChanged
    end
    return register(spec)
end
h:LoadCleaner()
local app = h:App()
local session, layout = h:OpenBank()
h:Tick(3)
assert(app.sidebar ~= nil and app:ChooseCategory("metal_bank"))
h:Tick(2)
assert(app.ext:IsOpen())

local function ready()
    return { bankOpen = true, viewAll = true, presetOpen = false,
        searchActive = false, filterActive = false }
end

-- Every blocked state removes our page and its selection, and explains recovery.
for _, case in ipairs({
    { "bankOpen", false, "Open your bank" },
    { "viewAll", false, 'Select "All Items"' },
    { "presetOpen", true, "Close the preset selector" },
    { "searchActive", true, "Clear the bank search" },
    { "filterActive", true, "Clear the bank filter" },
}) do
    local state = ready()
    state[case[1]] = case[2]
    listener(state)
    assert(app:ShownCategory() == nil and layout.shownPage == nil, case[1])
    assert(not app.scanning and app.status:find(case[3], 1, true), case[1])
    assert(not app.sidebar.statusBanner.hidden and app.sidebar.statusText.content == app.status)
    for _, entry in ipairs(app.sidebar.entries) do assert(not entry.selected) end
    listener(ready())
    assert(not app.ext:IsOpen() and app.status == nil and app.sidebar.statusBanner.hidden)
    assert(app:ChooseCategory("metal_bank"))
end

-- Another extension's page is never closed by Cleaner's state handler.
local other = assert(core.result.Register({ id = "other", name = "Other" }))
assert(other:SetPage({ rows = { { slots = { 2349 } } } }) and other:Open())
local state = ready()
state.searchActive = true
listener(state)
assert(other:IsOpen())
listener(ready())
assert(other:Close() and app:ChooseCategory("metal_bank"))

-- Real native controls drive state changes; a click cannot bypass a pending notice.
local getComponent = ui.Interfaces.GetComponent
local background, cancel = { spriteID = 8070 }, { visible = false }
local cancelText, preset = { visible = true, content = "" }, { visible = false }
ui.Interfaces.GetComponent = function(self, interfaceID, staticID, categoryID, dynamicID)
    if interfaceID == 517 then
        if staticID == 166 and categoryID == 0 and dynamicID == 0 then return background end
        if staticID == 257 then
            if categoryID == 0 and dynamicID == 9 then return cancelText end
            if categoryID == nil then return cancel end
        end
        if staticID == 86 then return preset end
    end
    return getComponent(self, interfaceID, staticID, categoryID, dynamicID)
end

for _, case in ipairs({
    { "Cancel Search", "Clear the bank search" },
    { "Clear Filter", "Clear the bank filter" },
}) do
    cancel.visible, cancelText.content = true, case[1]
    assert(not app:ChooseCategory("focus_storage"))
    assert(app.category == "metal_bank" and layout.shownPage == nil)
    assert(app.status:find(case[2], 1, true))
    session.pluginPages:Notify()
    h:Tick(2)
    assert(not app.ext:IsOpen() and not app.scanning)
    cancel.visible = false
    session.pluginPages:Notify()
    h:Tick(3)
    assert(not app.ext:IsOpen() and app.status == nil)
    assert(app:ChooseCategory("metal_bank"))
end

background.spriteID = 8069
assert(not app:ChooseCategory("metal_bank") and layout.shownPage == nil)
assert(app.status == 'Select "All Items" to view cleanup items.')
background.spriteID = 8070
layout:SetNativeViewAll(true)
assert(app:ChooseCategory("metal_bank"))
preset.visible = true
session.pluginPages:Notify()
h:Tick(2)
assert(not app.ext:IsOpen() and app.status == "Close the preset selector to view cleanup items.")
preset.visible = false
session.pluginPages:Notify()
h:Tick(2)
assert(app.status == nil and not app.ext:IsOpen())
assert(app:ChooseCategory("metal_bank"))
ui.Interfaces.GetComponent = getComponent

-- Open refusals that race with a valid snapshot are also explained.
local open = app.ext.Open
app.ext.Open = function() return false, "busy" end
assert(not app:ChooseCategory("focus_storage"))
assert(app.status == "The bank is still updating. Try again." and not app.ext:IsOpen())
app.ext.Open = open
assert(app:ChooseCategory("metal_bank") and app.status == nil)

-- Disposing the extension stops notifications and destroys the overlay.
local banner = app.sidebar.statusBanner
h.host:Unload("bankcleaner")
local heard = notices
session.pluginPages:Notify()
h:Tick(2)
assert(notices == heard and app.ext == nil and app.sidebar == nil)
assert(banner.destroyed)
h.host:Unload("bankcore")
print("bank_state_test: ok")
