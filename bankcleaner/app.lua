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
local OPEN_REFUSALS = {
    not_all_items = 'Select "All Items" to view cleanup items.',
    preset_open = "Close the preset selector to view cleanup items.",
    search_active = "Clear the bank search to view cleanup items.",
    filter_active = "Clear the bank filter to view cleanup items.",
    bank_closed = "Open your bank to view cleanup items.",
    busy = "The bank is still updating. Try again.",
}

local function bankStateBlocker(state)
    if state == nil then return "stale" end
    if not state.bankOpen then return "bank_closed" end
    if state.presetOpen then return "preset_open" end
    if state.searchActive then return "search_active" end
    if state.filterActive then return "filter_active" end
    if not state.viewAll then return "not_all_items" end
end

local function refusal(reason)
    return OPEN_REFUSALS[reason] or ("Cleanup items could not be shown (" .. tostring(reason) .. ").")
end

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
        -- Keep the open page's slots fixed once its initial scan finishes
        pageFrozen = false,
        -- Column folders, a summary of their counts, and collapsed folders
        folders = nil,
        foldersSignature = nil,
        collapsed = loadCollapsed(),
        -- Mounted column rows
        sidebar = nil,
        search = "",
        status = nil,
        bankBlocked = nil,
        scanning = false,
        started = false,
        shutDown = false,
    }, App)
    -- The Cleanup column, given to Bank Core on each registration
    self.column = {
        mount = function(ctx)
            self.search = ""
            self.sidebar = Sidebar.Mount(ctx, function(group) self:ToggleFolder(group) end,
                function(categoryID) self:ChooseCategory(categoryID) end,
                function(content)
                    self.search = tostring(content or "")
                    self.pageFrozen = false
                    self:Publish()
                end)
            self.sidebar:SetStatus(self.status)
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

-- Build the chosen page, keeping its slots fixed after the initial scan
function App:SetPage(members)
    if self.pageFrozen and self:ShownCategory() ~= nil then return true end
    members = members or self.categories:Members(self.search)
    local page = Pages.Page(Categories.Definition(self.category), members[self.category],
        not self.categories:HasScanned(), self.search:match("%S") ~= nil)
    local signature = Pages.Signature(page)
    if self.publishedPage == signature then
        if self:ShownCategory() ~= nil and not self:IsBusy() then self.pageFrozen = true end
        return true
    end
    local ok, reason = self.ext:SetPage(page)
    if ok then
        self.publishedPage = signature
        if self:ShownCategory() ~= nil and not self:IsBusy() then self.pageFrozen = true end
    end
    return ok, reason
end

-- Publish unfrozen page changes and current folder counts
function App:Publish()
    if self.ext == nil then return end
    local members = self.categories:Members(self.search)
    self:SetPage(members)
    local folders = Pages.Folders(members, self:IsBusy())
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
        onClose = function()
            self.pageFrozen = false
            self:RefreshSidebar()
        end,
        onBankItems = function() self:OnBankItems() end,
        onBankClose = function() self:OnBankClose() end,
        onBankStateChanged = function(state) self:OnBankStateChanged(state) end,
    })
    if ext == nil then return false, reason end
    self.ext = ext
    self:OnBankStateChanged(ext:GetBankState())
    self:Publish()
    return true
end

-- Drop the extension, the scan, and the last bank read
function App:Disconnect()
    self:StopScan()
    local ext = self.ext
    self.ext = nil
    self.bankBlocked, self.status = nil, nil
    self.publishedPage, self.foldersSignature = nil, nil
    self.pageFrozen = false
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

-- Show a notice over the bank title without rebuilding the column.
function App:ShowStatus(text)
    self.status = text
    if self.sidebar ~= nil then self.sidebar:SetStatus(text) end
end

-- Drop our page when native controls restrict the bank; recovery waits for a click.
function App:OnBankStateChanged(state)
    if self.ext == nil then return "stale" end
    local previous = self.bankBlocked
    local blocked = bankStateBlocker(state)
    self.bankBlocked = blocked
    if blocked ~= nil then
        self:StopScan()
        if self.ext:IsOpen() then self.ext:Close() end
        self:ShowStatus(refusal(blocked))
        self:RefreshSidebar()
    elseif previous ~= nil then
        self:ShowStatus(nil)
        if self:IsWatching() then self:ReadBank() end
    end
    return blocked
end

-- Show a category's page from its row, or close it when shown
-- A refused page selects no row
function App:ChooseCategory(categoryID)
    local ext = self.ext
    if ext == nil then return end
    local blocked = self:OnBankStateChanged(ext:GetBankState())
    if blocked ~= nil then return false end
    if categoryID == self:ShownCategory() then
        ext:Close()
        self:ShowStatus(nil)
    else
        local previous = self.category
        self.pageFrozen = false
        self.category = categoryID
        local shown, reason = self:SetPage()
        if shown then
            shown, reason = ext:Open()
            if shown then self.pageFrozen = not self:IsBusy() end
        else
            self.category = previous
        end
        if not shown and ext:IsOpen() then ext:Close() end
        self:ShowStatus(not shown and refusal(reason) or nil)
        self:RefreshSidebar()
        return shown
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
    if self:OnBankStateChanged(self.ext:GetBankState()) ~= nil then return end
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
    if self.ext ~= nil and self.bankBlocked == nil and self:IsWatching() and self.categories:IsScanning() then
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
