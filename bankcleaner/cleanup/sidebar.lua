-- Draw the Cleanup column's folder and category rows

local Icons = require("bankcleaner/data/sidebar_icons")

local Sidebar = {}
Sidebar.__index = Sidebar

local CONTENT_X = 8
local FIELD_TOP = 8
local FIELD_HEIGHT = 26
local LIST_TOP = FIELD_TOP + FIELD_HEIGHT + 6
local LIST_BOTTOM = 8
local ENTRY_HEIGHT = 32
local ROW_HEIGHT = 30
local ROW_LEFT = 6
local ICON_SIZE = 24
local ICON_GAP = 4
local FOLDER_LABEL_LEFT = 26
local CHEVRON_RIGHT = 8
local CHEVRON_SIZE = 14
local ACCENT_WIDTH = 2
local COUNT_WIDTH = 42
local FOLDER_PREFIX = "folder:"
-- Bank Tags' theme: gold headings over a warm folder row, categories on warmer stripes
local HEADING_TEXT = 0xE7C878FF
local HEADING_LINE = 0x756C60FF
local ROW_TEXT = 0xE7D7B0FF
local COUNT_TEXT = 0xAFA58FFF
local INNER_FRAME = 0x806432FF
local SELECTED_BORDER = 0xD2A84DFF
local ROW_HOVER = 0x403728FF
local ROW_SELECTED = 0x49371FFF
local FOLDER_ROW = 0x3B352DFF
local FOLDER_ROW_ODD = 0x27231DFF
local FOLDER_ROW_EVEN = 0x2D2823FF

-- Return the group behind a folder row's ID, or nil for a category row
function Sidebar.FolderOf(entryID)
    entryID = tostring(entryID or "")
    if string.sub(entryID, 1, #FOLDER_PREFIX) ~= FOLDER_PREFIX then return nil end
    return string.sub(entryID, #FOLDER_PREFIX + 1)
end

-- List each folder and, while open, its categories with counts
-- A collapsed folder holding the shown category gets the outline
function Sidebar.Entries(folders, collapsed, shownCategory)
    local entries = {}
    for _, folder in ipairs(folders) do
        local expanded = not collapsed[folder.label]
        local holdsShown = false
        for _, category in ipairs(folder.categories) do
            if category.id == shownCategory then holdsShown = true end
        end
        entries[#entries + 1] = { id = FOLDER_PREFIX .. folder.label,
            objectID = Icons.folders[folder.label],
            label = folder.label .. " (" .. folder.detail .. ")", enabled = true,
            expanded = expanded, selected = holdsShown and not expanded,
            backgroundColour = FOLDER_ROW, hoverColour = ROW_HOVER, selectedColour = ROW_SELECTED,
            textColour = HEADING_TEXT }
        if expanded then
            for index, category in ipairs(folder.categories) do
                entries[#entries + 1] = { id = category.id, label = category.label,
                    objectID = Icons.categories[category.id],
                    detail = category.detail, enabled = true, selected = category.id == shownCategory,
                    backgroundColour = index % 2 == 1 and FOLDER_ROW_ODD or FOLDER_ROW_EVEN,
                    hoverColour = ROW_HOVER, selectedColour = ROW_SELECTED, textColour = ROW_TEXT }
            end
        end
    end
    return entries
end

-- Create the row list in the mounted column's parent
function Sidebar.Mount(ctx, onFolder, onCategory, onSearch)
    local self = setmetatable({ ctx = ctx, entries = {}, entriesByID = {} }, Sidebar)
    local width, height = Sidebar.ListSize(ctx)
    self.search = prettyui.TextField.new(ctx.parent, {
        x = CONTENT_X, y = FIELD_TOP, width = width, height = FIELD_HEIGHT,
        placeholder = "Search cleanup items...", text = "", maxLength = 200,
        onChange = function(_, _, content) onSearch(content) end,
    })
    self.list = prettyui.List.new(ctx.parent, {
        x = CONTENT_X, y = LIST_TOP, width = width, height = height, entryHeight = ENTRY_HEIGHT,
        maxSelected = 1, backgroundColour = 0x00000000, borderColour = INNER_FRAME,
        selectedColour = 0x5A4526FF,
        _onEntryClick = function(_, entryID)
            local group = Sidebar.FolderOf(entryID)
            if group ~= nil then onFolder(group) else onCategory(entryID) end
        end,
    })
    return self
end

-- Size the list to the mounted column
function Sidebar.ListSize(ctx)
    return math.max(1, ctx.width - CONTENT_X * 2), math.max(1, ctx.height - LIST_TOP - LIST_BOTTOM)
end

-- Fit the list to the column's new size
function Sidebar:Resize()
    local width = Sidebar.ListSize(self.ctx)
    self.search.root:SetSize(width, FIELD_HEIGHT)
    self.list:SetSize(Sidebar.ListSize(self.ctx))
end

-- Show new rows
function Sidebar:SetEntries(entries)
    self.entries, self.entriesByID = entries, {}
    for _, entry in ipairs(entries) do self.entriesByID[entry.id] = entry end
    self.list:SetEntries(entries)
    self:DecorateRows()
end

-- Add a left bar that runs a folder's length
local function addAccent(root, height)
    local accent = ui.Rectangle.new(root)
    accent:SetPos(0, 0)
    accent:SetSize(ACCENT_WIDTH, height)
    accent.fill = true
    accent.rgba = HEADING_LINE
    accent.clickthrough = true
    accent:MoveToFront()
end

-- Outline a selected row with the native gold frame
local function addSelectedFrame(root)
    local frame = ui.Rectangle.new(root)
    frame:SetSize(0, ROW_HEIGHT, 1.0, 0)
    frame.fill = false
    frame.outlineThickness = 1
    frame.rgba = SELECTED_BORDER
    frame.clickthrough = true
    frame:MoveToFront()
end

-- Rotate a sprite using the host's rotation variants
local function rotate(sprite, radians, degrees)
    if sprite.SetRotation ~= nil then pcall(function() sprite:SetRotation(radians) end) end
    pcall(function() sprite.rotation = radians end)
    pcall(function() sprite.angle = radians end)
    pcall(function() sprite.rotationDegrees = degrees end)
    pcall(function() sprite.angleDegrees = degrees end)
end

-- Draw item icons with Bank Tags' size and spacing
local function addRowIcon(row, objectID, left)
    local icon = ui.Sprite.new(row.root)
    icon:SetPos(left, 3)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetAssociatedObject(objectID)
    icon.associatedObjectQuantityMode = ui.ObjectQuantityDisplayMode.NEVER
    icon.clickthrough = true
    icon:MoveToFront()
end

-- Add chevrons, accents, indents, counts, and selection frames
function Sidebar:DecorateRows()
    local rows = self.list.rows or {}
    for index, row in ipairs(rows) do
        -- PrettyUI may copy only known entry fields into its rows
        local entry = self.entriesByID[row.entry.id] or row.entry
        -- The accent joins up with the next row in the same folder
        local nextRow = rows[index + 1]
        local accentHeight = nextRow ~= nil and Sidebar.FolderOf(nextRow.entry.id) == nil
            and ENTRY_HEIGHT or ROW_HEIGHT
        row.background:SetSize(0, ROW_HEIGHT, 1.0, 0)
        row.label.font = id.Font.MUSEO_SANS_11PT_REGULAR
        row.root.opConfig:ClearOpCursors()
        row.root.cursorConfig.mouseOverCursor = -1
        if Sidebar.FolderOf(entry.id) ~= nil then
            local chevronLeft = -CHEVRON_RIGHT - CHEVRON_SIZE
            local labelLeft = ROW_LEFT + ICON_SIZE + ICON_GAP
            addRowIcon(row, entry.objectID, ROW_LEFT)
            row.label.rgba = HEADING_TEXT
            row.label:SetPos(labelLeft, 0)
            row.label:SetSize(chevronLeft - labelLeft - 4, ROW_HEIGHT, 1.0, 0)
            -- The arrow faces up and turns anticlockwise
            -- A half turn points down for open, three quarters right
            local chevron = ui.Sprite.new(row.root)
            chevron:SetPos(chevronLeft, math.floor((ROW_HEIGHT - CHEVRON_SIZE) / 2), 1.0, 0)
            chevron:SetSize(CHEVRON_SIZE, CHEVRON_SIZE)
            chevron.spriteID = id.Sprite.BANK_ARROW_UP_0
            if entry.expanded then rotate(chevron, math.pi, 180) else rotate(chevron, math.pi * 1.5, 270) end
            chevron.clickthrough = true
            chevron:MoveToFront()
            addAccent(row.root, accentHeight)
        else
            -- Folder members have the same icon and text indent as Bank Tags
            local labelLeft = FOLDER_LABEL_LEFT + ICON_SIZE + ICON_GAP
            addRowIcon(row, entry.objectID, FOLDER_LABEL_LEFT)
            row.label:SetPos(labelLeft, 0)
            row.label:SetSize(-labelLeft - COUNT_WIDTH - 12, ROW_HEIGHT, 1.0, 0)
            local count = ui.Text.new(row.root)
            count:SetPos(-COUNT_WIDTH - 8, 0, 1.0, 0)
            count:SetSize(COUNT_WIDTH, ROW_HEIGHT)
            count.content = entry.detail or ""
            count.font = id.Font.MUSEO_SANS_11PT_REGULAR
            count.rgba = COUNT_TEXT
            count.maxLines = 1
            count.alignHorizontal = ui.AlignMode.BOTTOMRIGHT
            count.alignVertical = ui.AlignMode.CENTRE
            count.clickthrough = true
            count:MoveToFront()
            row.count = count
            addAccent(row.root, accentHeight)
        end
        row.label:MoveToFront()
        if entry.selected then addSelectedFrame(row.root) end
    end
end

-- Destroy the list; Bank Core destroys the parent after unmount
function Sidebar:Destroy()
    local list, search = self.list, self.search
    self.list, self.search = nil, nil
    if list ~= nil then pcall(function() list:Destroy() end) end
    if search ~= nil then pcall(function() search:Destroy() end) end
end

return Sidebar
