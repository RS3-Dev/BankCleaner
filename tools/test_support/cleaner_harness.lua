-- Load the real Bank Core beside the built Bank Cleaner in Bank Core's own stand-in host, so
-- tests drive Bank Cleaner only through Bank Core's public API and what a player does.
-- Bank Core is read, never changed, from BANKCORE_ROOT, which must be set.
-- FAKE HOST: stand-in loader, components, and widgets, not the game client
-- Adapted from Bank Tags' harness. Kept outside tests/ so tools/check.lua does not count it
-- as a test program

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

-- Find Bank Core's checkout and let tests require its stand-in host modules. A checkout
-- without the API Bank Cleaner uses is refused rather than tested against
function Harness.CoreRoot()
    local root = os.getenv("BANKCORE_ROOT")
    if root == nil then error("set BANKCORE_ROOT to the Bank Core checkout the tests load", 0) end
    root = string.gsub(root, "\\", "/")
    if not exists(root .. "/plugins/bankcore/main.lua") then
        error("Bank Core was not found at " .. root .. "; set BANKCORE_ROOT to a bank-utilities checkout", 0)
    end
    local contract = readText(root .. "/HOST_CONTRACT.md") or ""
    for _, needed in ipairs({ "PluginDependencyUpdate(event)", "the root is a plain table", "onBankItems",
        "GetBankItems", "`{ label = text }` or `{ slots = list }`", "detail" }) do
        if not string.find(contract, needed, 1, true) then
            error("Bank Core at " .. root .. " lacks " .. needed .. " in its contract; set BANKCORE_ROOT "
                .. "to a checkout with the extension API Bank Cleaner uses", 0)
        end
    end
    -- Bank Cleaner's own tools come first; Bank Core's fill in what Bank Cleaner lacks
    if not string.find(package.path, root .. "/?.lua", 1, true) then
        package.path = package.path .. ";" .. root .. "/?.lua"
    end
    return root
end

-- Install the stand-in host and widgets, build Bank Cleaner into dist/test/<name>, and create
-- a loader. options.separateGlobals gives each plugin its own _G; options.cloneExports
-- injects an ordinary data clone of each export, as a host that clones exports would
function Harness.new(name, options)
    options = options or {}
    local coreRoot = Harness.CoreRoot()
    local bankHost = require("tools/test_support/fake_bank_host").install()
    bankHost:InstallSidebarWidgets()
    bankHost:InstallWindowWidgets()
    bankHost:InstallPanelWidgets()
    -- Quest completion the quest rule reads; tests mark quests finished
    local quests = {}
    config.Quest = { FromID = function(questID) return quests[questID] end }
    local contentSubscriptions = {}
    for _, event in ipairs({ "GameStateChanged", "MiniMenuEntrySelected", "MiniMenuReady",
        "InventoryAdded", "InventoryRemoved", "InventoryUpdated" }) do
        Event[event] = { Subscribe = function() end, Unsubscribe = function() end }
    end
    Event.ContentLayerReady = {
        Subscribe = function(key, action) contentSubscriptions[key] = action end,
        Unsubscribe = function(key) contentSubscriptions[key] = nil end,
    }
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
        contentSubscriptions = contentSubscriptions,
        coreRoot = coreRoot,
        out = out,
        coreFolder = coreRoot .. "/plugins/bankcore",
        cleanerFolder = built.folder,
        built = built,
    }, { __index = Harness })
end

-- Load Bank Core from its source checkout, as a plugin with its own module cache
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

-- Mount a bank window and open the bank for the running Core session in View All
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

-- Choose one of Bank Core's sidebar tabs, as clicking it in the tab rail does
function Harness:ChooseTab(ownerID, tabID)
    self:Session().layout:SetSidebarMode("__bankutils_ext_tab:" .. ownerID .. "/" .. tabID)
end

-- Run logic ticks
function Harness:Tick(count)
    for _ = 1, count or 1 do self.bankHost:Tick() end
end

-- Show the plugin's content panel, as selecting its ribbon icon does
function Harness:OpenContentPanel(event)
    local panel = ui.Layer.new(nil)
    panel:SetSize(300, 400)
    self.contentSubscriptions[event or "bankcleaner_content"]({ component = panel })
    return panel
end

-- Find a component under a parent whose text or content matches, searching depth first
function Harness.Find(parent, text)
    for _, child in ipairs(parent.children or {}) do
        if not child.destroyed and not child.hidden then
            local content = child.content or (child.text and child.text.content)
            if content == text then return child end
            local found = Harness.Find(child, text)
            if found ~= nil then return found end
        end
    end
    return nil
end

return Harness
