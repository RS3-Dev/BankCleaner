-- Start Bank Cleaner on top of Bank Core
-- Core is a required dependency, loaded before this plugin

local SESSION_KEY = "__bankcleaner_session"

local previous = rawget(_G, SESSION_KEY)
if previous ~= nil then pcall(function() previous:Shutdown() end) end
-- A reload reuses the same Lua state, so drop the old app before loading modules again
if rawget(_G, SESSION_KEY) == previous then _G[SESSION_KEY] = nil end
previous = nil
pcall(function() collectgarbage("collect") end)

-- Clear this plugin's saved modules so a reload uses the latest code
if package ~= nil and package.loaded ~= nil then
    for _, moduleName in ipairs({
        "app",
        "resources/cleanup/categories",
        "resources/cleanup/pages",
        "resources/cleanup/sidebar",
        "resources/data/armour_case_objects",
        "resources/data/bookcase_objects",
        "resources/data/cape_store_objects",
        "resources/data/clue_carrier_objects",
        "resources/data/diango_objects",
        "resources/data/fancy_dress_box_objects",
        "resources/data/focus_storage_optional_objects",
        "resources/data/focus_storage_recommended_objects",
        "resources/data/magic_wardrobe_objects",
        "resources/data/material_storage_objects",
        "resources/data/metal_bank_objects",
        "resources/data/object_quests",
        "resources/data/seed_bag_objects",
        "resources/data/sidebar_icons",
        "resources/data/stone_spirit_objects",
        "resources/data/storage_chest_objects",
        "resources/data/storm_barn_objects",
        "resources/data/tool_leprechaun_objects",
        "resources/data/toy_box_objects",
        "resources/data/treasure_chest_objects",
        "resources/data/wood_spirit_objects",
        "resources/data/workbench_artefact_objects",
    }) do
        package.loaded[moduleName] = nil
    end
end

local App = require("app")
local app = App.new()
_G[SESSION_KEY] = app
app:Start()

-- Handle dependency updates defensively if the host supplies them
function PluginDependencyUpdate(event)
    if event.pluginIdentifier ~= "bankcore" then return end
    if event.enabled then app:Connect() else app:Disconnect() end
end

-- Stop the session and drop its reload reference on unload
function PluginShutdown()
    app:Shutdown()
    if rawget(_G, SESSION_KEY) == app then _G[SESSION_KEY] = nil end
end
