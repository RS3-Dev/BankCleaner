package.path = "./?.lua;" .. package.path

local Build = require("tools/build")

-- Read a manifest without loading it as code
local function manifest(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("a")
    file:close()
    return text
end

-- Local builds retain folder dependencies; mod.io builds use published IDs
local source = manifest("plugins/bankcleaner/plugin.json")
local development = Build.Run({ out = "dist/manifest-local" })
local release = Build.Run({ out = "dist/manifest-release", release = true })
assert(manifest(development.folder .. "/plugin.json") == source)
local published, count = source:gsub('"bankcore"%s*:%s*"bankcore"', '"bankcore": 6464293')
assert(count == 1 and manifest(release.folder .. "/plugin.json") == published)
assert(manifest("plugins/bankcleaner/plugin.json") == source)

-- Rebuilding locally after packaging never inherits the published dependency
development = Build.Run({ out = "dist/manifest-local" })
assert(manifest(development.folder .. "/plugin.json") == source)
print("build_manifest_test: ok")
