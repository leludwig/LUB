-- Chicken Farm / 137233438285284. All farm logic and its WindUI controls live here.
return function(tab, data)
    local env = getgenv()
    local runtime = env.LUBRuntime
    local player = game:GetService("Players").LocalPlayer
    local storage = game:GetService("ReplicatedStorage")
    local place = tostring(game.PlaceId)
    local saved = type(data[place]) == "table" and data[place] or {}
    data[place] = saved
    -- Prefer eggs-only if a config has both modes enabled.
    local restoreEggs = saved.collect_eggs_only == true
    local restoreFarm = saved.farming == true and not restoreEggs
    env.Farming = false

    local function remote(name)
        local paper = storage:FindFirstChild("Paper")
        local remotes = paper and paper:FindFirstChild("Remotes")
        return remotes and remotes:FindFirstChild(name)
    end

    local section = tab:Section({ Title = "Auto Farm", Icon = "egg", Opened = true })
    local status, lastStatus
    local function setStatus(text)
        if status and runtime.alive and lastStatus ~= text then
            lastStatus = text
            status:SetDesc(text)
        end
    end
    local mode, generation = "off", 0
    local farmToggle, eggToggle

    -- Shared egg scan. The eggs-only mode never starts the full-farm loop below.
    local function collectEggs(token)
        local seen = setmetatable({}, { __mode = "k" })
        local count = 0
        local function active() return runtime.alive and mode ~= "off" and generation == token end
        while active() do
            local eggs, event = workspace:FindFirstChild("Eggs"), remote("__remoteevent")
            local failed = false
            if eggs and event then
                for _, egg in ipairs(eggs:GetChildren()) do
                    if not active() then return end
                    if egg.Parent == eggs and not seen[egg] then
                        local ok = pcall(function() event:FireServer("Collect Egg", egg.Name) end)
                        if not active() then return end
                        if ok then
                            seen[egg] = true
                            count = count + 1
                        else
                            failed = true
                        end
                        task.wait(0.05)
                    end
                end
                if active() then
                    setStatus(failed and "Collection request failed; retrying..." or "Collection requests: " .. tostring(count))
                end
            else
                setStatus("Waiting for eggs / game to load...")
            end
            task.wait(0.2)
        end
    end
    local suffixes = {
        "K","M","B","T","Qd","Qn","Sx","Sp","Oc","No","De",
        "UDe","DDe","TDe","QdDe","QnDe","SxDe","SpDe","OcDe","NoDe","Vt",
        "UVt","DVt","TVt","QdVt","QnVt","SxVt","SpVt","OcVt","NoVt","Tg",
        "UTg","DTg","TTg","QdTg","QnTg","SxTg","SpTg","OcTg","NoTg","qg",
        "Uqg","Dqg","Tqg","Qdqg","Qnqg","Sxqg","Spqg","Ocqg","Noqg","Qg",
        "UQg","DQg","TQg","QdQg","QnQg","SxQg","SpQg","OcQg","NoQg","sg",
        "Usg","Dsg","Tsg","Qdsg","Qnsg","Sxsg","Spsg","Ocsg","Nosg","Sg",
        "USg","DSg","TSg","QdSg","QnSg","SxSg","SpSg","OcSg","NoSg","Og",
        "UOg","DOg","TOg","QdOg","QnOg","SxOg","SpOg","OcOg","NoOg","Ng",
        "UNg","DNg","TNg","QdNg","QnNg","SxNg","SpNg","OcNg","NoNg","Ce","UCe",
    }
    local multipliers = { [""] = 1 }
    for index, suffix in ipairs(suffixes) do multipliers[suffix] = 1000 ^ index end
    local function number(text)
        local base, suffix = tostring(text):gsub("[%$,%s]", ""):match("^(%d*%.?%d+)(%a*)$")
        return tonumber(base) and multipliers[suffix] and tonumber(base) * multipliers[suffix] or nil
    end

    local function setMode(nextMode)
        if not runtime.alive then return end
        generation = generation + 1
        local token = generation
        mode = nextMode
        env.Farming = mode == "farm"
        saved.farming = mode == "farm"
        saved.collect_eggs_only = mode == "eggs"
        -- WindUI's second argument is isCallback: false updates the other switch silently.
        if farmToggle then farmToggle:Set(saved.farming, false) end
        if eggToggle then eggToggle:Set(saved.collect_eggs_only, false) end
        env.LUBSaveConfig(data)
        setStatus(mode == "off" and "Collection stopped." or "Starting collection...")
        if mode == "off" then return end
        task.spawn(function() collectEggs(token) end)
        if mode ~= "farm" then return end

        local function active() return runtime.alive and mode == "farm" and generation == token end
        local function invoke(action, argument)
            if not active() then return end
            local fn = remote("__remotefunction")
            if fn then
                if argument ~= nil then fn:InvokeServer(action, argument) else fn:InvokeServer(action) end
            end
        end
        task.spawn(function()
            while active() do
                local ok, err = pcall(function()
                    invoke("Deposit Eggs")
                    invoke("Collect Cash")
                    invoke("Upgrade Process Level")
                    if not active() then return end
                    -- Full-farm-only dependencies: egg mode does not access money or shop UI.
                    local gui = player:FindFirstChild("PlayerGui")
                    local main = gui and gui:FindFirstChild("Main")
                    local plots = workspace:FindFirstChild("Plots")
                    local plot = plots and plots:FindFirstChild(player.Name)
                    if main and plot then
                        local cash = number(main.Currencies.Cash.List.Amount.Text)
                        local buttons = plot.Buttons.BuyChickens
                        for _, amount in ipairs({ 100, 25, 5, 1 }) do
                            local price = number(buttons["Buy" .. amount].Button.UI.Cost.Text)
                            if cash and price and price <= cash then invoke("Buy Chickens", amount); break end
                        end
                    end
                    invoke("Merge Chickens")
                end)
                if not ok and active() then warn("LUB Autofarm: " .. tostring(err)) end
                task.wait(1)
            end
        end)
    end

    farmToggle = section:Toggle({
        Title = "Autofarm",
        Desc = "Full farm: collect, deposit, cash, upgrades, buy and merge. Buy your first chicken first.",
        Value = false,
        Callback = function(value)
            if value then setMode("farm") elseif mode == "farm" then setMode("off") end
        end,
    })
    eggToggle = section:Toggle({
        Title = "Collect Eggs Only",
        Desc = "Only collect eggs. No depositing, cash, upgrades, purchases or merging.",
        Value = false,
        Callback = function(value)
            if value then setMode("eggs") elseif mode == "eggs" then setMode("off") end
        end,
    })
    status = section:Paragraph({ Title = "Collection Status", Desc = "Collection stopped." })
    table.insert(runtime.cleanups, function()
        generation = generation + 1
        mode = "off"
        env.Farming = false
    end)
    -- Restore after both controls exist; WindUI does not call initial callbacks.
    setMode(restoreEggs and "eggs" or restoreFarm and "farm" or "off")
end
