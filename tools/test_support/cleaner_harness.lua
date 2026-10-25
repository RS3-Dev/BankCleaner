-- Load Bank Core from BANKCORE_ROOT beside the built Bank Cleaner
-- FAKE HOST: stand-in loader, components, and widgets, not the game client
-- Kept outside tests/ so tools/check.lua does not run it

local Harness = {}

-- Report whether a file exists
local function exists(path)
    local file = io.open(path, "rb")
    if file == nil then return false end
    file:close()
    return true
end

-- Read a file's text, or nil when it is missing
local function readText(path)
    local file = io.open(path, "rb")
    if file == nil then return nil end
    local text = file:read("a")
    file:close()
    return text
end

-- Find Bank Core's checkout and add its stand-in host modules
-- A checkout without the API Bank Cleaner uses is refused
function Harness.CoreRoot()
    local root = os.getenv("BANKCORE_ROOT")
    if root == nil then error("set BANKCORE_ROOT to the Bank Core checkout the tests load", 0) end
    root = string.gsub(root, "\\", "/")
    if not exists(root .. "/main.lua") then
        error("Bank Core was not found at " .. root .. "; set BANKCORE_ROOT to a bank-utilities checkout", 0)
    end
    local contract = readText(root .. "/HOST_CONTRACT.md") or ""
    for _, needed in ipairs({ "PluginDependencyUpdate(event)", "the root is a plain table", "onBankItems",
        "GetBankItems", "`{ label = text }` or `{ slots = list }`" }) do
        if not string.find(contract, needed, 1, true) then
            error("Bank Core at " .. root .. " lacks " .. needed .. " in its contract; set BANKCORE_ROOT "
                .. "to a checkout with the extension API Bank Cleaner uses", 0)
        end
    end
    -- Bank Cleaner's tools come first, then Bank Core's
    if not string.find(package.path, root .. "/?.lua", 1, true) then
        package.path = package.path .. ";" .. root .. "/?.lua"
    end
    return root
end

-- Install the stand-in host, build Bank Cleaner, and create a loader
-- separateGlobals gives each plugin its own _G
-- cloneExports injects a data copy of each export
function Harness.new(name, options)
    options = options or {}
    local coreRoot = Harness.CoreRoot()
    local bankHost = require("tools/test_support/fake_bank_host").install()
    bankHost:InstallSidebarWidgets()
    bankHost:InstallWindowWidgets()
    bankHost:InstallPanelWidgets()
    -- Quest completion read by the quest rule
    local quests = {}
    config.Quest = { FromID = function(questID) return quests[questID] end }
    -- Bank Core still listens for its own plugin panel
    for _, event in ipairs({ "GameStateChanged", "MiniMenuEntrySelected", "MiniMenuReady", "ContentLayerReady",
        "InventoryAdded", "InventoryRemoved", "InventoryUpdated" }) do
        Event[event] = { Subscribe = function() end, Unsubscribe = function() end }
    end
    local Build = require("tools/build")
    local out = "dist/test/" .. name
    local built = Build.Run({ out = out })
    local Loader = require("tools/test_support/fake_plugin_host")
    local globals = { ui = ui, id = id, Event = Event, config = config, Vector4 = Vector4,
        Mouse = Mouse, MiniMenuActionType = MiniMenuActionType,
        Player = { IsAvailable = function() return true end }, GameState = { GAME = 30 },
        log = function() end }
    local databases = {}
    local host = Loader.new(globals, { exports = { prettyui = prettyui }, databases = databases,
        separateGlobals = options.separateGlobals, cloneExports = options.cloneExports,
        recordEvents = true })
    return setmetatable({
        bankHost = bankHost,
        host = host,
        quests = quests,
        databases = databases,
        coreRoot = coreRoot,
        out = out,
        coreFolder = coreRoot,
        cleanerFolder = built.folder,
        built = built,
    }, { __index = Harness })
end

-- Load Bank Core from its source checkout
function Harness:LoadCore()
    self.core = self.host:Load("bankcore", self.coreFolder, nil, self.coreRoot)
    return self.core
end

-- Load the built Bank Cleaner folder
function Harness:LoadCleaner()
    self.cleaner = self.host:Load("bankcleaner", self.cleanerFolder)
    return self.cleaner
end

-- Return the running Bank Cleaner app
function Harness:App()
    return rawget(self.cleaner.env._G, "__bankcleaner_session")
end

-- Return the running Bank Core session
function Harness:Session()
    return rawget(self.core.env._G, "__bankcore_session")
end

-- Open the bank in View All on a mounted window
function Harness:OpenBank(width, height)
    if self.bankHost.window == nil then
        local window = self.bankHost:MountBankWindow(width or 714, height or 650)
        self.bankHost.viewport.parent = window.all
    end
    local session = self:Session()
    assert(session.layout:IsReady() and session.layout:Apply())
    session.layout.nativeViewAll = true
    return session, session.layout
end

-- Choose a Core sidebar tab as the tab rail does
function Harness:ChooseTab(ownerID, tabID)
    self:Session().layout:SetSidebarMode("__bankutils_ext_tab:" .. ownerID .. "/" .. tabID)
end

-- Run logic ticks
function Harness:Tick(count)
    for _ = 1, count or 1 do self.bankHost:Tick() end
end

return Harness
