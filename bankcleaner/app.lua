-- Show Bank Cleaner's pages and Cleanup tab through Bank Core's API

local Categories = require("bankcleaner/cleanup/categories")
local Pages = require("bankcleaner/cleanup/pages")
local Sidebar = require("bankcleaner/cleanup/sidebar")

local App = {}
App.__index = App

local OWNER_ID = "bankcleaner"
local OWNER_LABEL = "Bank Cleaner"
local CORE_API_KEY = "__bankcore_api"
local SCAN_EVENT = "bankcleaner_scan"
-- Where the collapsed folders are saved: { collapsed = { group, ... } }
local FOLDERS_KEY = "bankcleaner_folders"
-- Not-ready reasons that mean the bank is not open at all
local CLOSED = { stale_api = true, not_ready = true, bank_closed = true }
-- Reasons Bank Core gives for a page it cannot show, rather than for the bank's view
local PAGE_REFUSALS = { invalid_page = true, unknown_item = true, duplicate_slot = true, too_large = true }
local NEEDS_NEWER_CORE = "Bank Cleaner needs a newer Bank Core. Update Bank Core to review your bank."

-- Find Bank Core's API, injected first, then published
local function findBank()
    -- Either may be nil, so loop by index instead of ipairs
    local candidates = { bankcore, rawget(_G, CORE_API_KEY) }
    for index = 1, 2 do
        local candidate = candidates[index]
        if type(candidate) == "table" and type(candidate.RegisterExtension) == "function"
            and type(candidate.GetState) == "function" and candidate.GetState().running then
            return candidate
        end
    end
    return nil
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
        -- Bank Core's API and this plugin's owner handle
        bank = nil,
        handle = nil,
        -- Whether the Cleanup tab is in view
        tabActive = false,
        -- The category the player chose, and the one Bank Core reports shown
        category = Categories.DEFINITIONS[1].id,
        shownCategory = nil,
        -- A summary of the key and layout last shown
        publishedPage = nil,
        -- Tab folders, a summary of their counts, and collapsed folders
        folders = nil,
        foldersSignature = nil,
        collapsed = loadCollapsed(),
        -- Mounted tab rows
        sidebar = nil,
        scanning = false,
        retired = false,
        started = false,
        shutDown = false,
    }, App)
    -- Kept for the app's life so mounted rows are never replaced
    self.mount = {
        mount = function(ctx)
            self.sidebar = Sidebar.Mount(ctx, function(group) self:ToggleFolder(group) end,
                function(categoryID) self:ChooseCategory(ctx, categoryID) end)
            self:RefreshSidebar()
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

-- Report whether this plugin is registered with Bank Core
function App:IsConnected()
    return self.handle ~= nil and self.handle:GetState().live == true
end

-- Report whether counts may still change
function App:IsBusy()
    return not self.categories:HasSnapshot() or self.categories:IsScanning()
end

-- Describe the chosen category's page and a summary of it
-- An empty page says scanning only until the first scan ends
function App:CategoryPage()
    local page = Pages.Page(Categories.Definition(self.category), self.categories:Members()[self.category],
        not self.categories:HasScanned())
    return page, page.key .. "\n" .. Pages.Signature(page.layout)
end

-- Show the chosen category's page in the bank, or explain why not
function App:ShowCategory(ctx)
    local page, signature = self:CategoryPage()
    local shown, reason = ctx:CreatePage(page)
    if shown then self.publishedPage = signature end
    return shown, reason
end

-- Redraw the shown category if it changed, and the tab's folders if their counts did
-- The page is drawn only while Bank Core still shows Bank Cleaner's page, so a scan never
-- takes the bank from another plugin or the native view
function App:Publish()
    local handle = self.handle
    if handle == nil then return end
    if handle:GetState().pageVisible then
        local page, signature = self:CategoryPage()
        if self.publishedPage ~= signature and handle:CreatePage(page) then self.publishedPage = signature end
    end
    local folders = Pages.Folders(self.categories:Members(), self:IsBusy())
    local signature = Pages.FoldersSignature(folders)
    local changed = self.foldersSignature ~= signature
    self.folders, self.foldersSignature = folders, signature
    if changed then self:RefreshSidebar() end
end

-- Register the Cleanup tab and listener
function App:Connect()
    if self.shutDown then return false, "stopped" end
    if self:IsConnected() then return true end
    -- A newer Bank Cleaner load owns the ID now, so leave it
    if self.handle ~= nil and self.bank.GetState().running then
        self.handle, self.bank, self.retired = nil, nil, true
        self:Disconnect()
    end
    if self.retired then return false, "replaced" end
    self:Disconnect()
    local api = findBank()
    if api == nil then return false, "unavailable" end
    local handle, reason = api.RegisterExtension(OWNER_ID, OWNER_LABEL)
    if handle == nil then return false, reason end
    -- An older Bank Core shows pages another way, so it needs updating first
    if type(handle.CreatePage) ~= "function" then
        handle:Dispose()
        log(NEEDS_NEWER_CORE)
        return false, "bankcore_outdated"
    end
    self.bank, self.handle = api, handle
    -- The tab's rows need the folders before it mounts
    self:Publish()
    local ok = handle:RegisterTab(Pages.TAB_ID, Pages.Tab(self.mount))
    if ok then
        ok = handle:SetListener({
            onState = function(state) self:OnState(state) end,
            onPage = function(visible, key) self:OnPage(visible, key) end,
            onBankItems = function() self:OnBankItems() end,
        })
    end
    if not ok then
        self:Disconnect()
        return false, "refused"
    end
    return true
end

-- Drop the owner handle, the scan, and the last bank read
function App:Disconnect()
    self:StopScan()
    local handle = self.handle
    self.handle, self.bank = nil, nil
    self.tabActive, self.shownCategory, self.publishedPage, self.foldersSignature = false, nil, nil, nil
    self.categories:Clear()
    if handle ~= nil then pcall(function() handle:Dispose() end) end
end

-- Report whether the Cleanup tab or a category is shown
function App:IsWatching()
    return self.tabActive or self.shownCategory ~= nil
end

-- Track the bank, rereading quest progress when Cleanup opens
function App:OnState(state)
    local open = state.running and not CLOSED[state.reason]
    local tabActive = open and state.activeTab == Pages.TAB_ID
    local activated = tabActive and not self.tabActive
    self.tabActive = tabActive
    if not open then
        self.shownCategory = nil
        self:StopScan()
        self.categories:Clear()
        self:Publish()
        return
    end
    if activated then
        self.categories:Forget()
        self:ReadBank()
    end
    self:Follow()
end

-- Track the shown category from the page key, reading the bank on open
function App:OnPage(visible, key)
    local watching, shown = self:IsWatching(), self.shownCategory
    self.shownCategory = visible and Pages.CategoryOf(key) or nil
    if not watching and self:IsWatching() then self:ReadBank() end
    if shown ~= self.shownCategory then self:RefreshSidebar() end
    self:Follow()
end

-- Redraw the mounted tab's rows
function App:RefreshSidebar()
    if self.sidebar == nil or self.folders == nil then return end
    self.sidebar:SetEntries(Sidebar.Entries(self.folders, self.collapsed, self.shownCategory))
end

-- Show a category's page from its row, or leave it when shown
-- Rows are redrawn so a refused page leaves no selection
function App:ChooseCategory(ctx, categoryID)
    if categoryID == self.shownCategory then
        ctx:LeavePage()
    else
        local previous = self.category
        self.category = categoryID
        local shown, reason = self:ShowCategory(ctx)
        if not shown and PAGE_REFUSALS[reason] then
            self.category = previous
        elseif not shown and reason == "not_all_items" then
            self.handle:ShowWarning('Select "All Items" to review these items.')
        elseif not shown and reason == "preset_open" then
            self.handle:ShowWarning('Close the preset selector to review these items.')
        end
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

-- Read and show the bank, keeping the last items while Core builds
function App:ReadBank()
    if self.handle == nil then return end
    local snapshot, reason = self.handle:GetBankItems()
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
    if self.handle ~= nil and self:IsWatching() and self.categories:IsScanning() then
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
        if self.handle == nil or not self:IsWatching() then
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
