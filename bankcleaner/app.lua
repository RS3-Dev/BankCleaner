-- Compose Bank Cleaner: the cleanup categories, their pages and tab, the scan that classifies
-- new objects, and the connection to Bank Core's public API. Through that API Bank Cleaner
-- registers one page per category, the Cleanup tab of rows that open them, and a listener;
-- it reads the bank only through Bank Core's state and item snapshots

local Categories = require("bankcleaner/cleanup/categories")
local Pages = require("bankcleaner/cleanup/pages")

local App = {}
App.__index = App

local OWNER_ID = "bankcleaner"
local OWNER_LABEL = "Bank Cleaner"
local CORE_API_KEY = "__bankcore_api"
local SCAN_EVENT = "bankcleaner_scan"
local CONTENT_EVENT = "bankcleaner_content"
local NOT_CONNECTED = "Bank Cleaner needs Bank Core. Enable Bank Core to see cleanup pages in your bank."
local CONNECTED = "Bank Cleaner is in your bank: open the bank and choose the Cleanup tab in the sidebar."
local REPLACED = "A newer copy of Bank Cleaner took over; this copy is idle."
-- Readiness reasons that mean the bank is not open at all
local CLOSED = { stale_api = true, not_ready = true, bank_closed = true }

-- Find a running Bank Core API: the injected dependency first, the published copy second
local function findBank()
    -- Either may be missing, so both are checked by position rather than with ipairs
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

-- Create the categories, connected to nothing and subscribed to nothing
function App.new()
    return setmetatable({
        categories = Categories.new(),
        -- Bank Core's API table and this plugin's owner handle while connected
        bank = nil,
        handle = nil,
        -- Whether the bank is open with the Cleanup tab chosen, and which page is shown
        tabActive = false,
        shownPage = nil,
        -- What Bank Core was last given: each page's layout and the tab's rows, as signatures
        published = {},
        tabSignature = nil,
        scanning = false,
        -- Why Bank Core refused the tab or a page, shown on the plugin panel
        failure = nil,
        panel = nil,
        retired = false,
        started = false,
        shutDown = false,
    }, App)
end

-- Subscribe to this plugin's panel and connect to Bank Core if it runs
function App:Start()
    if self.shutDown or self.started then return end
    self.started = true
    Event.ContentLayerReady.Subscribe(CONTENT_EVENT, function(event) self:CreatePanel(event.component) end)
    self:Connect()
end

-- Report whether this plugin's owner is registered with a running Bank Core
function App:IsConnected()
    return self.handle ~= nil and self.handle:GetState().live == true
end

-- Report whether counts may still change: no bank read yet, or objects to classify
function App:IsBusy()
    return not self.categories:HasSnapshot() or self.categories:IsScanning()
end

-- Give Bank Core every page whose layout changed and the tab when a count changed. With
-- register set, every page and the tab are registered rather than updated. Empty pages say
-- the bank is being scanned only until the first scan finishes, so a new object does not
-- change every empty page
function App:Publish(register)
    local handle = self.handle
    if handle == nil then return true end
    local members, busy = self.categories:Members(), self:IsBusy()
    local firstScan = not self.categories:HasScanned()
    for _, definition in ipairs(Categories.DEFINITIONS) do
        local page = Pages.Page(definition, members[definition.id], firstScan)
        local signature = Pages.Signature(page.layout)
        if register or self.published[definition.id] ~= signature then
            local ok, reason
            if register then
                ok, reason = handle:RegisterPage(definition.id, page)
            else
                ok, reason = handle:UpdatePage(definition.id, page)
            end
            if not ok then
                self:Fail(definition.label .. " page", reason)
                return false
            end
            self.published[definition.id] = signature
        end
    end
    local tab = Pages.Tab(members, busy)
    local signature = Pages.TabSignature(tab)
    if register or self.tabSignature ~= signature then
        local ok, reason
        if register then
            ok, reason = handle:RegisterTab(Pages.TAB_ID, tab)
        else
            ok, reason = handle:UpdateTab(Pages.TAB_ID, tab)
        end
        if not ok then
            self:Fail("Cleanup tab", reason)
            return false
        end
        self.tabSignature = signature
    end
    return true
end

-- Record why Bank Core refused a registration and show it on the plugin panel
function App:Fail(what, reason)
    self.failure = "Bank Core refused the " .. what .. " (" .. tostring(reason) .. ")."
    self:UpdatePanelNotice()
end

-- Register the pages, the Cleanup tab, and the listener with the running Bank Core
function App:Connect()
    if self.shutDown then return false, "stopped" end
    if self:IsConnected() then return true end
    -- A newer load of Bank Cleaner took the owner ID; taking it back would undo that
    if self.handle ~= nil and self.bank.GetState().running then
        self.handle, self.bank, self.retired = nil, nil, true
        self:Disconnect()
    end
    if self.retired then return false, "replaced" end
    self:Disconnect()
    local api = findBank()
    if api == nil then return false, "unavailable" end
    local handle, reason = api.RegisterExtension(OWNER_ID, OWNER_LABEL)
    if handle == nil then
        self:Fail("registration", reason)
        return false, reason
    end
    self.bank, self.handle, self.failure = api, handle, nil
    local ok = self:Publish(true)
    if ok then
        local listening, failure = handle:SetListener({
            onState = function(state) self:OnState(state) end,
            onPage = function(pageID) self:OnPage(pageID) end,
            onBankItems = function() self:OnBankItems() end,
        })
        if not listening then self:Fail("listener", failure) end
        ok = listening
    end
    if not ok then
        local failure = self.failure
        self:Disconnect()
        self.failure = failure
        self:UpdatePanelNotice()
        return false, "refused"
    end
    self:UpdatePanelNotice()
    return true
end

-- Drop the owner handle, the scan, and the bank snapshot
function App:Disconnect()
    self:StopScan()
    local handle = self.handle
    self.handle, self.bank = nil, nil
    self.tabActive, self.shownPage, self.published, self.tabSignature = false, nil, {}, nil
    self.categories:Clear()
    if handle ~= nil then pcall(function() handle:Dispose() end) end
    self:UpdatePanelNotice()
end

-- Report whether the bank is open and the Cleanup tab or one of its pages is in view
function App:IsWatching()
    return self.tabActive or self.shownPage ~= nil
end

-- Follow the bank: a closed bank drops its snapshot, and choosing the Cleanup tab with the
-- bank open forgets every classification, so quest progress is read again
function App:OnState(state)
    local open = state.running and not CLOSED[state.reason]
    local tabActive = open and state.activeTab == Pages.TAB_ID
    local activated = tabActive and not self.tabActive
    self.tabActive = tabActive
    if not open then
        self.shownPage = nil
        self:StopScan()
        self.categories:Clear()
        self:Publish(false)
        return
    end
    if activated then
        self.categories:Forget()
        self:ReadBank()
    end
    self:Follow()
end

-- Remember which of the categories' pages is shown, reading the bank when one opens
function App:OnPage(pageID)
    local watching = self:IsWatching()
    self.shownPage = pageID
    if not watching and self:IsWatching() then self:ReadBank() end
    self:Follow()
end

-- Read a new bank generation while the categories are in view; otherwise it is read when
-- they come into view
function App:OnBankItems()
    if self:IsWatching() then self:ReadBank() end
end

-- Read the bank's items and show them. While Bank Core is still building, the last snapshot
-- stays; a closed bank drops it
function App:ReadBank()
    if self.handle == nil then return end
    local snapshot, reason = self.handle:GetBankItems()
    if snapshot ~= nil then
        self.categories:Observe(snapshot)
    elseif reason == "bank_closed" then
        self.categories:Clear()
    end
    self:Publish(false)
    self:Follow()
end

-- Run the scan while objects wait to be classified and the categories are in view
function App:Follow()
    if self.handle ~= nil and self:IsWatching() and self.categories:IsScanning() then
        self:StartScan()
    else
        self:StopScan()
    end
end

-- Classify a batch of new objects each logic tick, publishing once the batch run finishes
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
        self:Publish(false)
    end)
end

-- Stop the scan listener; unclassified objects wait for the next one
function App:StopScan()
    if not self.scanning then return end
    self.scanning = false
    Event.Logic.Unsubscribe(SCAN_EVENT)
end

-- Say whether Bank Cleaner is in the bank, or why not
function App:PanelNotice()
    if self.failure ~= nil then return self.failure end
    if self:IsConnected() then return CONNECTED end
    return self.retired and REPLACED or NOT_CONNECTED
end

-- Show the current notice on an open plugin panel
function App:UpdatePanelNotice()
    if self.panel ~= nil then self.panel.content = self:PanelNotice() end
end

-- Show the notice on this plugin's own panel, connecting first if Bank Core started
function App:CreatePanel(parent)
    if self.shutDown then return end
    self:Connect()
    self:DestroyPanel()
    self.panel = prettyui.Text.new(parent, {
        text = self:PanelNotice(), x = 12, y = 12, width = math.max(1, (parent.width or 300) - 24),
        height = 80, font = id.Font.MUSEO_SANS_11PT_REGULAR, colour = 0xD7C9ADFF, maxLines = 4,
    })
end

-- Release the panel's text
function App:DestroyPanel()
    local panel = self.panel
    self.panel = nil
    if panel ~= nil then pcall(function() panel:Destroy() end) end
end

-- Stop Bank Cleaner: release its panel, scan, and Bank Core registration
function App:Shutdown()
    if self.shutDown then return end
    self.shutDown = true
    if self.started then Event.ContentLayerReady.Unsubscribe(CONTENT_EVENT) end
    pcall(function() self:DestroyPanel() end)
    pcall(function() self:Disconnect() end)
end

return App
