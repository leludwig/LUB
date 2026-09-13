-- Pop Bubbles: aimed throws at rendered positions and recorded utility remotes.
return function(tab)
    local runtime = getgenv().LUBRuntime
    local player = game:GetService("Players").LocalPlayer
    local remotes = game:GetService("ReplicatedStorage").Remotes
    local drops = {Cash = {}, Gem = {}}
    local modes, controls = {}, {}
    local status
    local throwDelay, nextThrow, throws = 2, 0, 0
    local function show(message)
        if runtime.alive and status then status:SetDesc(message) end
    end
    for kind, pending in pairs(drops) do
        runtime.track(remotes[kind .. "DropEvent"].OnClientEvent:Connect(function(batch)
            if not runtime.alive or type(batch) ~= "table" then return end
            for _, item in ipairs(batch) do
                if type(item) == "table" and type(item.dropId) == "number" then
                    if item.kind == "Remove" then pending[item.dropId] = nil
                    elseif item.kind == "Spawn" then
                        pending[item.dropId] = {expires = os.clock() + (tonumber(item.lifetimeSeconds) or 60), nextTry = 0}
                    end
                end
            end
        end))
    end
    local function farm()
        if os.clock() >= nextThrow then
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local folder = workspace:FindFirstChild("ClientRenderedBubbles_" .. player.UserId)
            local direction, nearest
            if root and folder then
                for _, bubble in ipairs(folder:GetChildren()) do
                    local position
                    if bubble:IsA("Model") then position = bubble:GetPivot().Position
                    elseif bubble:IsA("BasePart") then position = bubble.Position end
                    if position then
                        local dx, dy, dz = position.X-root.Position.X, position.Y-root.Position.Y, position.Z-root.Position.Z
                        local distance = math.sqrt(dx*dx + dy*dy + dz*dz)
                        if distance > 0.01 and (not nearest or distance < nearest) then
                            nearest = distance
                            direction = Vector3.new(dx/distance, dy/distance, dz/distance)
                        end
                    end
                end
            end
            if direction then
                remotes.ThrowWeapon:FireServer(direction, tostring(player.UserId) .. "_" .. tostring(workspace:GetServerTimeNow()), true)
                throws += 1
                nextThrow = os.clock() + throwDelay
                show("Throws sent: " .. throws .. " | Collecting Cash and Gems")
            else
                show("Waiting for character and rendered bubbles")
            end
        end
        for kind, pending in pairs(drops) do
            local ids = {}
            for id, drop in pairs(pending) do
                if os.clock() >= drop.expires then pending[id] = nil
                elseif os.clock() >= drop.nextTry and #ids < 20 then
                    table.insert(ids, id)
                    drop.nextTry = os.clock() + 2
                end
            end
            if #ids > 0 then remotes[kind .. "DropCollect"]:FireServer(ids) end
        end
    end
    local section = tab:Section({Title = "Auto Farm", Opened = true})
    local function addMode(title, interval, action)
        local state = {enabled=false, worker=false, generation=0}
        modes[title] = state
        controls[title] = section:Toggle({Title=title, Value=false, Callback=function(value)
            state.enabled = value == true and runtime.alive
            state.generation += 1
            if not state.enabled then show(title .. " stopped") end
            if state.worker or not state.enabled then return end
            state.worker = true
            task.spawn(function()
                while runtime.alive and state.enabled do
                    local generation = state.generation
                    local function current() return runtime.alive and state.enabled and state.generation == generation end
                    local ok, err = pcall(action, current)
                    if not ok and current() then
                        state.enabled = false
                        controls[title]:Set(false, false)
                        show(title .. " stopped: " .. tostring(err))
                        warn("LUB Pop Bubbles: " .. tostring(err))
                    end
                    local finish = os.clock() + interval
                    while current() and os.clock() < finish do task.wait(0.1) end
                end
                state.worker = false
            end)
        end})
    end
    addMode("Autofarm", 0.25, farm)
    section:Slider({Title="Throw delay", Value={Min=0.25, Max=5, Default=2}, Step=0.05, Callback=function(value)
        throwDelay = math.clamp(tonumber(value) or 2, 0.25, 5)
    end})
    addMode("Auto Equip Best Bubblets", 10, function()
        local result = remotes.BubbletEquipBestRequest:InvokeServer()
        assert(type(result) == "table" and result.ok == true, "Equip Best was not confirmed")
    end)
    local upgrades = {"BubbleValue", "BubbleSpawnRate", "MaxBubbles", "MultiPopChance", "Luck"}
    addMode("Auto Upgrades", 5, function(current)
        for _, name in ipairs(upgrades) do
            if not current() then return end
            local result = remotes.UpgradeRequest:InvokeServer(name, 1)
            if not current() then return end
            assert(type(result) == "table" and type(result.success) == "boolean", "Invalid upgrade response")
            -- An unaffordable or maxed upgrade must not block other upgrades.
        end
    end)
    status = section:Paragraph({Title="Farm Status", Desc="Stopped"})
    table.insert(runtime.cleanups, function()
        for _, state in pairs(modes) do state.enabled = false; state.generation += 1 end
    end)
end
