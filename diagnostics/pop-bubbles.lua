-- LUB Pop Bubbles diagnostic: reads local state and incoming events only.
-- Does not invoke remotes, buy, throw, teleport or change controller settings.
local player = game:GetService("Players").LocalPlayer
local rs = game:GetService("ReplicatedStorage")
local http = game:GetService("HttpService")
assert(game.PlaceId == 72390882197205, "Run this diagnostic in Pop Bubbles")
local report = {placeId=game.PlaceId, version=getgenv().LUBRuntime and getgenv().LUBRuntime.version,
    capturedAt=os.time(), errors={}, scripts={}, scriptIndex={}, events={}, connections={}}
local function cleanString(value)
    if utf8.len(value) then return value end
    -- Decompiled source can contain raw non-UTF-8 bytes, rejected by JSONEncode.
    return "[non-UTF8 bytes escaped] " .. value:gsub("[\128-\255]", function(byte)
        return string.format("\\x%02X", string.byte(byte))
    end)
end
local function plain(value, depth, seen, wholeReport)
    local kind = typeof(value)
    if kind == "string" then return cleanString(value) end
    if kind == "nil" or kind == "boolean" then return value end
    if kind == "number" then return value == value and math.abs(value) < math.huge and value or tostring(value) end
    if kind == "Instance" then return cleanString(value:GetFullName()) end
    if kind ~= "table" then return cleanString(tostring(value)) end
    depth, seen = depth or 0, seen or {}
    if depth >= (wholeReport and 20 or 6) then return "[depth limit]" end
    if seen[value] then return "[reference]" end
    seen[value] = true
    local out, count = {}, 0
    for key, child in pairs(value) do
        count += 1
        if count > (wholeReport and 10000 or 300) then out._truncated = true; break end
        out[cleanString(tostring(key))] = plain(child, depth+1, seen, wholeReport)
    end
    seen[value] = nil
    return out
end
local function attempt(label, action)
    local ok, result = pcall(action)
    if not ok then table.insert(report.errors, label .. ": " .. tostring(result)); return nil end
    return result
end
local function inspect(object)
    local data = {path=object:GetFullName(), class=object.ClassName, attributes=plain(object:GetAttributes())}
    if object:IsA("BasePart") then
        data.position, data.size, data.transparency = tostring(object.Position), tostring(object.Size), object.Transparency
        data.canQuery, data.canTouch = object.CanQuery, object.CanTouch
    elseif object:IsA("Model") then data.pivot = tostring(object:GetPivot())
    elseif object:IsA("Attachment") then data.position = tostring(object.WorldPosition)
    elseif object:IsA("ValueBase") then data.value = plain(object.Value) end
    return data
end
local function tree(root, limit)
    local out = {inspect(root)}
    for index, child in ipairs(root:GetDescendants()) do
        if index > limit then table.insert(out, {truncated=true}); break end
        table.insert(out, inspect(child))
    end
    return out
end
local function snapshot()
    local state = {attributes=plain(player:GetAttributes()), world={}, character={}, controller={}}
    if player.Character then state.character = tree(player.Character, 160) end
    if player:FindFirstChild("leaderstats") then state.leaderstats = tree(player.leaderstats, 80) end
    for _, root in ipairs(workspace:GetChildren()) do
        local name = root.Name:lower()
        if root.Name == "ClientRenderedBubbles_" .. player.UserId or name:find("essence")
            or name:find("flame") or name:find("drop") then
            table.insert(state.world, tree(root, 250))
        end
    end
    state.controller = attempt("WeaponController", function()
        local class = require(player.PlayerScripts.Weapon.WeaponController).WeaponController
        local controller = class:getInstance()
        if not controller then return {found=false} end
        return {found=true, cachedRoot=plain(controller.cachedRoot), fireRate=controller.cachedFireRate,
            equippedId=controller.cachedEquippedId, lastFireTime=controller.lastFireTime,
            clockNow=tick(), autoThrow=controller.isAutoThrowEnabled,
            manualHeld=controller.isHoldingMouseButton, gamepadHeld=controller.isHoldingGamepadTrigger}
    end)
    return state
end
report.before = attempt("Initial state", snapshot)
local remotes = rs:FindFirstChild("Remotes")
report.remotes = {}
if remotes then
    for _, remote in ipairs(remotes:GetChildren()) do table.insert(report.remotes, {name=remote.Name, class=remote.ClassName}) end
end
local connections = {}
for _, name in ipairs({"EssenceDropEvent", "CashDropEvent", "GemDropEvent", "BubbleUpdate", "BubblePopBatch", "WeaponThrowVisual"}) do
    local remote = remotes and remotes:FindFirstChild(name)
    if remote and remote:IsA("RemoteEvent") then
        local connection = attempt("Listen " .. name, function()
            return remote.OnClientEvent:Connect(function(...)
                if #report.events >= 300 then report.eventsTruncated = true; return end
                local args = table.pack(...)
                attempt("Capture " .. name, function()
                    table.insert(report.events, {name=name, time=os.clock(), arguments=plain(args)})
                end)
            end)
        end)
        if connection then table.insert(connections, connection); table.insert(report.connections, name) end
    end
end
print("LUB diagnostic: recording for 15 seconds. Collect a flame and try Autofarm during this time.")
local started = os.clock()
attempt("Client sources", function()
    for _, root in ipairs({player.PlayerScripts, rs}) do
        for _, object in ipairs(root:GetDescendants()) do
            if object:IsA("ModuleScript") or object:IsA("LocalScript") then
                local name = object.Name:lower()
                local relevant = name == "clientmain" or name:find("essence") or name:find("drop")
                    or name:find("bubblet") or name:find("rebirth") or name:find("weaponcontroller")
                    or name:find("weaponrenderer") or name:find("throworigin") or name:find("loadingcontroller")
                    or name:find("bubblecontroller") or name:find("bubblerender")
                if relevant then
                    local path = object:GetFullName()
                    table.insert(report.scriptIndex, path)
                    if type(decompile) == "function" then
                        local source = attempt(path, function() return decompile(object) end)
                        if type(source) == "string" then report.scripts[path] = source end
                    end
                end
            end
        end
    end
end)
if type(decompile) ~= "function" then table.insert(report.errors, "decompile is unavailable") end
while os.clock()-started < 15 do task.wait(0.1) end
for _, connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
report.after = attempt("Final state", snapshot)
local safeReport = plain(report, 0, nil, true)
local encoded, output = pcall(function() return http:JSONEncode(safeReport) end)
local extension = ".json"
if not encoded then
    table.insert(report.errors, "JSONEncode failed; exporting text instead: " .. tostring(output))
    -- Preserve the complete report even if the executor's JSON encoder fails.
    local function textValue(value)
        if type(value) == "string" then return string.format("%q", value) end
        if type(value) ~= "table" then return tostring(value) end
        local parts = {"{"}
        for key, child in pairs(value) do
            table.insert(parts, "[" .. string.format("%q", key) .. "]=" .. textValue(child) .. ",\n")
        end
        table.insert(parts, "}")
        return table.concat(parts)
    end
    output = "LUB diagnostic (text fallback)\n" .. textValue(plain(report, 0, nil, true))
    extension = ".txt"
end
local saved = attempt("Save diagnostic", function()
    assert(type(writefile) == "function" and type(makefolder) == "function" and type(isfolder) == "function", "File APIs unavailable")
    if not isfolder("LUB") then makefolder("LUB") end
    local path = "LUB/PopBubbles-Diagnostic-" .. report.capturedAt .. extension
    writefile(path, output)
    return path
end)
local copied = attempt("Clipboard", function() assert(type(setclipboard) == "function", "Clipboard unavailable"); setclipboard(output); return true end)
print("LUB diagnostic complete: " .. #output .. " bytes. " .. (saved or "File could not be saved.") .. (copied and " Copied to clipboard." or ""))
if not saved and not copied then print(output) end
for _, message in ipairs(report.errors) do warn("LUB diagnostic: " .. message) end
