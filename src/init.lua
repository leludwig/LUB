-- LUB: modified from BrainrotPolice. See LICENSE and NOTICE.
if not game:IsLoaded() then game.Loaded:Wait() end

local env = getgenv()
local VERSION = "2.0.0"
if env.LUBRuntime and env.LUBRuntime.alive then
    if env.LUBRuntime.version == VERSION then
        env.LUBRuntime.show()
        return
    end
    -- Replace the old interface and stop its farm workers when upgrading in place.
    env.LUBRuntime.cleanup()
end

local http = game:GetService("HttpService")
local runtime = { alive = true, version = VERSION, cleanups = {}, cache = {} }
env.LUBRuntime = runtime
env.LUBRoot = env.LUBRoot or "LUB"
env.LUBConfigPath = env.LUBRoot .. "/Config.json"

function runtime.track(connection)
    table.insert(runtime.cleanups, function() connection:Disconnect() end)
    return connection
end

function runtime.cleanup(fromWindow)
    if not runtime.alive then return end
    runtime.alive = false
    for _, cleanup in ipairs(runtime.cleanups) do pcall(cleanup) end
    pcall(function() game:GetService("RunService"):Set3dRenderingEnabled(true) end)
    if runtime.window and not fromWindow then runtime.window:Destroy() end
end

function runtime.show()
    if runtime.window then runtime.window:Open() end
end

function env.LUBRead(path)
    if env.LUBSources and env.LUBSources[path] then return env.LUBSources[path] end
    local localPath = env.LUBRoot .. "/" .. path
    if isfile and readfile and isfile(localPath) then return readfile(localPath) end
    error("LUB: missing " .. path .. ". Run the bundled LUB.lua.")
end

function env.LUBRequire(path)
    if runtime.cache[path] ~= nil then return runtime.cache[path] end
    local chunk, compileError = loadstring(env.LUBRead(path), "@LUB/" .. path)
    assert(chunk, compileError)
    local result = chunk()
    runtime.cache[path] = result
    return result
end

local canSave = isfolder and makefolder and isfile and readfile and writefile
local config = { settings = {} }
local ok, reason = pcall(function()
    if canSave then
        if not isfolder(env.LUBRoot) then makefolder(env.LUBRoot) end
        if isfile(env.LUBConfigPath) then
            local decoded = http:JSONDecode(readfile(env.LUBConfigPath))
            assert(type(decoded) == "table", "Config must be an object")
            config = decoded
        end
    end
end)
if not ok then warn("LUB: settings could not be read: " .. tostring(reason)) end
if type(config.settings) ~= "table" then config.settings = {} end
-- Keep only the supported game when migrating an older LUB configuration.
config = { settings = config.settings, ["137233438285284"] = config["137233438285284"] }
config.settings.auto_rejoin_on_kick = config.settings.auto_rejoin_on_kick == true
config.settings.disable_3d_rendering = config.settings.disable_3d_rendering == true
runtime.config = config
runtime.canSave = not not canSave

function env.LUBSaveConfig(data)
    config = data or config
    runtime.config = config
    if not canSave then return end
    local saved, saveError = pcall(function()
        writefile(env.LUBConfigPath, http:JSONEncode(config))
    end)
    if not saved then warn("LUB: settings could not be saved: " .. tostring(saveError)) end
end

function env.setconfig(key, value)
    local place = tostring(game.PlaceId)
    if type(config[place]) ~= "table" then config[place] = {} end
    config[place][key] = value
    env.LUBSaveConfig()
end

function runtime.setSetting(key, value)
    config.settings[key] = value
    env.LUBSaveConfig()
end

env.LUBSaveConfig()
local rejoining = false
runtime.track(game:GetService("GuiService").ErrorMessageChanged:Connect(function(message)
    if runtime.alive and config.settings.auto_rejoin_on_kick and not rejoining and message ~= "" then
        rejoining = true
        local joined, joinError = pcall(function()
            game:GetService("TeleportService"):Teleport(game.PlaceId, game:GetService("Players").LocalPlayer)
        end)
        if not joined then
            rejoining = false
            warn("LUB: rejoin failed: " .. tostring(joinError))
        end
    end
end))

-- Reload the user's local bundle after teleport, never the upstream tool.
local queue = queue_on_teleport or queueonteleport
if queue and isfile and isfile(env.LUBRoot .. "/LUB.lua") then
    pcall(queue, string.format("getgenv().LUBRoot = %q; loadstring(readfile(%q))()", env.LUBRoot, env.LUBRoot .. "/LUB.lua"))
end

local loaded, loadError = pcall(function() env.LUBRequire("src/ui.lua") end)
if not loaded then
    runtime.cleanup()
    error("LUB could not start: " .. tostring(loadError))
end
