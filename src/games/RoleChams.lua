local RoleChams = {}
RoleChams.__index = RoleChams

function RoleChams.new(name)
    return setmetatable({Name = name, Entries = {}}, RoleChams)
end

function RoleChams:Show(model, color, seen)
    if not model or not model.Parent then return end
    seen[model] = true
    local highlight = self.Entries[model]
    if not highlight or not highlight.Parent then
        if highlight then pcall(function() highlight:Destroy() end) end
        highlight = Instance.new("Highlight")
        highlight.Name = self.Name
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillTransparency = 0.3
        highlight.OutlineTransparency = 0
        highlight.Adornee = model
        highlight.Parent = model
        self.Entries[model] = highlight
    end
    highlight.Enabled = true
    highlight.FillColor = color
    highlight.OutlineColor = color
end

function RoleChams:Finish(seen)
    for model, highlight in pairs(self.Entries) do
        if not seen[model] or not model.Parent or not highlight.Parent then
            pcall(function() highlight:Destroy() end)
            self.Entries[model] = nil
        end
    end
end

function RoleChams:Clear()
    for model, highlight in pairs(self.Entries) do
        pcall(function() highlight:Destroy() end)
        self.Entries[model] = nil
    end
end

return RoleChams
