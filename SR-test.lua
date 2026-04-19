-- ============================================================
-- SkyRivals | QuickPlay Race Script
-- Goal: Get into a filling lobby FASTER than anyone else
-- ============================================================

local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")

local PlaceId   = 16735970772
local Player    = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG = {
    -- Servers with this many players are "filling"
    -- Low number = earlier you get in = more likely to be in the match
    FillMin          = 1,
    FillMax          = 4,

    -- How many servers to fetch per request
    -- 100 is max the API allows
    FetchLimit       = 100,

    -- How fast to poll the API looking for a filling server
    -- 0.1 = 10 times per second (fast but safe)
    PollRate         = 0.1,

    -- How many poll attempts before giving up
    -- 50 attempts × 0.1s = 5 seconds max search time
    MaxAttempts      = 50,

    -- Seconds to wait before allowing another race trigger
    -- Prevents accidental double-fires
    TriggerCooldown  = 5,

    Version          = "v5.0",
    MaxLogLines      = 10,
}

-- ============================================================
-- STATE
-- ============================================================
local State = {
    LogLines        = {},
    IsRacing        = false,
    RaceCount       = 0,
    WinCount        = 0,
    StartTime       = os.time(),
    LastTriggerTime = 0,
}

-- ============================================================
-- DESTROY OLD GUI
-- ============================================================
pcall(function()
    local old = PlayerGui:FindFirstChild("SkyRivalsConsole")
    if old then old:Destroy() end
end)

task.wait(0.1)

-- ============================================================
-- GUI
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name         = "SkyRivalsConsole"
screenGui.ResetOnSpawn = false
screenGui.Parent       = PlayerGui

local frame = Instance.new("Frame")
frame.Name             = "MainFrame"
frame.Size             = UDim2.new(0, 300, 0, 390)
frame.Position         = UDim2.new(0.5, -150, 0.5, -195)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel  = 1
frame.Active           = true
frame.Parent           = screenGui

local titleLbl = Instance.new("TextLabel")
titleLbl.Size             = UDim2.new(1, 0, 0, 30)
titleLbl.Position         = UDim2.new(0, 0, 0, 0)
titleLbl.Text             = "SR RACE " .. CONFIG.Version
titleLbl.TextColor3       = Color3.fromRGB(0, 200, 255)
titleLbl.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
titleLbl.Font             = Enum.Font.GothamBold
titleLbl.TextSize         = 14
titleLbl.BorderSizePixel  = 0
titleLbl.Parent           = frame

local statusLbl = Instance.new("TextLabel")
statusLbl.Size             = UDim2.new(1, 0, 0, 24)
statusLbl.Position         = UDim2.new(0, 0, 0, 32)
statusLbl.Text             = "Status: Waiting for QuickPlay..."
statusLbl.TextColor3       = Color3.fromRGB(255, 255, 255)
statusLbl.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
statusLbl.Font             = Enum.Font.Gotham
statusLbl.TextSize         = 11
statusLbl.BorderSizePixel  = 0
statusLbl.Parent           = frame

local function setStatus(txt)
    statusLbl.Text = "Status: " .. txt
end

local timeLbl = Instance.new("TextLabel")
timeLbl.Size             = UDim2.new(1, 0, 0, 22)
timeLbl.Position         = UDim2.new(0, 0, 0, 58)
timeLbl.Text             = "Server Time: --:--:-- UTC"
timeLbl.TextColor3       = Color3.fromRGB(200, 200, 200)
timeLbl.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
timeLbl.Font             = Enum.Font.Gotham
timeLbl.TextSize         = 11
timeLbl.BorderSizePixel  = 0
timeLbl.Parent           = frame

local statsLbl = Instance.new("TextLabel")
statsLbl.Size             = UDim2.new(1, 0, 0, 22)
statsLbl.Position         = UDim2.new(0, 0, 0, 82)
statsLbl.Text             = "Races: 0  |  Wins: 0  |  Uptime: 0s"
statsLbl.TextColor3       = Color3.fromRGB(200, 200, 200)
statsLbl.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
statsLbl.Font             = Enum.Font.Gotham
statsLbl.TextSize         = 11
statsLbl.BorderSizePixel  = 0
statsLbl.Parent           = frame

local function updateStats()
    local up    = os.time() - State.StartTime
    local m     = math.floor(up / 60)
    local s     = up % 60
    local upStr = m > 0
        and string.format("%dm%ds", m, s)
        or  string.format("%ds", s)
    statsLbl.Text = string.format(
        "Races: %d  |  Wins: %d  |  Uptime: %s",
        State.RaceCount, State.WinCount, upStr
    )
end

-- Race progress bar
local progressBg = Instance.new("Frame")
progressBg.Size             = UDim2.new(1, -10, 0, 14)
progressBg.Position         = UDim2.new(0, 5, 0, 107)
progressBg.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
progressBg.BorderSizePixel  = 1
progressBg.Parent           = frame

local progressBar = Instance.new("Frame")
progressBar.Size             = UDim2.new(0, 0, 1, 0)
progressBar.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
progressBar.BorderSizePixel  = 0
progressBar.Parent           = progressBg

local progressLbl = Instance.new("TextLabel")
progressLbl.Size               = UDim2.new(1, 0, 1, 0)
progressLbl.Text               = "IDLE"
progressLbl.TextColor3         = Color3.fromRGB(255, 255, 255)
progressLbl.BackgroundTransparency = 1
progressLbl.Font               = Enum.Font.GothamBold
progressLbl.TextSize           = 9
progressLbl.Parent             = progressBg

local function setProgress(ratio, label)
    -- ratio = 0.0 to 1.0
    progressBar.Size             = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0)
    progressBar.BackgroundColor3 = ratio >= 1
        and Color3.fromRGB(0, 255, 100)
        or  Color3.fromRGB(0, 200 * ratio + 50, 255 * (1 - ratio))
    progressLbl.Text = label or ""
end

local logLbl = Instance.new("TextLabel")
logLbl.Size             = UDim2.new(1, -10, 0, 175)
logLbl.Position         = UDim2.new(0, 5, 0, 128)
logLbl.Text             = ""
logLbl.TextColor3       = Color3.fromRGB(200, 255, 200)
logLbl.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
logLbl.Font             = Enum.Font.Code
logLbl.TextSize         = 10
logLbl.TextXAlignment   = Enum.TextXAlignment.Left
logLbl.TextYAlignment   = Enum.TextYAlignment.Top
logLbl.TextWrapped      = true
logLbl.BorderSizePixel  = 1
logLbl.Parent           = frame

-- Buttons
local raceBtn = Instance.new("TextButton")
raceBtn.Size             = UDim2.new(0, 88, 0, 30)
raceBtn.Position         = UDim2.new(0, 5, 0, 310)
raceBtn.Text             = "▶ RACE"
raceBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
raceBtn.BackgroundColor3 = Color3.fromRGB(30, 150, 30)
raceBtn.Font             = Enum.Font.GothamBold
raceBtn.TextSize         = 12
raceBtn.BorderSizePixel  = 0
raceBtn.Parent           = frame

local stopBtn = Instance.new("TextButton")
stopBtn.Size             = UDim2.new(0, 88, 0, 30)
stopBtn.Position         = UDim2.new(0, 100, 0, 310)
stopBtn.Text             = "■ STOP"
stopBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
stopBtn.BackgroundColor3 = Color3.fromRGB(160, 30, 30)
stopBtn.Font             = Enum.Font.GothamBold
stopBtn.TextSize         = 12
stopBtn.BorderSizePixel  = 0
stopBtn.Parent           = frame

local clearBtn = Instance.new("TextButton")
clearBtn.Size             = UDim2.new(0, 88, 0, 30)
clearBtn.Position         = UDim2.new(0, 195, 0, 310)
clearBtn.Text             = "CLEAR"
clearBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
clearBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
clearBtn.Font             = Enum.Font.GothamBold
clearBtn.TextSize         = 12
clearBtn.BorderSizePixel  = 0
clearBtn.Parent           = frame

-- Fill range controls
local rangeLbl = Instance.new("TextLabel")
rangeLbl.Size             = UDim2.new(1, -10, 0, 20)
rangeLbl.Position         = UDim2.new(0, 5, 0, 348)
rangeLbl.Text             = string.format("Fill range: %dP - %dP  (target filling lobbies)", CONFIG.FillMin, CONFIG.FillMax)
rangeLbl.TextColor3       = Color3.fromRGB(180, 180, 180)
rangeLbl.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
rangeLbl.Font             = Enum.Font.Gotham
rangeLbl.TextSize         = 10
rangeLbl.BorderSizePixel  = 0
rangeLbl.Parent           = frame

local function updateRangeLbl()
    rangeLbl.Text = string.format(
        "Fill range: %dP - %dP  (target filling lobbies)",
        CONFIG.FillMin, CONFIG.FillMax
    )
end

local rangeBtnDefs = {
    { label = "Fil-", x = 5,   fn = function() CONFIG.FillMin = math.max(0, CONFIG.FillMin - 1) end },
    { label = "Fil+", x = 40,  fn = function() CONFIG.FillMin = math.min(CONFIG.FillMax, CONFIG.FillMin + 1) end },
    { label = "Max-", x = 80,  fn = function() CONFIG.FillMax = math.max(CONFIG.FillMin, CONFIG.FillMax - 1) end },
    { label = "Max+", x = 115, fn = function() CONFIG.FillMax = CONFIG.FillMax + 1 end },
}

local allContent = { statusLbl, timeLbl, statsLbl, progressBg, logLbl, raceBtn, stopBtn, clearBtn, rangeLbl }

for _, def in ipairs(rangeBtnDefs) do
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(0, 30, 0, 22)
    btn.Position         = UDim2.new(0, def.x, 0, 372)
    btn.Text             = def.label
    btn.TextColor3       = Color3.fromRGB(255, 255, 255)
    btn.BackgroundColor3 = def.label:find("-")
        and Color3.fromRGB(80, 40, 40)
        or  Color3.fromRGB(40, 80, 40)
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 9
    btn.BorderSizePixel  = 0
    btn.Parent           = frame
    btn.MouseButton1Click:Connect(function()
        def.fn()
        updateRangeLbl()
    end)
    table.insert(allContent, btn)
end

-- Minimize
local isMinimized = false
local minBtn = Instance.new("TextButton")
minBtn.Size             = UDim2.new(0, 60, 0, 20)
minBtn.Position         = UDim2.new(0, 235, 0, 5)
minBtn.Text             = "[ - ]"
minBtn.TextColor3       = Color3.fromRGB(200, 200, 200)
minBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
minBtn.Font             = Enum.Font.GothamBold
minBtn.TextSize         = 11
minBtn.BorderSizePixel  = 0
minBtn.Parent           = frame

minBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    for _, v in ipairs(allContent) do v.Visible = not isMinimized end
    frame.Size  = isMinimized
        and UDim2.new(0, 300, 0, 30)
        or  UDim2.new(0, 300, 0, 390)
    minBtn.Text = isMinimized and "[ + ]" or "[ - ]"
end)

-- ============================================================
-- MOBILE-SAFE DRAG
-- ============================================================
do
    local dragging  = false
    local dragStart = Vector2.zero
    local frameOrig = Vector2.zero

    local function startDrag(pos)
        dragging  = true
        dragStart = pos
        frameOrig = Vector2.new(
            frame.Position.X.Offset,
            frame.Position.Y.Offset
        )
    end
    local function moveDrag(pos)
        if not dragging then return end
        local d  = pos - dragStart
        local vp = screenGui.AbsoluteSize
        frame.Position = UDim2.fromOffset(
            math.clamp(frameOrig.X + d.X, 0, vp.X - 300),
            math.clamp(frameOrig.Y + d.Y, 0, vp.Y - (isMinimized and 30 or 390))
        )
    end
    local function stopDrag() dragging = false end

    titleLbl.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            startDrag(Vector2.new(i.Position.X, i.Position.Y))
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch then
            moveDrag(Vector2.new(i.Position.X, i.Position.Y))
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            stopDrag()
        end
    end)
end

-- ============================================================
-- LOGGING
-- ============================================================
local prefixMap = {
    info = "›", ok = "✓", warn = "⚠",
    err  = "✕", race = "⚡", time = "⏱",
}

local function log(msg, level)
    level = level or "info"
    local ts   = os.date("!%H:%M:%S")
    local pre  = prefixMap[level] or "›"
    local line = string.format("[%s] %s %s", ts, pre, tostring(msg))

    table.insert(State.LogLines, 1, line)
    while #State.LogLines > CONFIG.MaxLogLines do
        table.remove(State.LogLines)
    end

    logLbl.Text = table.concat(State.LogLines, "\n")
    print("[SkyRivals] " .. line)
end

-- ============================================================
-- HTTP  (http_request primary)
-- ============================================================
local function httpGet(url)
    -- PRIMARY: http_request
    if http_request then
        local ok, res = pcall(http_request, {
            Url     = url,
            Method  = "GET",
            Headers = { ["Accept"] = "application/json" },
        })
        if ok and res then
            local code = tonumber(res.StatusCode or res.statusCode) or 200
            if code == 429 then return nil, "RATE_LIMITED" end
            if code ~= 200 then return nil, "HTTP_" .. tostring(code) end
            local body = res.Body or res.body
            if body and #body > 0 then return body end
            return nil, "EMPTY_BODY"
        end
        return nil, "http_request pcall failed: " .. tostring(res)
    end

    -- FALLBACK: request
    if request then
        local ok, res = pcall(request, {
            Url     = url,
            Method  = "GET",
            Headers = { ["Accept"] = "application/json" },
        })
        if ok and res then
            local code = tonumber(res.StatusCode or res.statusCode) or 200
            if code == 429 then return nil, "RATE_LIMITED" end
            if code ~= 200 then return nil, "HTTP_" .. tostring(code) end
            local body = res.Body or res.body
            if body and #body > 0 then return body end
        end
    end

    -- FALLBACK: syn
    if syn and syn.request then
        local ok, res = pcall(syn.request, { Url = url, Method = "GET" })
        if ok and res then
            local body = res.Body or res.body
            if body and #body > 0 then return body end
        end
    end

    return nil, "ALL_HTTP_FAILED"
end

-- ============================================================
-- HEARTBEAT
-- ============================================================
RunService.Heartbeat:Connect(function()
    timeLbl.Text = "Server Time: " .. os.date("!%H:%M:%S") .. " UTC"
    updateStats()
end)

-- ============================================================
-- REMOTE LINKING
-- ============================================================
log("Waiting for QuickPlay remote...", "race")

local RemoteFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
local QuickPlay    = RemoteFolder and RemoteFolder:WaitForChild("QuickPlay", 10)

if QuickPlay then
    setStatus("Hooked — click QuickPlay to race")
    log("QuickPlay remote found", "ok")
else
    setStatus("Remote not found — manual scan only")
    log("QuickPlay not found", "err")
end

-- ============================================================
-- CORE RACE LOGIC
-- This is the entire point of the script.
-- Poll the API as fast as safely possible,
-- the MOMENT a filling server appears → teleport instantly.
-- ============================================================
local stopRace = false  -- flag to cancel mid-race

local function doRace(onFail)
    if State.IsRacing then
        log("Already racing", "warn")
        return
    end

    stopRace         = false
    State.IsRacing   = true
    State.RaceCount += 1
    local attempt    = 0
    local raceStart  = os.clock()

    log(string.format(
        "RACE STARTED | target %dP-%dP | max %d attempts",
        CONFIG.FillMin, CONFIG.FillMax, CONFIG.MaxAttempts
    ), "race")
    setStatus("Racing...")

    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=%d",
        PlaceId, CONFIG.FetchLimit
    )

    while attempt < CONFIG.MaxAttempts and not stopRace do
        attempt += 1

        -- Update progress bar
        local ratio = attempt / CONFIG.MaxAttempts
        setProgress(ratio, string.format("Attempt %d/%d", attempt, CONFIG.MaxAttempts))

        -- Fetch server list
        local body, err = httpGet(url)

        if not body then
            if err == "RATE_LIMITED" then
                -- Back off on rate limit
                log("Rate limited — backing off 2s", "warn")
                task.wait(2)
                continue
            else
                log("Fetch err: " .. tostring(err), "err")
                task.wait(0.5)
                continue
            end
        end

        -- Decode JSON
        local ok, decoded = pcall(HttpService.JSONDecode, HttpService, body)
        if not ok or not decoded or not decoded.data then
            task.wait(CONFIG.PollRate)
            continue
        end

        -- ── THE RACE FILTER ──────────────────────────────
        -- Find the BEST filling server as fast as possible
        -- Priority: lowest player count in range (just started filling = 
        -- most room + most time before it locks)
        local bestServer = nil
        local bestCount  = math.huge

        for _, sv in ipairs(decoded.data) do
            -- Skip current server
            if sv.id == game.JobId then continue end

            local p = tonumber(sv.playing) or 0

            -- Is this server in our target fill range?
            if p >= CONFIG.FillMin and p <= CONFIG.FillMax then
                -- Take the server with FEWEST players
                -- (freshest lobby = most advantage)
                if p < bestCount then
                    bestCount  = p
                    bestServer = sv
                end
            end
        end

        -- ── FOUND ONE — GO IMMEDIATELY ───────────────────
        if bestServer then
            local elapsed = os.clock() - raceStart
            local p       = tonumber(bestServer.playing) or 0
            local cap     = tonumber(bestServer.maxPlayers) or 0
            local ping    = bestServer.ping
                and math.floor(bestServer.ping) or "?"

            log(string.format(
                "FOUND! %dP/%dP | ~%sms | attempt %d | %.2fs",
                p, cap, tostring(ping), attempt, elapsed
            ), "ok")
            setStatus(string.format("Teleporting! (%dP server)", p))
            setProgress(1, "LOCKED IN!")

            -- Teleport instantly — no delays
            local tpOk, tpErr = pcall(function()
                TeleportService:TeleportToPlaceInstance(
                    PlaceId, bestServer.id, Player
                )
            end)

            if tpOk then
                State.WinCount  += 1
                State.IsRacing   = false
                return
            else
                log("TP failed: " .. tostring(tpErr), "err")
                -- Server may have filled up in the milliseconds between
                -- finding it and teleporting — keep racing
            end
        else
            -- Log every 5 attempts so we don't spam
            if attempt % 5 == 0 then
                log(string.format(
                    "Attempt %d — no fill server yet, polling...",
                    attempt
                ), "info")
            end
        end

        -- Poll again after short delay
        task.wait(CONFIG.PollRate)
    end

    -- ── RACE FAILED (no server found in time) ────────────
    if not stopRace then
        local elapsed = os.clock() - raceStart
        log(string.format(
            "No filling server found after %d attempts (%.1fs)",
            attempt, elapsed
        ), "warn")
        setStatus("No filling lobby found — try again")
        setProgress(0, "FAILED")

        -- Fall back to normal QuickPlay if called from hook
        if onFail then onFail() end
    else
        log("Race stopped manually", "warn")
        setStatus("Stopped — click QuickPlay to race")
        setProgress(0, "STOPPED")
    end

    State.IsRacing = false
end

-- ============================================================
-- BUTTON WIRING
-- ============================================================
raceBtn.MouseButton1Click:Connect(function()
    if State.IsRacing then
        log("Already racing", "warn")
        return
    end
    task.spawn(doRace, nil)
end)

stopBtn.MouseButton1Click:Connect(function()
    if State.IsRacing then
        stopRace = true
        log("Stop requested", "warn")
    else
        log("Not currently racing", "info")
    end
end)

clearBtn.MouseButton1Click:Connect(function()
    State.LogLines = {}
    logLbl.Text    = ""
    log("Log cleared", "info")
end)

-- ============================================================
-- HOOK  (the real trigger — fires when player clicks QuickPlay)
-- ============================================================
if hookmetamethod and getnamecallmethod then
    local oldNC
    oldNC = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()

        if self == QuickPlay
        and (method == "FireServer" or method == "InvokeServer") then

            -- Cooldown so accidental double clicks don't fire twice
            local now = os.time()
            if (now - State.LastTriggerTime) < CONFIG.TriggerCooldown then
                log("Cooldown — ignoring duplicate trigger", "warn")
                return nil
            end
            State.LastTriggerTime = now

            local args = { ... }
            log("QuickPlay intercepted — starting race!", "race")

            task.spawn(function()
                doRace(function()
                    -- Only fires if race totally failed
                    -- Let original QuickPlay through as last resort
                    log("Falling back to normal QuickPlay", "warn")
                    pcall(function() oldNC(self, table.unpack(args)) end)
                end)
            end)

            -- Block original call — we handle it
            return nil
        end

        return oldNC(self, ...)
    end)

    log("Hook active — click QuickPlay to race", "ok")
else
    log("hookmetamethod unavailable", "warn")
    setStatus("Hook N/A — use RACE button manually")
end

-- ============================================================
-- STARTUP
-- ============================================================
log("SR Race " .. CONFIG.Version .. " loaded", "ok")
log("Time: " .. os.date("!%H:%M:%S") .. " UTC", "time")
log("Click QuickPlay OR press RACE button", "info")
