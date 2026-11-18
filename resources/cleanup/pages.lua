-- Build the Cleanup column's folders and each category's Bank Core page

local Categories = require("resources/cleanup/categories")

local Pages = {}

Pages.EMPTY = "None of these items are in your bank."
Pages.NO_MATCHES = "No cleanup items match your search."
Pages.SCANNING = "Scanning bank..."
-- The count shown beside a category while it may still change
Pages.BUSY = "..."
-- The count column fits six characters
local DETAIL_LIMIT = 999999

-- List one row of slots for members
local function slotRow(members)
    local slots = {}
    for index, member in ipairs(members) do slots[index] = member.objectID end
    return { slots = slots }
end

-- Lay out a category page by section, or a status label if empty
function Pages.Rows(definition, members, scanning, searching)
    if #members == 0 then
        return { { label = scanning and Pages.SCANNING or (searching and Pages.NO_MATCHES or Pages.EMPTY) } }
    end
    if definition.sections == nil then return { slotRow(members) } end
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

-- Title pages that have no labels
function Pages.Page(definition, members, scanning, searching)
    local rows = Pages.Rows(definition, members, scanning, searching)
    local title = rows[1] ~= nil and rows[1].label == nil and definition.label or nil
    return { title = title, rows = rows }
end

-- Summarise a page so an unchanged one is not resent
function Pages.Signature(page)
    local parts = { page.title or "" }
    for _, row in ipairs(page.rows) do
        if row.label ~= nil then
            parts[#parts + 1] = "L" .. row.label
        else
            parts[#parts + 1] = "S" .. table.concat(row.slots, ",")
        end
    end
    return table.concat(parts, "\n")
end

-- Describe the column's folders with counts or a busy mark
function Pages.Folders(members, scanning)
    local folders = {}
    for _, group in ipairs(Categories.GROUPS) do
        local categories, total = {}, 0
        for _, definition in ipairs(Categories.DEFINITIONS) do
            if definition.group == group then
                local count = math.min(#members[definition.id], DETAIL_LIMIT)
                total = total + count
                categories[#categories + 1] = { id = definition.id, label = definition.label,
                    detail = scanning and Pages.BUSY or tostring(count) }
            end
        end
        folders[#folders + 1] = { label = group, categories = categories,
            detail = scanning and Pages.BUSY or tostring(total) }
    end
    return folders
end

-- Summarise folder counts so unchanged counts skip a redraw
function Pages.FoldersSignature(folders)
    local parts = {}
    for _, folder in ipairs(folders) do
        for _, category in ipairs(folder.categories) do parts[#parts + 1] = category.id .. "=" .. category.detail end
    end
    return table.concat(parts, " ")
end

return Pages
