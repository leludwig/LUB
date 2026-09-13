-- Pop Bubbles: aimed throws at rendered positions and recorded utility remotes.
return function(tab)
    local runtime = getgenv().LUBRuntime
    local player = game:GetService("Players").LocalPlayer
    local remotes = game:GetService("ReplicatedStorage").Remotes
    local weaponClass = require(player.PlayerScripts.Weapon.WeaponController).WeaponController
    local drops = {Cash = {}, Gem = {}, Essence = {}}
    local modes, controls = {}, {}
    local status
    local throwDelay, nextThrow, throws = 0, 0, 0
    local bubbletSlots = 6
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
    local function collectDrops(onlyKind)
        for kind, pending in pairs(drops) do
            if onlyKind and kind ~= onlyKind then continue end
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
    local function farm()
        if os.clock() >= nextThrow then
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local folder = workspace:FindFirstChild("ClientRenderedBubbles_" .. player.UserId)
            local target, nearest
            if root and folder then
                for _, bubble in ipairs(folder:GetChildren()) do
                    -- Live bubbles use a transparent Outer part as their target.
                    -- Model pivots and transparency do not locate/render it reliably.
                    local position, largest
                    local parts = bubble:IsA("BasePart") and {bubble} or bubble:GetDescendants()
                    for _, part in ipairs(parts) do
                        if part:IsA("BasePart") and (part.Name == "Outer" or part.Transparency < 1) then
                            local size = part.Size
                            local volume = size.X * size.Y * size.Z
                            if part.Name == "Outer" and volume > 0 then
                                position = part.Position
                                break
                            end
                            if volume > 0 and (not largest or volume > largest) then
                                largest, position = volume, part.Position
                            end
                        end
                    end
                    if position then
                        local dx, dy, dz = position.X-root.Position.X, position.Y-root.Position.Y, position.Z-root.Position.Z
                        local distance = math.sqrt(dx*dx + dy*dy + dz*dz)
                        if distance > 0.01 and (not nearest or distance < nearest) then
                            nearest = distance
                            target = position
                        end
                    end
                end
            end
            local weapon = weaponClass:getInstance()
            if target and weapon and weapon.cachedRoot == root then
                -- throw() synchronously creates the local projectile, reports it
                -- to the server and invokes the game's hit-system callbacks.
                -- Override only this call's target; leave manual/auto input intact.
                local previous = rawget(weapon, "getTargetPosition")
                local before = weapon.lastFireTime
                weapon.getTargetPosition = function() return target end
                local ok, err = pcall(weapon.throw, weapon, false)
                weapon.getTargetPosition = previous
                if not ok then error(err, 0) end
                if weapon.lastFireTime ~= before then
                    throws += 1
                    nextThrow = os.clock() + throwDelay
                    show("Throws fired: " .. throws .. " | Collecting Cash, Gems and Flames")
                end
            else
                show("Waiting for character and rendered bubbles")
            end
        end
        collectDrops()
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
                    while current() and os.clock() < finish do task.wait(math.min(0.05, finish - os.clock())) end
                end
                state.worker = false
            end)
        end})
    end
    addMode("Autofarm", 0.05, farm)
    section:Slider({Title="Throw delay", Value={Min=0, Max=5, Default=0}, Step=0.05, Callback=function(value)
        throwDelay = math.clamp(tonumber(value) or 0, 0, 5)
        nextThrow = math.min(nextThrow, os.clock() + throwDelay)
    end})
    addMode("Auto Equip Best Bubblets", 10, function()
        local result = remotes.BubbletEquipBestRequest:InvokeServer()
        assert(type(result) == "table" and result.ok == true, "Equip Best was not confirmed")
    end)
    section:Slider({Title="Equipped Bubblet slots", Value={Min=1, Max=12, Default=6}, Step=1, Callback=function(value)
        bubbletSlots = math.clamp(math.floor(tonumber(value) or 6), 1, 12)
    end})
    addMode("Auto Upgrade Bubblets", 0.1, function(current)
        -- Upgrade each equipped slot separately, including identical Bubblets.
        for slot = 0, bubbletSlots - 1 do
            if not current() then return end
            local result = remotes.BubbletLevelUpRequest:InvokeServer({target={slotIndex=slot, kind="equipped"}, mode="max"})
            if not current() then return end
            assert(type(result) == "table" and type(result.ok) == "boolean", "Invalid Bubblet upgrade response")
        end
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
    addMode("Auto Rebirth", 5, function(current)
        collectDrops("Essence")
        local result = remotes.RebirthRequest:InvokeServer()
        if not current() then return end
        assert(type(result) == "table" and type(result.success) == "boolean", "Invalid rebirth response")
        if result.success then show("Rebirth confirmed") end
    end)
    status = section:Paragraph({Title="Farm Status", Desc="Stopped"})
    table.insert(runtime.cleanups, function()
        for _, state in pairs(modes) do state.enabled = false; state.generation += 1 end
    end)
end
