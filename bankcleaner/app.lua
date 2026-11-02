-- Show Bank Cleaner's pages and Cleanup column through Bank Core's API

local Categories = require("bankcleaner/cleanup/categories")
local Pages = require("bankcleaner/cleanup/pages")
local Sidebar = require("bankcleaner/cleanup/sidebar")

local App = {}
App.__index = App

local EXTENSION_ID = "bankcleaner"
local EXTENSION_NAME = "Bank Cleaner"
local ICON = "ERASER"
local CORE_API_KEY = "__bankcore_api"
local SCAN_EVENT = "bankcleaner_scan"
-- Where the collapsed folders are saved: { collapsed = { group, ... } }
local FOLDERS_KEY = "bankcleaner_folders"

-- Read which folders the player collapsed, keeping only groups that still exist
local function loadCollapsed()
    local collapsed = {}
    local ok, saved = pcall(function() return PersistentDB:GetStructuredData(FOLDERS_KEY) end)
    if not ok or type(saved) ~= "table" or type(saved.collapsed) ~= "table" then return collapsed end
    for _, group in ipairs(Categories.GROUPS) do
        for _, name in ipairs(saved.collapsed) do
            if name == group then collapsed[group] = true end
        end
    end
    return collapsed
end

-- Create the app before it connects or subscribes
function App.new()
    local self = setmetatable({
        categories = Categories.new(),
        -- This plugin's Bank Core extension
        ext = nil,
        -- The category the player chose, whose page was last set
        category = Categories.DEFINITIONS[1].id,
        -- A summary of the page last set
        publishedPage = nil,
        -- Column folders, a summary of their counts, and collapsed folders
        folders = nil,
        foldersSignature = nil,
        collapsed = loadCollapsed(),
        -- Mounted column rows
        sidebar = nil,
        scanning = false,
        started = false,
        shutDown = false,
    }, App)
    -- The Cleanup column, given to Bank Core on each registration
    self.column = {
        mount = function(ctx)
            self.sidebar = Sidebar.Mount(ctx, function(group) self:ToggleFolder(group) end,
                function(categoryID) self:ChooseCategory(categoryID) end)
            -- Opening Cleanup rereads quest progress; the rows are drawn once the bank is read
            self.categories:Forget()
            self.foldersSignature = nil
            self:ReadBank()
        end,
        resize = function()
            if self.sidebar ~= nil then self.sidebar:Resize() end
        end,
        unmount = function()
            local sidebar = self.sidebar
            self.sidebar = nil
            if sidebar ~= nil then sidebar:Destroy() end
        end,
    }
    return self
end

-- Connect to Bank Core if it runs
function App:Start()
    if self.shutDown or self.started then return end
    self.started = true
    self:Connect()
end

-- Report whether counts may still change
function App:IsBusy()
    return not self.categories:HasSnapshot() or self.categories:IsScanning()
end

-- Find the category Bank Core shows, or nil
function App:ShownCategory()
    return self.ext ~= nil and self.ext:IsOpen() and self.category or nil
end

-- Give Bank Core the chosen category's page if it changed
-- Core redraws it in place while it is shown, and otherwise keeps it until opened
-- An empty page says scanning only until the first scan ends
function App:SetPage()
    local page = Pages.Page(Categories.Definition(self.category), self.categories:Members()[self.category],
        not self.categories:HasScanned())
    local signature = Pages.Signature(page)
    if self.publishedPage == signature then return true end
    local ok = self.ext:SetPage(page)
    if ok then self.publishedPage = signature end
    return ok
end

-- Set the chosen category's page, and redraw the folders if their counts changed
function App:Publish()
    if self.ext == nil then return end
    self:SetPage()
    local folders = Pages.Folders(self.categories:Members(), self:IsBusy())
    local signature = Pages.FoldersSignature(folders)
    local changed = self.foldersSignature ~= signature
    self.folders, self.foldersSignature = folders, signature
    if changed then self:RefreshSidebar() end
end

-- Register the Cleanup icon, column, and callbacks, replacing an earlier registration
function App:Connect()
    if self.shutDown then return false, "stopped" end
    self:Disconnect()
    local api = bankcore or rawget(_G, CORE_API_KEY)
    if api == nil then return false, "unavailable" end
    local ext, reason = api.Register({
        id = EXTENSION_ID,
        name = EXTENSION_NAME,
        icon = ICON,
        column = self.column,
        onClose = function() self:RefreshSidebar() end,
        onBankItems = function() self:OnBankItems() end,
        onBankClose = function() self:OnBankClose() end,
    })
    if ext == nil then return false, reason end
    self.ext = ext
    self:Publish()
    return true
end

-- Drop the extension, the scan, and the last bank read
function App:Disconnect()
    self:StopScan()
    local ext = self.ext
    self.ext = nil
    self.publishedPage, self.foldersSignature = nil, nil
    self.categories:Clear()
    if ext ~= nil then ext:Dispose() end
end

-- Report whether the Cleanup column or a category is shown
function App:IsWatching()
    return self.sidebar ~= nil or self:ShownCategory() ~= nil
end

-- Redraw the mounted column's rows
function App:RefreshSidebar()
    if self.sidebar == nil or self.folders == nil then return end
    self.sidebar:SetEntries(Sidebar.Entries(self.folders, self.collapsed, self:ShownCategory()))
end

-- Show a category's page from its row, or close it when shown
-- A refused page selects no row
function App:ChooseCategory(categoryID)
    local ext = self.ext
    if ext == nil then return end
    if categoryID == self:ShownCategory() then
        ext:Close()
    else
        local previous = self.category
        self.category = categoryID
        if self:SetPage() then ext:Open() else self.category = previous end
    end
    self:RefreshSidebar()
end

-- Toggle a folder and save the collapsed folders
-- A refused save leaves the folder as shown until Bank Cleaner reloads
function App:ToggleFolder(group)
    self.collapsed[group] = not self.collapsed[group] or nil
    local collapsed = {}
    for _, name in ipairs(Categories.GROUPS) do
        if self.collapsed[name] then collapsed[#collapsed + 1] = name end
    end
    pcall(function() PersistentDB:SetStructuredData(FOLDERS_KEY, { collapsed = collapsed }) end)
    self:RefreshSidebar()
end

-- Reread the bank after it changes, if the categories are in view
function App:OnBankItems()
    if self:IsWatching() then self:ReadBank() end
end

-- Drop the last bank read when the bank closes
function App:OnBankClose()
    self:StopScan()
    self.categories:Clear()
    self:Publish()
end

-- Read and show the bank, keeping the last items outside All Items or while Core is busy
function App:ReadBank()
    if self.ext == nil then return end
    local snapshot, reason = self.ext:GetBankItems()
    if snapshot ~= nil then
        self.categories:Observe(snapshot)
    elseif reason == "bank_closed" then
        self.categories:Clear()
    end
    self:Publish()
    self:Follow()
end

-- Keep scanning while items are left and the categories are in view
function App:Follow()
    if self.ext ~= nil and self:IsWatching() and self.categories:IsScanning() then
        self:StartScan()
    else
        self:StopScan()
    end
end

-- Classify a batch each tick, then send the results
function App:StartScan()
    if self.scanning then return end
    self.scanning = true
    Event.Logic.Subscribe(SCAN_EVENT, function()
        if self.ext == nil or not self:IsWatching() then
            self:StopScan()
            return
        end
        if not self.categories:Step(Categories.BATCH) then return end
        self:StopScan()
        self:Publish()
    end)
end

-- Stop the scan listener; unclassified items wait for the next scan
function App:StopScan()
    if not self.scanning then return end
    self.scanning = false
    Event.Logic.Unsubscribe(SCAN_EVENT)
end

-- Release the scan and Bank Core registration
function App:Shutdown()
    if self.shutDown then return end
    self.shutDown = true
    pcall(function() self:Disconnect() end)
end

return App
