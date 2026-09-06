-- Chicken Farm. Modified for LUB: separate, mutually exclusive egg-only mode.
return function(section, data)
    local env = getgenv()
    local runtime = env.LUBRuntime
    local elements = env.LUBRequire("src/elements.lua")
    local Collector = env.LUBRequire("src/modules/egg_collector.lua")
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

    elements:Label("Auto Farm", section)
    elements:Label("Buy your first chicken before enabling the full Autofarm.", section)
    local status
    local collector = Collector.new({
        getEggs = function() return workspace:FindFirstChild("Eggs") end,
        getRemote = function() return remote("__remoteevent") end,
        isAlive = function() return runtime.alive end,
        status = function(text) if status then status.Text = text end end,
    })

    local mode, generation = "off", 0
    local farmToggle, eggToggle
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
        generation = generation + 1
        local token = generation
        mode = nextMode
        env.Farming = mode == "farm"
        collector:Stop()
        saved.farming = mode == "farm"
        saved.collect_eggs_only = mode == "eggs"
        if farmToggle then farmToggle:Set(saved.farming, true) end
        if eggToggle then eggToggle:Set(saved.collect_eggs_only, true) end
        env.LUBSaveConfig(data)
        if status then status.Text = mode == "off" and "Collection stopped." or "Starting collection..." end
        if mode == "off" then return end
        collector:Start()
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

    farmToggle = elements:Toggle("Autofarm", section, false, function(value)
        if value then setMode("farm") elseif mode == "farm" then setMode("off") end
    end)
    eggToggle = elements:Toggle("Collect Eggs Only", section, false, function(value)
        if value then setMode("eggs") elseif mode == "eggs" then setMode("off") end
    end)
    elements:Label("Collect Eggs Only collects existing and newly spawned eggs.\nNo depositing, cash collection, upgrades, purchases or merging.", section)
    status = elements:Label("Collection stopped.", section)
    table.insert(runtime.cleanups, function()
        generation = generation + 1
        mode = "off"
        env.Farming = false
        collector:Stop()
    end)
    -- Synchronous restore invalidates both deferred initial toggle callbacks.
    setMode(restoreEggs and "eggs" or restoreFarm and "farm" or "off")
end
