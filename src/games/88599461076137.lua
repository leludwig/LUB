-- Fishing Chef: recorded fishing and kitchen remotes.
return function(tab)
    local env = getgenv()
    local runtime = env.LUBRuntime
    local player = game:GetService("Players").LocalPlayer
    local rs = game:GetService("ReplicatedStorage")
    local knit = require(rs.Packages.Knit)
    local fishing = knit.GetController("FishingController")
    local backpack = knit.GetController("Backpack")
    local data = knit.GetController("DataController")
    local validator = require(rs.Shared.FishingCastValidator)
    local recipes = require(rs.Modules.CookingConfig)
    local fishIndex = require(rs.Shared.FishIndex)
    local remotes = rs.Packages.Knit.Services.Fish
    local enabled, generation, worker = false, 0, false
    local mode, selectedRecipe = "farm", "Nigiri"
    local ownsFishing = false
    local castSession, fishingSpot
    local goToSpotOnStart = false
    local resolveDelay = 5
    local activeCharacter
    local status
    local toggles = {}
    local state = { phase = "Stopped", caught = 0, cooked = 0, served = 0 }
    runtime.fishingChef = state
    local cancelled = {}
    local function restoreBackpack()
        player:SetAttribute("Backpack", true)
        pcall(function() backpack:SetBackpackEnabled(true) end)
    end
    -- A direct CastRequest triggers the game's hide action without its normal
    -- minigame completion path. Also repair a bar hidden by an earlier run.
    restoreBackpack()
    runtime.track(remotes.RE.CastResponse.OnClientEvent:Connect(function(response)
        if castSession and castSession.token == generation then
            castSession.received = true
            castSession.response = response
            task.defer(function()
                if runtime.alive and ownsFishing then restoreBackpack() end
            end)
        end
    end))

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
    local function stopFishing()
        local restore = ownsFishing or castSession ~= nil
        if castSession then
            castSession = nil
            pcall(function() remotes.RF.MinigameResolved:InvokeServer(false) end)
        end
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
    local function fishFor(recipe, requiredFish)
        for _, item in ipairs(data:GetData("Fish") or {}) do
            if item.ID ~= nil and not favorite("FavoriteFish", item.ID)
                and (not requiredFish or item.Name == requiredFish)
                and (not recipe.RequiredFish or recipe.RequiredFish[item.Name]) then return item end
        end
    end
    local function available(name)
        local recipe = recipes[name]
        if not recipe then return false end
        local level = data:GetData("Level") or 1
        local stallLevel = plot().STALL:GetAttribute("Level") or 1
        if level < (recipe.PlayerLevel or 1) or stallLevel < (recipe.StallLevel or 1) then return false end
        if recipe.RequiresQuest and not table.find(data:GetData("CompletedQuests") or {}, recipe.RequiresQuest) then return false end
        return true
    end
    local function perfect(item)
        -- CookingFormula labels quality 4 as Perfect (five stars).
        -- Dish presentation clamps Data to 1..4, including Sashimi.
        return type(item.Data) == "number" and item.Data >= 4
    end
    local function normalize(text)
        return type(text) == "string" and text:lower():gsub("[%s_%-]+", "") or ""
    end
    local function order(npc)
        local raw = npc:GetAttribute("Order")
        local text = npc:GetAttribute("OrderText") or raw
        if type(raw) ~= "string" or type(text) ~= "string" then return end
        local name = recipes[raw] and raw
        if not name then
            for recipe in pairs(recipes) do
                if text:sub(-#recipe) == recipe and (not name or #recipe > #name) then name = recipe end
            end
        end
        if not name then return end
        if text == name then return name end
        -- OrderText is the displayed order, e.g. "Bluefin Tuna Sushi".
        -- Unknown fish labels must never fall back to an arbitrary ingredient.
        local suffix = " " .. name
        if text:sub(-#suffix) ~= suffix then return end
        local label = normalize(text:sub(1, -#suffix - 1))
        for id, fish in pairs(fishIndex) do
            if type(fish) == "table" and (normalize(id) == label or normalize(fish.name) == label) then return name, id end
        end
    end
    local function orderValid(npc, name, requiredFish)
        local currentName, currentFish = order(npc)
        local owner = npc and npc:FindFirstChild("Owner")
        return npc and npc.Parent and owner and owner.Value == player.Name
            and npc:GetAttribute("Arrived") and not npc:GetAttribute("Despawn")
            and npc:GetAttribute("WaitingForFood") ~= false and currentName == name and currentFish == requiredFish
    end
    local function customers()
        local result = {}
        for _, npc in ipairs(workspace.Code.ActiveNPCs:GetChildren()) do
            local name, requiredFish = order(npc)
            if name and orderValid(npc, name, requiredFish) then table.insert(result, npc) end
        end
        return result
    end
    local function plateFor(name, requiredFish)
        local selected
        for _, plate in ipairs(data:GetData("Plates") or {}) do
            if plate.Name == name then
                -- StoreFood chooses the plate on the server, so do not serve a
                -- recipe with a protected plate when selection is ambiguous.
                if favorite("FavoritePlates", plate.ID) then return nil, true end
                if not requiredFish or plate.CF == requiredFish then selected = selected or plate end
            end
        end
        return selected, false
    end
    local function serve(token, npc)
        local name, requiredFish = order(npc)
        if not name then return false end
        show("Serving " .. name)
        check(token)
        local owner = npc:FindFirstChild("Owner")
        if not npc.Parent or not owner or owner.Value ~= player.Name
            or npc:GetAttribute("Despawn") or npc:GetAttribute("WaitingForFood") == false
            or not orderValid(npc, name, requiredFish) or not plateFor(name, requiredFish) then return false end
        local before = (data:GetData("NightMarket") or {}).CustomersServedTotal or 0
        fire(token, "StoreFood", npc)
        for _ = 1, 30 do
            pause(token, 0.1)
            local after = (data:GetData("NightMarket") or {}).CustomersServedTotal or 0
            if after > before then state.served += after - before; return true end
        end
        if restore then restoreBackpack() end
        error("Server did not confirm serving " .. name .. ". Check customer availability and interaction distance.")
    end
    local function catch(token)
        show("Checking current fishing spot")
        local char, humanoid, root = character()
        if mode == "fish" and goToSpotOnStart then
            goToSpotOnStart = false
            if fishingSpot then
                check(token)
                show("Moving to saved fishing spot")
                root.CFrame = fishingSpot
                root.AssemblyLinearVelocity = Vector3.zero
                pause(token, 0.5)
            end
        end
        if fishingSpot then
            local here, saved = root.CFrame.Position, fishingSpot.Position
            local dx, dy, dz = here.X - saved.X, here.Y - saved.Y, here.Z - saved.Z
            assert(dx * dx + dy * dy + dz * dz <= 9, "Return to your saved fishing spot or set a new one. LUB will not move you automatically.")
        end
        assert(validator:CanCastFromCharacter(char), "No fishable water ahead. Stand by water and face it, then restart. LUB will not move you.")
        local rod
        for _, container in ipairs({char, player.Backpack}) do
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") and tool:GetAttribute("IsRod") then rod = tool; break end
            end
        end
        assert(rod, "No fishing rod found.")
        ownsFishing = true
        fishing:SetAutoFishEnabled(false)
        humanoid:EquipTool(rod)
        pause(token, 0.1)
        local before = data:GetData("FishCaught") or 0
        local session = {token = token}
        castSession = session
        show("Casting via remote")
        invoke(token, "CastRequest", 0.85373490388447)
        for _ = 1, 50 do
            if session.received then break end
            pause(token, 0.1)
        end
        assert(session.received and type(session.response) == "table" and session.response.fish,
            "Server did not confirm the cast. Check your position and rod.")
        show("Resolving catch via remote")
        pause(token, resolveDelay)
        invoke(token, "MinigameResolved", true)
        for _ = 1, 50 do
            if (data:GetData("FishCaught") or 0) > before then break end
            pause(token, 0.1)
        end
        local gained = (data:GetData("FishCaught") or 0) - before
        if gained <= 0 then
            stopFishing()
            show("Catch not confirmed; casting again")
            pause(token, 1)
            return
        end
        castSession = nil
        state.caught += gained
        stopFishing()
    end
    local function cook(token, name, npc, requiredFish)
        local function checkOrder()
            check(token)
            if npc and (player:GetAttribute("ROPEN") ~= true or not orderValid(npc, name, requiredFish)) then error(cancelled, 0) end
        end
        checkOrder()
        local recipe = recipes[name]
        local items = invoke(token, "RequestRestaurauntData")
        local filet
        for _, item in ipairs(items or {}) do
            if item.Name == "Fish Filet" and perfect(item)
                and (not requiredFish or item.CF == requiredFish)
                and (not recipe.RequiredFish or recipe.RequiredFish[item.CF]) then filet = item; break end
        end
        checkOrder()
        local score
        if not filet then
            local item = fishFor(recipe, requiredFish)
            if not item then return false end
            show("Cutting " .. item.Name)
            local goals = invoke(token, "StartCutSession")
            assert(type(goals) == "table" and #goals == 2, "Unexpected cutting session; stopped.")
            score = 0
            for index, goal in ipairs(goals) do
                assert(type(goal) == "number" and goal >= 0 and goal <= 1, "Invalid cutting target.")
                -- Restore the descending pass and original inter-cut delay.
                local duration = (math.pi - math.asin(2 * goal - 1)) / 2
                local started = os.clock()
                pause(token, duration)
                local elapsed = os.clock() - started
                local cursor = (math.sin(2 * elapsed) + 1) / 2
                score += math.clamp(1 - math.abs(goal - cursor) / 0.2, 0, 1)
                fire(token, "CutAction", index, elapsed)
                pause(token, 0.25)
            end
            checkOrder()
            if favorite("FavoriteFish", item.ID) then return false end
            assert(score >= 1.3, "Cut timing missed Perfect quality; fish was not consumed. Restart to try again.")
            invoke(token, "CutFish", item.ID, score)
            items = invoke(token, "RequestRestaurauntData")
            for _, candidate in ipairs(items or {}) do
                if candidate.Name == "Fish Filet" and candidate.CF == item.Name and perfect(candidate) then filet = candidate; break end
            end
            assert(filet, "Server did not confirm a Perfect filet. Stopped before cooking.")
        end
        show("Cooking " .. name)
        -- EstTime describes the manual minigame, not a confirmed server cooldown.
        -- Submit as soon as a current Perfect filet exists; confirm the result.
        local fresh
        for _, item in ipairs(invoke(token, "RequestRestaurauntData") or {}) do
            if item.ID == filet.ID and item.CF == filet.CF and item.CookedAt == filet.CookedAt
                and item.Name == "Fish Filet" and perfect(item) then fresh = item; break end
        end
        if not fresh then return true end
        checkOrder()
        if not available(name) then return true end
        local before = {}
        for _, plate in ipairs(data:GetData("Plates") or {}) do before[plate.ID] = true end
        invoke(token, "Cook", name, fresh)
        local confirmed = false
        for _ = 1, 30 do
            pause(token, 0.1)
            for _, plate in ipairs(data:GetData("Plates") or {}) do
                if plate.Name == name and not before[plate.ID] then
                    assert(plate.CF == fresh.CF, "Server returned a dish with a different fish. Stopped before serving.")
                    assert(perfect(plate), "Server returned a dish without confirmed Perfect quality. Stopped before serving.")
                    confirmed = true; break
                end
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
        if mode == "fish" then catch(token); return end
        if mode == "cook" then
            local name = selectedRecipe
            if not available(name) then
                show(name .. " is locked: check your level, stall and recipe quest")
                pause(token, 2)
            elseif not cook(token, name) then
                show("Waiting for Perfect filets or fish to cut: " .. name)
                pause(token, 2)
            end
            return
        end
        if player:GetAttribute("ROPEN") ~= true then
            show("Open your restaurant to continue"); pause(token, 2); return
        end
        local waiting = customers()
        for _, npc in ipairs(waiting) do
            local name, requiredFish = order(npc)
            if plateFor(name, requiredFish) and serve(token, npc) then return end
        end
        for _, npc in ipairs(waiting) do
            local name, requiredFish = order(npc)
            local plate, protected = plateFor(name, requiredFish)
            if available(name) and not plate and not protected then
                if not cook(token, name, npc, requiredFish) then catch(token) end
                return
            end
        end
        show(#waiting == 0 and "Waiting for a customer order" or "Waiting: orders locked, plates protected or serving pending")
        pause(token, 2)
    end
    function state.setMode(nextMode, value)
        assert(nextMode == "farm" or nextMode == "fish" or nextMode == "cook", "Invalid mode")
        if not value and mode ~= nextMode then return end
        mode = nextMode
        enabled = value == true and runtime.alive
        goToSpotOnStart = enabled and mode == "fish"
        state.mode = enabled and mode or nil
        generation += 1
        if enabled and fishing:IsAutoFishEnabled() then ownsFishing = true end
        stopFishing()
        for key, control in pairs(toggles) do control:Set(enabled and key == mode, false) end
        show(enabled and "Starting" or "Stopped")
        if worker or not enabled then return end
        worker = true
        task.spawn(function()
            while enabled and runtime.alive do
                local token = generation
                local ok, err = pcall(step, token)
                stopFishing()
                if not ok and err ~= cancelled and generation == token and runtime.alive then
                    state.setMode(mode, false)
                    show("Stopped: " .. tostring(err))
                    warn("LUB Fishing Chef: " .. tostring(err))
                end
                task.wait(0.1)
            end
            worker = false
        end)
    end
    function state.setEnabled(value) state.setMode("farm", value) end
    table.insert(runtime.cleanups, function()
        enabled = false
        generation += 1
        stopFishing()
    end)
    local section = tab:Section({Title = "Auto Farm", Opened = true})
    toggles.farm = section:Toggle({Title = "Autofarm", Value = false, Callback = state.setEnabled})
    toggles.fish = section:Toggle({Title = "Auto Fish", Value = false, Callback = function(value) state.setMode("fish", value) end})
    local names = {}
    for name in pairs(recipes) do table.insert(names, name) end
    table.sort(names)
    section:Dropdown({Title = "Cook recipe", Values = names, Value = selectedRecipe, Multi = false, Callback = function(name)
        if not runtime.alive or not recipes[name] then return end
        selectedRecipe = name
        if enabled and mode == "cook" then state.setMode("cook", true) end
    end})
    toggles.cook = section:Toggle({Title = "Auto Cook", Value = false, Callback = function(value) state.setMode("cook", value) end})
    status = section:Paragraph({Title = "Farm Status", Desc = "Stopped"})
    section:Button({Title = "Set fishing spot", Desc = "Save your current position and facing direction for this session.", Callback = function()
        if not runtime.alive then return end
        if enabled then show("Stop the current mode before setting a fishing spot."); return end
        local char, _, root = character()
        if not validator:CanCastFromCharacter(char) then show("Face fishable water before setting the spot."); return end
        fishingSpot = root.CFrame
        show("Fishing spot saved for this session")
    end})
    section:Button({Title = "Go to fishing spot", Desc = "Move once to your saved spot, only when you click this button.", Callback = function()
        if not runtime.alive then return end
        if enabled then show("Stop the current mode before moving to your saved spot."); return end
        if not fishingSpot then show("Set a fishing spot first."); return end
        local _, _, root = character()
        root.CFrame = fishingSpot
        root.AssemblyLinearVelocity = Vector3.zero
        show("At saved fishing spot")
    end})
    section:Slider({Title = "Resolve delay", Desc = "Seconds between confirmed cast and remote resolution. Increase if the server rejects catches.", Step = 0.1,
        Value = {Min = 0.1, Max = 12, Default = resolveDelay}, Callback = function(value)
            if type(value) == "number" and value == value then resolveDelay = math.clamp(value, 0.1, 12) end
        end})
    section:Button({Title = "Check fishing spot", Desc = "Check for fishable water ahead without moving or turning.", Callback = function()
        if not runtime.alive then return end
        local char = player.Character
        show(char and validator:CanCastFromCharacter(char) and "Current fishing spot is valid" or "Stand by fishable water and face it")
    end})
    show("Stopped")
    -- Start explicitly: loading a new game module must not consume inventory.
end
