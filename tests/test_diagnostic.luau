-- Run the actual diagnostic against malformed source bytes and encoder failure.
for _, rejectJson in ipairs({false, true}) do
    local now, saved, clipboard, outputPath = 0, nil, nil, nil
    local source = "return '\255\254' -- gültiger Text"
    local cyclic = {}; cyclic.self = cyclic
    local scriptNode = {Name="ClientMain", ClassName="LocalScript"}
    function scriptNode:IsA(kind) return kind == "LocalScript" end
    function scriptNode:GetFullName() return "PlayerScripts.ClientMain" end
    local scripts = {Weapon={WeaponController={}}, GetDescendants=function() return {scriptNode} end}
    local player = {UserId=1, PlayerScripts=scripts, GetAttributes=function()
        return {invalid="\255", cycle=cyclic, good="gültig", nonfinite=0/0}
    end, FindFirstChild=function() return nil end}
    local storage = {GetDescendants=function() return {} end, FindFirstChild=function() return nil end}
    local http = {JSONEncode=function(_, report)
        assert(report.scripts["PlayerScripts.ClientMain"]:find("\\xFF\\xFE", 1, true))
        assert(report.before.attributes.good == "gültig")
        assert(type(report.before.controller.fireRate) == "string", "Nonfinite controller field not sanitized")
        local function validate(value)
            if type(value) == "string" then assert(utf8.len(value))
            elseif type(value) == "number" then assert(value == value and math.abs(value) < math.huge)
            elseif type(value) == "table" then
                for key, child in pairs(value) do assert(type(key) == "string" and utf8.len(key)); validate(child) end
            else assert(type(value) == "boolean" or value == nil) end
        end
        validate(report)
        if rejectJson then error("Can't convert to JSON") end
        return '{"validated":true}'
    end}
    local env = setmetatable({}, {__index=getfenv()})
    env.game = {PlaceId=72390882197205, GetService=function(_, name)
        return ({Players={LocalPlayer=player}, ReplicatedStorage=storage, HttpService=http})[name]
    end}
    env.workspace = {GetChildren=function() return {} end}
    env.getgenv = function() return {} end
    env.os = {clock=function() return now end, time=function() return 123 end}
    env.tick = function() return now end
    env.task = {wait=function(seconds) now += seconds end}
    env.require = function() return {WeaponController={getInstance=function() return {cachedFireRate=math.huge} end}} end
    env.decompile = function() return source end
    env.isfile = function() return false end
    env.isfolder = function() return true end
    env.makefolder = function() end
    env.writefile = function(path, text) outputPath, saved = path, text end
    env.setclipboard = function(text) clipboard = text end
    env.print, env.warn = function() end, function() end
    local run = assert(loadstring(DIAGNOSTIC_SOURCE))
    setfenv(run, env)
    run()
    assert(saved and clipboard == saved and now >= 15)
    if rejectJson then
        assert(outputPath:sub(-4) == ".txt" and saved:find("text fallback", 1, true))
        assert(saved:find("JSONEncode failed", 1, true))
    else assert(outputPath:sub(-5) == ".json" and saved == '{"validated":true}') end
end
print("2 diagnostic export tests passed")
