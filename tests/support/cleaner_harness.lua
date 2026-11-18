-- Load BANKCORE_ROOT beside Bank Cleaner using a fake game host

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
        error("Bank Core was not found at " .. root .. "; set BANKCORE_ROOT to a Bank Core checkout", 0)
    end
    local spec = readText(root .. "/docs/API.md") or ""
    for _, needed in ipairs({ "bankcore.Register(spec)", "ext:GetBankState()",
        "onBankStateChanged(state)", "`filterActive`" }) do
        if not string.find(spec, needed, 1, true) then
            error("Bank Core at " .. root .. " lacks " .. needed .. "; set BANKCORE_ROOT "
                .. "to a Core 1.5.0 or later checkout", 0)
        end
    end
    -- Resolve local test modules before Bank Core's helpers
    if not string.find(package.path, root .. "/?.lua", 1, true) then
        package.path = package.path .. ";" .. root .. "/?.lua"
    end
    return root
end

-- Create the test host and load Cleaner directly from the repository
-- separateGlobals isolates each plugin's _G; cloneExports copies injected exports
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
    local folder = "."
    local Loader = require("tools/test_support/fake_plugin_host")
    -- Core's older stand-in reads the legacy dependencies field only.
    local cleanerManifest = Loader.ReadManifest(folder)
    local Json = require("tools/json")
    local declared = Json.decode(assert(readText(folder .. "/plugin.json")))
    for dependency in pairs(declared.requiredDependencies or {}) do
        cleanerManifest.dependencies[dependency] = true
    end
    -- Exercise the defensive update handler separately from required load order.
    if options.optionalCore then
        cleanerManifest.dependencies.bankcore = nil
        cleanerManifest.optional.bankcore = true
    end
    local catalogIDs = require("tests/support/catalog_ids")
    id.Obj, id.Quest = catalogIDs.Obj, catalogIDs.Quest
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
        coreFolder = coreRoot,
        cleanerFolder = folder,
        cleanerManifest = cleanerManifest,
    }, { __index = Harness })
end

-- Load Bank Core from its source checkout
function Harness:LoadCore()
    self.core = self.host:Load("bankcore", self.coreFolder, nil, self.coreRoot)
    return self.core
end

-- Load Bank Cleaner from the repository root
function Harness:LoadCleaner()
    for dependency in pairs(self.cleanerManifest.dependencies) do
        assert(self.host.exports[dependency] ~= nil, "missing required dependency: " .. dependency)
    end
    self.cleaner = self.host:Load("bankcleaner", self.cleanerFolder, self.cleanerManifest)
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

-- Click an extension's rail icon as the tab rail does
function Harness:ChooseIcon(extensionID)
    self:Session().layout:SetSidebarMode("__bankutils_ext_tab:" .. extensionID)
end

-- Run logic ticks
function Harness:Tick(count)
    for _ = 1, count or 1 do self.bankHost:Tick() end
end

return Harness
