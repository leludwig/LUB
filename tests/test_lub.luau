-- LUB behavior with deterministic Roblox/WindUI test doubles. Run tools/test.py.
local passed = 0
local function expect(value, message) assert(value, message or "Expectation failed") end

local function setup(options)
    options = options or {}
    local state = { now = 0, jobs = {}, calls = {}, warnings = {}, saved = {}, destroyed = 0 }
    local globals = setmetatable({}, { __index = getfenv() })
    state.globals = globals
    globals.getgenv = function() return globals end
    globals.warn = function(message) table.insert(state.warnings, message) end
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
        ErrorMessageChanged = true, ChildAdded = true, ChildRemoved = true }
    local methods = {}
    function methods:GetChildren() return table.clone(self._children) end
    function methods:FindFirstChild(name)
        for _, child in ipairs(self._children) do if child.Name == name then return child end end
        return nil
    end
    function methods:GetPropertyChangedSignal(name)
        if not self._signals[name] then self._signals[name] = signal() end
        return self._signals[name]
    end
    function methods:SetAttribute(name, value) self._attrs[name] = value end
    function methods:GetAttribute(name) return self._attrs[name] end
    function methods:Destroy()
        if self.Parent == state.eggs then state.destroyed = state.destroyed + 1 end
        self.Parent = nil
        for _, child in ipairs(self:GetChildren()) do child:Destroy() end
    end
    function methods:IsA(class) return self.ClassName == class end
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
        RunService = { Set3dRenderingEnabled = function(_, enabled) state.rendering = enabled end },
        TeleportService = { Teleport = function(_, id) state.teleport = id end },
    }
    state.services = services
    globals.game = { PlaceId = options.place or 137233438285284,
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
            table.insert(state.calls, { kind = "event", action = action, name = name })
        end
        local fn = node("RemoteFunction", "__remotefunction", remotes)
        fn.InvokeServer = function(_, action, value)
            table.insert(state.calls, { kind = "function", action = action, value = value })
            globals.task.wait(0.1)
        end
    end
    function state:egg(name) return node("Model", name, self.eggs) end
    if not options.lateWorld then state:world() end
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
        for _, elementKind in ipairs({ "Section", "Paragraph", "Toggle", "Button" }) do
            result[elementKind] = function(self, config)
                local control = container(config.Title, elementKind, self)
                control.Desc = config.Desc
                control.Value = config.Value
                control.Callback = config.Callback
                function control:SetDesc(text) self.Desc = text end
                function control:Set(value, isCallback)
                    self.Value = value
                    if isCallback ~= false and self.Callback then
                        globals.task.spawn(function() self.Callback(value) end)
                    end
                end
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
            function window:Destroy()
                self.Destroyed = true
                if self.destroyCallback then globals.task.spawn(self.destroyCallback) end
            end
            return window
        end,
    }
    globals.game.HttpGet = function(_, url)
        expect(url == "https://github.com/Footagesus/WindUI/releases/download/1.6.66/main.lua", "Unexpected dependency URL")
        if options.failWindUI then error("WindUI download failed") end
        return "return getgenv().TEST_WINDUI"
    end
    if options.legacy then
        globals.LUBRuntime = { alive = true, cleanup = function() state.legacyStopped = true end }
    end
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
    expect(state.destroyed == 0, "Collector destroyed a local egg")
end

test("WindUI has exactly three tabs and one game entry", function()
    local s = setup()
    expect(s.window.Config.Title == "LUB" and s.window.Config.NewElements == true)
    expect(#s.window.Tabs == 3 and s.window.Selected == 1)
    expect(s.window.Tabs[1].Title == "Game")
    expect(s.window.Tabs[2].Title == "Games List")
    expect(s.window.Tabs[3].Title == "Settings")
    s:click("Games List")
    local entries = 0
    for _, control in ipairs(s.window.Tabs[2].Elements) do if control.Kind == "Button" then entries = entries + 1 end end
    expect(entries == 1 and s:find("Chicken Farm").Desc:find("137233438285284", 1, true))
    s:click("Chicken Farm")
    expect(s.window.Selected == 1 and not s.teleport, "Current game should open the Game tab")
    local section = s:find("Auto Farm")
    expect(section.Parent == s.window.Tabs[1])
    expect(section.Elements[1].Title == "Autofarm" and section.Elements[2].Title == "Collect Eggs Only")
    expect(#s.warnings == 0, table.concat(s.warnings, "\n"))
end)

test("egg-only collects existing and new eggs exactly once per activation", function()
    local s = setup()
    s:egg("a"); s:egg("b")
    expect(#s.calls == 0, "Farm started by default")
    s:click("Collect Eggs Only"); s:advance(2)
    expect(#s.calls == 2, "Existing eggs were missed or duplicated")
    s:egg("c"); s:advance(2)
    expect(#s.calls == 3, "New egg was missed or duplicated")
    eggCallsOnly(s)
    s:click("Collect Eggs Only"); s:egg("d"); s:advance(2)
    expect(#s.calls == 3, "Collection continued after disabling")
    expect(s.globals.LUBRuntime.config["137233438285284"].collect_eggs_only == false)
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

test("late game hierarchy and replaced egg folder recover", function()
    local s = setup({ lateWorld = true })
    s:click("Collect Eggs Only"); s:advance(1)
    expect(#s.calls == 0)
    s:world(); s:egg("late"); s:advance(1)
    expect(#s.calls == 1)
    s.eggs:Destroy()
    s.eggs = s.node("Folder", "Eggs", s.globals.workspace)
    s:egg("replacement"); s:advance(1)
    expect(#s.calls == 2)
end)

test("temporary collection errors retry without counting a failure", function()
    local s = setup()
    s:egg("retry"); s.failEvent = true
    s:click("Collect Eggs Only"); s:advance(1)
    expect(#s.calls == 0)
    s.failEvent = false; s:advance(1)
    expect(#s.calls == 1)
    eggCallsOnly(s)
end)

test("switching from full farm cancels its pending follow-up actions", function()
    local s = setup()
    s:click("Autofarm")
    expect(s.calls[1].action == "Deposit Eggs")
    s:click("Collect Eggs Only")
    s:egg("egg"); s:advance(2)
    expect(#s.calls == 2 and s.calls[2].action == "Collect Egg", "Old full-farm worker kept running")
    local saved = s.globals.LUBRuntime.config["137233438285284"]
    expect(saved.collect_eggs_only and not saved.farming)
    expect(not s.globals.Farming)
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
    expect(s.legacyStopped and s.globals.LUBRuntime.version == "2.0.0")
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

print(string.format("%d behavioral tests passed", passed))
