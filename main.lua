-- BezNigativa v7.0 injector entrypoint.
local BASE_URL = "https://raw.githubusercontent.com/Repid21/BezNigativa/main/src/"
local BUILD_QUERY = "?build=7.1"
local cache = {}

local function loadModule(name)
    if cache[name] ~= nil then return cache[name] end

    local url = BASE_URL .. name .. ".lua" .. BUILD_QUERY
    local ok, source = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok then
        error("BezNigativa failed to download " .. name .. ": " .. tostring(source))
    end

    local compiler = loadstring or load
    if type(compiler) ~= "function" then
        error("Executor does not provide loadstring")
    end
    local chunk, compileError = compiler(source, "@BezNigativa/" .. name .. ".lua")
    if not chunk then error(compileError) end

    local module = chunk()
    cache[name] = module
    return module
end

return loadModule("App").start(loadModule)
