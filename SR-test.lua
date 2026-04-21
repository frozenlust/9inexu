-- ============================================================
--  ANIMATED CROSSHAIR - FULL SCRIPT
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

local player = Players.LocalPlayer

-- ============================================================
--  FIND SAFE GUI PARENT
--  Tries every known executor-safe container in order
-- ============================================================
local function getSafeGuiParent()
    -- gethui() is supported by most modern executors (Synapse, Fluxus, etc.)
    if gethui then
        local ok, result = pcall(gethui)
        if ok and result then
            return result
        end
    end

    -- Some executors expose it differently
    if get_hidden_gui then
        local ok, result = pcall(get_hidden_gui)
        if ok and result then
            return result
        end
    end

    -- CoreGui fallback
    local CoreGui = game:GetService("CoreGui")
    local ok = pcall(function()
        local t = Instance.new("Frame")
        t.Parent = CoreGui
        t:Destroy()
    end)
    if ok then return CoreGui end

    -- Last resort: PlayerGui
    return player:WaitForChild("PlayerGui")
end

-- ============================================================
--  LOGGER
-- ============================================================
local LOG    = {}
local _rows  = 0
local _scroll = nil
local _container = nil

do
    local safeParent = getSafeGuiParent()

    -- Clean up old logger if rerunning
    for _, v in ipairs(safeParent:GetChildren()) do
        if v.Name == "__CLog" then v:Destroy() end
    end

    local sg = Instance.new("ScreenGui")
    sg.Name           = "__CLog"
    sg.ResetOnSpawn   = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder   = 999999
    sg.Parent         = safeParent

    -- Main window
    local win = Instance.new("Frame")
    win.Name              = "Win"
    win.Size              = UDim2.new(0, 350, 0, 240)
    win.Position          = UDim2.new(0, 6, 0, 6)
    win.BackgroundColor3  = Color3.fromRGB(12, 12, 12)
    win.BorderSizePixel   = 0
    win.ClipsDescendants  = true
    win.Parent            = sg
    _container            = win

    Instance.new("UICorner", win).CornerRadius = UDim.new(0, 8)

    local winStroke = Instance.new("UIStroke", win)
    winStroke.Color     = Color3.fromRGB(55, 55, 55)
    winStroke.Thickness = 1

    -- Title bar
    local bar = Instance.new("Frame")
    bar.Name             = "Bar"
    bar.Size             = UDim2.new(1, 0, 0, 26)
    bar.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    bar.BorderSizePixel  = 0
    bar.Parent           = win

    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 8)

    local barTitle = Instance.new("TextLabel")
    barTitle.Size                = UDim2.new(1, -30, 1, 0)
    barTitle.Position            = UDim2.new(0, 10, 0, 0)
    barTitle.BackgroundTransparency = 1
    barTitle.Text                = "◈ Crosshair Debug"
    barTitle.TextColor3          = Color3.fromRGB(160, 160, 160)
    barTitle.TextSize            = 12
    barTitle.Font                = Enum.Font.Code
    barTitle.TextXAlignment      = Enum.TextXAlignment.Left
    barTitle.Parent              = bar

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size               = UDim2.new(0, 26, 0, 26)
    toggleBtn.Position           = UDim2.new(1, -26, 0, 0)
    toggleBtn.BackgroundTransparency = 1
    toggleBtn.Text               = "−"
    toggleBtn.TextColor3         = Color3.fromRGB(180, 180, 180)
    toggleBtn.TextSize           = 18
    toggleBtn.Font               = Enum.Font.Code
    toggleBtn.Parent             = bar

    -- Scroll area
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name                  = "Scroll"
    scroll.Size                  = UDim2.new(1, 0, 1, -26)
    scroll.Position              = UDim2.new(0, 0, 0, 26)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel       = 0
    scroll.ScrollBarThickness    = 4
    scroll.ScrollBarImageColor3  = Color3.fromRGB(70, 70, 70)
    scroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
    scroll.Parent                = win
    _scroll                      = scroll

    local list = Instance.new("UIListLayout", scroll)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding   = UDim.new(0, 2)

    local pad = Instance.new("UIPadding", scroll)
    pad.PaddingLeft  = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.PaddingTop   = UDim.new(0, 6)

    -- Collapse / expand
    local open = true
    local OPEN_H   = 240
    local CLOSE_H  = 26

    toggleBtn.MouseButton1Click:Connect(function()
        open = not open
        toggleBtn.Text = open and "−" or "+"
        TweenService:Create(win, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
            Size = UDim2.new(0, 350, 0, open and OPEN_H or CLOSE_H)
        }):Play()
    end)

    -- Drag
    local dragging, dragStart, winStart
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = i.Position
            winStart  = win.Position
        end
    end)
    bar.InputChanged:Connect(function(i)
        if dragging and (
            i.UserInputType == Enum.UserInputType.MouseMovement or
            i.UserInputType == Enum.UserInputType.Touch
        ) then
            local d = i.Position - dragStart
            win.Position = UDim2.new(
                winStart.X.Scale, winStart.X.Offset + d.X,
                winStart.Y.Scale, winStart.Y.Offset + d.Y
            )
        end
    end)
    bar.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    -- Color map
    local COLORS = {
        info  = Color3.fromRGB(210, 210, 210),
        ok    = Color3.fromRGB(0,   210, 100),
        warn  = Color3.fromRGB(255, 200, 0  ),
        error = Color3.fromRGB(255, 65,  65 ),
        cyan  = Color3.fromRGB(0,   190, 255),
    }

    local PREFIX = {
        info  = "  ",
        ok    = "✓ ",
        warn  = "⚠ ",
        error = "✗ ",
        cyan  = "» ",
    }

    function LOG.print(msg, level)
        level = level or "info"

        -- Backup to executor console
        if level == "error" then
            warn("[CLog][ERR] " .. msg)
        elseif level == "warn" then
            warn("[CLog][WRN] " .. msg)
        else
            print("[CLog] " .. msg)
        end

        _rows += 1

        local row = Instance.new("Frame")
        row.Name               = tostring(_rows)
        row.Size               = UDim2.new(1, 0, 0, 17)
        row.BackgroundTransparency = 1
        row.LayoutOrder        = _rows
        row.Parent             = _scroll

        local lbl = Instance.new("TextLabel")
        lbl.Size                = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3          = COLORS[level] or COLORS.info
        lbl.TextSize            = 12
        lbl.Font                = Enum.Font.Code
        lbl.TextXAlignment      = Enum.TextXAlignment.Left
        lbl.TextWrapped         = true
        lbl.Text                = (PREFIX[level] or "  ") .. msg
        lbl.Parent              = row

        -- Resize row if text wraps, then scroll to bottom
        task.defer(function()
            local h = lbl.TextBounds.Y
            if h > 17 then
                row.Size = UDim2.new(1, 0, 0, h + 2)
            end
            _scroll.CanvasPosition = Vector2.new(
                0,
                math.max(0, _scroll.AbsoluteCanvasSize.Y - _scroll.AbsoluteSize.Y)
            )
        end)
    end

    function LOG.hide(after)
        task.delay(after or 8, function()
            TweenService:Create(win, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {
                BackgroundTransparency = 1,
                Size = UDim2.new(0, 350, 0, 0),
            }):Play()
            task.wait(0.65)
            sg:Destroy()
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
    LOG.print("BgRemover | mode=" .. cfg.MODE .. " tol=" .. cfg.TOLERANCE, "cyan")
    return self
end

function BgRemover:_offset(x, y)
    return (y * self.width + x) * 4
end

local function colorDistSq(r1,g1,b1,r2,g2,b2)
    local dr,dg,db = r1-r2, g1-g2, b1-b2
    return dr*dr + dg*dg + db*db
end

function BgRemover:_detectBgColor(buf)
    local mode = self.cfg.MODE
    if mode == "white" then return 255,255,255
    elseif mode == "black" then return 0,0,0
    elseif mode == "color" then
        return self.cfg.BG_COLOR.R, self.cfg.BG_COLOR.G, self.cfg.BG_COLOR.B
    else
        local W,H = self.width, self.height
        local pts = {
            {0,0},{1,0},{0,1},
            {W-1,0},{W-2,0},{W-1,1},
            {0,H-1},{W-1,H-1},
        }
        local rS,gS,bS,n = 0,0,0,0
        for _,p in ipairs(pts) do
            local ox,oy = p[1],p[2]
            if ox>=0 and ox<W and oy>=0 and oy<H then
                local off = self:_offset(ox,oy)
                rS += buffer.readu8(buf,off)
                gS += buffer.readu8(buf,off+1)
                bS += buffer.readu8(buf,off+2)
                n  += 1
            end
        end
        if n==0 then return 255,255,255 end
        return math.floor(rS/n+.5), math.floor(gS/n+.5), math.floor(bS/n+.5)
    end
end

function BgRemover:_floodFill(buf, bgR,bgG,bgB)
    local W,H   = self.width, self.height
    local tolSq = self.cfg.TOLERANCE^2 * 3
    local vis   = self.visited
    local que   = self.queue

    for i=1,self.pixelCount do vis[i]=false end

    local qH,qT = 1,0

    local function enq(x,y)
        if x<0 or x>=W or y<0 or y>=H then return end
        local idx = y*W+x+1
        if vis[idx] then return end
        local off = (idx-1)*4
        local pa  = buffer.readu8(buf,off+3)
        local bg  = (pa==0) or (colorDistSq(
            buffer.readu8(buf,off),
            buffer.readu8(buf,off+1),
            buffer.readu8(buf,off+2),
            bgR,bgG,bgB
        ) <= tolSq)
        if bg then
            vis[idx]=true
            qT+=1
            que[qT]=idx
        end
    end

    for x=0,W-1 do enq(x,0) enq(x,H-1) end
    for y=1,H-2 do enq(0,y) enq(W-1,y) end

    while qH<=qT do
        local idx=que[qH]; qH+=1
        local x=(idx-1)%W
        local y=math.floor((idx-1)/W)
        enq(x-1,y) enq(x+1,y) enq(x,y-1) enq(x,y+1)
    end

    return vis
end

function BgRemover:processFrame(buf)
    if not self.cfg.ENABLED then return end
    local W,H    = self.width, self.height
    local tol    = self.cfg.TOLERANCE
    local feath  = self.cfg.FEATHER
    local tolSq  = tol*tol*3
    local bgR,bgG,bgB = self:_detectBgColor(buf)
    local mask   = self.cfg.FLOOD_FILL and self:_floodFill(buf,bgR,bgG,bgB) or nil

    for y=0,H-1 do
        for x=0,W-1 do
            local idx = y*W+x+1
            local off = (idx-1)*4
            if mask and not mask[idx] then goto c end
            local pa = buffer.readu8(buf,off+3)
            if pa==0 then goto c end
            local dSq = colorDistSq(
                buffer.readu8(buf,off),
                buffer.readu8(buf,off+1),
                buffer.readu8(buf,off+2),
                bgR,bgG,bgB
            )
            if dSq<=tolSq then
                local newA = 0
                if feath>0 then
                    local b = math.min(math.sqrt(dSq)/(tol*1.7321*feath),1)
                    b = b*b*(3-2*b)
                    newA = math.floor(pa*b+.5)
                end
                buffer.writeu8(buf,off+3,newA)
            end
            ::c::
        end
    end
end

-- ============================================================
--  EDITABLE IMAGE HELPERS
-- ============================================================
local function createEditableImage(size)
    local img

    local ok, err = pcall(function()
        img = AssetService:CreateEditableImage({ Size = size })
    end)
    if ok and img then
        LOG.print("EditableImage via AssetService", "ok")
        return img
    end
    LOG.print("AssetService failed: " .. tostring(err), "warn")

    ok, err = pcall(function()
        img = Instance.new("EditableImage")
        img.Size = size
    end)
    if ok and img then
        LOG.print("EditableImage via Instance.new", "ok")
        return img
    end
    LOG.print("Instance.new failed: " .. tostring(err), "warn")

    return nil
end

local function linkEditableImage(lbl, img)
    local tries = {
        { "Content.fromObject",      function() lbl.Content      = Content.fromObject(img) end },
        { "ImageContent.fromObject", function() lbl.ImageContent = Content.fromObject(img) end },
        { "SetParent",               function() img:SetParent(lbl) end },
    }
    for _, t in ipairs(tries) do
        local ok, err = pcall(t[2])
        if ok then
            LOG.print("Linked: " .. t[1], "ok")
            return true
        end
        LOG.print("Link [" .. t[1] .. "] failed: " .. tostring(err), "warn")
    end
    return false
end

-- ============================================================
--  MAIN
-- ============================================================
local function init()
    task.wait(2)
    LOG.print("Initialising...", "info")

    -- 1. Find target frame
    local pGui = player:WaitForChild("PlayerGui")
    local mainFrame

    local function searchFrame()
        for _, v in ipairs(pGui:GetDescendants()) do
            if v.Name == CONFIG.TARGET_NAME and v:IsA("Frame") then
                return v
            end
        end
    end

    mainFrame = searchFrame()
    if not mainFrame then
        LOG.print("Waiting for frame '" .. CONFIG.TARGET_NAME .. "'...", "warn")
        local t = tick()
        while not mainFrame and tick()-t < 15 do
            task.wait(0.5)
            mainFrame = searchFrame()
        end
    end

    if not mainFrame then
        LOG.print("Frame not found! Aborting.", "error")
        return
    end
    LOG.print("Frame: " .. mainFrame:GetFullName(), "ok")

    -- 2. HTTP
    local httpFunc = (syn and syn.request)
        or (http and http.request)
        or http_request or request

    if not httpFunc then
        LOG.print("No HTTP function!", "error")
        return
    end

    LOG.print("Fetching data...", "info")
    local ok1, res = pcall(httpFunc, {
        Url    = CONFIG.URL,
        Method = "GET",
        Headers = { ["User-Agent"]="Mozilla/5.0", ["Accept"]="*/*" },
    })

    if not ok1 or not res.Success or not res.Body or #res.Body == 0 then
        LOG.print("Fetch failed! status=" .. tostring(res and res.StatusCode), "error")
        return
    end
    LOG.print("Downloaded " .. #res.Body .. " bytes", "ok")

    -- 3. Parse
    local masterBuf   = buffer.fromstring(res.Body)
    local SIZE        = Vector2.new(CONFIG.RAW_SIZE, CONFIG.RAW_SIZE)
    local frameSize   = CONFIG.RAW_SIZE * CONFIG.RAW_SIZE * 4
    local totalFrames = math.floor(buffer.len(masterBuf) / frameSize)

    LOG.print("Frames detected: " .. totalFrames, "info")
    if totalFrames == 0 then
        LOG.print("No frames found!", "error")
        return
    end

    -- 4. BG removal pre-bake
    local cleanFrames
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
        LOG.print("Pre-bake complete", "ok")
    end

    -- 5. EditableImage
    local editImg = createEditableImage(SIZE)
    if not editImg then
        LOG.print("EditableImage failed entirely!", "error")
        return
    end

    local firstBuf = cleanFrames and cleanFrames[1] or (function()
        local b = buffer.create(frameSize)
        buffer.copy(b, 0, masterBuf, 0, frameSize)
        return b
    end)()

    local ok3, err3 = pcall(function()
        editImg:WritePixelsBuffer(Vector2.zero, SIZE, firstBuf)
    end)
    if not ok3 then
        LOG.print("WritePixelsBuffer: " .. tostring(err3), "error")
        return
    end
    LOG.print("WritePixelsBuffer OK", "ok")

    -- 6. Overlay
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
    LOG.print("Overlay ready | Z=" .. overlay.ZIndex, "ok")

    -- 7. Link
    if not linkEditableImage(overlay, editImg) then
        LOG.print("All link methods failed!", "error")
        overlay:Destroy()
        return
    end

    -- 8. Hide original
    if CONFIG.HIDE_ORIGINAL then
        for _, c in ipairs(mainFrame:GetChildren()) do
            pcall(function()
                if c:IsA("GuiObject") then c.Visible = false end
            end)
        end
        pcall(function() mainFrame.BackgroundTransparency = 1 end)
        LOG.print("Original hidden", "ok")
    end

    -- 9. Animate
    local fallback  = buffer.create(frameSize)
    local startTime = tick()
    local lastFrame = -1

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
                buffer.copy(fallback, 0, masterBuf, fi*frameSize, frameSize)
                editImg:WritePixelsBuffer(Vector2.zero, SIZE, fallback)
            end
        end)
    end)

    LOG.print("Running! " .. totalFrames .. "f @ " .. CONFIG.FPS .. "fps", "ok")
    LOG.hide(12)
end

task.spawn(init)
