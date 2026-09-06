-- LUB: egg-only collection. This module can only send the Collect Egg event.
local Collector = {}
Collector.__index = Collector

function Collector.new(options)
    return setmetatable({ options = options, generation = 0, running = false, count = 0 }, Collector)
end

function Collector:Stop()
    self.running = false
    self.generation = self.generation + 1
end

function Collector:Start()
    self:Stop()
    self.running = true
    self.count = 0
    local generation = self.generation
    local seen = setmetatable({}, { __mode = "k" })
    local function active()
        return self.running and self.generation == generation and self.options.isAlive()
    end
    task.spawn(function()
        while active() do
            local eggs, remote = self.options.getEggs(), self.options.getRemote()
            if eggs and remote then
                for _, egg in ipairs(eggs:GetChildren()) do
                    if not active() then return end
                    if egg.Parent == eggs and not seen[egg] then
                        local ok = pcall(function() remote:FireServer("Collect Egg", egg.Name) end)
                        if active() and ok then
                            seen[egg] = true
                            self.count = self.count + 1
                        end
                        task.wait(0.05)
                    end
                end
                if active() and self.options.status then
                    self.options.status("Collection requests: " .. tostring(self.count))
                end
            elseif self.options.status then
                self.options.status("Waiting for eggs / game to load...")
            end
            task.wait(0.2)
        end
    end)
end

return Collector
