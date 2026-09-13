-- Pop Bubbles: aimed throws at rendered positions and recorded utility remotes.
return function(tab)
    local runtime = getgenv().LUBRuntime
    local player = game:GetService("Players").LocalPlayer
    local remotes = game:GetService("ReplicatedStorage").Remotes
    local weaponClass = require(player.PlayerScripts.Weapon.WeaponController).WeaponController
    local bubbleRenderer = require(player.PlayerScripts.Bubbles.BubbleRenderer).BubbleRenderer
    local drops = {Cash = {}, Gem = {}, Essence = {}}
    local modes, controls = {}, {}
    local status
    local throwDelay, nextThrow, throws = 0, 0, 0
    local bubbletSlots = 6
    local nextBubbletSlot = 0
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
    local seenFlames = setmetatable({}, {__mode="k"})
    local function collectDrops(onlyKind)
        -- DropRenderer names existing flame models EssenceDrop_<dropId>.
        local folder = workspace:FindFirstChild("LocalEssenceDrops_" .. player.UserId)
        if folder then
            for _, object in ipairs(folder:GetChildren()) do
                local id = tonumber(object.Name:match("^EssenceDrop_(%d+)$"))
                if id and not seenFlames[object] then
                    seenFlames[object] = true
                    if not drops.Essence[id] then
                        drops.Essence[id] = {expires=os.clock()+180, nextTry=0, visual=object}
                    end
                end
            end
        end
        for kind, pending in pairs(drops) do
            if onlyKind and kind ~= onlyKind then continue end
            local ids = {}
            for id, drop in pairs(pending) do
                if os.clock() >= drop.expires or (drop.visual and not drop.visual.Parent) then pending[id] = nil
                elseif os.clock() >= drop.nextTry and #ids < 20 then
                    table.insert(ids, id)
                    drop.nextTry = os.clock() + 2
                end
            end
            if #ids > 0 then remotes[kind .. "DropCollect"]:FireServer(ids) end
        end
    end
    local hookedWeapon, previousTarget, targetHook, observedFireTime
    local function restoreTarget()
        if hookedWeapon and rawget(hookedWeapon, "getTargetPosition") == targetHook then
            hookedWeapon.getTargetPosition = previousTarget
        end
        hookedWeapon, previousTarget, targetHook = nil, nil, nil
    end
    local function bindTarget(weapon)
        if hookedWeapon == weapon then return end
        restoreTarget()
        hookedWeapon, previousTarget = weapon, rawget(weapon, "getTargetPosition")
        observedFireTime = weapon.lastFireTime
        local original = weapon.getTargetPosition
        targetHook = function(self, root, flat, manual)
            if not runtime.alive or not modes.Autofarm.enabled or manual
                or self.isHoldingMouseButton or self.isHoldingGamepadTrigger then
                return original(self, root, flat, manual)
            end
            if os.clock() < nextThrow then return nil end
            local char = player.Character
            if not char or char:FindFirstChild("HumanoidRootPart") ~= root then return nil end
            -- The renderer excludes predicted pops and disappearing/hidden bubbles.
            local model = bubbleRenderer:getClosestBubbleModelToPosition(root.Position)
            local part = model and model.Parent and model.PrimaryPart
            if not part or not part.Parent then return nil end
            local position = part.Position
            local dx, dy, dz = position.X-root.Position.X, position.Y-root.Position.Y, position.Z-root.Position.Z
            if dx*dx+dy*dy+dz*dz <= 0.0001 then return nil end
            return flat and Vector3.new(position.X, root.Position.Y, position.Z) or position
        end
        weapon.getTargetPosition = targetHook
    end
    local function farm()
        local weapon = weaponClass:getInstance()
        if weapon then
            bindTarget(weapon)
            -- Also routes the already-running native throw loop to our live target;
            -- it can no longer consume the shared cooldown with another target.
            weapon:throw(false)
            if weapon.lastFireTime ~= observedFireTime then
                observedFireTime = weapon.lastFireTime
                throws += 1
                nextThrow = os.clock() + throwDelay
                show("Throws observed: " .. throws .. " | Collecting Cash, Gems and Flames")
            end
        else
            restoreTarget()
            show("Waiting for weapon controller")
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
            if not state.enabled then
                if title == "Autofarm" then restoreTarget() end
                show(title .. " stopped")
            end
            if state.worker or not state.enabled then return end
            state.worker = true
            task.spawn(function()
                while runtime.alive and state.enabled do
                    local generation = state.generation
                    local function current() return runtime.alive and state.enabled and state.generation == generation end
                    local ok, err = pcall(action, current)
                    if not ok and current() then
                        state.enabled = false
                        if title == "Autofarm" then restoreTarget() end
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
    addMode("Auto Upgrade Bubblets", 0.03, function(current)
        -- One level per slot. Resume at the unpaid slot when cash runs out.
        for _ = 1, bubbletSlots do
            if not current() then return end
            local slot = nextBubbletSlot % bubbletSlots
            local result = remotes.BubbletLevelUpRequest:InvokeServer({target={slotIndex=slot, kind="equipped"}, mode="single"})
            if not current() then return end
            assert(type(result) == "table" and type(result.ok) == "boolean", "Invalid Bubblet upgrade response")
            if not result.ok and result.error == "insufficient_cash" then return end
            nextBubbletSlot = (slot + 1) % bubbletSlots
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
        restoreTarget()
        for _, state in pairs(modes) do state.enabled = false; state.generation += 1 end
    end)
end
