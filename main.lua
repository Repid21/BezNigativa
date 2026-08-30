-- BezNigativa v7.0 entrypoint. Feature code lives in src/.
local environment = getgenv and getgenv() or _G
local cache = {}

local function readModule(name)
    local roots = {}
    if type(environment.BezNigativaSourceRoot) == "string" then table.insert(roots, environment.BezNigativaSourceRoot) end
    table.insert(roots, "src")
    table.insert(roots, ".")
    local errors = {}
    for _, root in ipairs(roots) do
        local path = (root == "." and "" or root .. "/") .. name .. ".lua"
        if type(readfile) == "function" then
            local ok, source = pcall(readfile, path)
            if ok then
                local compiler = loadstring or load
                if type(compiler) ~= "function" then error("Executor does not provide loadstring") end
                local chunk, compileError = compiler(source, "@" .. path)
                if not chunk then error(compileError) end
                return chunk()
            end
            table.insert(errors, path)
        elseif type(loadfile) == "function" then
            local chunk = loadfile(path)
            if chunk then return chunk() end
            table.insert(errors, path)
        end
    end
    error("BezNigativa module not found: " .. name .. " (checked " .. table.concat(errors, ", ") .. ")")
end

local function loadModule(name)
    if cache[name] == nil then cache[name] = readModule(name) end
    return cache[name]
end

return loadModule("App").start(loadModule)
