local Janitor = {}
Janitor.__index = Janitor

function Janitor.new()
    return setmetatable({items = {}, cleaned = false}, Janitor)
end

function Janitor:Add(item, method)
    if not item then return item end
    if self.cleaned then
        pcall(function()
            if type(item) == "function" then item()
            elseif method then item[method](item)
            elseif typeof(item) == "RBXScriptConnection" then item:Disconnect()
            elseif item.Destroy then item:Destroy() end
        end)
        return item
    end
    table.insert(self.items, {item = item, method = method})
    return item
end

function Janitor:Cleanup()
    if self.cleaned then return end
    self.cleaned = true
    for index = #self.items, 1, -1 do
        local entry = self.items[index]
        pcall(function()
            if type(entry.item) == "function" then
                entry.item()
            elseif entry.method then
                entry.item[entry.method](entry.item)
            elseif typeof(entry.item) == "RBXScriptConnection" then
                entry.item:Disconnect()
            elseif entry.item.Destroy then
                entry.item:Destroy()
            end
        end)
    end
    table.clear(self.items)
end

return Janitor
