-- LUB 2.0: WindUI 1.6.66, with Game, Games List and Settings only.
local env = getgenv()
local runtime = env.LUBRuntime
local source = game:HttpGet("https://github.com/Footagesus/WindUI/releases/download/1.6.66/main.lua")
local library, compileError = loadstring(source, "@WindUI/1.6.66")
assert(library, "LUB: WindUI could not compile: " .. tostring(compileError))
local WindUI = library()
local Window = WindUI:CreateWindow({
    Title = "LUB",
    Author = "Chicken Farm",
    Folder = "LUB/WindUI",
    Icon = "egg",
    Theme = "Dark",
    Size = UDim2.fromOffset(660, 480),
    SideBarWidth = 180,
    NewElements = true,
    Transparent = false,
    Acrylic = false,
    ToggleKey = Enum.KeyCode.RightShift,
    OpenButton = { Title = "LUB", Enabled = true, Draggable = true, OnlyMobile = false },
})
assert(Window, "LUB: WindUI window could not be created")
runtime.window = Window
Window:OnDestroy(function() runtime.cleanup(true) end)

local GameTab = Window:Tab({ Title = "Game", Icon = "gamepad-2" })
local GamesTab = Window:Tab({ Title = "Games List", Icon = "list" })
local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })
Window:SelectTab(1)

local gameList = game:GetService("HttpService"):JSONDecode(env.LUBRead("src/gameslist.json"))
local supported
GamesTab:Section({ Title = "Supported Game" })
for _, entry in ipairs(gameList) do
    if tostring(game.PlaceId) == tostring(entry.id) then supported = entry end
    GamesTab:Button({
        Title = entry.game,
        Desc = "Place ID: " .. tostring(entry.id),
        Icon = "play",
        Callback = function()
            if not runtime.alive then return end
            if tostring(game.PlaceId) == tostring(entry.id) then
                Window:SelectTab(1)
            else
                game:GetService("TeleportService"):Teleport(tonumber(entry.id), game:GetService("Players").LocalPlayer)
            end
        end,
    })
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
SettingsTab:Paragraph({
    Title = "LUB 2.0",
    Desc = "WindUI by Footages. Based on BrainrotPolice by esore / vaehz.\nRight Shift: show / hide. Settings save automatically when file access is available.",
})
SettingsTab:Button({
    Title = "Unload LUB", Desc = "Stop farming and close LUB.", Icon = "power",
    Callback = function() runtime.cleanup() end,
})

if supported then
    local ok, err = pcall(function()
        env.LUBRequire("src/games/" .. supported.id .. ".lua")(GameTab, runtime.config)
    end)
    if not ok then
        GameTab:Paragraph({ Title = "Game could not load", Desc = tostring(err) })
        warn("LUB: " .. tostring(err))
    end
else
    GameTab:Paragraph({ Title = "Chicken Farm only", Desc = "LUB supports place 137233438285284. Open it through Games List." })
    GameTab:Button({ Title = "Open Games List", Icon = "list", Callback = function() Window:SelectTab(2) end })
end
return Window
