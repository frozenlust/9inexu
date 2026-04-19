-- ============================================================
-- SkyRivals Remote Hijacker | Owner Debug Tool
-- ============================================================

local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")

local PlaceId = 16735970772
local Player  = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG = {
    MinPlayers       = 1,
    MaxPlayers       = 20,
    ServerFetchLimit = 100,
    MaxPages         = 3,
    PageDelay        = 0.4,
    ScanCooldown     = 4,
    MaxLogLines      = 10,
    Version          = "v4.6",
}

-- ============================================================
-- STATE
-- ============================================================
local State = {
    LogLines        = {},
    IsScanning      = false,
    HijackCount     = 0,
    ScanCount       = 0,
    StartTime       = os.time(),
    LastScanTime    = 0,
    RemoteLinked    = false,
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
screenGui.Name           = "SkyRivalsConsole"
screenGui.ResetOnSpawn   = false
screenGui.Parent         = PlayerGui

local frame = Instance.new("Frame")
frame.Name              = "MainFrame"
frame.Size              = UDim2.new(0, 300, 0, 410)
frame.Position          = UDim2.new(0.5, -150, 0.5, -205)
frame.BackgroundColor3  = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel   = 1
frame.Active            = true
frame.Parent            = screenGui

local titleLbl = Instance.new("TextLabel")
titleLbl.Size               = UDim2.new(1, 0, 0, 30)
titleLbl.Position           = UDim2.new(0, 0, 0, 0)
titleLbl.Text               = "SR HIJACKER " .. CONFIG.Version
titleLbl.TextColor3         = Color3.fromRGB(0, 200, 255)
titleLbl.BackgroundColor3   = Color3.fromRGB(20, 20, 20)
titleLbl.Font               = Enum.Font.GothamBold
titleLbl.TextSize           = 14
titleLbl.BorderSizePixel    = 0
titleLbl.Parent             = frame

local statusLbl = Instance.new("TextLabel")
statusLbl.Size              = UDim2.new(1, 0, 0, 24)
statusLbl.Position          = UDim2.new(0, 0, 0, 32)
statusLbl.Text              = "Status: Initializing..."
statusLbl.TextColor3        = Color3.fromRGB(255, 255, 255)
statusLbl.BackgroundColor3  = Color3.fromRGB(25, 25, 25)
statusLbl.Font              = Enum.Font.Gotham
statusLbl.TextSize          = 11
statusLbl.BorderSizePixel   = 0
statusLbl.Parent            = frame

local function setStatus(txt)
    statusLbl.Text = "Status: " .. txt
end

local timeLbl = Instance.new("TextLabel")
timeLbl.Size              = UDim2.new(1, 0, 0, 22)
timeLbl.Position          = UDim2.new(0, 0, 0, 58)
timeLbl.Text              = "Server Time: --:--:-- UTC"
timeLbl.TextColor3        = Color3.fromRGB(200, 200, 200)
timeLbl.BackgroundColor3  = Color3.fromRGB(25, 25, 25)
timeLbl.Font              = Enum.Font.Gotham
timeLbl.TextSize          = 11
timeLbl.BorderSizePixel   = 0
timeLbl.Parent            = frame

local statsLbl = Instance.new("TextLabel")
statsLbl.Size             = UDim2.new(1, 0, 0, 22)
statsLbl.Position         = UDim2.new(0, 0, 0, 82)
statsLbl.Text             = "Hijacks: 0  |  Scans: 0  |  Uptime: 0s"
statsLbl.TextColor3       = Color3.fromRGB(200, 200, 200)
statsLbl.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
statsLbl.Font             = Enum.Font.Gotham
statsLbl.TextSize         = 11
statsLbl.BorderSizePixel  = 0
statsLbl.Parent           = frame

local function updateStats()
    local up = os.time() - State.StartTime
    local m  = math.floor(up / 60)
    local s  = up % 60
    local upStr = m > 0
        and string.format("%dm%ds", m, s)
        or  string.format("%ds", s)
    statsLbl.Text = string.format(
        "Hijacks: %d  |  Scans: %d  |  Uptime: %s",
        State.HijackCount, State.ScanCount, upStr
    )
end

local logLbl = Instance.new("TextLabel")
logLbl.Size               = UDim2.new(1, -10, 0, 200)
logLbl.Position           = UDim2.new(0, 5, 0, 110)
logLbl.Text               = ""
logLbl.TextColor3         = Color3.fromRGB(200, 255, 200)
logLbl.BackgroundColor3   = Color3.fromRGB(15, 15, 15)
logLbl.Font               = Enum.Font.Code
logLbl.TextSize           = 10
logLbl.TextXAlignment     = Enum.TextXAlignment.Left
logLbl.TextYAlignment     = Enum.TextYAlignment.Top
logLbl.TextWrapped        = true
logLbl.BorderSizePixel    = 1
logLbl.Parent             = frame

local scanBtn = Instance.new("TextButton")
scanBtn.Size              = UDim2.new(0, 88, 0, 30)
scanBtn.Position          = UDim2.new(0, 5, 0, 318)
scanBtn.Text              = "SCAN"
scanBtn.TextColor3        = Color3.fromRGB(255, 255, 255)
scanBtn.BackgroundColor3  = Color3.fromRGB(30, 90, 200)
scanBtn.Font              = Enum.Font.GothamBold
scanBtn.TextSize          = 12
scanBtn.BorderSizePixel   = 0
scanBtn.Parent            = frame

local clearBtn = Instance.new("TextButton")
clearBtn.Size             = UDim2.new(0, 88, 0, 30)
clearBtn.Position         = UDim2.new(0, 100, 0, 318)
clearBtn.Text             = "CLEAR LOG"
clearBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
clearBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
clearBtn.Font             = Enum.Font.GothamBold
clearBtn.TextSize         = 12
clearBtn.BorderSizePixel  = 0
clearBtn.Parent           = frame

local infoBtn = Instance.new("TextButton")
infoBtn.Size              = UDim2.new(0, 88, 0, 30)
infoBtn.Position          = UDim2.new(0, 195, 0, 318)
infoBtn.Text              = "INFO"
infoBtn.TextColor3        = Color3.fromRGB(255, 255, 255)
infoBtn.BackgroundColor3  = Color3.fromRGB(50, 50, 80)
infoBtn.Font              = Enum.Font.GothamBold
infoBtn.TextSize          = 12
infoBtn.BorderSizePixel   = 0
infoBtn.Parent            = frame

-- Range label
local rangeLbl = Instance.new("TextLabel")
rangeLbl.Size             = UDim2.new(1, -10, 0, 22)
rangeLbl.Position         = UDim2.new(0, 5, 0, 355)
rangeLbl.Text             = string.format("Target range: %dP - %dP", CONFIG.MinPlayers, CONFIG.MaxPlayers)
rangeLbl.TextColor3       = Color3.fromRGB(180, 180, 180)
rangeLbl.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
rangeLbl.Font             = Enum.Font.Gotham
rangeLbl.TextSize         = 11
rangeLbl.BorderSizePixel  = 0
rangeLbl.Parent           = frame

local function updateRangeLbl()
    rangeLbl.Text = string.format(
        "Target range: %dP - %dP",
        CONFIG.MinPlayers, CONFIG.MaxPlayers
    )
end

-- Range buttons
local rangeButtons = {
    { label = "Min-", x = 5,   action = function() CONFIG.MinPlayers = math.max(0, CONFIG.MinPlayers - 1) end },
    { label = "Min+", x = 40,  action = function() CONFIG.MinPlayers = math.min(CONFIG.MaxPlayers, CONFIG.MinPlayers + 1) end },
    { label = "Max-", x = 80,  action = function() CONFIG.MaxPlayers = math.max(CONFIG.MinPlayers, CONFIG.MaxPlayers - 1) end },
    { label = "Max+", x = 115, action = function() CONFIG.MaxPlayers = CONFIG.MaxPlayers + 1 end },
}

local allRangeBtns = {}
for _, def in ipairs(rangeButtons) do
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(0, 30, 0, 22)
    btn.Position         = UDim2.new(0, def.x, 0, 380)
    btn.Text             = def.label
    btn.TextColor3       = Color3.fromRGB(255, 255, 255)
    btn.BackgroundColor3 = def.label:find("-")
        and Color3.fromRGB(80, 40, 40)
        or  Color3.fromRGB(40, 80, 40)
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 10
    btn.BorderSizePixel  = 0
    btn.Parent           = frame
    btn.MouseButton1Click:Connect(function()
        def.action()
        updateRangeLbl()
    end)
    table.insert(allRangeBtns, btn)
end

-- Minimize
local isMinimized = false
local minBtn = Instance.new("TextButton")
minBtn.Size              = UDim2.new(0, 60, 0, 20)
minBtn.Position          = UDim2.new(0, 235, 0, 5)
minBtn.Text              = "[ - ]"
minBtn.TextColor3        = Color3.fromRGB(200, 200, 200)
minBtn.BackgroundColor3  = Color3.fromRGB(40, 40, 40)
minBtn.Font              = Enum.Font.GothamBold
minBtn.TextSize          = 11
minBtn.BorderSizePixel   = 0
minBtn.Parent            = frame

local allContent = {
    statusLbl, timeLbl, statsLbl, logLbl,
    scanBtn, clearBtn, infoBtn,
    rangeLbl,
}
for _, b in ipairs(allRangeBtns) do
    table.insert(allContent, b)
end

minBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    for _, v in ipairs(allContent) do
        v.Visible = not isMinimized
    end
    frame.Size = isMinimized
        and UDim2.new(0, 300, 0, 30)
        or  UDim2.new(0, 300, 0, 410)
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
            math.clamp(frameOrig.Y + d.Y, 0, vp.Y - (isMinimized and 30 or 410))
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
    info = "›",
    ok   = "✓",
    warn = "⚠",
    err  = "✕",
    scan = "◈",
    time = "⏱",
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
-- HTTP WRAPPER
-- http_request() primary, all others as fallback
-- ============================================================
local function httpGet(url)

    -- ── PRIMARY: http_request ──────────────────────────────
    if http_request then
        local ok, res = pcall(http_request, {
            Url     = url,
            Method  = "GET",
            Headers = { ["Accept"] = "application/json" },
        })

        if not ok then
            log("http_request pcall err: " .. tostring(res), "err")
            -- fall through to next method
        elseif res then
            local code = tonumber(res.StatusCode or res.statusCode) or 200

            if code == 429 then
                return nil, "RATE_LIMITED"
            end

            if code ~= 200 then
                return nil, "HTTP_STATUS_" .. tostring(code)
            end

            local body = res.Body or res.body
            if body and #body > 0 then
                return body
            else
                return nil, "EMPTY_BODY"
            end
        else
            log("http_request returned nil", "err")
        end
    end

    -- ── FALLBACK 1: request ────────────────────────────────
    if request then
        local ok, res = pcall(request, {
            Url     = url,
            Method  = "GET",
            Headers = { ["Accept"] = "application/json" },
        })

        if ok and res then
            local code = tonumber(res.StatusCode or res.statusCode) or 200
            if code == 429 then return nil, "RATE_LIMITED" end
            if code ~= 200 then return nil, "HTTP_STATUS_" .. tostring(code) end
            local body = res.Body or res.body
            if body and #body > 0 then return body end
        end

        log("request() fallback also failed", "warn")
    end

    -- ── FALLBACK 2: syn.request ────────────────────────────
    if syn and syn.request then
        local ok, res = pcall(syn.request, {
            Url    = url,
            Method = "GET",
        })

        if ok and res then
            local code = tonumber(res.StatusCode) or 200
            if code == 429 then return nil, "RATE_LIMITED" end
            if code ~= 200 then return nil, "HTTP_STATUS_" .. tostring(code) end
            local body = res.Body or res.body
            if body and #body > 0 then return body end
        end

        log("syn.request fallback also failed", "warn")
    end

    -- ── FALLBACK 3: game:HttpGet ───────────────────────────
    if game.HttpGet then
        local ok, res = pcall(function()
            return game:HttpGet(url)
        end)
        if ok and res and #res > 0 then
            return res
        end
        log("game:HttpGet fallback also failed", "warn")
    end

    return nil, "ALL_HTTP_METHODS_FAILED"
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
log("Waiting for Remotes...", "scan")

local RemoteFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
local QuickPlay    = RemoteFolder and RemoteFolder:WaitForChild("QuickPlay", 10)

if QuickPlay then
    State.RemoteLinked = true
    setStatus("Remote linked - Ready")
    log("QuickPlay remote linked", "ok")
else
    setStatus("Remote NOT found - scan only")
    log("QuickPlay remote not found", "err")
end

-- ============================================================
-- SERVER FETCH  (paginated, rate-limit aware)
-- ============================================================
local function fetchAllServers()
    State.ScanCount += 1

    local allServers = {}
    local cursor     = nil
    local page       = 1

    while page <= CONFIG.MaxPages do
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=%d",
            PlaceId, CONFIG.ServerFetchLimit
        )
        if cursor and cursor ~= "" then
            url = url .. "&cursor=" .. cursor
        end

        log(string.format("Page %d/%d...", page, CONFIG.MaxPages), "scan")

        local body, err = httpGet(url)

        -- Handle rate limiting with one retry
        if not body and err == "RATE_LIMITED" then
            log("Rate limited — waiting 5s then retrying", "warn")
            task.wait(5)
            body, err = httpGet(url)
        end

        if not body then
            log("Fetch stopped: " .. tostring(err), "err")
            break
        end

        -- Decode
        local ok, decoded = pcall(HttpService.JSONDecode, HttpService, body)
        if not ok or not decoded then
            log("JSON error: " .. tostring(decoded), "err")
            -- Log raw body preview to help diagnose
            log("Body preview: " .. tostring(body):sub(1, 80), "info")
            break
        end

        if not decoded.data then
            log("Missing 'data' key in JSON", "err")
            log("Keys present: " .. (function()
                local keys = {}
                for k in pairs(decoded) do table.insert(keys, tostring(k)) end
                return table.concat(keys, ", ")
            end)(), "info")
            break
        end

        local pageCount = #decoded.data
        for _, sv in ipairs(decoded.data) do
            table.insert(allServers, sv)
        end

        log(string.format(
            "Page %d: +%d servers (total %d)",
            page, pageCount, #allServers
        ), "info")

        -- Pagination
        if decoded.nextPageCursor
        and decoded.nextPageCursor ~= ""
        and decoded.nextPageCursor ~= nil then
            cursor = decoded.nextPageCursor
        else
            log("Last page reached", "info")
            break
        end

        page += 1

        -- Controlled delay between pages
        if page <= CONFIG.MaxPages then
            task.wait(CONFIG.PageDelay)
        end
    end

    return #allServers > 0 and allServers or nil
end

-- ============================================================
-- FIND BEST SERVER
-- ============================================================
local function findBestServer(servers)
    local candidates = {}

    for _, sv in ipairs(servers) do
        if sv.id == game.JobId then continue end

        local p   = tonumber(sv.playing)    or 0
        local cap = tonumber(sv.maxPlayers) or 0

        if p >= CONFIG.MinPlayers and p <= CONFIG.MaxPlayers then
            local midpoint  = (CONFIG.MinPlayers + CONFIG.MaxPlayers) / 2
            local distScore = 1 / (1 + math.abs(p - midpoint))
            local pingScore = sv.ping and (1 / (1 + sv.ping)) or 0.5
            local fillScore = cap > 0 and (p / cap) or 0
            local total     = distScore * 0.5 + pingScore * 0.3 + fillScore * 0.2

            table.insert(candidates, { server = sv, score = total })
        end
    end

    if #candidates == 0 then return nil end

    table.sort(candidates, function(a, b) return a.score > b.score end)

    -- Log top candidates
    for i = 1, math.min(3, #candidates) do
        local c  = candidates[i]
        local sv = c.server
        log(string.format(
            "#%d: %dP/%dP | ping~%s | score %.2f",
            i,
            tonumber(sv.playing) or 0,
            tonumber(sv.maxPlayers) or 0,
            sv.ping and tostring(math.floor(sv.ping)) or "?",
            c.score
        ), "info")
    end

    return candidates[1].server
end

-- ============================================================
-- SCAN AND TELEPORT
-- ============================================================
local scanAndTeleport

scanAndTeleport = function(originalCall)
    if State.IsScanning then
        log("Already scanning", "warn")
        return
    end

    State.IsScanning   = true
    State.LastScanTime = os.time()
    setStatus("Scanning...")
    log(string.format(
        "Scan | range [%d-%dP] | %d pages x %d",
        CONFIG.MinPlayers, CONFIG.MaxPlayers,
        CONFIG.MaxPages, CONFIG.ServerFetchLimit
    ), "scan")

    local servers = fetchAllServers()

    if not servers then
        log("No servers returned at all", "err")
        setStatus("Scan failed - fallback")
        State.IsScanning = false
        if originalCall then originalCall() end
        return
    end

    log("Total fetched: " .. #servers .. " servers", "info")

    local target = findBestServer(servers)

    if target then
        local p    = tonumber(target.playing) or 0
        local cap  = tonumber(target.maxPlayers) or 0
        local ping = target.ping and math.floor(target.ping) or "?"

        log(string.format(
            "Target: %dP/%dP | ~%sms",
            p, cap, tostring(ping)
        ), "ok")
        setStatus("Teleporting to " .. p .. "P server")
        log("Joining " .. tostring(target.id):sub(1, 18) .. "...", "ok")

        task.wait(0.15)

        local tpOk, tpErr = pcall(function()
            TeleportService:TeleportToPlaceInstance(PlaceId, target.id, Player)
        end)

        if not tpOk then
            log("Teleport failed: " .. tostring(tpErr), "err")
            setStatus("Teleport failed - fallback")
            if originalCall then originalCall() end
        end
    else
        -- Dump player counts for diagnosis
        local counts = {}
        for _, sv in ipairs(servers) do
            local p = tonumber(sv.playing) or 0
            table.insert(counts, tostring(p))
        end
        local countStr = table.concat(counts, " "):sub(1, 100)
        log("Player counts: " .. countStr, "warn")
        log(string.format(
            "No server matched [%d-%dP] — adjust range!",
            CONFIG.MinPlayers, CONFIG.MaxPlayers
        ), "warn")
        setStatus("No match - adjust range with buttons")
        if originalCall then originalCall() end
    end

    State.IsScanning = false
end

-- ============================================================
-- BUTTON WIRING
-- ============================================================
scanBtn.MouseButton1Click:Connect(function()
    task.spawn(scanAndTeleport, nil)
end)

clearBtn.MouseButton1Click:Connect(function()
    State.LogLines = {}
    logLbl.Text    = ""
    log("Log cleared", "info")
end)

infoBtn.MouseButton1Click:Connect(function()
    -- Detect active HTTP method
    local method = "none"
    if http_request       then method = "http_request()" end
    if request            then method = method .. " + request()" end
    if syn and syn.request then method = method .. " + syn.request" end

    log("HTTP: " .. method, "info")
    log("PlaceId: " .. tostring(PlaceId), "info")
    log("JobId: "   .. game.JobId:sub(1, 14) .. "...", "info")
    log("Players here: " .. #Players:GetPlayers(), "info")
    log(string.format(
        "Range [%d-%dP] | %d pages | %.1fs delay",
        CONFIG.MinPlayers, CONFIG.MaxPlayers,
        CONFIG.MaxPages, CONFIG.PageDelay
    ), "info")
end)

-- ============================================================
-- HOOK
-- ============================================================
if hookmetamethod and getnamecallmethod then
    local oldNC
    oldNC = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()

        if self == QuickPlay
        and (method == "FireServer" or method == "InvokeServer") then
            State.HijackCount += 1

            if (os.time() - State.LastScanTime) < CONFIG.ScanCooldown then
                log("Cooldown - passing through", "warn")
                return oldNC(self, ...)
            end

            local args = { ... }
            task.spawn(function()
                scanAndTeleport(function()
                    pcall(function()
                        oldNC(self, table.unpack(args))
                    end)
                end)
            end)

            return nil
        end

        return oldNC(self, ...)
    end)

    log("Hook active", "ok")
else
    log("hookmetamethod unavailable", "warn")
    setStatus("Hook N/A - scan-only mode")
end

-- ============================================================
-- STARTUP
-- ============================================================
log("SR Hijacker " .. CONFIG.Version .. " ready", "ok")
log("Time: " .. os.date("!%H:%M:%S") .. " UTC", "time")
log("Press INFO for diagnostics", "info")
log("Press SCAN or trigger QuickPlay", "info")
