-- Describe the Cleanup tab's folders and one Bank Core page per category from the categories'
-- members. Every slot names an exact present stack, { item, copy }, of the snapshot the
-- members came from; categories are labelled with Bank Core's standard label rows

local Categories = require("bankcleaner/cleanup/categories")

local Pages = {}

Pages.TAB_ID = "cleanup"
Pages.EMPTY = "None of these items are in your bank."
Pages.SCANNING = "Scanning bank..."
-- The count shown beside a category while it may still change
Pages.BUSY = "..."
-- The count column fits six characters
local DETAIL_LIMIT = 999999

-- Name the page key for a category; it never changes, so a rescan keeps the scroll position
function Pages.Key(categoryID)
    return "cleanup:" .. categoryID
end

-- List one row of slots for members
local function slotRow(members)
    local slots = {}
    for index, member in ipairs(members) do slots[index] = { item = member.objectID, copy = member.copy } end
    return { slots = slots }
end

-- Lay out a category's members: its label and slots, or each non-empty section's label and
-- slots in the definition's order. A category with no members is one status label
function Pages.Layout(definition, members, scanning)
    if #members == 0 then return { { label = scanning and Pages.SCANNING or Pages.EMPTY } } end
    if definition.sections == nil then return { { label = definition.label }, slotRow(members) } end
    local rows = {}
    for _, section in ipairs(definition.sections) do
        local inSection = {}
        for _, member in ipairs(members) do
            if member.section == section.id then inSection[#inSection + 1] = member end
        end
        if #inSection > 0 then
            rows[#rows + 1] = { label = section.label }
            rows[#rows + 1] = slotRow(inSection)
        end
    end
    return rows
end

-- Describe a category's page for Bank Core
function Pages.Page(definition, members, scanning)
    return { title = definition.label, key = Pages.Key(definition.id),
        layout = Pages.Layout(definition, members, scanning) }
end

-- Summarise a layout as text, so an unchanged page is not sent to Bank Core again
function Pages.Signature(layout)
    local parts = {}
    for _, row in ipairs(layout) do
        if row.label ~= nil then
            parts[#parts + 1] = "L" .. row.label
        else
            local slots = {}
            for index, slot in ipairs(row.slots) do slots[index] = slot.item .. ":" .. slot.copy end
            parts[#parts + 1] = "S" .. table.concat(slots, ",")
        end
    end
    return table.concat(parts, "\n")
end

-- Describe the Cleanup tab's folders: each group with its categories and their counts, or a
-- busy mark while objects are still being classified
function Pages.Folders(members, scanning)
    local folders = {}
    for _, group in ipairs(Categories.GROUPS) do
        local categories = {}
        for _, definition in ipairs(Categories.DEFINITIONS) do
            if definition.group == group then
                local count = math.min(#members[definition.id], DETAIL_LIMIT)
                categories[#categories + 1] = { id = definition.id, label = definition.label,
                    detail = scanning and Pages.BUSY or tostring(count) }
            end
        end
        folders[#folders + 1] = { label = group, categories = categories }
    end
    return folders
end

-- Summarise the folders' counts as text, so unchanged counts do not redraw the rows
function Pages.FoldersSignature(folders)
    local parts = {}
    for _, folder in ipairs(folders) do
        for _, category in ipairs(folder.categories) do parts[#parts + 1] = category.id .. "=" .. category.detail end
    end
    return table.concat(parts, " ")
end

-- Describe the Cleanup tab, whose column the mount callbacks draw
function Pages.Tab(mount)
    return { label = "Cleanup", icon = "ERASER", tooltip = "Items that belong in other storage", mount = mount }
end

return Pages
