package.path = "./?.lua;" .. package.path

local function read(path)
    local file = assert(io.open(path, "rb"))
    local bytes = file:read("a")
    file:close()
    return bytes
end

local manifest = read("plugin.json")
assert(manifest:find('"name"%s*:%s*"Bank Cleaner"'))
assert(manifest:find('"contactEmailAddress"%s*:%s*"plugins@rs3.dev"'))
assert(manifest:find('"bankcore"%s*:%s*6464293'))
assert(not manifest:find('"description"%s*:'))

-- Every imported module must ship and be evicted on a same-state reload.
local entry = read("main.lua")
local seen = {}
local function visit(path)
    if seen[path] then return end
    seen[path] = true
    local source = read(path .. ".lua")
    assert(load(source, "@" .. path .. ".lua", "t", {}))
    for module in source:gmatch('require%s*%(%s*"([^"]+)"%s*%)') do
        assert(module == "app" or module:match("^resources/"), module)
        assert(entry:find('"' .. module .. '",', 1, true), "reload list missing " .. module)
        visit(module)
    end
end
visit("main")
assert(seen.app and seen["resources/cleanup/categories"])
print("runtime_layout_test: ok")
