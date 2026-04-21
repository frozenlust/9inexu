-- ============================================================
--  ANIMATED CROSSHAIR - AUTO-SYNC & HEADER FIX
-- ============================================================

local CONFIG = {
    URL              = "https://cdn.discordapp.com/attachments/1489720049932439798/1496216646447009962/ikuyo.bin?ex=69e913d6&is=69e7c256&hm=4f2b051e3c3b9cd76c165612fa177ae88d6200a661aef78aa5fb064ea1326329&",
    RAW_SIZE         = 64,
    DISPLAY_SIZE     = UDim2.new(0, 26, 0, 26),
    FPS              = 12,
    TARGET_NAME      = "Main",
    HIDE_ORIGINAL    = true,
    IMAGE_TRANSPARENCY = 0, -- 0 = fully visible, 1 = fully invisible
}

local Players      = game:GetService("Players")
local AssetService = game:GetService("AssetService")
local RunService   = game:GetService("RunService")

local player = Players.LocalPlayer
local pGui   = player:WaitForChild("PlayerGui")

-- [ LOGGING SYSTEM ] --
local logGui = Instance.new("ScreenGui")
logGui.Name = "CrosshairLog"
logGui.ResetOnSpawn = false
logGui.Parent = pGui

local logFrame = Instance.new("Frame")
logFrame.Size = UDim2.new(0, 300, 0, 200)
logFrame.Position = UDim2.new(0, 10, 0, 10)
logFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
logFrame.BackgroundTransparency = 0.5
logFrame.Parent = logGui

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = logFrame

local logCount = 0
local function log(msg, color)
    logCount += 1
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 18)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = color or Color3.new(1,1,1)
    lbl.TextSize = 13
    lbl.Font = Enum.Font.Code
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextWrapped = true
    lbl.LayoutOrder = logCount
    lbl.Text = "  " .. msg
    lbl.Parent = logFrame
    logFrame.Size = UDim2.new(0, 300, 0, logCount * 18 + 5)
end

local GREEN  = Color3.fromRGB(0, 255, 100)
local RED    = Color3.fromRGB(255, 80, 80)
local YELLOW = Color3.fromRGB(255, 255, 0)
local WHITE  = Color3.new(1, 1, 1)

-- ============================================================
--  MAIN
-- ============================================================
local function init()
    task.wait(3)
    log("Starting...", YELLOW)

    -- Step 1: Find Main frame
    local mainFrame = nil
    for _, v in ipairs(pGui:GetDescendants()) do
        if v.Name == CONFIG.TARGET_NAME and v:IsA("Frame") then
            mainFrame = v
            break
        end
    end

    if not mainFrame then
        log("Main frame NOT found!", RED)
        return
    end
    log("Found: " .. mainFrame:GetFullName(), GREEN)
    log("Size: " .. tostring(mainFrame.AbsoluteSize), WHITE)

    -- Step 2: Fetch binary data
    local httpFunc = (syn and syn.request)
        or (http and http.request)
        or http_request
        or request

    log("Fetching binary data...", WHITE)

    local ok1, res = pcall(httpFunc, {
        Url    = CONFIG.URL,
        Method = "GET",
        Headers = {
            ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            ["Accept"]     = "*/*"
        }
    })

    if not ok1 or not res.Success or #res.Body == 0 then
        log("Fetch FAILED", RED)
        return
    end

    log("Downloaded: " .. #res.Body .. " bytes", GREEN)

    local masterBuffer = buffer.fromstring(res.Body)

    -- Step 3: Auto-detect frame count
    local SIZE         = Vector2.new(CONFIG.RAW_SIZE, CONFIG.RAW_SIZE)
    local frameSize    = CONFIG.RAW_SIZE * CONFIG.RAW_SIZE * 4
    local totalFrames  = math.floor(buffer.len(masterBuffer) / frameSize)
    local actualBytes  = buffer.len(masterBuffer)
    local expectedBytes = frameSize * totalFrames

    log("Total bytes: " .. actualBytes, WHITE)
    log("Detected frames: " .. totalFrames, GREEN)

    if totalFrames == 0 then
        log("File too small / wrong format!", RED)
        return
    end

    if actualBytes ~= expectedBytes then
        log("Warning: leftover bytes " .. (actualBytes - expectedBytes), YELLOW)
    else
        log("Buffer size validated!", GREEN)
    end

    -- Step 4: Create EditableImage
    local editImg
    local ok2, err2 = pcall(function()
        editImg = AssetService:CreateEditableImage({ Size = SIZE })
    end)

    if not ok2 or not editImg then
        log("EditableImage failed: " .. tostring(err2), RED)
        return
    end
    log("EditableImage created", GREEN)

    -- Step 5: Write first frame as validation
    local testBuffer = buffer.create(frameSize)
    buffer.copy(testBuffer, 0, masterBuffer, 0, frameSize)

    local ok3, err3 = pcall(function()
        editImg:WritePixelsBuffer(Vector2.zero, SIZE, testBuffer)
    end)

    if not ok3 then
        log("WritePixels failed: " .. tostring(err3), RED)
        return
    end
    log("First frame written OK", GREEN)

    -- Step 6: Create overlay
    local overlay = Instance.new("ImageLabel")
    overlay.Name                   = "AnimatedCrosshairOverlay"
    overlay.BackgroundTransparency = 1
    overlay.ImageTransparency      = CONFIG.IMAGE_TRANSPARENCY  -- ← applied here
    overlay.BorderSizePixel        = 0
    overlay.ZIndex                 = mainFrame.ZIndex + 50
    overlay.Size                   = CONFIG.DISPLAY_SIZE
    overlay.Position               = mainFrame.Position
    overlay.AnchorPoint            = mainFrame.AnchorPoint
    overlay.Parent                 = mainFrame.Parent

    log("Overlay created", GREEN)
    log("ZIndex: " .. overlay.ZIndex, WHITE)
    log("Transparency: " .. CONFIG.IMAGE_TRANSPARENCY, WHITE)

    -- Step 7: Link EditableImage (same order as working reference)
    local linked = false

    if not linked then
        local ok4 = pcall(function()
            overlay.Content = Content.fromObject(editImg)
            linked = true
        end)
        if ok4 and linked then log("Linked via Content.fromObject", GREEN) end
    end

    if not linked then
        local ok5 = pcall(function()
            overlay.ImageContent = Content.fromObject(editImg)
            linked = true
        end)
        if ok5 and linked then log("Linked via ImageContent", GREEN) end
    end

    if not linked then
        log("Could not link EditableImage!", RED)
        return
    end

    -- Step 8: Hide original
    if CONFIG.HIDE_ORIGINAL then
        for _, child in ipairs(mainFrame:GetChildren()) do
            pcall(function()
                if child:IsA("GuiObject") then
                    child.Visible = false
                end
            end)
        end
        pcall(function()
            mainFrame.BackgroundTransparency = 1
        end)
        log("Original hidden", GREEN)
    end

    -- Step 9: Animation + position sync loop
    local frameBuffer = buffer.create(frameSize)
    local startTime   = tick()
    local lastFrame   = -1

    RunService.RenderStepped:Connect(function()
        -- Keep synced to original crosshair position
        overlay.Size             = CONFIG.DISPLAY_SIZE
        overlay.Position         = mainFrame.Position
        overlay.AnchorPoint      = mainFrame.AnchorPoint
        overlay.ImageTransparency = CONFIG.IMAGE_TRANSPARENCY  -- ← stays in sync if changed at runtime

        local frameIndex = math.floor((tick() - startTime) * CONFIG.FPS) % totalFrames

        if frameIndex == lastFrame then return end
        lastFrame = frameIndex

        pcall(function()
            buffer.copy(frameBuffer, 0, masterBuffer, frameIndex * frameSize, frameSize)
            editImg:WritePixelsBuffer(Vector2.zero, SIZE, frameBuffer)
        end)
    end)

    log("Animation running!", YELLOW)

    task.delay(5, function()
        if logGui then logGui:Destroy() end
    end)
end

task.spawn(init)
