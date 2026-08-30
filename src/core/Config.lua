local Config = {}
Config.__index = Config

function Config.new(httpService, janitor)
    local self = setmetatable({}, Config)
    self.http = httpService
    self.folder = "BezNigativa"
    self.file = self.folder .. "/config.json"
    self.available = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
    self.provider = nil
    self.loading = false
    self.token = 0
    self.janitor = janitor
    return self
end

function Config:SetProvider(provider)
    self.provider = provider
end

function Config:Load()
    if not self.available or not isfile(self.file) then return {} end
    local ok, data = pcall(function()
        return self.http:JSONDecode(readfile(self.file))
    end)
    return ok and type(data) == "table" and data or {}
end

function Config:SaveNow()
    if self.loading or not self.available or not self.provider then return false end
    return pcall(function()
        if type(makefolder) == "function" then pcall(makefolder, self.folder) end
        writefile(self.file, self.http:JSONEncode(self.provider()))
    end)
end

function Config:Touch()
    if self.loading or not self.available then return end
    self.token += 1
    local token = self.token
    task.delay(0.35, function()
        if token == self.token then self:SaveNow() end
    end)
end

return Config
