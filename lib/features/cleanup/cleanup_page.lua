-- Describe how a generated cleanup page is titled, built, and refreshed. The bank passes
-- itself; the cleanup categories belong to its attached features

local titleCase = require("lib/core/text").titleCase

local CleanupPage = {
    -- Cleanup pages are generated, so players cannot remove their items
    isMembershipEditable = false,
}

-- Claim every cleanup-prefixed selection ID
function CleanupPage.OwnsSelection(layout, categoryID)
    return layout.features.cleanupCategories:IsGenerated(categoryID)
end

-- Show the selection name as before; no screen displays it yet
function CleanupPage.Title(_, categoryID)
    return titleCase(categoryID)
end

-- Lay out the category's generated members and heading
function CleanupPage.Apply(layout, categoryID)
    return layout.pageState:Apply(categoryID)
end

-- Refuse a category while its batch scan is still running
function CleanupPage.IsSelectable(layout, categoryID)
    return not layout.features.cleanupCategories:IsRefreshing(categoryID)
end

-- Check whether bank changes made the category's results stale
function CleanupPage.NeedsRefresh(layout, categoryID)
    return layout.features.cleanupCategories:IsDirty(categoryID)
end

-- Scan the bank again for a stale category after it is shown
function CleanupPage.Refresh(layout, categoryID)
    layout.features:BeginCleanupRefresh(categoryID)
end

return CleanupPage
