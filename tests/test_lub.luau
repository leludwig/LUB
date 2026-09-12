-- LUB behavior with deterministic Roblox/WindUI test doubles. Run tools/test.py.
local passed = 0
local function expect(value, message) assert(value, message or "Expectation failed") end

local function setup(options)
    options = options or {}
    local state = { now = 0, jobs = {}, calls = {}, warnings = {}, saved = {}, destroyed = 0, trace = {},
        serverRequests = {}, joins = {}, nativePrompts = {} }
    local globals = setmetatable({}, { __index = getfenv() })
    state.globals = globals
    globals._G = {}
    globals.getgenv = function() return globals end
    globals.warn = function(message) table.insert(state.warnings, message) end
    globals.os = setmetatable({ clock = function() return state.now end }, { __index = os })
    local function enqueue(thread, delay)
        table.insert(state.jobs, { thread = thread, at = state.now + (delay or 0) })
    end
    globals.task = {
        spawn = function(fn) enqueue(coroutine.create(fn)) end,
        defer = function(fn) enqueue(coroutine.create(fn)) end,
        wait = function(delay) return coroutine.yield(delay or 0.001) end,
    }
    function state:advance(seconds)
        local finish = self.now + seconds
        local iterations = 0
        while true do
            local index, earliest
            for i, job in ipairs(self.jobs) do
                if job.at <= finish and (not earliest or job.at < earliest) then index, earliest = i, job.at end
            end
            if not index then break end
            self.now = earliest
            local job = table.remove(self.jobs, index)
            local ok, delay = coroutine.resume(job.thread)
            assert(ok, delay)
            if coroutine.status(job.thread) ~= "dead" then enqueue(job.thread, delay) end
            iterations = iterations + 1
            assert(iterations < 20000, "Runaway background loop")
        end
        self.now = finish
    end
    local function signal()
        local event = { listeners = {} }
        function event:Connect(fn)
            local listener = { connected = true, fn = fn }
            table.insert(self.listeners, listener)
            return { Disconnect = function() listener.connected = false end }
        end
        function event:Fire(...)
            local args = table.pack(...)
            for _, listener in ipairs(self.listeners) do
                if listener.connected then globals.task.spawn(function() listener.fn(table.unpack(args, 1, args.n)) end) end
            end
        end
        return event
    end
    local events = { Activated = true, FocusLost = true, InputBegan = true, InputChanged = true, InputEnded = true,
        ErrorMessageChanged = true, ChildAdded = true, ChildRemoved = true, OnClientEvent = true }
    local methods = {}
    function methods:GetChildren() return table.clone(self._children) end
    function methods:GetDescendants()
        local children = {}
        for _, child in ipairs(self._children) do
            table.insert(children, child)
            for _, descendant in ipairs(child:GetDescendants()) do table.insert(children, descendant) end
        end
        return children
    end
    function methods:FindFirstChild(name, recursive)
        for _, child in ipairs(self._children) do if child.Name == name then return child end end
        if recursive then
            for _, child in ipairs(self:GetDescendants()) do if child.Name == name then return child end end
        end
        return nil
    end
    function methods:WaitForChild(name) return self:FindFirstChild(name) end
    function methods:FindFirstChildOfClass(class)
        for _, child in ipairs(self:GetChildren()) do if child.ClassName == class then return child end end
    end
    function methods:FindFirstChildWhichIsA(class, recursive)
        for _, child in ipairs(recursive and self:GetDescendants() or self:GetChildren()) do
            if child:IsA(class) then return child end
        end
        return nil
    end
    function methods:FindFirstAncestorWhichIsA(class)
        local ancestor = self.Parent
        while ancestor do
            if ancestor:IsA(class) then return ancestor end
            ancestor = ancestor.Parent
        end
        return nil
    end
    function methods:GetPropertyChangedSignal(name)
        if not self._signals[name] then self._signals[name] = signal() end
        return self._signals[name]
    end
    function methods:SetAttribute(name, value) self._attrs[name] = value end
    function methods:GetAttribute(name) return self._attrs[name] end
    function methods:Destroy()
        if self.Parent == state.eggs then
            state.destroyed = state.destroyed + 1
            table.insert(state.trace, { action = "Destroy", name = self.Name, at = state.now })
        end
        self.Parent = nil
        for _, child in ipairs(self:GetChildren()) do child:Destroy() end
    end
    function methods:IsA(class) return self.ClassName == class or (class == "BasePart" and self.ClassName == "Part") end
    local function node(class, name, parent)
        local object = setmetatable({ _props = { ClassName = class, Name = name or class }, _children = {}, _signals = {}, _attrs = {} }, {
            __index = function(self, key)
                if methods[key] then return methods[key] end
                if events[key] then
                    if not self._signals[key] then self._signals[key] = signal() end
                    return self._signals[key]
                end
                if self._props[key] ~= nil then return self._props[key] end
                return methods.FindFirstChild(self, key)
            end,
            __newindex = function(self, key, value)
                if key == "Parent" then
                    local old = self._props.Parent
                    if old then
                        for i, child in ipairs(old._children) do if child == self then table.remove(old._children, i); break end end
                    end
                    if value then table.insert(value._children, self) end
                    self._props.Parent = value
                    if old and old ~= value then old.ChildRemoved:Fire(self) end
                    if value and old ~= value then value.ChildAdded:Fire(self) end
                end
                self._props[key] = value
                if self._signals[key] then self._signals[key]:Fire() end
            end,
        })
        object.Parent = parent
        return object
    end
    state.node = node
    globals.Instance = { new = function(class) return node(class) end }
    local function enum(path)
        return setmetatable({}, { __index = function(self, key)
            local value = enum(path .. "." .. key); rawset(self, key, value); return value
        end })
    end
    globals.Enum = enum("Enum")
    globals.Color3 = { fromRGB = function(...) return { ... } end }
    globals.UDim = { new = function(scale, offset) return { Scale = scale, Offset = offset } end }
    globals.UDim2 = {
        new = function(xs, xo, ys, yo) return { X = { Scale = xs or 0, Offset = xo or 0 }, Y = { Scale = ys or 0, Offset = yo or 0 } } end,
    }
    globals.UDim2.fromOffset = function(x, y) return globals.UDim2.new(0, x, 0, y) end
    globals.UDim2.fromScale = function(x, y) return globals.UDim2.new(x, 0, y, 0) end
    globals.Vector2 = { new = function(x, y) return { X = x, Y = y } end }
    globals.Vector3 = { new = function(x, y, z)
        return setmetatable({ X = x, Y = y, Z = z }, { __add = function(a, b)
            return globals.Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
        end })
    end }
    globals.CFrame = { new = function(position) return { Position = position } end }
    globals.workspace = node("Workspace")
    local camera = node("Camera")
    camera.ViewportSize = { X = 1280, Y = 720 }
    globals.workspace.CurrentCamera = camera
    local storage = node("ReplicatedStorage")
    local player = node("Player", "TestPlayer")
    local services = {
        ReplicatedStorage = storage, Players = { LocalPlayer = player }, CoreGui = node("CoreGui"),
        UserInputService = node("UserInputService"), GuiService = node("GuiService"),
        HttpService = {
            UrlEncode = function(_, value)
                return (value:gsub("[^%w%-_%.~]", function(c) return string.format("%%%02X", string.byte(c)) end))
            end,
            JSONDecode = function(_, text)
                if text == SOURCES["src/gameslist.json"] then return GAME_LIST end
                if text == "invalid" then error("invalid config") end
                return state.saved[text]
            end,
            JSONEncode = function(_, value)
                state.encoding = (state.encoding or 0) + 1
                local key = "json:" .. state.encoding
                state.saved[key] = value
                return key
            end,
        },
        RunService = { Heartbeat = signal(), Set3dRenderingEnabled = function(_, enabled) state.rendering = enabled end },
        TweenService = {},
        TeleportService = {
            TeleportInitFailed = signal(),
            Teleport = function(_, id, target)
                state.rejoinCalls = (state.rejoinCalls or 0) + 1
                state.teleport = id; state.teleportPlayer = target
            end,
            TeleportToPlaceInstance = function(_, id, serverId, target)
                state.teleport = id; state.teleportPlayer = target
                table.insert(state.joins, { place = id, serverId = serverId, player = target })
                if options.joinError then error(options.joinError) end
            end,
            PromptExperienceDetailsAsync = function(_, target, universe)
                table.insert(state.nativePrompts, { player = target, universe = universe })
                if options.nativeError then error("Dialog unavailable") end
                if options.nativeDelay then globals.task.wait(options.nativeDelay) end
                return options.nativeAttempted and globals.Enum.PromptExperienceDetailsResult.TeleportAttempted
                    or globals.Enum.PromptExperienceDetailsResult.PromptClosed
            end,
        },
    }
    state.services = services
    globals.game = { PlaceId = options.place or 137233438285284, JobId = "current-server",
        IsLoaded = function() return true end, GetService = function(_, name) return assert(services[name], name) end }
    state.files = {}
    if options.config then state.saved.config = options.config; state.files["LUB/Config.json"] = "config" end
    if options.corrupt then state.files["LUB/Config.json"] = "invalid" end
    if not options.noFiles then
        globals.isfolder = function() return true end
        globals.makefolder = function() end
        globals.isfile = function(path) return state.files[path] ~= nil end
        globals.readfile = function(path) return assert(state.files[path], path) end
        globals.writefile = function(path, value) state.files[path] = value end
    end
    function state:world()
        self.eggs = node("Folder", "Eggs", globals.workspace)
        local paper = node("Folder", "Paper", storage)
        local remotes = node("Folder", "Remotes", paper)
        local event = node("RemoteEvent", "__remoteevent", remotes)
        event.FireServer = function(_, action, name)
            if state.failEvent then error("Temporary remote failure") end
            local call = { kind = "event", action = action, name = name, at = state.now }
            table.insert(state.calls, call)
            table.insert(state.trace, call)
        end
        local fn = node("RemoteFunction", "__remotefunction", remotes)
        fn.InvokeServer = function(_, action, value)
            table.insert(state.calls, { kind = "function", action = action, value = value, at = state.now })
            globals.task.wait(0.1)
        end
    end
    function state:egg(name) return node("Model", name, self.eggs) end
    function state:farmUI()
        local gui = node("PlayerGui", "PlayerGui", player)
        local main = node("ScreenGui", "Main", gui)
        local currencies = node("Folder", "Currencies", main)
        local cash = node("Folder", "Cash", currencies)
        local list = node("Folder", "List", cash)
        node("TextLabel", "Amount", list).Text = "$30K"
        local plots = node("Folder", "Plots", globals.workspace)
        local plot = node("Folder", player.Name, plots)
        local buttons = node("Folder", "Buttons", plot)
        local buyChickens = node("Folder", "BuyChickens", buttons)
        for _, amount in ipairs({ 100, 25, 5, 1 }) do
            local buy = node("Folder", "Buy" .. amount, buyChickens)
            local button = node("Folder", "Button", buy)
            local ui = node("Folder", "UI", button)
            node("TextLabel", "Cost", ui).Text = "$" .. amount .. "K"
        end
    end
    if not options.lateWorld then state:world() end
    if options.place == 122572082932179 then
        local remotes = node("Folder", "Remotes", storage)
        local bases = node("Folder", "Bases", globals.workspace)
        node("Model", "Base1", bases):SetAttribute("OwnerUserId", 900)
        player.UserId = 42
        local base = node("Model", "Base4", bases)
        base:SetAttribute("OwnerUserId", player.UserId)
        state.base = base
        local money = node("StringValue", "Money", node("Folder", "leaderstats", player))
        money.Value = "$1000"
        state.money = money
        local function addMoney(amount)
            money.Value = "$" .. tostring(tonumber(money.Value:sub(2)) + amount)
        end
        player.Character = node("Model", "Character")
        state.hrp = node("Part", "HumanoidRootPart", player.Character)
        state.hrp.CFrame = globals.CFrame.new(globals.Vector3.new(0, 0, 0))
        node("ModuleScript", "OreMetadata", storage).Module = {
            ByName = { ["Stone Ore"] = { seedCost = 100, baseIncome = 1, growTimeSeconds = 1 } },
            RarityRank = { Common = 1 },
        }
        node("ModuleScript", "GearMetadata", storage).Module = { List = function() return {} end }
        globals.require = function(module) return assert(module and module.Module, "Missing module") end
        local rollEvent = node("RemoteEvent", "RollerRollEvent", storage)
        state.crateEvent = node("RemoteEvent", "BaseCrateStateChanged", remotes)
        node("RemoteEvent", "AdminEventClockState", remotes)
        node("RemoteEvent", "AlienEventDialogue", remotes)
        local function prompt(parent, name, enabled, action)
            local part = node("Part", name .. "Part", parent)
            part.Position = globals.Vector3.new(10, 2, 30)
            local result = node("ProximityPrompt", name, part)
            result.Enabled = enabled
            result.ActionText = action or "Use"
            return result
        end
        local roller = node("Folder", "Roller", base)
        local lever = node("Part", "Lever", roller)
        lever.Position = globals.Vector3.new(10, 2, 30)
        local rollPrompt = node("ProximityPrompt", "RollPrompt", lever)
        rollPrompt.Enabled = true
        local pedestals = node("Folder", "OrePedestals", base)
        local pedestal = node("Model", "RolledOrePedestal1", pedestals)
        local buyPrompt = prompt(pedestal, "LocalRollingOreDisplayPrompt", true, "Buy")
        local spawnPoint = node("Part", "CrateSpawnPoint", node("Model", "CrateMaker", base))
        spawnPoint.Position = globals.Vector3.new(20, 2, 30)
        local pickPrompt = node("ProximityPrompt", "PickUpOresPrompt", spawnPoint)
        pickPrompt.Enabled = true
        local sellPrompt = prompt(node("Model", "SellerTable", base), "SellOresPrompt", false)
        local furnace = node("Model", "Furnace", base)
        furnace:SetAttribute("FurnacePurchased", false)
        state.furnaceRate = node("TextLabel", "CurrentProcessingRate", furnace)
        state.furnaceRate.Text = "$1000/s"
        node("TextLabel", "AmountRemaining", furnace).Text = "$0"
        node("Model", "Floor1", node("Folder", "Floors", base))
        local board = node("Model", "BaseUpgradesBoardFloor1", node("Folder", "BaseUpgradesBoards", base))
        if options.sellUpgrade then
            local row = node("Frame", "SpeedRow", board)
            node("TextLabel", "Label", row).Text = "Drill Speed"
            node("TextLabel", "UpgradeText", row).Text = "1 > 2"
            state.upgradePrice = node("TextButton", "TextButton", row)
            state.upgradePrice.Text = "$250"
        end
        state.prompts = {}
        globals.fireproximityprompt = function(p)
            expect(p.Enabled, "Used disabled prompt")
            table.insert(state.prompts, { name = p.Name, at = state.now })
            if p == rollPrompt then
                rollEvent.OnClientEvent:Fire({ baseName = "Base4", results = {
                    { pedestalName = "RolledOrePedestal1", oreName = "Stone Ore", rarity = "Common", seedCost = 100 },
                } })
            elseif p == buyPrompt then addMoney(-100)
            elseif p == pickPrompt then pickPrompt.Enabled = false; sellPrompt.Enabled = true
            elseif p == sellPrompt then pickPrompt.Enabled = true; sellPrompt.Enabled = false; addMoney(100) end
        end
        globals.getconnections = function() return {} end
        local spins = options.sellRewards and 2 or 0
        local daily = options.sellRewards == true
        for _, name in ipairs({ "BaseBuildTunnelAction", "BaseUpgradeDrillSpeed", "GetDailyRewardsState",
            "PlaytimeRewardsGetState", "OfflineEarningsClaimRequest", "GetLuckySpinState", "RequestLuckySpin", "CompleteLuckySpin" }) do
            local remote = node("RemoteFunction", name, remotes)
            remote.InvokeServer = function(_, ...)
                local args = table.pack(...)
                table.insert(state.calls, { action = name, args = args, at = state.now })
                globals.task.wait(0.05)
                if name == "BaseBuildTunnelAction" then
                    expect(args[1] == "Base4" and args[2] == 1 and args[3] == "Tunnel1" and args[4] == "EquipBest")
                    return { success = true, result = { inventoryCount = 0, changed = 0, equipped = {} } }
                elseif name == "BaseUpgradeDrillSpeed" then
                    expect(args[1] == "Base4" and args[2] == 1)
                    addMoney(-250)
                    state.upgradePrice.Text = "$100000"
                    return { success = true, state = { level = 2 } }
                elseif name == "GetDailyRewardsState" then return { isAvailable = daily }
                elseif name == "PlaytimeRewardsGetState" then
                    return { elapsed = 100, rewards = options.sellRewards and {
                        { index = 4, unlockAt = 50 }, { index = 5, unlockAt = 200 },
                    } or {} }
                elseif name == "GetLuckySpinState" then return { spins = spins, remaining = 999 }
                elseif name == "RequestLuckySpin" then
                    if spins <= 0 then return { ok = false } end
                    spins -= 1
                    return { ok = true, spinId = "spin-" .. spins, reward = "Ore" }
                end
                return { success = true }
            end
        end
        for _, name in ipairs({ "ClaimDailyReward", "PlaytimeRewardsClaim" }) do
            node("RemoteEvent", name, remotes).FireServer = function(_, ...)
                table.insert(state.calls, { action = name, args = table.pack(...), at = state.now })
                if name == "ClaimDailyReward" then daily = false end
                addMoney(10)
            end
        end
    end

    function state:load(path)
        local chunk, err = loadstring(assert(SOURCES[path], path), "@" .. path)
        assert(chunk, err)
        setfenv(chunk, globals)
        return chunk()
    end
    globals.loadstring = function(source, name)
        local chunk, err = loadstring(source, name)
        if chunk then setfenv(chunk, globals) end
        return chunk, err
    end
    -- WindUI 1.6.66 contract: :Set(v, false) suppresses callbacks; user callbacks
    -- run asynchronously; construction does not invoke the initial toggle value.
    state.controls = {}
    local function container(title, kind, parent)
        local result = { Title = title, Kind = kind, Parent = parent, Elements = {} }
        table.insert(state.controls, result)
        if parent then table.insert(parent.Elements, result) end
        for _, elementKind in ipairs({ "Section", "Paragraph", "Toggle", "Button", "Input", "Slider", "Dropdown" }) do
            result[elementKind] = function(self, config)
                local control = container(config.Title, elementKind, self)
                control.Desc = config.Desc
                control.Value = config.Value
                control.Callback = config.Callback
                if elementKind == "Button" then
                    -- Public objects exposed by WindUI 1.6.66's Button element.
                    control.UIElements = { ButtonIcon = { Position = globals.UDim2.new(1, 0, 0.5, 0) } }
                    control.ButtonFrame = { UIElements = { Container = {
                        TitleFrame = { Size = globals.UDim2.new(1, -20, 0, 0) },
                    } }, SetDesc = function(_, text) control.Desc = text end }
                end
                function control:SetDesc(text) self.Desc = text end
                function control:Set(value, isCallback)
                    self.Value = value
                    if (elementKind == "Input" or isCallback ~= false) and self.Callback then
                        globals.task.spawn(function() self.Callback(value) end)
                    end
                end
                -- Unlike Toggle, WindUI Input calls its callback for its initial value.
                if elementKind == "Input" and control.Callback then control.Callback(control.Value) end
                return control
            end
        end
        return result
    end
    globals.TEST_WINDUI = {
        CreateWindow = function(_, config)
            local window = { Tabs = {}, Config = config, Closed = false }
            state.window = window
            function window:Tab(tabConfig)
                local tab = container(tabConfig.Title, "Tab")
                table.insert(self.Tabs, tab)
                return tab
            end
            function window:SelectTab(index)
                assert(type(index) == "number" and self.Tabs[index], "WindUI requires a numeric tab index")
                self.Selected = index
            end
            function window:OnDestroy(fn) self.destroyCallback = fn end
            function window:Open() self.Closed = false end
            function window:Close() self.Closed = true end
            function window:Toggle() self.Closed = not self.Closed end
            function window:Destroy()
                self.Destroyed = true
                if self.destroyCallback then globals.task.spawn(self.destroyCallback) end
            end
            return window
        end,
    }
    local function serverResponse(url)
        table.insert(state.serverRequests, url)
        if options.listDelay then globals.task.wait(options.listDelay) end
        if options.listError then error("Server list request failed") end
        local page = url:find("&cursor=", 1, true) and 2 or 1
        local value = options.serverPages and options.serverPages[page] or {
            data = {
                { id = "current-server", playing = 1, maxPlayers = 6 },
                { id = "full-server", playing = 6, maxPlayers = 6 },
                { id = "empty-server", playing = 0, maxPlayers = 6 },
                { id = "open-server-1", playing = 2, maxPlayers = 6 },
                { id = "open-server-2", playing = 3, maxPlayers = 6 },
                { id = "open-server-3", playing = 4, maxPlayers = 6 },
            },
        }
        local token = "servers:" .. #state.serverRequests
        state.saved[token] = value
        return token
    end
    if options.executorRequest then
        globals.request = function(args)
            expect(args.Method == "GET" and args.Url:match("^https://games%.roblox%.com/"))
            return { StatusCode = options.httpStatus or 200, Body = serverResponse(args.Url) }
        end
    end
    globals.game.HttpGet = function(_, url)
        if url:match("^https://games%.roblox%.com/v1/games/%d+/servers/Public%?") then
            expect(not options.executorRequest, "Did not use available executor request")
            return serverResponse(url)
        end
        expect(url == "https://github.com/Footagesus/WindUI/releases/download/1.6.66/main.lua", "Unexpected dependency URL")
        if options.failWindUI then error("WindUI download failed") end
        return "return getgenv().TEST_WINDUI"
    end
    if options.legacy then
        globals.LUBRuntime = { alive = true, version = "2.4.0", cleanup = function() state.legacyStopped = true end }
    end
    if options.prepare then options.prepare(state, player, storage) end
    globals.LUBSources = SOURCES
    local initialized, initError = pcall(function() state:load("src/init.lua") end)
    if options.failWindUI then
        expect(not initialized and tostring(initError):find("WindUI download failed", 1, true))
    else
        assert(initialized, initError)
    end
    state:advance(0)
    function state:find(text)
        for _, control in ipairs(self.controls) do
            if control.Title == text then return control end
        end
        error("Missing control: " .. text)
    end
    function state:click(text)
        local object = self:find(text)
        if object.Kind == "Toggle" then
            object:Set(not object.Value)
        elseif object.Kind == "Tab" then
            for index, tab in ipairs(self.window.Tabs) do
                if tab == object then self.window:SelectTab(index) end
            end
        else
            globals.task.spawn(object.Callback)
        end
        self:advance(0)
    end
    return state
end

local function test(name, fn)
    fn()
    passed = passed + 1
    print("PASS " .. name)
end

local function eggCallsOnly(state)
    for _, call in ipairs(state.calls) do
        expect(call.kind == "event" and call.action == "Collect Egg", "Egg-only mode performed " .. call.action)
    end
end

test("WindUI has exactly three tabs and all registered games are listed and can be joined", function()
    local s = setup()
    expect(s.window.Config.Title == "LUB" and s.window.Config.NewElements == true)
    expect(#s.window.Tabs == 3 and s.window.Selected == 1)
    expect(s.window.Tabs[1].Title == "Game")
    expect(s.window.Tabs[2].Title == "Games List")
    expect(s.window.Tabs[3].Title == "Settings")
    s:click("Games List")
    local entries = 0
    for _, control in ipairs(s.window.Tabs[2].Elements) do if control.Kind == "Button" then entries = entries + 1 end end
    expect(entries == #GAME_LIST and s:find("Chicken Farm").Desc:find("137233438285284", 1, true))
    s:click("Sell Ores")
    expect(s.teleport == 122572082932179)
    s:advance(31)
    s:click("Chicken Farm")
    expect(s.window.Selected == 2 and s.teleport == 137233438285284, "Game button must join even from the same place")
    expect(s.teleportPlayer == s.services.Players.LocalPlayer, "Join must target the local player")
    s:advance(31)
    s:click("Fishing Chef")
    expect(s.teleport == 88599461076137)
    local section = s:find("Auto Farm")
    expect(section.Parent == s.window.Tabs[1])
    expect(section.Elements[1].Title == "Autofarm" and section.Elements[2].Title == "Collect Eggs Only")
    expect(#s.warnings == 0, table.concat(s.warnings, "\n"))
end)

test("Insert toggles the menu, ignores processed input and stops after unload", function()
    local s = setup()
    local input = s.services.UserInputService.InputBegan
    local key = { KeyCode = s.globals.Enum.KeyCode.Insert }
    expect(s.window.Config.ToggleKey == nil, "WindUI must not add a second keyboard shortcut")
    input:Fire(key, false); s:advance(0)
    expect(s.window.Closed, "Insert did not hide the menu")
    input:Fire(key, true); s:advance(0)
    expect(s.window.Closed, "Processed input toggled the menu")
    input:Fire({ KeyCode = s.globals.Enum.KeyCode.A }, false); s:advance(0)
    expect(s.window.Closed, "Unrelated key toggled the menu")
    input:Fire({ KeyCode = s.globals.Enum.KeyCode.RightShift }, false); s:advance(0)
    expect(s.window.Closed, "Right Shift must not toggle the menu")
    input:Fire(key, false); s:advance(0)
    expect(not s.window.Closed, "Insert did not reopen the menu")
    input:Fire(key, false)
    s.globals.LUBRuntime.cleanup(); s:advance(0)
    input:Fire(key, false); s:advance(0)
    expect(s.window.Destroyed and not s.window.Closed, "Queued or disconnected input changed an unloaded window")
end)

test("original existing-egg sequence fires, waits, then destroys each egg", function()
    local s = setup()
    s:egg("a"); s:egg("b")
    expect(#s.calls == 0, "Farm started by default")
    s:click("Collect Eggs Only")
    expect(#s.calls == 1 and s.destroyed == 0, "Original wait before Destroy was lost")
    s:advance(2)
    expect(#s.calls == 2, "Existing eggs were missed or duplicated")
    expect(s.destroyed == 2 and #s.eggs:GetChildren() == 0)
    expect(#s.trace == 4)
    for index = 1, 4, 2 do
        local collect, destroy = s.trace[index], s.trace[index + 1]
        expect(collect.action == "Collect Egg" and destroy.action == "Destroy" and collect.name == destroy.name)
        expect(destroy.at > collect.at, "Destroy must happen after task.wait()")
    end
    s:egg("c"); s:advance(2)
    expect(#s.calls == 3, "New egg was missed or duplicated")
    expect(s.destroyed == 3)
    eggCallsOnly(s)
    s:click("Collect Eggs Only"); s:egg("d"); s:advance(2)
    expect(#s.calls == 3, "Collection continued after disabling")
    expect(s.globals.LUBRuntime.config["137233438285284"].collect_eggs_only == false)
end)

test("ChildAdded waits one second before collecting and then yields before Destroy", function()
    local s = setup()
    s:click("Collect Eggs Only"); s:advance(0.01)
    local start = s.now
    local egg = s:egg("new")
    s:advance(0.999)
    expect(#s.calls == 0 and egg.Parent == s.eggs, "New egg collected before the original one-second delay")
    s:advance(start + 1 - s.now)
    expect(#s.calls == 1 and s.calls[1].at == start + 1)
    expect(egg.Parent == s.eggs, "New egg destroyed before the original yield")
    s:advance(0.01)
    expect(egg.Parent == nil and s.destroyed == 1)
    eggCallsOnly(s)
end)

test("eggs appearing during the initial scan are not missed", function()
    local s = setup()
    s:egg("existing"); s:click("Collect Eggs Only")
    s:egg("during-scan"); s:advance(2)
    expect(#s.calls == 2 and s.destroyed == 2)
    eggCallsOnly(s)
end)

test("disable interrupts an in-progress egg scan", function()
    local s = setup()
    s:egg("first"); s:egg("second")
    s:click("Collect Eggs Only")
    expect(#s.calls == 1)
    s:click("Collect Eggs Only"); s:advance(1)
    expect(#s.calls == 1, "Pending scan ignored stop")
end)

test("rapid start-stop-start leaves one active collector", function()
    local s = setup()
    s:click("Collect Eggs Only"); s:click("Collect Eggs Only"); s:click("Collect Eggs Only")
    s:egg("only"); s:advance(2)
    expect(#s.calls == 1, "Multiple collector workers remained active")
    eggCallsOnly(s)
end)

test("missing game hierarchy shows a stopped error and can be enabled when loaded", function()
    local s = setup({ lateWorld = true })
    s:click("Collect Eggs Only"); s:advance(1)
    expect(#s.calls == 0 and not s:find("Collect Eggs Only").Value)
    expect(s:find("Collection Status").Desc:find("Collection stopped:", 1, true))
    s:world(); s:egg("late"); s:click("Collect Eggs Only"); s:advance(1)
    expect(#s.calls == 1 and s.destroyed == 1)
end)

test("failed remote does not destroy the egg and reports the error", function()
    local s = setup()
    s:egg("retry"); s.failEvent = true
    s:click("Collect Eggs Only"); s:advance(1)
    expect(#s.calls == 0 and s.destroyed == 0 and not s:find("Collect Eggs Only").Value)
    expect(s:find("Collection Status").Desc:find("Temporary remote failure", 1, true))
    s.failEvent = false; s:click("Collect Eggs Only"); s:advance(1)
    expect(#s.calls == 1 and s.destroyed == 1)
    eggCallsOnly(s)
end)

test("turning off cancels a ChildAdded callback already waiting", function()
    local s = setup()
    s:click("Collect Eggs Only"); s:advance(0.01)
    s:egg("pending"); s:advance(0.5)
    s:click("Collect Eggs Only"); s:advance(2)
    expect(#s.calls == 0 and s.destroyed == 0, "Disconnected callback ignored stop while waiting")
end)

test("switching from full farm cancels its pending follow-up actions", function()
    local s = setup()
    s:farmUI()
    s:click("Autofarm"); s:advance(0.002)
    expect(s.calls[1].action == "Deposit Eggs")
    s:click("Collect Eggs Only")
    s:egg("egg"); s:advance(2)
    expect(#s.calls == 2 and s.calls[2].action == "Collect Egg", "Old full-farm worker kept running")
    local saved = s.globals.LUBRuntime.config["137233438285284"]
    expect(saved.collect_eggs_only and not saved.farming)
    expect(not s.globals.Farming)
end)

test("full farm retains the original collect/deposit/cash/upgrade/buy/merge order", function()
    local s = setup()
    s:farmUI(); s:egg("first")
    s:click("Autofarm"); s:advance(0.6)
    local actions = { "Collect Egg", "Deposit Eggs", "Collect Cash", "Upgrade Process Level", "Buy Chickens", "Merge Chickens" }
    expect(#s.calls == #actions)
    for i, action in ipairs(actions) do expect(s.calls[i].action == action, "Changed original farm action order") end
    expect(s.calls[5].value == 25, "Original purchase selection changed")
    expect(s.destroyed == 1)
    s:click("Autofarm")
end)

test("conflicting saved modes restore only egg collection", function()
    local s = setup({ config = { settings = {}, ["137233438285284"] = { farming = true, collect_eggs_only = true } } })
    s:egg("restored"); s:advance(2)
    expect(#s.calls == 1)
    eggCallsOnly(s)
end)

test("cleanup stops pending collection and rerun keeps one UI", function()
    local s = setup()
    local ui = s.globals.LUBRuntime.window
    s:load("src/init.lua")
    expect(s.globals.LUBRuntime.window == ui, "Rerun duplicated the UI")
    s:click("Collect Eggs Only")
    s.globals.LUBRuntime.cleanup()
    s:egg("after-cleanup"); s:advance(2)
    expect(#s.calls == 0)
    expect(s.rendering == true)
end)

test("unknown games and unavailable/corrupt config retain working settings", function()
    local s = setup({ place = 1, noFiles = true })
    expect(s:find("Open Games List"))
    expect(s:find("Game not supported").Desc:find("No LUB script is available", 1, true))
    expect(s.window.Config.Author == "Game Tools")
    s:click("Settings"); s:click("Disable 3D Rendering")
    expect(s.rendering == false)
    s:click("Auto Rejoin (when kicked)")
    s.services.GuiService.ErrorMessageChanged:Fire("Disconnected"); s:advance(0)
    expect(s.teleport == 1)
    local recovered = setup({ corrupt = true })
    expect(recovered.globals.LUBRuntime.alive)
    expect(#recovered.warnings == 1)
end)

test("old UI upgrades, old game settings are removed, settings restore", function()
    local s = setup({ legacy = true, config = {
        settings = { disable_3d_rendering = true },
        ["137233438285284"] = { collect_eggs_only = true },
        ["999"] = { farming = true },
    } })
    expect(s.legacyStopped and s.globals.LUBRuntime.version == "2.5.0")
    expect(s.globals.LUBRuntime.config["999"] == nil and s.rendering == false)
    expect(s:find("Collect Eggs Only").Value and not s:find("Autofarm").Value)
    s:egg("restored"); s:advance(1)
    eggCallsOnly(s)
    s:click("Unload LUB"); s:egg("after-unload"); s:advance(1)
    expect(#s.calls == 1 and s.window.Destroyed and not s.globals.LUBRuntime.alive)
end)

test("WindUI destroy stops workers and unknown place can join Chicken Farm", function()
    local s = setup()
    s:click("Collect Eggs Only"); s.window:Destroy(); s:advance(0)
    s:egg("after-close"); s:advance(1)
    expect(#s.calls == 0 and not s.globals.LUBRuntime.alive)
    local other = setup({ place = 1 })
    other:click("Open Games List"); other:click("Chicken Farm")
    expect(other.window.Selected == 2 and other.teleport == 137233438285284)
end)

test("WindUI download failure leaves no active runtime", function()
    local s = setup({ failWindUI = true })
    expect(not s.globals.LUBRuntime.alive)
end)

local function manualSellConfig(extra)
    local config = { settings = {}, ["122572082932179"] = {
        auto = false, autoBuyOre = false, autoGear = false, autoRewards = false,
    } }
    for key, value in pairs(extra or {}) do config["122572082932179"][key] = value end
    return config
end

test("supplied Sell Ores script runs inside LUB and identifies its own base", function()
    local s = setup({ place = 122572082932179, config = manualSellConfig() })
    local core = s.globals.LUBRuntime.sellOres
    expect(core and core.findBase() == s.base)
    expect(#s.window.Tabs == 3 and s.window.Config.Author == "Sell Ores")
    local toggles = 0
    for _, control in ipairs(s.controls) do
        if control.Kind == "Toggle" and control.Title ~= "Disable 3D Rendering" and control.Title ~= "Auto Rejoin (when kicked)" then
            toggles += 1
            expect(control.Desc == nil, "Game feature description restored")
        end
    end
    expect(toggles == 15)
    expect(s:find("Decisions") and s:find("Max payback"))
    expect(#s.warnings == 0, table.concat(s.warnings, "\n"))
end)

test("Sell Ores keeps original defaults and completes roll buy pickup sell", function()
    local s = setup({ place = 122572082932179 })
    local core = s.globals.LUBRuntime.sellOres
    expect(core.CONFIG.auto and core.CONFIG.autoBuyOre and core.CONFIG.autoGear and core.CONFIG.autoRewards)
    s:advance(8)
    expect(core.STATE.rolls > 0, "No roll")
    expect(core.STATE.oresBought > 0, "No ore bought")
    expect(core.STATE.sells > 0, "No sale")
    for _, call in ipairs(s.calls) do expect(call.action ~= "BaseCrateAction") end
end)

test("manual roll holds character by prompt and retains original settle time", function()
    local s = setup({ place = 122572082932179, config = manualSellConfig() })
    s:click("Roll once"); s:advance(0.1)
    s.services.RunService.Heartbeat:Fire(); s:advance(0)
    expect(s.hrp.CFrame.Position.X == 10 and s.hrp.CFrame.Position.Y == 5)
    expect(#s.prompts == 0)
    s:advance(0.11)
    expect(#s.prompts == 1 and s.prompts[1].name == "RollPrompt" and s.prompts[1].at >= 0.2)
    s:advance(0.5)
    expect(s.globals.LUBRuntime.sellOres.STATE.rolls == 1)
end)

test("manual crate action picks up before selling and counts actual balance change", function()
    local s = setup({ place = 122572082932179, config = manualSellConfig() })
    s:click("Pick up + sell now"); s:advance(3)
    expect(#s.prompts == 2 and s.prompts[1].name == "PickUpOresPrompt" and s.prompts[2].name == "SellOresPrompt")
    local st = s.globals.LUBRuntime.sellOres.STATE
    expect(st.pickups == 1 and st.sells == 1 and st.earned == 100 and st.money == 1100)
end)

test("unload cancels pending prompts and disconnects character and remote listeners", function()
    local s = setup({ place = 122572082932179, config = manualSellConfig() })
    s:click("Pick up + sell now"); s:advance(0.1)
    s:click("Unload LUB"); s:advance(5)
    expect(#s.prompts == 0 and s.window.Destroyed)
    for _, listener in ipairs(s.services.RunService.Heartbeat.listeners) do expect(not listener.connected) end
    for _, listener in ipairs(s.crateEvent.OnClientEvent.listeners) do expect(not listener.connected) end
    expect(s.globals._G.__SELLORES_DBG == nil and #s.warnings == 0)
end)

test("rewards claim available indices and all banked spins despite countdown", function()
    local s = setup({ place = 122572082932179, config = manualSellConfig(), sellRewards = true })
    s:click("Claim everything now"); s:advance(4)
    local counts = {}
    for _, call in ipairs(s.calls) do
        counts[call.action] = (counts[call.action] or 0) + 1
        if call.action == "PlaytimeRewardsClaim" then expect(call.args[1] == 4) end
    end
    expect(counts.RequestLuckySpin == 2 and counts.CompleteLuckySpin == 2)
    expect(counts.ClaimDailyReward == 1 and counts.PlaytimeRewardsClaim == 1)
end)

test("upgrade guard shares the declared furnace state and buys affordable upgrade", function()
    local s = setup({ place = 122572082932179, config = manualSellConfig(), sellUpgrade = true })
    local core = s.globals.LUBRuntime.sellOres
    s.globals.task.spawn(function() core.buyUpgrades() end)
    s:advance(1)
    expect(core.STATE.upgrades == 1 and s.money.Value == "$750")
end)

test("original ore mutation and furnace throughput decisions are preserved", function()
    local s = setup({ place = 122572082932179, config = manualSellConfig() })
    local core = s.globals.LUBRuntime.sellOres
    core.LOADOUT.count = 1; core.LOADOUT.worstRate = 10
    expect(not core.oreWanted({ oreName = "Stone Ore", seedCost = 100, rarity = "Common" }))
    expect(core.oreWanted({ oreName = "Stone Ore", seedCost = 100, rarity = "Common", mutation = "Alien" }))
    core.INCOME.perSecond = 1000; core.FURNACE.purchased = true
    expect(core.furnaceWorthUsing())
    s.furnaceRate.Text = "$500/s"
    expect(not core.furnaceWorthUsing())
end)

test("WindUI settings persist separately and stale targets and infinity are not serialized", function()
    local config = manualSellConfig({ base = "Base1" })
    config["137233438285284"] = { collect_eggs_only = true }
    local s = setup({ place = 122572082932179, config = config })
    s:click("Auto Roll")
    s:find("Max payback"):Set("60 min"); s:find("Cycle wait"):Set(2); s:advance(0)
    local saved = s.globals.LUBRuntime.config
    expect(saved["137233438285284"].collect_eggs_only)
    local sell = saved["122572082932179"]
    expect(sell.autoRoll and sell.maxPayback == 3600 and sell.cycleWait == 2)
    expect(sell.base == nil and sell.maxUpgradePayback == nil)
    expect(s.globals.LUBRuntime.sellOres.CONFIG.maxUpgradePayback == math.huge)
end)

test("game joining chooses a live public server with space and excludes the current server", function()
    local s = setup()
    s:click("Chicken Farm")
    expect(#s.joins == 1 and s.joins[1].serverId == "open-server-1")
    expect(s.joins[1].place == s.globals.game.PlaceId and s.joins[1].player == s.services.Players.LocalPlayer)
    expect(s.serverRequests[1]:find("/servers/Public?", 1, true)
        and s.serverRequests[1]:find("excludeFullGames=true", 1, true))
    expect(not s.rejoinCalls and #s.nativePrompts == 0)
end)

test("server lookup paginates and supports the executor HTTP transport", function()
    local s = setup({ executorRequest = true, serverPages = {
        { data = { { id = "current-server", playing = 1, maxPlayers = 6 } }, nextPageCursor = "next+/=" },
        { data = { { id = "page-two", playing = 1, maxPlayers = 6 } } },
    } })
    s:click("Chicken Farm")
    expect(#s.serverRequests == 2 and s.serverRequests[2]:find("cursor=next%2B%2F%3D", 1, true))
    expect(s.joins[1].serverId == "page-two")
end)

test("full or closed servers trigger fresh lookups and at most three distinct attempts", function()
    local s = setup()
    s:click("Chicken Farm")
    local tp, enum, player = s.services.TeleportService, s.globals.Enum, s.services.Players.LocalPlayer
    for i = 1, 3 do
        expect(#s.joins == i and s.joins[i].serverId == "open-server-" .. i)
        tp.TeleportInitFailed:Fire(player, enum.TeleportResult.GameFull, "Server full", s.globals.game.PlaceId,
            { ServerInstanceId = s.joins[i].serverId })
        s:advance(1.1)
    end
    expect(#s.serverRequests == 3 and #s.joins == 3 and #s.nativePrompts == 1)
    expect(not s.globals.LUBRuntime.joinInProgress)
end)

test("restricted join opens Roblox's experience dialog and does not rejoin the source game", function()
    local s = setup({ nativeDelay = 1 })
    s:click("Auto Rejoin (when kicked)")
    s:click("Sell Ores")
    local player = s.services.Players.LocalPlayer
    s.services.GuiService.ErrorMessageChanged:Fire("Attempted to teleport to a restricted place")
    s.services.TeleportService.TeleportInitFailed:Fire(player, s.globals.Enum.TeleportResult.Unauthorized,
        "Restricted", 122572082932179)
    s:advance(0)
    expect(#s.joins == 1 and #s.nativePrompts == 1)
    expect(s.nativePrompts[1].universe == 10336278580 and s.nativePrompts[1].player == player)
    expect(not s.rejoinCalls)
    s:advance(1)
    s.services.GuiService.ErrorMessageChanged:Fire("Teleport failed"); s:advance(0)
    expect(not s.rejoinCalls and not s.globals.LUBRuntime.joinInProgress)
end)

test("unavailable or empty server lists use Roblox matchmaking and handle denied native joins", function()
    for _, options in ipairs({ { listError = true }, { serverPages = { { data = {} } } },
        { executorRequest = true, httpStatus = 429 } }) do
        options.nativeAttempted = true
        local s = setup(options)
        s:click("Chicken Farm")
        expect(#s.joins == 0 and #s.nativePrompts == 1)
        expect(s.globals.LUBRuntime.joinInProgress)
        s.services.TeleportService.TeleportInitFailed:Fire(s.services.Players.LocalPlayer,
            s.globals.Enum.TeleportResult.Unauthorized, "Restricted", 137233438285284)
        s:advance(0)
        expect(not s.globals.LUBRuntime.joinInProgress)
        expect(s:find("Chicken Farm").Desc:find("https://www.roblox.com/games/137233438285284", 1, true))
        expect(#s.nativePrompts == 1, "Failure reopened the native dialog")
    end
end)

test("synchronous teleport and dialog errors are reported without a stuck join", function()
    local s = setup({ joinError = "restricted place (773)", nativeError = true })
    s:click("Chicken Farm")
    expect(#s.joins == 1 and #s.nativePrompts == 1 and not s.globals.LUBRuntime.joinInProgress)
    expect(s:find("Chicken Farm").Desc:find("press Play", 1, true))
end)

test("double clicks and unrelated teleport failures do not start additional joins", function()
    local s = setup()
    s:click("Chicken Farm"); s:click("Chicken Farm"); s:click("Sell Ores")
    expect(#s.joins == 1 and #s.serverRequests == 1)
    local tp, enum, player = s.services.TeleportService, s.globals.Enum, s.services.Players.LocalPlayer
    tp.TeleportInitFailed:Fire(player, enum.TeleportResult.GameFull, "Full", 122572082932179)
    tp.TeleportInitFailed:Fire({}, enum.TeleportResult.GameFull, "Full", 137233438285284)
    tp.TeleportInitFailed:Fire(player, enum.TeleportResult.GameFull, "Old failure", 137233438285284,
        { ServerInstanceId = "old-server" })
    s:advance(2)
    expect(#s.joins == 1 and #s.nativePrompts == 0)
    s:advance(29); s:click("Sell Ores")
    expect(#s.joins == 2 and s.joins[2].place == 122572082932179)
end)

test("unload cancels pending server lookup and delayed retries", function()
    local s = setup({ listDelay = 2 })
    s:click("Chicken Farm"); s:click("Unload LUB"); s:advance(3)
    expect(#s.joins == 0 and #s.nativePrompts == 0)
    local retry = setup()
    retry:click("Chicken Farm")
    retry.services.TeleportService.TeleportInitFailed:Fire(retry.services.Players.LocalPlayer,
        retry.globals.Enum.TeleportResult.GameFull, "Full", 137233438285284)
    retry:advance(0); retry:click("Unload LUB"); retry:advance(3)
    expect(#retry.joins == 1 and #retry.serverRequests == 1)
    for _, listener in ipairs(retry.services.TeleportService.TeleportInitFailed.listeners) do expect(not listener.connected) end
end)

-- Fishing Chef fixtures follow the Cobalt responses: Plates are data records,
-- StoreFood takes only the owned NPC; the native controller supplies catches.
local function chef(options)
    options = options or {}
    return setup({ place = 88599461076137, prepare = function(s, player, storage)
        local g, node = s.globals, s.node
        local cfMeta = { __mul = function(a) return a end }
        g.CFrame.new = function(pos) return setmetatable({ Position = pos }, cfMeta) end
        g.CFrame.Angles = function() return g.CFrame.new() end
        g.Vector3.zero = g.Vector3.new(0, 0, 0)
        g.require = function(module) return assert(module.Module) end
        player:SetAttribute("ROPEN", not options.closed)
        player.Backpack = node("Backpack")
        player.Character = node("Model", "Character")
        local hrp = node("Part", "HumanoidRootPart", player.Character)
        hrp.CFrame = g.CFrame.new(g.Vector3.zero)
        local hum = node("Humanoid", "Humanoid", player.Character)
        hum.EquipTool = function(_, tool) tool.Parent = player.Character end
        hum.UnequipTools = function()
            for _, tool in ipairs(player.Character:GetChildren()) do
                if tool:IsA("Tool") then tool.Parent = player.Backpack end
            end
        end
        if not options.noRod then node("Tool", "Silver Rod", player.Backpack):SetAttribute("IsRod", true) end
        local code = node("Folder", "Code", g.workspace)
        local plots = node("Folder", "Plots", code)
        local own = node("Model", player.Name, plots)
        own:SetAttribute("Owner", player.Name)
        node("Part", "BoatSpawnJetty", own).Position = g.Vector3.zero
        local stall = node("Model", "STALL", own)
        stall:SetAttribute("Level", 1)
        local board = node("Part", "CuttingBoard", node("Model", "CookingStation", stall))
        board.CFrame = g.CFrame.new(g.Vector3.zero)
        local npcs = node("Folder", "ActiveNPCs", code)
        function s:customer(ownerName, order)
            local npc = node("Folder", "Customer", npcs)
            node("StringValue", "Owner", npc).Value = ownerName
            node("CFrameValue", "Location", npc).Value = g.CFrame.new(g.Vector3.zero)
            npc:SetAttribute("Arrived", true)
            npc:SetAttribute("Order", order or "Nigiri")
            return npc
        end
        s.npc = s:customer(options.foreign and "OtherPlayer" or player.Name, options.order)
        s.profile = { Fish = options.empty and {} or {{ID = 77, Name = "salmon", Weight = 4}},
            FishCaught = 12, Plates = {}, FavoriteFish = options.favorite and {["77"] = true} or {},
            FavoritePlates = {}, FishPond = {{ID = 999, Name = "tuna"}}, Level = 3,
            NightMarket = {CustomersServedTotal = 0} }
        s.items, s.cuts, s.dishes, s.feeds = {}, {}, {}, {}
        local controller = { GetData = function(_, key) return s.profile[key] end,
            IsDataLoaded = function() return true end }
        local autoGeneration = 0
        s.native = { IsAutoFishEnabled = function() return s.autoEnabled == true end,
            SetAutoFishEnabled = function(_, enabled)
                s.autoEnabled = enabled
                autoGeneration += 1
                local token = autoGeneration
                if enabled then
                    s.autoStarts = (s.autoStarts or 0) + 1
                    g.task.spawn(function()
                        g.task.wait(2)
                        if token ~= autoGeneration or not s.autoEnabled or options.noCatch then return end
                        s.profile.FishCaught += 1
                        table.insert(s.profile.Fish, {ID = s.profile.FishCaught + 100, Name = "anchovy", Weight = 1})
                    end)
                end
            end }
        local packages = node("Folder", "Packages", storage)
        local knit = node("ModuleScript", "Knit", packages)
        knit.Module = {GetController = function(name) return name == "DataController" and controller or s.native end}
        local fish = node("Folder", "Fish", node("Folder", "Services", knit))
        local rf, re = node("Folder", "RF", fish), node("Folder", "RE", fish)
        local shared = node("Folder", "Shared", storage)
        node("ModuleScript", "FishingCastValidator", shared).Module = {
            CanCastFromCharacter = function() return not options.invalidSpot end }
        node("ModuleScript", "CookingConfig", node("Folder", "Modules", storage)).Module = {
            Nigiri = {EstTime = 7, StallLevel = 1, Tool = "Nigiri Plate"},
            Sashimi = {EstTime = 10, Sashimi = true, PlayerLevel = 3} }
        local function remote(name, fn)
            node("RemoteFunction", name, rf).InvokeServer = function(_, ...)
                table.insert(s.calls, {action = name, at = s.now})
                if options.delayRemote == name then g.task.wait(5) end
                return fn(...)
            end
        end
        remote("RequestRestaurauntData", function() return table.clone(s.items), {}, {}, s.profile.NightMarket end)
        remote("StartCutSession", function() return options.badGoals and {0.8, "invalid"} or {0.8, 0.4} end)
        node("RemoteEvent", "ServerAnims", re).FireServer = function(_, _, _, active) s.cutting = active end
        node("RemoteEvent", "CutAction", re).FireServer = function(_, index, elapsed)
            table.insert(s.cuts, {index=index, elapsed=elapsed})
        end
        remote("CutFish", function(id, score)
            assert(#s.cuts >= 2 and s.cuts[#s.cuts].index == 2, "CutFish before cuts")
            assert(score >= 1.3 and score <= 2, "Cut score inconsistent with recorded goals")
            for i, item in ipairs(s.profile.Fish) do
                if item.ID == id then
                    assert(not s.profile.FavoriteFish[tostring(id)], "Favorite consumed")
                    s.lastCut = id
                    table.remove(s.profile.Fish, i)
                    table.insert(s.items, {ID = 1, Name = "Fish Filet", CF = item.Name, CookedAt = 100, Data = 4, Amount = 1})
                    return 1
                end
            end
            error("Fish no longer exists")
        end)
        remote("Cook", function(name, item)
            assert(name == "Nigiri" and table.find(s.items, item), "Cook must use current server item")
            table.insert(s.dishes, {name=name, item=item, at=s.now})
            table.remove(s.items, table.find(s.items, item))
            if not options.rejectCook then
                table.insert(s.profile.Plates, {Name=name, ID="P" .. #s.dishes, CF=item.CF, Value=330})
            end
            return "Cooked meal Nigiri"
        end)
        node("RemoteEvent", "StoreFood", re).FireServer = function(_, npc, ...)
            assert(select("#", ...) == 0, "StoreFood only takes an NPC")
            assert(npc.Owner.Value == player.Name, "Foreign customer")
            assert(#s.profile.Plates > 0, "Serving without a plate")
            table.insert(s.feeds, npc)
            table.remove(s.profile.Plates, 1)
            s.profile.NightMarket.CustomersServedTotal += 1
            npc:SetAttribute("Despawn", true)
        end
    end })
end

test("Fishing Chef loads disabled and completes catch cut cook serve using server records", function()
    local s = chef({empty=true})
    expect(s.globals.LUBRuntime.fishingChef and #s.calls == 0)
    s:click("Autofarm")
    s:advance(19)
    local state = s.globals.LUBRuntime.fishingChef
    expect(state.caught >= 1 and state.cooked >= 1 and state.served == 1, state.phase)
    expect(#s.feeds == 1 and #s.profile.FishPond == 1)
    s:click("Unload LUB")
    local count = #s.calls
    s:advance(30)
    expect(#s.calls == count and not s.autoEnabled and not s.cutting)
end)

test("Fishing Chef protects favorites and ignores foreign customers", function()
    local s = chef({favorite=true, foreign=true})
    s:click("Autofarm"); s:advance(20)
    expect(s.profile.Fish[1].ID == 77 and s.lastCut ~= 77)
    expect(#s.dishes == 1 and #s.feeds == 0)
    s:advance(20)
    expect(#s.dishes == 1, "Unbounded cooking with no customers")
end)

test("Fishing Chef never consumes or replaces a favorited plate", function()
    local s = chef()
    s.profile.Plates = {{Name="Nigiri", ID="P1"}}
    s.profile.FavoritePlates.P1 = true
    s:click("Autofarm"); s:advance(20)
    expect(#s.feeds == 0 and #s.dishes == 0 and #s.calls == 0)
end)

test("Fishing Chef stops pending cutting and can restart without duplicate workers", function()
    local s = chef()
    s:click("Autofarm"); s:advance(0.7)
    s:click("Autofarm")
    local count = #s.calls
    s:advance(5)
    expect(#s.calls == count and #s.cuts == 0 and not s.cutting)
    s:click("Autofarm"); s:click("Autofarm"); s:click("Autofarm")
    s:advance(16)
    expect(#s.dishes == 1 and #s.feeds == 1)
end)

test("Fishing Chef unload during a remote response prevents subsequent actions", function()
    local s = chef({delayRemote="StartCutSession"})
    s:click("Autofarm"); s:advance(1)
    s:click("Unload LUB"); local count = #s.calls
    s:advance(15)
    expect(#s.calls == count and #s.cuts == 0 and #s.dishes == 0)
end)

test("Fishing Chef closed restaurant and unsupported recipes do not get served", function()
    local s = chef({closed=true})
    s:click("Autofarm"); s:advance(20)
    expect(#s.calls == 0)
    s.services.Players.LocalPlayer:SetAttribute("ROPEN", true)
    s.npc:SetAttribute("Order", "Sashimi")
    s:advance(20)
    expect(#s.dishes == 1 and #s.feeds == 0 and s.dishes[1].name == "Nigiri")
end)

test("Fishing Chef rechecks owner after travelling to customer", function()
    local s = chef()
    s.profile.Plates = {{Name="Nigiri", ID="P1"}}
    s:click("Autofarm"); s:advance(0.2)
    s.npc.Owner.Value = "OtherPlayer"
    s:advance(10)
    expect(#s.feeds == 0)
end)

test("Fishing Chef malformed cutting targets fail closed", function()
    local s = chef({badGoals=true})
    s:click("Autofarm"); s:advance(15)
    expect(not s:find("Autofarm").Value and #s.dishes == 0 and not s.lastCut)
    expect(not s.cutting and s:find("Farm Status").Desc:find("Invalid cutting target",1,true))
end)

test("Fishing Chef rejected cooking is not counted as success or retried", function()
    local s = chef({rejectCook=true})
    s:click("Autofarm"); s:advance(30)
    expect(#s.dishes == 1 and s.globals.LUBRuntime.fishingChef.cooked == 0 and #s.feeds == 0)
    expect(not s:find("Autofarm").Value)
end)

test("Fishing Chef stops native fishing on disable and times out missing catches", function()
    local s = chef({empty=true,noCatch=true})
    s:click("Autofarm"); s:advance(3)
    expect(s.autoEnabled)
    s:click("Autofarm"); s:advance(5)
    expect(not s.autoEnabled and s.profile.FishCaught == 12)
    s:click("Autofarm"); s:advance(65)
    expect(not s.autoEnabled and not s:find("Autofarm").Value)
end)

test("Fishing Chef detects missing rods and invalid fishing spots", function()
    for _, options in ipairs({{empty=true,noRod=true},{empty=true,invalidSpot=true}}) do
        local s = chef(options)
        s:click("Autofarm"); s:advance(5)
        expect(not s.autoEnabled and not s:find("Autofarm").Value and #s.dishes == 0)
    end
end)

test("Fishing Chef cancels preparation when the character is replaced", function()
    local s = chef()
    s:click("Autofarm"); s:advance(0.7)
    s.services.Players.LocalPlayer.Character = s.node("Model", "NewCharacter")
    s:advance(10)
    expect(not s:find("Autofarm").Value and #s.dishes == 0 and not s.cutting)
end)

print(string.format("%d behavioral tests passed", passed))
