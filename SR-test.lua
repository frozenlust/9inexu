-- ============================================================
--  ANIMATED CROSSHAIR - AUTO-SYNC, BG REMOVER, SCREEN LOG
-- ============================================================

local CONFIG = {
    URL           = "https://cdn.discordapp.com/attachments/1489720049932439798/1496160101516706026/ikuyo.bin?ex=69e8df2d&is=69e78dad&hm=cf0550ab82617725e17099b373967f69a719aac577f512622098d1034a0ff23d&",
    RAW_SIZE      = 64,
    DISPLAY_SIZE  = UDim2.new(0, 200, 0, 200),
    FPS           = 24,
    TARGET_NAME   = "Main",
    HIDE_ORIGINAL = true,

    BG_REMOVE = {
        ENABLED    = true,
        MODE       = "auto",
        BG_COLOR   = { R = 255, G = 255, B = 255 },
        TOLERANCE  = 30,
        FEATHER    = 0.5,
        FLOOD_FILL = true,
    },
}

local Players      = game:GetService("Players")
local AssetService = game:GetService("AssetService")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui      = game:GetService("CoreGui")

local player = Players.LocalPlayer

-- ============================================================
--  SCREEN LOGGER
--  Placed in CoreGui so it ALWAYS appears regardless of
--  executor ScreenGui restrictions on PlayerGui
-- ============================================================
local LOG = {}
do
    -- Destroy any old instance first
    local old = CoreGui:FindFirstChild("__CrosshairLogger")
    if old then old:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name            = "__CrosshairLogger"
    screenGui.ResetOnSpawn    = false
    screenGui.IgnoreGuiInset  = true
    screenGui.DisplayOrder    = 9999
    screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Global

    -- Try CoreGui first, fallback to PlayerGui
    local ok = pcall(function()
        screenGui.Parent = CoreGui
    end)
    if not ok then
        screenGui.Parent = player:WaitForChild("PlayerGui")
    end

    -- Outer container (draggable)
    local container = Instance.new("Frame")
    container.Name                 = "Container"
    container.Size                 = UDim2.new(0, 340, 0, 24)
    container.Position             = UDim2.new(0, 8, 0, 8)
    container.BackgroundColor3     = Color3.fromRGB(10, 10, 10)
    container.BorderSizePixel      = 0
    container.ClipsDescendants     = true
    container.Parent               = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent       = container

    local stroke = Instance.new("UIStroke")
    stroke.Color     = Color3.fromRGB(60, 60, 60)
    stroke.Thickness = 1
    stroke.Parent    = container

    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Name              = "TitleBar"
    titleBar.Size              = UDim2.new(1, 0, 0, 24)
    titleBar.BackgroundColor3  = Color3.fromRGB(25, 25, 25)
    titleBar.BorderSizePixel   = 0
    titleBar.Parent            = container

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 6)
    titleCorner.Parent       = titleBar

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size                = UDim2.new(1, -30, 1, 0)
    titleLabel.Position            = UDim2.new(0, 8, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text                = "Crosshair Logger"
    titleLabel.TextColor3          = Color3.fromRGB(180, 180, 180)
    titleLabel.TextSize            = 12
    titleLabel.Font                = Enum.Font.Code
    titleLabel.TextXAlignment      = Enum.TextXAlignment.Left
    titleLabel.Parent              = titleBar

    -- Toggle button
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size                 = UDim2.new(0, 24, 0, 24)
    toggleBtn.Position             = UDim2.new(1, -24, 0, 0)
    toggleBtn.BackgroundTransparency = 1
    toggleBtn.Text                 = "-"
    toggleBtn.TextColor3           = Color3.fromRGB(200, 200, 200)
    toggleBtn.TextSize             = 16
    toggleBtn.Font                 = Enum.Font.Code
    toggleBtn.Parent               = titleBar

    -- Scroll frame for logs
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name               = "LogScroll"
    scrollFrame.Size               = UDim2.new(1, 0, 1, -24)
    scrollFrame.Position           = UDim2.new(0, 0, 0, 24)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel    = 0
    scrollFrame.ScrollBarThickness = 3
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
    scrollFrame.CanvasSize         = UDim2.new(0, 0, 0, 0)
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.Parent             = container

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder  = Enum.SortOrder.LayoutOrder
    listLayout.Padding    = UDim.new(0, 1)
    listLayout.Parent     = scrollFrame

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft   = UDim.new(0, 6)
    padding.PaddingRight  = UDim.new(0, 6)
    padding.PaddingTop    = UDim.new(0, 4)
    padding.Parent        = scrollFrame

    -- Collapsed state
    local collapsed   = false
    local EXPANDED_H  = 220
    local COLLAPSED_H = 24

    container.Size = UDim2.new(0, 340, 0, EXPANDED_H)

    toggleBtn.MouseButton1Click:Connect(function()
        collapsed = not collapsed
        toggleBtn.Text = collapsed and "+" or "-"
        local targetH  = collapsed and COLLAPSED_H or EXPANDED_H
        TweenService:Create(
            container,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad),
            { Size = UDim2.new(0, 340, 0, targetH) }
        ):Play()
    end)

    -- Drag logic
    local dragging, dragStart, startPos
    titleBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = inp.Position
            startPos  = container.Position
        end
    end)
    titleBar.InputChanged:Connect(function(inp)
        if dragging and (
            inp.UserInputType == Enum.UserInputType.MouseMovement or
            inp.UserInputType == Enum.UserInputType.Touch
        ) then
            local delta = inp.Position - dragStart
            container.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    titleBar.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    -- Log entry counter
    local entryCount = 0

    local COLOR_MAP = {
        info  = Color3.fromRGB(220, 220, 220),
        ok    = Color3.fromRGB(0,   220, 100),
        warn  = Color3.fromRGB(255, 200, 0  ),
        error = Color3.fromRGB(255, 70,  70 ),
        cyan  = Color3.fromRGB(0,   200, 255),
    }

    -- Public log function
    function LOG.print(msg, level)
        level = level or "info"

        -- Also output to executor console as backup
        if level == "error" or level == "warn" then
            warn("[Crosshair][" .. level:upper() .. "] " .. msg)
        else
            print("[Crosshair] " .. msg)
        end

        entryCount += 1

        local row = Instance.new("Frame")
        row.Name               = "Row_" .. entryCount
        row.Size               = UDim2.new(1, 0, 0, 16)
        row.BackgroundTransparency = 1
        row.LayoutOrder        = entryCount
        row.Parent             = scrollFrame

        local label = Instance.new("TextLabel")
        label.Size              = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.TextColor3        = COLOR_MAP[level] or COLOR_MAP.info
        label.TextSize          = 12
        label.Font              = Enum.Font.Code
        label.TextXAlignment    = Enum.TextXAlignment.Left
        label.TextYAlignment    = Enum.TextYAlignment.Center
        label.TextWrapped       = true
        label.Text              = msg
        label.Parent            = row

        -- Dynamically resize row if text wraps
        task.defer(function()
            local textH = label.TextBounds.Y
            if textH > 16 then
                row.Size = UDim2.new(1, 0, 0, textH + 2)
            end
            -- Auto-scroll to bottom
            scrollFrame.CanvasPosition = Vector2.new(
                0,
                math.max(0, scrollFrame.AbsoluteCanvasSize.Y - scrollFrame.AbsoluteSize.Y)
            )
        end)
    end

    -- Auto-hide after delay (optional, set to nil to keep forever)
    function LOG.autoHide(seconds)
        task.delay(seconds, function()
            TweenService:Create(
                container,
                TweenInfo.new(0.5, Enum.EasingStyle.Quad),
                { BackgroundTransparency = 1 }
            ):Play()
            for _, v in ipairs(screenGui:GetDescendants()) do
                if v:IsA("TextLabel") or v:IsA("TextButton") then
                    TweenService:Create(
                        v,
                        TweenInfo.new(0.5),
                        { TextTransparency = 1 }
                    ):Play()
                end
            end
            task.wait(0.6)
            screenGui:Destroy()
        end)
    end
end

-- ============================================================
--  BACKGROUND REMOVER
-- ============================================================
local BgRemover = {}
BgRemover.__index = BgRemover

function BgRemover.new(cfg, imgSize)
    local self      = setmetatable({}, BgRemover)
    self.cfg        = cfg
    self.width      = imgSize.X
    self.height     = imgSize.Y
    self.pixelCount = imgSize.X * imgSize.Y
    self.visited    = table.create(self.pixelCount, false)
    self.queue      = table.create(self.pixelCount, 0)
    LOG.print("BgRemover ready | mode=" .. cfg.MODE .. " tol=" .. cfg.TOLERANCE, "cyan")
    return self
end

function BgRemover:_offset(x, y)
    return (y * self.width + x) * 4
end

local function colorDistSq(r1, g1, b1, r2, g2, b2)
    local dr, dg, db = r1-r2, g1-g2, b1-b2
    return dr*dr + dg*dg + db*db
end

function BgRemover:_detectBgColor(buf)
    local mode = self.cfg.MODE
    if mode == "white" then return 255, 255, 255
    elseif mode == "black" then return 0, 0, 0
    elseif mode == "color" then
        local c = self.cfg.BG_COLOR
        return c.R, c.G, c.B
    else
        local W, H = self.width, self.height
        local samples = {
            {0,0},{1,0},{0,1},
            {W-1,0},{W-2,0},{W-1,1},
            {0,H-1},{W-1,H-1},
        }
        local rS, gS, bS, n = 0, 0, 0, 0
        for _, s in ipairs(samples) do
            local ox, oy = s[1], s[2]
            if ox >= 0 and ox < W and oy >= 0 and oy < H then
                local off = self:_offset(ox, oy)
                rS += buffer.readu8(buf, off)
                gS += buffer.readu8(buf, off+1)
                bS += buffer.readu8(buf, off+2)
                n  += 1
            end
        end
        if n == 0 then return 255,255,255 end
        return
            math.floor(rS/n+.5),
            math.floor(gS/n+.5),
            math.floor(bS/n+.5)
    end
end

function BgRemover:_floodFill(buf, bgR, bgG, bgB)
    local W, H    = self.width, self.height
    local tolSq   = self.cfg.TOLERANCE^2 * 3
    local visited = self.visited
    local queue   = self.queue

    for i = 1, self.pixelCount do visited[i] = false end

    local qHead, qTail = 1, 0

    local function tryEnqueue(x, y)
        if x < 0 or x >= W or y < 0 or y >= H then return end
        local idx = y * W + x + 1
        if visited[idx] then return end
        local off = (idx-1)*4
        local pa  = buffer.readu8(buf, off+3)
        local isBg = (pa == 0) or (colorDistSq(
            buffer.readu8(buf,off), buffer.readu8(buf,off+1), buffer.readu8(buf,off+2),
            bgR, bgG, bgB
        ) <= tolSq)
        if isBg then
            visited[idx] = true
            qTail += 1
            queue[qTail] = idx
        end
    end

    for x = 0, W-1 do tryEnqueue(x,0) tryEnqueue(x,H-1) end
    for y = 1, H-2 do tryEnqueue(0,y) tryEnqueue(W-1,y) end

    while qHead <= qTail do
        local idx = queue[qHead]; qHead += 1
        local x = (idx-1) % W
        local y = math.floor((idx-1) / W)
        tryEnqueue(x-1,y) tryEnqueue(x+1,y)
        tryEnqueue(x,y-1) tryEnqueue(x,y+1)
    end

    return visited
end

function BgRemover:processFrame(buf)
    if not self.cfg.ENABLED then return end
    local W, H    = self.width, self.height
    local tol     = self.cfg.TOLERANCE
    local feather = self.cfg.FEATHER
    local tolSq   = tol*tol*3
    local bgR, bgG, bgB = self:_detectBgColor(buf)
    local bgMask  = self.cfg.FLOOD_FILL and self:_floodFill(buf, bgR, bgG, bgB) or nil

    for y = 0, H-1 do
        for x = 0, W-1 do
            local idx = y*W+x+1
            local off = (idx-1)*4
            if bgMask and not bgMask[idx] then goto continue end
            local pa  = buffer.readu8(buf, off+3)
            if pa == 0 then goto continue end
            local dSq = colorDistSq(
                buffer.readu8(buf,off), buffer.readu8(buf,off+1), buffer.readu8(buf,off+2),
                bgR, bgG, bgB
            )
            if dSq <= tolSq then
                local newA = 0
                if feather > 0 then
                    local blend = math.min(math.sqrt(dSq) / (tol * 1.7321 * feather), 1)
                    blend  = blend*blend*(3-2*blend)
                    newA   = math.floor(pa * blend + .5)
                end
                buffer.writeu8(buf, off+3, newA)
            end
            ::continue::
        end
    end
end

-- ============================================================
--  EDITABLE IMAGE HELPERS
-- ============================================================
local function createEditableImage(size)
    local img, ok, err

    ok, err = pcall(function()
        img = AssetService:CreateEditableImage({ Size = size })
    end)
    if ok and img then
        LOG.print("EditableImage created (AssetService)", "ok")
        return img
    end
    LOG.print("AssetService method failed: " .. tostring(err), "warn")

    ok, err = pcall(function()
        img = Instance.new("EditableImage")
        img.Size = size
    end)
    if ok and img then
        LOG.print("EditableImage created (Instance.new)", "ok")
        return img
    end
    LOG.print("Instance.new method failed: " .. tostring(err), "warn")

    return nil
end

local function linkEditableImage(label, editImg)
    local methods = {
        { name = "Content.fromObject",      fn = function() label.Content      = Content.fromObject(editImg) end },
        { name = "ImageContent.fromObject", fn = function() label.ImageContent = Content.fromObject(editImg) end },
        { name = "SetParent",               fn = function() editImg:SetParent(label) end },
    }
    for _, m in ipairs(methods) do
        local ok, err = pcall(m.fn)
        if ok then
            LOG.print("Linked via " .. m.name, "ok")
            return true
        end
        LOG.print("Link [" .. m.name .. "] failed: " .. tostring(err), "warn")
    end
    return false
end

-- ============================================================
--  MAIN
-- ============================================================
local function init()
    task.wait(2)
    LOG.print("Script started", "ok")

    -- ── 1. Find target frame ─────────────────────────────────
    local pGui     = player:WaitForChild("PlayerGui")
    local mainFrame = nil

    for _, v in ipairs(pGui:GetDescendants()) do
        if v.Name == CONFIG.TARGET_NAME and v:IsA("Frame") then
            mainFrame = v
            break
        end
    end

    if not mainFrame then
        LOG.print("Waiting for '" .. CONFIG.TARGET_NAME .. "' frame...", "warn")
        local t = tick()
        while not mainFrame and tick()-t < 15 do
            task.wait(0.5)
            for _, v in ipairs(pGui:GetDescendants()) do
                if v.Name == CONFIG.TARGET_NAME and v:IsA("Frame") then
                    mainFrame = v
                    break
                end
            end
        end
    end

    if not mainFrame then
        LOG.print("Target frame not found! Aborting.", "error")
        return
    end
    LOG.print("Found: " .. mainFrame:GetFullName(), "ok")

    -- ── 2. HTTP fetch ────────────────────────────────────────
    local httpFunc = (syn and syn.request)
        or (http and http.request)
        or http_request or request

    if not httpFunc then
        LOG.print("No HTTP function found!", "error")
        return
    end

    LOG.print("Fetching sprite data...", "info")

    local ok1, res = pcall(httpFunc, {
        Url    = CONFIG.URL,
        Method = "GET",
        Headers = {
            ["User-Agent"] = "Mozilla/5.0",
            ["Accept"]     = "*/*",
        },
    })

    if not ok1 or not res.Success or not res.Body or #res.Body == 0 then
        LOG.print("Fetch failed! ok=" .. tostring(ok1) .. " status=" .. tostring(res and res.StatusCode), "error")
        return
    end
    LOG.print("Downloaded " .. #res.Body .. " bytes", "ok")

    -- ── 3. Parse frames ──────────────────────────────────────
    local masterBuf  = buffer.fromstring(res.Body)
    local SIZE       = Vector2.new(CONFIG.RAW_SIZE, CONFIG.RAW_SIZE)
    local frameSize  = CONFIG.RAW_SIZE * CONFIG.RAW_SIZE * 4
    local totalFrames = math.floor(buffer.len(masterBuf) / frameSize)

    LOG.print("Frame size: " .. frameSize .. "b | Frames: " .. totalFrames, "info")

    if totalFrames == 0 then
        LOG.print("Zero frames detected!", "error")
        return
    end

    -- ── 4. Pre-bake with BG removal ──────────────────────────
    local cleanFrames = nil
    if CONFIG.BG_REMOVE.ENABLED then
        LOG.print("Pre-baking " .. totalFrames .. " frames...", "info")
        local bgr = BgRemover.new(CONFIG.BG_REMOVE, SIZE)
        cleanFrames = table.create(totalFrames)
        for i = 0, totalFrames-1 do
            local fb = buffer.create(frameSize)
            buffer.copy(fb, 0, masterBuf, i*frameSize, frameSize)
            bgr:processFrame(fb)
            cleanFrames[i+1] = fb
        end
        LOG.print("Pre-bake done", "ok")
    end

    -- ── 5. EditableImage ─────────────────────────────────────
    local editImg = createEditableImage(SIZE)
    if not editImg then
        LOG.print("EditableImage creation failed!", "error")
        return
    end

    -- Write frame 1 to validate
    local firstBuf = cleanFrames and cleanFrames[1] or (function()
        local b = buffer.create(frameSize)
        buffer.copy(b, 0, masterBuf, 0, frameSize)
        return b
    end)()

    local ok3, err3 = pcall(function()
        editImg:WritePixelsBuffer(Vector2.zero, SIZE, firstBuf)
    end)
    if not ok3 then
        LOG.print("WritePixelsBuffer failed: " .. tostring(err3), "error")
        return
    end
    LOG.print("Frame 1 written OK", "ok")

    -- ── 6. Overlay ───────────────────────────────────────────
    local overlay = Instance.new("ImageLabel")
    overlay.Name                   = "AnimatedCrosshairOverlay"
    overlay.BackgroundTransparency = 1
    overlay.ImageTransparency      = 0
    overlay.BorderSizePixel        = 0
    overlay.ZIndex                 = mainFrame.ZIndex + 50
    overlay.Size                   = CONFIG.DISPLAY_SIZE
    overlay.Position               = mainFrame.Position
    overlay.AnchorPoint            = mainFrame.AnchorPoint
    overlay.Parent                 = mainFrame.Parent
    LOG.print("Overlay created | ZIndex " .. overlay.ZIndex, "ok")

    -- ── 7. Link ──────────────────────────────────────────────
    if not linkEditableImage(overlay, editImg) then
        LOG.print("Linking failed entirely!", "error")
        overlay:Destroy()
        return
    end

    -- ── 8. Hide original ─────────────────────────────────────
    if CONFIG.HIDE_ORIGINAL then
        for _, c in ipairs(mainFrame:GetChildren()) do
            pcall(function()
                if c:IsA("GuiObject") then c.Visible = false end
            end)
        end
        pcall(function() mainFrame.BackgroundTransparency = 1 end)
        LOG.print("Original hidden", "ok")
    end

    -- ── 9. Animate ───────────────────────────────────────────
    local fallbackBuf = buffer.create(frameSize)
    local startTime   = tick()
    local lastFrame   = -1

    RunService.RenderStepped:Connect(function()
        overlay.Size        = CONFIG.DISPLAY_SIZE
        overlay.Position    = mainFrame.Position
        overlay.AnchorPoint = mainFrame.AnchorPoint

        local fi = math.floor((tick()-startTime) * CONFIG.FPS) % totalFrames
        if fi == lastFrame then return end
        lastFrame = fi

        pcall(function()
            if cleanFrames then
                editImg:WritePixelsBuffer(Vector2.zero, SIZE, cleanFrames[fi+1])
            else
                buffer.copy(fallbackBuf, 0, masterBuf, fi*frameSize, frameSize)
                editImg:WritePixelsBuffer(Vector2.zero, SIZE, fallbackBuf)
            end
        end)
    end)

    LOG.print("Animation running! " .. totalFrames .. " frames @ " .. CONFIG.FPS .. "fps", "ok")

    -- Auto-hide log after 10 seconds
    LOG.autoHide(10)
end

task.spawn(init)
