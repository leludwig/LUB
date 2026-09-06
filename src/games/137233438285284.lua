-- Chicken Farm: collection and full-farm sequence from BrainrotPolice.
-- LUB changes: WindUI/config integration, eggs-only mode and stop/unload guards.
return function(tab, data)
    local env = getgenv()
    local runtime = env.LUBRuntime
    local plr = game:GetService("Players").LocalPlayer
    local place = tostring(game.PlaceId)
    local setdata = type(data[place]) == "table" and data[place] or {}
    data[place] = setdata
    local restoreEggs = setdata.collect_eggs_only == true
    local restoreFarm = setdata.farming == true and not restoreEggs
    env.Farming = false

    local section = tab:Section({ Title = "Auto Farm", Icon = "egg", Opened = true })
    local status, farmToggle, eggToggle
    local mode, generation = "off", 0
    local addedCon
    local setMode

    local function active(token)
        return runtime.alive and mode ~= "off" and generation == token
    end
    local function disconnect()
        if addedCon then addedCon:Disconnect(); addedCon = nil end
    end
    local function setStatus(text)
        if status and runtime.alive then status:SetDesc(text) end
    end
    local function guarded(token, callback)
        local ok, err = pcall(callback)
        if not ok and active(token) then
            setMode("off")
            setStatus("Collection stopped: " .. tostring(err))
            warn("LUB Chicken Farm: " .. tostring(err))
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
        "UNg","DNg","TNg","QdNg","QnNg","SxNg","SpNg","OcNg","NoNg","Ce","UCe"
    }
    local suffixValue = {}
    for i, suf in ipairs(suffixes) do suffixValue[suf] = 1000 ^ i end
    local function parseSuffixedNumber(str)
        str = str:gsub("[%$,%s]", "")
        local numberPart, suffixPart = str:match("^(-?%d*%.?%d+)(%a*)$")
        local base = tonumber(numberPart)
        if suffixPart == "" then return base end
        local multiplier = suffixValue[suffixPart]
        return base * multiplier
    end

    local function run(token, eggsOnly)
        if not active(token) then return end
        local mainEvent = game:GetService("ReplicatedStorage").Paper.Remotes.__remoteevent
        local mainFunction, cashval, buyBtns
        -- These original dependencies are only needed by the full farm.
        if not eggsOnly then
            mainFunction = game:GetService("ReplicatedStorage").Paper.Remotes.__remotefunction
            cashval = plr.PlayerGui.Main.Currencies.Cash.List.Amount
            buyBtns = workspace.Plots[plr.Name].Buttons.BuyChickens
        end

        -- Original new-egg sequence, including its one-second delay.
        -- Subscribe before scanning so eggs appearing during the scan aren't missed.
        addedCon = workspace.Eggs.ChildAdded:Connect(function(c)
            guarded(token, function()
                task.wait(1)
                if not active(token) then return end
                mainEvent:FireServer("Collect Egg", c.Name)
                task.wait()
                if not active(token) then return end
                c:Destroy()
                if not eggsOnly then mainFunction:InvokeServer("Deposit Eggs") end
            end)
        end)

        -- Original existing-egg sequence: collect, yield, destroy locally.
        for i, v in pairs(workspace.Eggs:GetChildren()) do
            if not active(token) then return end
            mainEvent:FireServer("Collect Egg", v.Name)
            task.wait()
            if not active(token) then return end
            v:Destroy()
        end
        task.wait()
        if not active(token) then return end
        if not eggsOnly then mainFunction:InvokeServer("Deposit Eggs") end
        if not active(token) then return end
        setStatus(eggsOnly and "Collecting existing and new eggs." or "Autofarm running.")
        if eggsOnly then return end

        -- Original full-farm actions and waits. Never entered in eggs-only mode.
        while active(token) do
            mainFunction:InvokeServer("Collect Cash")
            task.wait()
            if not active(token) then return end
            mainFunction:InvokeServer("Upgrade Process Level")
            task.wait()
            if not active(token) then return end
            local tobuy = 0
            local result = parseSuffixedNumber(cashval.Text)
            if parseSuffixedNumber(buyBtns.Buy100.Button.UI.Cost.Text) <= result then
                tobuy = 100
            elseif parseSuffixedNumber(buyBtns.Buy25.Button.UI.Cost.Text) <= result then
                tobuy = 25
            elseif parseSuffixedNumber(buyBtns.Buy5.Button.UI.Cost.Text) <= result then
                tobuy = 5
            elseif parseSuffixedNumber(buyBtns.Buy1.Button.UI.Cost.Text) <= result then
                tobuy = 1
            end
            mainFunction:InvokeServer("Buy Chickens", tobuy)
            task.wait()
            if not active(token) then return end
            mainFunction:InvokeServer("Merge Chickens")
            task.wait(1)
        end
    end

    setMode = function(nextMode)
        if not runtime.alive then return end
        generation = generation + 1
        local token = generation
        disconnect()
        mode = nextMode
        env.Farming = mode == "farm"
        setdata.farming = mode == "farm"
        setdata.collect_eggs_only = mode == "eggs"
        -- WindUI: false suppresses callbacks when updating the other switch.
        if farmToggle then farmToggle:Set(setdata.farming, false) end
        if eggToggle then eggToggle:Set(setdata.collect_eggs_only, false) end
        env.LUBSaveConfig(data)
        setStatus(mode == "off" and "Collection stopped." or "Starting collection...")
        if mode ~= "off" then
            local eggsOnly = mode == "eggs"
            task.spawn(function() guarded(token, function() run(token, eggsOnly) end) end)
        end
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
        Desc = "Collect existing and new eggs. No depositing, cash, upgrades, purchases or merging.",
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
        disconnect()
    end)
    setMode(restoreEggs and "eggs" or restoreFarm and "farm" or "off")
end
