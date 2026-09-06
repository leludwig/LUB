-- Sell Ores. Remote names, arguments and response fields follow the supplied logs.
-- Reward IDs must come from a fresh DrillTunnel response, never from a recording.
return function(tab, data)
    local env = getgenv()
    local runtime = env.LUBRuntime
    local place = tostring(game.PlaceId)
    local saved = type(data[place]) == "table" and data[place] or {}
    data[place] = saved
    saved.base = type(saved.base) == "string" and saved.base or "Base1"
    saved.floor = type(saved.floor) == "string" and saved.floor or "1"
    saved.tunnels = type(saved.tunnels) == "string" and saved.tunnels or "Tunnel3, Tunnel4"
    local restore = saved.farming == true
    local running, generation = false, 0
    local toggle, status

    local function active(token)
        return runtime.alive and running and generation == token
    end
    local function setStatus(text)
        if runtime.alive and status then status:SetDesc(text) end
    end
    local function stop()
        generation = generation + 1
        running = false
        saved.farming = false
        if toggle then toggle:Set(false, false) end
        env.LUBSaveConfig(data)
        setStatus("Autofarm stopped.")
    end
    local function targets()
        local base = saved.base:match("^%s*(Base%d+)%s*$")
        assert(base, "Base must be a name such as Base1.")
        local floor = tonumber(saved.floor)
        assert(floor and floor >= 1 and floor < math.huge and floor % 1 == 0, "Floor must be a positive whole number.")
        local names, seen = {}, {}
        for name in saved.tunnels:gmatch("[^,%s]+") do
            if name:match("^%d+$") then name = "Tunnel" .. name end
            assert(name:match("^Tunnel%d+$"), "Use tunnel names such as Tunnel3, Tunnel4.")
            if not seen[name] then
                seen[name] = true
                table.insert(names, { name = name, nextCheck = 0 })
            end
        end
        assert(#names > 0 and #names <= 20, "Enter between 1 and 20 tunnels.")
        return base, floor, names
    end
    local function payload(response, action)
        local reason = type(response) == "table" and (response.message or response.error) or nil
        assert(type(response) == "table" and response.success == true,
            action .. ": " .. tostring(reason or "server rejected the request"))
        assert(type(response.result) == "table", action .. ": missing server result")
        return response.result
    end
    local function rewardIds(result)
        local raw = result.PendingRewardIds
        if raw == nil and type(result.PendingRewardId) == "string" then raw = { result.PendingRewardId } end
        assert(type(raw) == "table", "DrillTunnel returned no reward IDs.")
        local ids, seen = {}, {}
        for _, id in ipairs(raw) do
            assert(type(id) == "string" and id ~= "", "DrillTunnel returned an invalid reward ID.")
            if not seen[id] then seen[id] = true; table.insert(ids, id) end
        end
        assert(#ids > 0, "DrillTunnel returned no reward IDs.")
        return ids
    end
    local function delay(value, fallback)
        return type(value) == "number" and value == value and math.clamp(value, 0.5, 60) or fallback
    end

    local function run(token, base, floor, tunnels)
        local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
        local drill = remotes and remotes:FindFirstChild("BaseBuildTunnelAction")
        local crates = remotes and remotes:FindFirstChild("BaseCrateAction")
        assert(drill and drill:IsA("RemoteFunction") and crates and crates:IsA("RemoteFunction"),
            "Game remotes are not loaded yet. Try enabling Autofarm after the game loads.")
        local batches = 0
        while active(token) do
            local nextCheck = math.huge
            for _, tunnel in ipairs(tunnels) do
                if not active(token) then return end
                if os.clock() >= tunnel.nextCheck then
                    local response = drill:InvokeServer(base, floor, tunnel.name, "GetDrillState")
                    if not active(token) then return end
                    local state = payload(response, "GetDrillState")
                    assert(type(state.ready) == "boolean", "GetDrillState returned no ready flag.")
                    if state.ready then
                        -- The recorded client waits about one second before drilling.
                        task.wait(1)
                        if not active(token) then return end
                        response = drill:InvokeServer(base, floor, tunnel.name, "DrillTunnel")
                        if not active(token) then return end
                        if type(response) == "table" and response.success == false then
                            -- A drone may have mined it since the readiness check.
                            tunnel.nextCheck = os.clock() + 2
                            setStatus(tunnel.name .. ": " .. tostring(response.message or response.error or "not ready; retrying"))
                        else
                            local result = payload(response, "DrillTunnel")
                            local ids = rewardIds(result)
                            tunnel.nextCheck = os.clock() + delay(result.GrowTime, 3)
                            -- Allow the drops to appear before collecting, as in the logs.
                            task.wait(1.5)
                            if not active(token) then return end
                            local collected
                            for attempt = 1, 3 do
                                response = crates:InvokeServer(base, "CollectDroneOres", ids)
                                if not active(token) then return end
                                if type(response) == "table" and response.success == true then
                                    payload(response, "CollectDroneOres")
                                    collected = true
                                    break
                                end
                                if attempt < 3 then
                                    task.wait(1)
                                    if not active(token) then return end
                                end
                            end
                            if not collected then payload(response, "CollectDroneOres") end
                            batches = batches + 1
                            setStatus("Ore batches collected: " .. batches)
                        end
                    else
                        tunnel.nextCheck = os.clock() + delay(state.remainingSeconds, 1)
                        setStatus("Waiting for " .. tunnel.name .. " to regrow. Collected batches: " .. batches)
                    end
                end
                nextCheck = math.min(nextCheck, tunnel.nextCheck)
            end
            task.wait(math.clamp(nextCheck - os.clock(), 0.25, 1))
        end
    end
    local function start()
        if not runtime.alive then return end
        stop()
        local valid, base, floor, tunnels = pcall(targets)
        if not valid then setStatus(tostring(base)); return end
        running = true
        saved.farming = true
        toggle:Set(true, false)
        env.LUBSaveConfig(data)
        local token = generation
        setStatus("Checking tunnels...")
        task.spawn(function()
            if not active(token) then return end
            local ok, err = pcall(function() run(token, base, floor, tunnels) end)
            if not ok and active(token) then
                stop()
                setStatus("Autofarm stopped: " .. tostring(err))
                warn("LUB Sell Ores: " .. tostring(err))
            end
        end)
    end

    local farm = tab:Section({ Title = "Auto Farm", Icon = "pickaxe", Opened = true })
    toggle = farm:Toggle({
        Title = "Autofarm", Value = false,
        Callback = function(value)
            if not runtime.alive then return end
            if value then start() else stop() end
        end,
    })
    status = farm:Paragraph({ Title = "Farm Status", Desc = "Autofarm stopped." })
    local settings = tab:Section({ Title = "Farm Targets", Opened = false })
    for _, field in ipairs({
        { key = "base", title = "Base", placeholder = "Base1" },
        { key = "floor", title = "Floor", placeholder = "1" },
        { key = "tunnels", title = "Tunnels", placeholder = "Tunnel3, Tunnel4" },
    }) do
        settings:Input({
            Title = field.title, Value = saved[field.key], Placeholder = field.placeholder,
            Callback = function(value)
                -- WindUI calls Input callbacks during construction as well.
                if not runtime.alive or type(value) ~= "string" or value == saved[field.key] then return end
                stop()
                saved[field.key] = value
                env.LUBSaveConfig(data)
                setStatus("Targets updated. Enable Autofarm to start.")
            end,
        })
    end
    table.insert(runtime.cleanups, function()
        generation = generation + 1
        running = false
    end)
    if restore then start() else saved.farming = false; env.LUBSaveConfig(data) end
end
