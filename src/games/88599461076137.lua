-- Fishing Chef: native fishing controller plus recorded kitchen actions.
return function(tab)
    local env = getgenv()
    local runtime = env.LUBRuntime
    local player = game:GetService("Players").LocalPlayer
    local rs = game:GetService("ReplicatedStorage")
    local knit = require(rs.Packages.Knit)
    local fishing = knit.GetController("FishingController")
    local data = knit.GetController("DataController")
    local validator = require(rs.Shared.FishingCastValidator)
    local recipes = require(rs.Modules.CookingConfig)
    local remotes = rs.Packages.Knit.Services.Fish
    local enabled, generation, worker = false, 0, false
    local ownsFishing = false
    local cuttingBoard
    local activeCharacter
    local customSpot
    local status, toggle
    local state = { phase = "Stopped", caught = 0, cooked = 0, served = 0 }
    runtime.fishingChef = state
    local cancelled = {}

    local function show(message)
        state.phase = message
        if runtime.alive and status then
            status:SetDesc(string.format("%s\nFish: %d | Cooked: %d | Served: %d", message, state.caught, state.cooked, state.served))
        end
    end
    local function check(token)
        if not runtime.alive or not enabled or token ~= generation then error(cancelled, 0) end
        assert(not activeCharacter or player.Character == activeCharacter, "Character changed; enable Autofarm after respawning.")
    end
    local function pause(token, seconds)
        local finish = os.clock() + seconds
        repeat check(token); task.wait(math.min(0.1, math.max(0, finish - os.clock()))) until os.clock() >= finish
        check(token)
    end
    local function invoke(token, name, ...)
        check(token)
        local result = table.pack(remotes.RF[name]:InvokeServer(...))
        check(token)
        return table.unpack(result, 1, result.n)
    end
    local function fire(token, name, ...)
        check(token)
        remotes.RE[name]:FireServer(...)
    end
    local function character()
        local char = player.Character
        assert(char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChildOfClass("Humanoid"), "Character is not ready; enable Autofarm after respawning.")
        return char, char:FindFirstChildOfClass("Humanoid"), char.HumanoidRootPart
    end
    local function plot()
        local found = workspace.Code.Plots:FindFirstChild(player.Name)
        assert(found and found:GetAttribute("Owner") == player.Name, "Own restaurant is not loaded.")
        return found
    end
    local function move(token, cf)
        check(token)
        local _, _, root = character()
        root.CFrame = cf
        root.AssemblyLinearVelocity = Vector3.zero
        pause(token, 0.5)
    end
    local function stopCutting()
        if cuttingBoard then
            local board = cuttingBoard
            cuttingBoard = nil
            pcall(function() remotes.RE.ServerAnims:FireServer("CuttingBoard", board, false) end)
        end
    end
    local function stopFishing()
        if ownsFishing then
            ownsFishing = false
            pcall(function() fishing:SetAutoFishEnabled(false) end)
            pcall(function() local _, humanoid = character(); humanoid:UnequipTools() end)
        end
    end
    local function favorite(key, id)
        local favorites = data:GetData(key) or {}
        return favorites[id] or favorites[tostring(id)]
    end
    local function fishFor(recipe)
        for _, item in ipairs(data:GetData("Fish") or {}) do
            if item.ID ~= nil and not favorite("FavoriteFish", item.ID)
                and (not recipe.RequiredFish or recipe.RequiredFish[item.Name]) then return item end
        end
    end
    local function available(name)
        local recipe = recipes[name]
        -- Only Nigiri has a complete recorded cooking/serving sequence.
        if name ~= "Nigiri" or not recipe then return false end
        local level = data:GetData("Level") or 1
        local stallLevel = plot().STALL:GetAttribute("Level") or 1
        return level >= (recipe.PlayerLevel or 1) and stallLevel >= (recipe.StallLevel or 1)
    end
    local function customers()
        local result = {}
        for _, npc in ipairs(workspace.Code.ActiveNPCs:GetChildren()) do
            local owner = npc:FindFirstChild("Owner")
            if owner and owner.Value == player.Name and npc:GetAttribute("Arrived")
                and not npc:GetAttribute("Despawn") and npc:GetAttribute("WaitingForFood") ~= false
                and available(npc:GetAttribute("Order")) then table.insert(result, npc) end
        end
        return result
    end
    local function plateFor(name)
        local selected
        for _, plate in ipairs(data:GetData("Plates") or {}) do
            if plate.Name == name then
                -- StoreFood chooses the plate on the server, so do not serve a
                -- recipe with a protected plate when selection is ambiguous.
                if favorite("FavoritePlates", plate.ID) then return nil, true end
                selected = selected or plate
            end
        end
        return selected, false
    end
    local function serve(token, npc)
        local location = npc:FindFirstChild("Location")
        if not location then return false end
        local name = npc:GetAttribute("Order")
        show("Serving " .. name)
        move(token, location.Value * CFrame.new(0, 2, 3))
        local owner = npc:FindFirstChild("Owner")
        if not npc.Parent or not owner or owner.Value ~= player.Name
            or npc:GetAttribute("Despawn") or npc:GetAttribute("WaitingForFood") == false
            or npc:GetAttribute("Order") ~= name or not plateFor(name) then return false end
        local before = (data:GetData("NightMarket") or {}).CustomersServedTotal or 0
        fire(token, "StoreFood", npc)
        pause(token, 1.5)
        local after = (data:GetData("NightMarket") or {}).CustomersServedTotal or 0
        if after > before then state.served += after - before; return true end
        return false
    end
    local function catch(token)
        show("Finding a fishing spot")
        local char, humanoid, root = character()
        local found = false
        if customSpot then
            move(token, customSpot)
            found = validator:CanCastFromCharacter(char)
        else
            local origin = plot().BoatSpawnJetty.Position
            for angle = 0, 7 do
                check(token)
                root.CFrame = CFrame.new(origin + Vector3.new(0, 3, 0)) * CFrame.Angles(0, angle * math.pi / 4, 0)
                root.AssemblyLinearVelocity = Vector3.zero
                if validator:CanCastFromCharacter(char) then found = true; break end
            end
            pause(token, 0.5)
        end
        assert(found, "No valid fishing spot. Stand by water, face it, then use Set fishing spot.")
        local rod
        for _, container in ipairs({char, player.Backpack}) do
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") and tool:GetAttribute("IsRod") then rod = tool; break end
            end
        end
        assert(rod, "No fishing rod found.")
        humanoid:EquipTool(rod)
        pause(token, 0.5)
        local before = data:GetData("FishCaught") or 0
        ownsFishing = true
        fishing:SetAutoFishEnabled(true)
        show("Fishing")
        local started = os.clock()
        repeat pause(token, 0.5) until (data:GetData("FishCaught") or 0) > before or os.clock() - started > 60
        stopFishing()
        local gained = (data:GetData("FishCaught") or 0) - before
        assert(gained > 0, "No catch within 60 seconds. Check the rod and fishing spot.")
        state.caught += gained
        pause(token, 0.5)
    end
    local function cook(token, name)
        local recipe = recipes[name]
        local items = invoke(token, "RequestRestaurauntData")
        local filet
        for _, item in ipairs(items or {}) do
            if item.Name == "Fish Filet" and (not recipe.RequiredFish or recipe.RequiredFish[item.CF]) then filet = item; break end
        end
        local board = plot().STALL.CookingStation.CuttingBoard
        move(token, board.CFrame * CFrame.new(0, 3, 3))
        local score
        if not filet then
            local item = fishFor(recipe)
            if not item then return false end
            show("Cutting " .. item.Name)
            local goals = invoke(token, "StartCutSession")
            assert(type(goals) == "table" and #goals == 2, "Unexpected cutting session; stopped.")
            cuttingBoard = board
            fire(token, "ServerAnims", "CuttingBoard", board, true)
            score = 0
            for index, goal in ipairs(goals) do
                assert(type(goal) == "number" and goal >= 0 and goal <= 1, "Invalid cutting target.")
                -- Normal cutter: cursor = (sin(2*t)+1)/2. Use the descending pass.
                local duration = (math.pi - math.asin(2 * goal - 1)) / 2
                local started = os.clock()
                pause(token, duration)
                local elapsed = os.clock() - started
                local cursor = (math.sin(2 * elapsed) + 1) / 2
                score += math.clamp(1 - math.abs(goal - cursor) / 0.2, 0, 1)
                fire(token, "CutAction", index, elapsed)
                pause(token, 0.25)
            end
            stopCutting()
            if favorite("FavoriteFish", item.ID) then return false end
            invoke(token, "CutFish", item.ID, score)
            items = invoke(token, "RequestRestaurauntData")
            for _, candidate in ipairs(items or {}) do
                if candidate.Name == "Fish Filet" and candidate.CF == item.Name then filet = candidate; break end
            end
            assert(filet, "Server did not confirm the cut fish.")
        end
        show("Cooking " .. name)
        pause(token, recipe.EstTime or 7)
        -- Re-read after waiting: a manual action may have consumed the filet.
        local fresh
        for _, item in ipairs(invoke(token, "RequestRestaurauntData") or {}) do
            if item.ID == filet.ID and item.CF == filet.CF and item.CookedAt == filet.CookedAt
                and item.Name == "Fish Filet" then fresh = item; break end
        end
        if not fresh then return true end
        local before = {}
        for _, plate in ipairs(data:GetData("Plates") or {}) do before[plate.ID] = true end
        invoke(token, "Cook", name, fresh)
        local confirmed = false
        for _ = 1, 30 do
            pause(token, 0.1)
            for _, plate in ipairs(data:GetData("Plates") or {}) do
                if plate.Name == name and not before[plate.ID] then confirmed = true; break end
            end
            if confirmed then break end
        end
        assert(confirmed, "Server did not confirm a new " .. name .. " plate.")
        state.cooked += 1
        return true
    end
    local function step(token)
        activeCharacter = character()
        assert(data:IsDataLoaded(), "Player data is not ready.")
        if player:GetAttribute("ROPEN") ~= true then
            show("Open your restaurant to continue"); pause(token, 2); return
        end
        local waiting = customers()
        for _, npc in ipairs(waiting) do
            if plateFor(npc:GetAttribute("Order")) and serve(token, npc) then return end
        end
        local name = waiting[1] and waiting[1]:GetAttribute("Order") or "Nigiri"
        local plate, protected = plateFor(name)
        if plate or protected then show(protected and "Favorited Nigiri protected" or "Waiting for a Nigiri customer"); pause(token, 2); return end
        if not cook(token, name) then catch(token) end
    end
    function state.setEnabled(value)
        enabled = value == true and runtime.alive
        generation += 1
        if enabled and fishing:IsAutoFishEnabled() then ownsFishing = true end
        stopFishing()
        stopCutting()
        if toggle then toggle:Set(enabled, false) end
        show(enabled and "Starting" or "Stopped")
        if worker or not enabled then return end
        worker = true
        task.spawn(function()
            while enabled and runtime.alive do
                local token = generation
                local ok, err = pcall(step, token)
                stopFishing()
                stopCutting()
                if not ok and err ~= cancelled and generation == token and runtime.alive then
                    state.setEnabled(false)
                    show("Stopped: " .. tostring(err))
                    warn("LUB Fishing Chef: " .. tostring(err))
                end
                task.wait(0.5)
            end
            worker = false
        end)
    end
    table.insert(runtime.cleanups, function()
        enabled = false
        generation += 1
        stopFishing()
        stopCutting()
    end)
    local section = tab:Section({Title = "Auto Farm", Opened = true})
    toggle = section:Toggle({Title = "Autofarm", Value = false, Callback = state.setEnabled})
    status = section:Paragraph({Title = "Farm Status", Desc = "Stopped"})
    section:Button({Title = "Set fishing spot", Desc = "Use your current position and facing direction for this session.", Callback = function()
        if not runtime.alive then return end
        if enabled then show("Stop Autofarm before changing the fishing spot."); return end
        local char, _, root = character()
        if not validator:CanCastFromCharacter(char) then show("Face fishable water before setting the spot."); return end
        customSpot = root.CFrame
        show("Fishing spot saved for this session")
    end})
    section:Paragraph({Title = "Full routine", Desc = "Fish, cut, cook Nigiri and serve your own Nigiri customers. Favorites and pond fish stay protected. Open your restaurant and enable Autofarm."})
    show("Stopped")
    -- Start explicitly: loading a new game module must not consume inventory.
end
