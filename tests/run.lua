-- Run each test in its own Lua process to isolate fake host globals.
local interpreter = arg[-1] or "lua54"
local tests = {
    "runtime_layout", "cleanup_categories", "cleanup_catalogs", "cleanup_pages",
    "cleanup_app", "cleanup_sidebar", "bank_state", "plugin_reload",
}
local failures = 0
for _, name in ipairs(tests) do
    local ok = os.execute(('"%s" tests/%s_test.lua'):format(interpreter, name))
    if not ok then failures = failures + 1 end
end
print(("%d of %d tests passed"):format(#tests - failures, #tests))
os.exit(failures == 0 and 0 or 1)
