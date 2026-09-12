-- LUB 2.8.2: WindUI 1.6.66, with Game, Games List and Settings only.
local env = getgenv()
local runtime = env.LUBRuntime
local source = game:HttpGet("https://github.com/Footagesus/WindUI/releases/download/1.6.66/main.lua")
local library, compileError = loadstring(source, "@WindUI/1.6.66")
assert(library, "LUB: WindUI could not compile: " .. tostring(compileError))
local WindUI = library()
-- Executor UI containers can require Plugin capability in later callbacks.
-- Use WindUI's supported parent API before it creates the window controls.
WindUI:SetParent(game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"))
runtime.disconnectUI = function() WindUI.Creator.DisconnectAll() end
runtime.uiRoots = {}
for _, name in ipairs({"ScreenGui", "NotificationGui", "DropdownGui", "TooltipGui"}) do
    if WindUI[name] then table.insert(runtime.uiRoots, WindUI[name]) end
end
local Window = WindUI:CreateWindow({
    Title = "LUB " .. runtime.version,
    Author = runtime.gameEntry and runtime.gameEntry.game or "Game Tools",
    Folder = "LUB/WindUI",
    Icon = "egg",
    Theme = "Dark",
    Size = UDim2.fromOffset(660, 480),
    SideBarWidth = 180,
    NewElements = true,
    Transparent = false,
    Acrylic = false,
    OpenButton = { Title = "LUB", Enabled = true, Draggable = true, OnlyMobile = false },
})
assert(Window, "LUB: WindUI window could not be created")
runtime.window = Window
Window:OnDestroy(function() runtime.cleanup(true) end)
-- Insert is the only keyboard shortcut; disconnect it when LUB is unloaded.
runtime.track(game:GetService("UserInputService").InputBegan:Connect(function(input, isProcessed)
    if runtime.alive and not isProcessed and input.KeyCode == Enum.KeyCode.Insert then
        Window:Toggle()
    end
end))

local GameTab = Window:Tab({ Title = "Game", Icon = "gamepad-2" })
local GamesTab = Window:Tab({ Title = "Games List", Icon = "list" })
local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })
Window:SelectTab(1)

local function insetButtonIcon(button)
    -- Keep WindUI's full-width, left-aligned text layout; only inset the icon.
    local inset = 18
    button.UIElements.ButtonIcon.Position = UDim2.new(1, -inset, 0.5, 0)
    -- Reserve the same extra space so wrapped text cannot overlap the icon.
    local textFrame = button.ButtonFrame.UIElements.Container.TitleFrame
    local size = textFrame.Size
    textFrame.Size = UDim2.new(size.X.Scale, size.X.Offset - inset, size.Y.Scale, size.Y.Offset)
end

local gameList = runtime.games
local supported = runtime.gameEntry
GamesTab:Section({ Title = "Supported Games" })
for _, entry in ipairs(gameList) do
    local joinButton
    joinButton = GamesTab:Button({
        Title = entry.game,
        Desc = "Place ID: " .. tostring(entry.id),
        Icon = "play",
        Justify = "Between",
        IconAlign = "Right",
        Callback = function()
            if not runtime.alive then return end
            runtime.joinGame(entry, function(message) joinButton.ButtonFrame:SetDesc(message) end)
        end,
    })
    insetButtonIcon(joinButton)
end

SettingsTab:Section({ Title = "Preferences" })
local settings = runtime.config.settings
local renderingToggle
local function setRendering(value)
    if not runtime.alive then return end
    local ok, err = pcall(function() game:GetService("RunService"):Set3dRenderingEnabled(not value) end)
    if ok then
        runtime.setSetting("disable_3d_rendering", value)
    else
        if renderingToggle then renderingToggle:Set(false, false) end
        runtime.setSetting("disable_3d_rendering", false)
        warn("LUB: rendering setting is unavailable: " .. tostring(err))
    end
end
renderingToggle = SettingsTab:Toggle({
    Title = "Disable 3D Rendering", Desc = "Keep the UI visible while hiding the 3D world.",
    Value = settings.disable_3d_rendering, Callback = setRendering,
})
SettingsTab:Toggle({
    Title = "Auto Rejoin (when kicked)", Desc = "Reconnect after a disconnect or kick.",
    Value = settings.auto_rejoin_on_kick,
    Callback = function(value)
        if runtime.alive then runtime.setSetting("auto_rejoin_on_kick", value) end
    end,
})
-- WindUI intentionally does not invoke toggle callbacks for their initial value.
setRendering(settings.disable_3d_rendering)
local unloadButton = SettingsTab:Button({
    Title = "Unload LUB", Desc = "Close LUB and stop farming.", Icon = "power",
    Justify = "Between", IconAlign = "Right",
    Callback = function() runtime.cleanup() end,
})
insetButtonIcon(unloadButton)

if supported then
    local ok, err = pcall(function()
        env.LUBRequire("src/games/" .. supported.id .. ".lua")(GameTab, runtime.config)
    end)
    if not ok then
        GameTab:Paragraph({ Title = "Game could not load", Desc = tostring(err) })
        warn("LUB: " .. tostring(err))
    end
else
    GameTab:Paragraph({ Title = "Game not supported", Desc = "No LUB script is available for this game (Place ID: " .. tostring(game.PlaceId) .. ")." })
    GameTab:Button({ Title = "Open Games List", Icon = "list", Callback = function() Window:SelectTab(2) end })
end
return Window
