package.path = "./?.lua;./?/init.lua;" .. package.path

-- Check required load order and defensive dependency updates in isolated plugins
-- FAKE HOST: stand-in loader, components, and widgets, not the game client

local Harness = require("tools/test_support/cleaner_harness")

-- Production requires Core before Cleaner; reloading Cleaner reconnects after Core reloads.
local required = Harness.new("plugin_required")
local loaded, reason = pcall(function() required:LoadCleaner() end)
assert(not loaded and string.find(reason, "missing required dependency: bankcore", 1, true))
required:LoadCore()
required:LoadCleaner()
assert(required:App().ext ~= nil)
local oldRequiredApp = required:App()
required.host:Reload("bankcore", { shutdown = true })
required.host:Reload("bankcleaner")
assert(oldRequiredApp.shutDown and required:App().ext ~= nil)
required.host:Unload("bankcleaner")
required.host:Unload("bankcore")

-- An optional-only fixture models updates the host does not promise for required Core.
local h = Harness.new("plugin_reload", { optionalCore = true })
local Loader = require("tools/test_support/fake_plugin_host")
local TAB_ID = "__bankutils_ext_tab:bankcleaner"
h.bankHost:SetItems({ { 2349, 3, "Bronze bar" }, { 1944, 1, "Egg" } })

-- Bank Cleaner has no plugin window entry, so it has no ribbon icon or panel
local manifest = assert(io.open(h.cleanerFolder .. "/plugin.json", "rb"))
assert(string.find(manifest:read("a"), '"hasRibbonIcon": false', 1, true))
manifest:close()

-- Report whether an extension is still registered
-- Close does nothing while its page is not shown, and a replaced one answers stale
local function live(ext)
    return ext ~= nil and ext:Close() == true
end

-- Without Bank Core, nothing is published
local cleaner = h:LoadCleaner()
local app = h:App()
assert(app ~= nil and app.ext == nil and cleaner.result == nil)
assert(type(rawget(cleaner.env, "PluginDependencyUpdate")) == "function")
for _, subscription in ipairs(h.host:SubscriptionsOf("bankcleaner")) do
    assert(string.sub(subscription, 1, 18) ~= "ContentLayerReady.", subscription .. " is a plugin panel")
end
-- Only Bank Cleaner's own modules are in its cache
for moduleName in pairs(cleaner.env.package.loaded) do
    assert(string.sub(moduleName, 1, 12) == "bankcleaner/", moduleName .. " is not a Bank Cleaner module")
end

-- A late Core connects through the dependency update
local core = h:LoadCore()
assert(live(app.ext) and not app.ext:IsOpen())
-- The rail entry appears on the next tick
h:Tick()
assert(h:Session().layout:FindSidebarTab(TAB_ID).label == "Bank Cleaner")
local _, layout = h:OpenBank()
h:Tick(4)
-- Its icon is the only one, so the bank opens on its column
assert(app.sidebar ~= nil and not app:IsBusy() and string.find(app.foldersSignature, "metal_bank=1", 1, true))
-- Opening the bank and the Cleanup tab saves nothing
assert(next(h.databases.bankcleaner or {}) == nil)

-- Core reported unloaded and loaded again: dispose, then register
local disposed = app.ext
rawget(cleaner.env, "PluginDependencyUpdate")({ pluginIdentifier = "bankcore", enabled = false })
assert(app.ext == nil and not live(disposed) and h:Session().layout:FindSidebarTab(TAB_ID) == nil)
rawget(cleaner.env, "PluginDependencyUpdate")({ pluginIdentifier = "bankcore", enabled = true })
h:Tick()
assert(live(app.ext) and h:Session().layout:FindSidebarTab(TAB_ID) ~= nil)

-- A Core reload reconnects to the new API and scans again
-- The shown category is dropped; the chosen one stays, and nothing is shown until a click
h:OpenBank()
h:Tick(4)
assert(app.sidebar.list:Click("metal_bank"))
h:Tick(2)
assert(app:ShownCategory() == "metal_bank")
local oldExt = app.ext
h.host:Reload("bankcore", { shutdown = true, notify = true, reinject = true })
assert(select(2, oldExt:Open()) == "stale" and live(app.ext) and app.ext ~= oldExt)
assert(app:ShownCategory() == nil and app.category == "metal_bank")
_, layout = h:OpenBank()
h:Tick(4)
assert(app.sidebar ~= nil and string.find(app.foldersSignature, "metal_bank=1", 1, true))
assert(app.sidebar.list:Click("metal_bank"))
h:Tick(2)
assert(app:ShownCategory() == "metal_bank" and layout.shownPage.title == "Metal Bank")

-- A copied Core API still connects after a reload
h.host:Reload("bankcore", { shutdown = true })
h.host.exports.bankcore = Loader.Clone(core.result)
h.host:Notify("bankcore", true, true)
assert(live(app.ext))

-- Core unloading stops any scan
h.host:Unload("bankcore")
assert(app.ext == nil and not app.scanning)
h:LoadCore()
assert(live(app.ext))
h:OpenBank()
h:Tick(4)

-- A same-state reload shuts the old session down before the new one registers
-- The old copy registers nothing when told Core loaded
h.host:Reload("bankcleaner", { freshEnvironment = true })
local reloaded = h:App()
assert(reloaded ~= app and app.shutDown and live(reloaded.ext))
rawget(cleaner.env, "PluginDependencyUpdate")({ pluginIdentifier = "bankcore", enabled = true })
assert(live(reloaded.ext) and app.ext == nil)
h:Tick(4)
assert(reloaded.sidebar ~= nil and string.find(reloaded.foldersSignature, "metal_bank=1", 1, true))

-- A reload that keeps cached modules still runs fresh ones
local cachedApp = h.cleaner.env.package.loaded["bankcleaner/app"]
h.host:Reload("bankcleaner")
local hot = h:App()
assert(hot ~= reloaded and reloaded.shutDown and live(hot.ext))
assert(h.cleaner.env.package.loaded["bankcleaner/app"] ~= cachedApp)

-- Unloading mid-scan leaves no icon, page, callback, or subscription
local many = {}
for index = 1, 40 do many[index] = { 40000 + index, 1 } end
h.bankHost:SetItems(many)
h:Session().layout:HandleInventoryUpdate()
h:Tick(2)
assert(hot.scanning and h:Session().layout:FindSidebarTab(TAB_ID) ~= nil)
h.host:Unload("bankcleaner")
assert(hot.ext == nil and not hot.scanning)
for _, subscription in ipairs(h.host:SubscriptionsOf("bankcleaner")) do
    error("Bank Cleaner left " .. subscription .. " subscribed")
end
assert(h:Session().layout:FindSidebarTab(TAB_ID) == nil)
h.host:Unload("bankcore")

-- In separate Lua states, a newer copy's registration replaces the older one's
local split = Harness.new("plugin_reload_split", { separateGlobals = true, cloneExports = true })
split:LoadCore()
local first = split:LoadCleaner()
local firstApp = rawget(first.env, "__bankcleaner_session")
assert(live(firstApp.ext) and rawget(first.env._G, "__bankcore_api") == nil)
local second = split.host:Load("bankcleaner_copy", split.cleanerFolder,
    { name = "bankcleaner", dependencies = {}, optional = { bankcore = true } })
local secondApp = rawget(second.env, "__bankcleaner_session")
assert(live(secondApp.ext) and not live(firstApp.ext))

print("plugin_reload_test: ok")
