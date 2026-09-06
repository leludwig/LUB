-- LUB: independent interface with exactly Game, Games List and Settings.
local env = getgenv()
local runtime = env.LUBRuntime
local elements = env.LUBRequire("src/elements.lua")
local colors = elements.colors
local input = game:GetService("UserInputService")
local function create(class, props, parent) return elements:Create(class, props, parent) end

local ui = create("ScreenGui", {
    Name = "LUB", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 100, IgnoreGuiInset = false,
})
runtime.ui = ui
local hiddenGui = gethui or get_hidden_gui
ui.Parent = hiddenGui and hiddenGui() or game:GetService("CoreGui")
local main = create("Frame", {
    Name = "Main", Size = UDim2.fromOffset(620, 460), AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = colors.background, BorderSizePixel = 0,
}, ui)
runtime.main = main
elements:Round(main, 14)
create("UIStroke", { Color = colors.border, Thickness = 1 }, main)
local scale = create("UIScale", {}, main)
local function fit()
    local camera = workspace.CurrentCamera
    if camera then
        scale.Scale = math.min(1, (camera.ViewportSize.X - 24) / 620, (camera.ViewportSize.Y - 70) / 460)
    end
end
fit()
local cameraConnection
local function watchCamera()
    if cameraConnection then cameraConnection:Disconnect() end
    if workspace.CurrentCamera then
        cameraConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
    end
    fit()
end
watchCamera()
runtime.track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera))
table.insert(runtime.cleanups, function() if cameraConnection then cameraConnection:Disconnect() end end)

local topbar = create("Frame", {
    Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, Active = true,
}, main)
create("TextLabel", {
    Position = UDim2.fromOffset(22, 10), Size = UDim2.fromOffset(100, 30),
    BackgroundTransparency = 1, Text = "LUB", TextColor3 = colors.accent,
    TextSize = 25, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
}, topbar)
create("TextLabel", {
    Position = UDim2.fromOffset(23, 40), Size = UDim2.fromOffset(240, 16),
    BackgroundTransparency = 1, Text = "Your games. Your controls.", TextColor3 = colors.muted,
    TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
}, topbar)
local hide = create("TextButton", {
    Position = UDim2.new(1, -54, 0, 18), Size = UDim2.fromOffset(32, 28),
    BackgroundColor3 = colors.card, BorderSizePixel = 0, Text = "-",
    TextSize = 22, TextColor3 = colors.text, Font = Enum.Font.Gotham,
}, topbar)
elements:Round(hide)
local toggle = create("TextButton", {
    Name = "OpenLUB", Position = UDim2.fromOffset(18, 100), Size = UDim2.fromOffset(64, 40),
    BackgroundColor3 = colors.accent, BorderSizePixel = 0, Text = "LUB", Visible = false,
    TextSize = 16, TextColor3 = colors.background, Font = Enum.Font.GothamBold,
}, ui)
runtime.toggle = toggle
elements:Round(toggle)
hide.Activated:Connect(function() main.Visible = false; toggle.Visible = true end)
toggle.Activated:Connect(runtime.show)

local tabs, pages = {}, {}
local function selectTab(name)
    for key, page in pairs(pages) do
        page.Visible = key == name
        tabs[key].BackgroundColor3 = key == name and colors.accent or colors.card
        tabs[key].TextColor3 = key == name and colors.background or colors.muted
    end
end
for index, name in ipairs({ "Game", "Games List", "Settings" }) do
    local tab = create("TextButton", {
        Name = name, Position = UDim2.fromOffset(22 + (index - 1) * 196, 78),
        Size = UDim2.fromOffset(184, 38), BorderSizePixel = 0,
        Text = name, TextSize = 13, Font = Enum.Font.GothamBold,
    }, main)
    elements:Round(tab)
    tabs[name] = tab
    pages[name] = create("ScrollingFrame", {
        Name = name, Position = UDim2.fromOffset(22, 134), Size = UDim2.new(1, -44, 1, -168),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = colors.border, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
        Visible = false,
    }, main)
    create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, pages[name])
    create("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, pages[name])
    tab.Activated:Connect(function() selectTab(name) end)
end
create("TextLabel", {
    Position = UDim2.new(0, 22, 1, -26), Size = UDim2.new(1, -44, 0, 16),
    BackgroundTransparency = 1, Text = "LUB 1.0  /  Right Shift to show or hide",
    TextSize = 10, Font = Enum.Font.Gotham, TextColor3 = colors.muted,
    TextXAlignment = Enum.TextXAlignment.Left,
}, main)
selectTab("Game")

local dragging, dragStart, frameStart, touchInput
topbar.InputBegan:Connect(function(event)
    if event.UserInputType == Enum.UserInputType.MouseButton1 or event.UserInputType == Enum.UserInputType.Touch then
        dragging, dragStart, frameStart = true, event.Position, main.Position
        touchInput = event.UserInputType == Enum.UserInputType.Touch and event or nil
    end
end)
runtime.track(input.InputEnded:Connect(function(event)
    if event.UserInputType == Enum.UserInputType.MouseButton1 or event == touchInput then dragging = false end
end))
runtime.track(input.InputChanged:Connect(function(event)
    if dragging and (event.UserInputType == Enum.UserInputType.MouseMovement or event == touchInput) then
        local delta = event.Position - dragStart
        main.Position = UDim2.new(frameStart.X.Scale, frameStart.X.Offset + delta.X, frameStart.Y.Scale, frameStart.Y.Offset + delta.Y)
    end
end))
runtime.track(input.InputBegan:Connect(function(event, processed)
    if not processed and event.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
        toggle.Visible = not main.Visible
    end
end))

local settings = runtime.config.settings
elements:Label("Preferences", pages.Settings)
elements:Toggle("Disable 3D Rendering", pages.Settings, settings.disable_3d_rendering, function(value)
    game:GetService("RunService"):Set3dRenderingEnabled(not value)
    runtime.setSetting("disable_3d_rendering", value)
end)
elements:Toggle("Auto Rejoin (when kicked)", pages.Settings, settings.auto_rejoin_on_kick, function(value)
    runtime.setSetting("auto_rejoin_on_kick", value)
end)
elements:Label(runtime.canSave and "Settings are saved automatically in LUB/Config.json." or "File access unavailable: settings last for this session.", pages.Settings)
elements:Label("LUB is based on BrainrotPolice by esore / vaehz.\nContributors: __ven0x__, wirlypirly12. Apache-2.0.", pages.Settings)

local gameList = game:GetService("HttpService"):JSONDecode(env.LUBRead("src/gameslist.json"))
elements:Searchbar(pages["Games List"])
elements:Label("Status indicators are inherited from the original project.", pages["Games List"])
local gameName = "Place " .. tostring(game.PlaceId)
for _, entry in ipairs(gameList) do
    if tostring(entry.id) == tostring(game.PlaceId) then gameName = entry.game end
    elements:addGame(pages["Games List"], entry.game, entry.status, function()
        game:GetService("TeleportService"):Teleport(tonumber(entry.id), game:GetService("Players").LocalPlayer)
    end)
end
elements:Label(gameName .. "  /  " .. tostring(game.PlaceId), pages.Game)

-- A delayed game hierarchy must not block Settings or Games List.
task.spawn(function()
    local path = "src/games/" .. tostring(game.PlaceId) .. ".lua"
    local found, source = pcall(env.LUBRead, path)
    if env.FileScripts and isfile and readfile and isfile(env.LUBRoot .. "/" .. tostring(game.PlaceId) .. ".lua") then
        found, source = pcall(readfile, env.LUBRoot .. "/" .. tostring(game.PlaceId) .. ".lua")
    end
    if not runtime.alive then return end
    if not found then
        elements:Unsupported(pages.Game, function() selectTab("Games List") end)
        return
    end
    local ok, err = pcall(function()
        local chunk, compileError = loadstring(source, "@LUB/" .. path)
        assert(chunk, compileError)
        local module = chunk()
        assert(type(module) == "function", "Game module must return a function")
        module(pages.Game, runtime.config)
    end)
    if not ok and runtime.alive then
        elements:Label("Game module could not load. Details are in the console.", pages.Game)
        warn("LUB: " .. tostring(err))
    end
end)
return ui
