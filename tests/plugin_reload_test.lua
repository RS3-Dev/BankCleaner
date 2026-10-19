package.path = "./?.lua;./?/init.lua;" .. package.path

-- Load the built Bank Cleaner beside the real Bank Core in isolated plugin environments and
-- follow the dependency through every load order: Bank Cleaner without Core, Core arriving
-- late, Core reloading, cloned, and unloading, Bank Cleaner reloading with and without a
-- shared Lua state, and a newer copy taking the owner ID. Each plugin has its own module cache
-- FAKE HOST: stand-in loader, components, and widgets, not the game client

local Harness = require("tools/test_support/cleaner_harness")

local NOT_CONNECTED = "Bank Cleaner needs Bank Core. Enable Bank Core to see cleanup pages in your bank."
local CONNECTED = "Bank Cleaner is in your bank: open the bank and choose the Cleanup tab in the sidebar."
local REPLACED = "A newer copy of Bank Cleaner took over; this copy is idle."

local h = Harness.new("plugin_reload")
local Loader = require("tools/test_support/fake_plugin_host")
h.bankHost:SetItems({ { 2349, 3, "Bronze bar" }, { 1944, 1, "Egg" } })

-- Bank Cleaner loads without Bank Core: it publishes nothing and says Core is needed
local cleaner = h:LoadCleaner()
local app = h:App()
assert(app ~= nil and not app:IsConnected() and cleaner.result == nil)
assert(type(rawget(cleaner.env, "PluginDependencyUpdate")) == "function")
local panel = h:OpenContentPanel()
assert(Harness.Find(panel, NOT_CONNECTED) ~= nil)
-- Only Bank Cleaner's own modules are in its cache
for moduleName in pairs(cleaner.env.package.loaded) do
    assert(string.sub(moduleName, 1, 12) == "bankcleaner/", moduleName .. " is not a Bank Cleaner module")
end

-- Core arrives late; the host's dependency update connects Bank Cleaner
local core = h:LoadCore()
assert(app:IsConnected() and app.bank == core.result)
assert(Harness.Find(panel, CONNECTED) ~= nil)
local state = app.handle:GetState()
assert(#state.pages == 13 and state.tabs[1] == "cleanup")
local _, layout = h:OpenBank()
h:Tick(4)
assert(app.tabActive and not app:IsBusy() and app.published.metal_bank == "LMetal Bank\nS2349:1")
-- Bank Cleaner saves nothing
assert(next(h.databases.bankcleaner or {}) == nil)

-- The host reports Core unloaded and loaded again without reloading it: Bank Cleaner lets go
-- and registers again
rawget(cleaner.env, "PluginDependencyUpdate")({ pluginIdentifier = "bankcore", enabled = false })
assert(not app:IsConnected() and app.handle == nil)
rawget(cleaner.env, "PluginDependencyUpdate")({ pluginIdentifier = "bankcore", enabled = true })
assert(app:IsConnected() and #app.handle:GetState().pages == 13)

-- Core reloads; Bank Cleaner reconnects to the new API and scans again in the new bank
local oldAPI = core.result
h.host:Reload("bankcore", { shutdown = true, notify = true, reinject = true })
assert(not oldAPI.GetState().running and app:IsConnected() and app.bank == core.result)
h:OpenBank()
h:Tick(4)
assert(app.tabActive and app.published.metal_bank == "LMetal Bank\nS2349:1")

-- A host that clones exports hands Bank Cleaner a copy of Core's API; a reload still connects
h.host:Reload("bankcore", { shutdown = true })
h.host.exports.bankcore = Loader.Clone(core.result)
h.host:Notify("bankcore", true, true)
assert(app:IsConnected() and app.bank == h.host.exports.bankcore and getmetatable(app.bank) == nil)

-- Core unloads: Bank Cleaner lets go, stops any scan, and says Core is needed again
h.host:Unload("bankcore")
assert(not app:IsConnected() and not app.scanning)
assert(Harness.Find(panel, NOT_CONNECTED) ~= nil)
h:LoadCore()
assert(app:IsConnected())
h:OpenBank()
h:Tick(4)

-- Bank Cleaner reloads in the same Lua state: the previous session shuts down and the new
-- one takes the owner ID; the old copy, told Core loaded again, takes nothing back
h.host:Reload("bankcleaner", { freshEnvironment = true })
local reloaded = h:App()
assert(reloaded ~= app and app.shutDown and reloaded:IsConnected())
rawget(cleaner.env, "PluginDependencyUpdate")({ pluginIdentifier = "bankcore", enabled = true })
assert(reloaded:IsConnected() and not app:IsConnected())
h:Tick(4)
assert(reloaded.tabActive and reloaded.published.metal_bank == "LMetal Bank\nS2349:1")

-- A hot reload that keeps the module cache still runs fresh modules: the entry evicts them
local cachedApp = h.cleaner.env.package.loaded["bankcleaner/app"]
h.host:Reload("bankcleaner")
local hot = h:App()
assert(hot ~= reloaded and reloaded.shutDown and hot:IsConnected())
assert(h.cleaner.env.package.loaded["bankcleaner/app"] ~= cachedApp)

-- Unloading Bank Cleaner mid-scan leaves no tab, page, listener, or subscription behind
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

-- Separate Lua states: a newer copy takes the owner ID while the older one keeps running.
-- The older copy, told Core loaded, sees it was replaced and stays idle: no ping-pong
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
local firstPanel = ui.Layer.new(nil)
firstPanel:SetSize(300, 400)
firstApp:CreatePanel(firstPanel)
assert(Harness.Find(firstPanel, REPLACED) ~= nil)

print("plugin_reload_test: ok")
