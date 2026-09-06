-- Public-server selection for Games List; no saved/private server IDs.
return function(runtime)
    local env = getgenv()
    local http = game:GetService("HttpService")
    local teleport = game:GetService("TeleportService")
    local player = game:GetService("Players").LocalPlayer
    local active

    local function alive(context)
        return runtime.alive and active == context
    end
    local function report(context, message)
        if alive(context) then context.report(message) end
    end
    local function finish(context, message)
        if not alive(context) then return end
        report(context, message)
        active = nil
        runtime.joinInProgress = false
        -- A teleport error can also arrive through GuiService after this callback.
        runtime.joinFailureUntil = os.clock() + 5
    end
    local function websiteMessage(context)
        return "Roblox could not join. Open https://www.roblox.com/games/" .. context.entry.id .. " and press Play."
    end
    local function requestJSON(url)
        local requestFn = (env.syn and env.syn.request) or (env.http and env.http.request)
            or env.request or env.http_request
        local body
        if type(requestFn) == "function" then
            local response = requestFn({ Url = url, Method = "GET" })
            local code = type(response) == "table" and tonumber(response.StatusCode)
            assert(code and code >= 200 and code < 300, "Server list unavailable")
            body = response.Body
        else
            body = game:HttpGet(url, true)
        end
        return http:JSONDecode(body)
    end
    local function findServer(context)
        local cursor
        local seen = {}
        for _ = 1, 3 do
            if not alive(context) then return end
            local url = "https://games.roblox.com/v1/games/" .. context.entry.id
                .. "/servers/Public?sortOrder=Asc&excludeFullGames=true&limit=100"
                .. "&t=" .. tostring(os.time())
            if cursor then url = url .. "&cursor=" .. http:UrlEncode(cursor) end
            local page = requestJSON(url)
            if not alive(context) then return end
            assert(type(page) == "table" and type(page.data) == "table", "Invalid server list")
            for _, server in ipairs(page.data) do
                if type(server) == "table" and type(server.id) == "string" and server.id ~= ""
                    and server.id ~= game.JobId and not context.tried[server.id]
                    and type(server.playing) == "number" and type(server.maxPlayers) == "number"
                    and server.playing > 0 and server.playing < server.maxPlayers then
                    return server.id
                end
            end
            cursor = page.nextPageCursor
            if type(cursor) ~= "string" or cursor == "" or seen[cursor] then break end
            seen[cursor] = true
        end
    end
    local function startTimeout(context, attempt)
        task.spawn(function()
            task.wait(30)
            if alive(context) and context.attempt == attempt
                and (context.phase == "waiting" or context.phase == "native") then
                finish(context, "Join timed out. Click to try again.")
            end
        end)
    end
    local function normalPlay(context)
        if not alive(context) then return end
        context.phase = "prompt"
        report(context, "Choose Play / Join in the Roblox dialog.")
        local ok, result = pcall(function()
            return teleport:PromptExperienceDetailsAsync(player, tonumber(context.entry.universeId))
        end)
        if not alive(context) then return end
        if not ok then
            warn("LUB: Roblox join dialog failed: " .. tostring(result))
            finish(context, websiteMessage(context))
        elseif result == Enum.PromptExperienceDetailsResult.TeleportAttempted then
            context.phase = "native"
            report(context, "Roblox is finding a server...")
            startTimeout(context, context.attempt)
        else
            finish(context, "Join cancelled. Click to try again.")
        end
    end
    local attemptJoin
    local function failed(context, result, message)
        if not alive(context) or context.phase ~= "waiting" then return end
        context.phase = "retry"
        local text = string.lower(tostring(message))
        local restricted = result == Enum.TeleportResult.Unauthorized
            or text:find("restricted", 1, true) or text:find("unauthorized", 1, true)
            or text:find("permission", 1, true) or text:find("773", 1, true)
        if restricted or context.attempt >= 3 then
            normalPlay(context)
        else
            report(context, "Server unavailable. Finding another server...")
            task.wait(1)
            if alive(context) then attemptJoin(context) end
        end
    end
    attemptJoin = function(context)
        if not alive(context) then return end
        context.phase = "search"
        report(context, "Finding a public server with free slots...")
        local ok, serverId = pcall(findServer, context)
        if not alive(context) then return end
        if not ok or not serverId then normalPlay(context); return end
        context.tried[serverId] = true
        context.attempt += 1
        context.serverId = serverId
        context.phase = "waiting"
        report(context, "Joining " .. context.entry.game .. "...")
        local joined, err = pcall(function()
            teleport:TeleportToPlaceInstance(tonumber(context.entry.id), serverId, player)
        end)
        if not alive(context) then return end
        if not joined then failed(context, nil, err) else startTimeout(context, context.attempt) end
    end
    runtime.track(teleport.TeleportInitFailed:Connect(function(target, result, message, placeId, options)
        local context = active
        if not context or not alive(context) or target ~= player or tonumber(placeId) ~= tonumber(context.entry.id) then return end
        if context.phase == "native" or context.phase == "prompt" then
            finish(context, websiteMessage(context))
        elseif context.phase == "waiting" then
            if options and options.ServerInstanceId and options.ServerInstanceId ~= ""
                and options.ServerInstanceId ~= context.serverId then return end
            failed(context, result, message)
        end
    end))
    function runtime.joinGame(entry, onStatus)
        if not runtime.alive then return end
        if active then onStatus("A join is already in progress."); return end
        local context = { entry = entry, report = onStatus, tried = {}, attempt = 0 }
        active = context
        runtime.joinInProgress = true
        attemptJoin(context)
    end
    table.insert(runtime.cleanups, function()
        active = nil
        runtime.joinInProgress = false
    end)
end
