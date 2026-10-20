package.path = "./?.lua;./?/init.lua;" .. package.path

-- Follow Bank Core through every load order in isolated plugins
-- FAKE HOST: stand-in loader, components, and widgets, not the game client

local Harness = require("tools/test_support/cleaner_harness")

local h = Harness.new("plugin_reload")
local Loader = require("tools/test_support/fake_plugin_host")
h.bankHost:SetItems({ { 2349, 3, "Bronze bar" }, { 1944, 1, "Egg" } })

-- Bank Cleaner has no plugin window entry, so it has no ribbon icon or panel
local manifest = assert(io.open(h.cleanerFolder .. "/plugin.json", "rb"))
assert(string.find(manifest:read("a"), '"hasRibbonIcon": false', 1, true))
manifest:close()

-- Without Bank Core, nothing is published
local cleaner = h:LoadCleaner()
local app = h:App()
assert(app ~= nil and not app:IsConnected() and cleaner.result == nil)
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
assert(app:IsConnected() and app.bank == core.result)
local state = app.handle:GetState()
assert(#state.pages == 13 and state.tabs[1] == "cleanup")
local _, layout = h:OpenBank()
h:Tick(4)
assert(app.tabActive and not app:IsBusy() and app.published.metal_bank == "LMetal Bank\nS2349:1")
-- Opening the bank and the Cleanup tab saves nothing
assert(next(h.databases.bankcleaner or {}) == nil)

-- Core reported unloaded and loaded again: release, then register
rawget(cleaner.env, "PluginDependencyUpdate")({ pluginIdentifier = "bankcore", enabled = false })
assert(not app:IsConnected() and app.handle == nil)
rawget(cleaner.env, "PluginDependencyUpdate")({ pluginIdentifier = "bankcore", enabled = true })
assert(app:IsConnected() and #app.handle:GetState().pages == 13)

-- A Core reload reconnects to the new API and scans again
local oldAPI = core.result
h.host:Reload("bankcore", { shutdown = true, notify = true, reinject = true })
assert(not oldAPI.GetState().running and app:IsConnected() and app.bank == core.result)
h:OpenBank()
h:Tick(4)
assert(app.tabActive and app.published.metal_bank == "LMetal Bank\nS2349:1")

-- A copied Core API still connects after a reload
h.host:Reload("bankcore", { shutdown = true })
h.host.exports.bankcore = Loader.Clone(core.result)
h.host:Notify("bankcore", true, true)
assert(app:IsConnected() and app.bank == h.host.exports.bankcore and getmetatable(app.bank) == nil)

-- Core unloading stops any scan
h.host:Unload("bankcore")
assert(not app:IsConnected() and not app.scanning)
h:LoadCore()
assert(app:IsConnected())
h:OpenBank()
h:Tick(4)

-- A same-state reload hands the owner ID to the new session
-- The old copy takes nothing back when told Core loaded
h.host:Reload("bankcleaner", { freshEnvironment = true })
local reloaded = h:App()
assert(reloaded ~= app and app.shutDown and reloaded:IsConnected())
rawget(cleaner.env, "PluginDependencyUpdate")({ pluginIdentifier = "bankcore", enabled = true })
assert(reloaded:IsConnected() and not app:IsConnected())
h:Tick(4)
assert(reloaded.tabActive and reloaded.published.metal_bank == "LMetal Bank\nS2349:1")

-- A reload that keeps cached modules still runs fresh ones
local cachedApp = h.cleaner.env.package.loaded["bankcleaner/app"]
h.host:Reload("bankcleaner")
local hot = h:App()
assert(hot ~= reloaded and reloaded.shutDown and hot:IsConnected())
assert(h.cleaner.env.package.loaded["bankcleaner/app"] ~= cachedApp)

-- Unloading mid-scan leaves no tab, page, listener, or subscription
local many = {}
for index = 1, 40 do many[index] = { 40000 + index, 1 } end
h.bankHost:SetItems(many)
h:Session().layout:HandleInventoryUpdate()
h:Tick(2)
assert(hot.scanning and h:Session().layout:FindSidebarTab("__bankutils_ext_tab:bankcleaner/cleanup") ~= nil)
h.host:Unload("bankcleaner")
assert(not hot:IsConnected() and not hot.scanning)
for _, subscription in ipairs(h.host:SubscriptionsOf("bankcleaner")) do
    error("Bank Cleaner left " .. subscription .. " subscribed")
end
assert(h:Session().layout:FindSidebarTab("__bankutils_ext_tab:bankcleaner/cleanup") == nil)
h.host:Unload("bankcore")

-- In separate Lua states, a newer copy takes the owner ID
-- The older copy sees it was replaced and stays idle
local split = Harness.new("plugin_reload_split", { separateGlobals = true, cloneExports = true })
split:LoadCore()
local first = split:LoadCleaner()
local firstApp = rawget(first.env, "__bankcleaner_session")
assert(firstApp:IsConnected() and rawget(first.env._G, "__bankcore_api") == nil)
local second = split.host:Load("bankcleaner_copy", split.cleanerFolder,
    { name = "bankcleaner", dependencies = {}, optional = { bankcore = true } })
local secondApp = rawget(second.env, "__bankcleaner_session")
assert(secondApp:IsConnected() and not firstApp:IsConnected())
rawget(first.env, "PluginDependencyUpdate")({ pluginIdentifier = "bankcore", enabled = true })
assert(firstApp.retired and not firstApp:IsConnected() and secondApp:IsConnected())

print("plugin_reload_test: ok")
