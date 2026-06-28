-- --- FallensHub_Loader.lua ---
local HttpService   = game:GetService("HttpService")
local TweenService  = game:GetService("TweenService")
local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local LocalPlayer   = Players.LocalPlayer
local PlayerGui     = LocalPlayer:WaitForChild("PlayerGui")

local VALIDATE_URL = "https://getkeypalen-production.up.railway.app/validate?key="
local MAIN_SCRIPT  = "https://raw.githubusercontent.com/FallensHub/FallensHub/refs/heads/main/FREEMIUM"
local STORAGE_KEY  = "FallensHub_SavedKey"
local TTL_MS       = 24 * 60 * 60 * 1000  -- 24 jam dalam ms

-- ── Storage helpers (executor writefile/readfile) ─────────────────────────────
local function saveKey(key, createdAt)
    local data = HttpService:JSONEncode({ key = key, createdAt = createdAt })
    pcall(writefile, STORAGE_KEY .. ".json", data)
end

local function loadSavedKey()
    local ok, raw = pcall(readfile, STORAGE_KEY .. ".json")
    if not ok or not raw or raw == "" then return nil end
    local parsed, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not parsed or type(data) ~= "table" then return nil end
    if not data.key or not data.createdAt then return nil end
    return data
end

local function clearSavedKey()
    pcall(delfile, STORAGE_KEY .. ".json")
end

-- ── Load main script ──────────────────────────────────────────────────────────
local function loadMainScript()
    local loadOk, loadErr = pcall(function()
        local src = game:HttpGet(MAIN_SCRIPT)
        local fn, compErr = loadstring(src)
        if not fn then error("compile: " .. tostring(compErr)) end
        fn()
    end)
    if not loadOk then
        warn("[Fallens Hub] Load error: " .. tostring(loadErr))
    end
end

-- ── Validate key against server ───────────────────────────────────────────────
-- returns: "valid" | "expired" | "invalid" | "error"
local function validateKeyRemote(key)
    local ok, res = pcall(function()
        return game:HttpGet(VALIDATE_URL .. HttpService:UrlEncode(key))
    end)
    if not ok then return "error" end

    local parsed, data = pcall(function() return HttpService:JSONDecode(res) end)
    if not parsed or type(data) ~= "table" then return "error" end

    if data.valid then return "valid" end

    local reason = (data.reason or ""):lower()
    if reason:find("expired") then return "expired" end
    return "invalid"
end

-- ── Silent auto-load path ─────────────────────────────────────────────────────
local function trySilentLoad()
    local saved = loadSavedKey()
    if not saved then return false end

    -- cek TTL lokal dulu biar ga buang request kalau udah jelas expired
    local now = os.time() * 1000
    if (now - saved.createdAt) >= TTL_MS then
        clearSavedKey()
        return false
    end

    -- konfirmasi ke server
    local status = validateKeyRemote(saved.key)
    if status == "valid" then
        loadMainScript()
        return true
    end

    -- expired atau invalid → hapus cache, paksa UI
    clearSavedKey()
    return false
end

-- ── Utility ───────────────────────────────────────────────────────────────────
local function tween(obj, props, t, style, dir)
    style = style or Enum.EasingStyle.Quint
    dir   = dir   or Enum.EasingDirection.Out
    TweenService:Create(obj, TweenInfo.new(t or 0.35, style, dir), props):Play()
end

local function round(obj, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = obj
    return c
end

local function mkLabel(parent, props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Font                   = props.font  or Enum.Font.GothamMedium
    l.TextSize               = props.size  or 13
    l.TextColor3             = props.color or Color3.fromRGB(255, 255, 255)
    l.Text                   = props.text  or ""
    l.TextXAlignment         = props.align or Enum.TextXAlignment.Left
    l.TextYAlignment         = Enum.TextYAlignment.Center
    l.Size                   = props.sz    or UDim2.new(1, 0, 0, 24)
    l.Position               = props.pos   or UDim2.new(0, 0, 0, 0)
    l.ZIndex                 = props.z     or 4
    l.Parent                 = parent
    return l
end

-- ── Entry point: coba silent load dulu ───────────────────────────────────────
if trySilentLoad() then return end  -- key masih valid → langsung load, UI skip

-- ── Kalau sampai sini = belum ada key / expired → tampilkan UI ───────────────

local C = {
    bg0      = Color3.fromRGB(6,   6,   14 ),
    bg1      = Color3.fromRGB(12,  12,  22 ),
    bg2      = Color3.fromRGB(18,  18,  32 ),
    bg3      = Color3.fromRGB(26,  26,  44 ),
    accent   = Color3.fromRGB(108, 99,  255),
    accentLt = Color3.fromRGB(148, 142, 255),
    accentDk = Color3.fromRGB(72,  52,  200),
    green    = Color3.fromRGB(52,  211, 153),
    red      = Color3.fromRGB(248, 113, 113),
    yellow   = Color3.fromRGB(251, 191,  36),
    text0    = Color3.fromRGB(240, 240, 255),
    text1    = Color3.fromRGB(160, 155, 200),
    text2    = Color3.fromRGB(70,  68,  100),
    glass    = Color3.fromRGB(255, 255, 255),
}

local Blur = Instance.new("BlurEffect")
Blur.Size   = 0
Blur.Parent = game:GetService("Lighting")

local Gui = Instance.new("ScreenGui")
Gui.Name              = "FallensHub_KeyUI"
Gui.ResetOnSpawn      = false
Gui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
Gui.IgnoreGuiInset    = true
Gui.Parent            = PlayerGui

local Overlay = Instance.new("Frame")
Overlay.Size                   = UDim2.new(1, 0, 1, 0)
Overlay.BackgroundColor3       = Color3.fromRGB(8, 6, 20)
Overlay.BackgroundTransparency = 1
Overlay.BorderSizePixel        = 0
Overlay.ZIndex                 = 1
Overlay.Parent                 = Gui

tween(Overlay, { BackgroundTransparency = 0.55 }, 0.6)
tween(Blur,    { Size = 18 }, 0.6)

local PARTICLE_COUNT = 38
local particles      = {}

local particleColors = {
    Color3.fromRGB(108, 99,  255),
    Color3.fromRGB(148, 142, 255),
    Color3.fromRGB(80,  60,  200),
    Color3.fromRGB(200, 190, 255),
    Color3.fromRGB(255, 255, 255),
}

local function spawnParticle(immediate)
    local size  = math.random(3, 9)
    local xFrac = math.random(1, 980) / 1000
    local speed = math.random(28, 90)
    local col   = particleColors[math.random(#particleColors)]
    local trans = math.random(55, 82) / 100

    local p = Instance.new("Frame")
    p.Size                   = UDim2.new(0, size, 0, size)
    p.BackgroundColor3       = col
    p.BackgroundTransparency = trans
    p.BorderSizePixel        = 0
    p.ZIndex                 = 2
    p.Parent                 = Gui
    round(p, size / 2)

    local startY = immediate and math.random(-900, 0) or -size - 4
    p.Position = UDim2.new(xFrac, 0, 0, startY)

    if size >= 6 then
        local s = Instance.new("UIStroke")
        s.Color        = col
        s.Thickness    = 1
        s.Transparency = 0.5
        s.Parent       = p
    end

    local function drop()
        while p and p.Parent do
            local dt = task.wait(0.016)
            local cy = p.Position.Y.Offset
            cy = cy + speed * dt
            p.Position = UDim2.new(xFrac, 0, 0, cy)
            if cy > 760 then
                p.Position = UDim2.new(xFrac, 0, 0, -size - 4)
                xFrac = math.random(1, 980) / 1000
            end
        end
    end

    task.spawn(drop)
    return p
end

for i = 1, PARTICLE_COUNT do
    table.insert(particles, spawnParticle(true))
end

local Card = Instance.new("Frame")
Card.Name                   = "Card"
Card.AnchorPoint            = Vector2.new(0.5, 0.5)
Card.Size                   = UDim2.new(0, 460, 0, 310)
Card.Position               = UDim2.new(0.5, 0, -0.5, 0)
Card.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
Card.BackgroundTransparency = 0.88
Card.BorderSizePixel        = 0
Card.ZIndex                 = 5
Card.ClipsDescendants       = true
Card.Parent                 = Gui

round(Card, 20)

local CardGlassGrad = Instance.new("UIGradient")
CardGlassGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 255, 255)),
    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(180, 170, 255)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(120, 100, 220)),
})
CardGlassGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0,   0.88),
    NumberSequenceKeypoint.new(0.5, 0.92),
    NumberSequenceKeypoint.new(1,   0.90),
})
CardGlassGrad.Rotation = 135
CardGlassGrad.Parent   = Card

local CardStroke = Instance.new("UIStroke")
CardStroke.Color           = Color3.fromRGB(200, 190, 255)
CardStroke.Thickness       = 1.2
CardStroke.Transparency    = 0.55
CardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
CardStroke.Parent          = Card

local RainBlocker = Instance.new("Frame")
RainBlocker.Name                   = "RainBlocker"
RainBlocker.AnchorPoint            = Vector2.new(0.5, 0.5)
RainBlocker.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
RainBlocker.BackgroundTransparency = 1
RainBlocker.BorderSizePixel        = 0
RainBlocker.ZIndex                 = 4
RainBlocker.Parent                 = Gui

RunService.Heartbeat:Connect(function()
    local vp    = workspace.CurrentCamera.ViewportSize
    local scale = math.clamp(vp.X / 1280, 0.55, 1.15)
    local w     = math.floor(460 * scale)
    local h     = math.floor(310 * scale)
    if Card.Size.X.Offset ~= w then
        Card.Size = UDim2.new(0, w, 0, h)
    end
    RainBlocker.Size     = Card.Size
    RainBlocker.Position = Card.Position
end)

task.delay(0.05, function()
    local vp    = workspace.CurrentCamera.ViewportSize
    local scale = math.clamp(vp.X / 1280, 0.55, 1.15)
    Card.Size     = UDim2.new(0, math.floor(460 * scale), 0, math.floor(310 * scale))
    Card.Position = UDim2.new(0.5, 0, -0.5, 0)
    tween(Card, { Position = UDim2.new(0.5, 0, 0.5, 0) }, 0.6, Enum.EasingStyle.Back)
end)

local function cardLine(yOff)
    local l = Instance.new("Frame")
    l.Size                   = UDim2.new(1, -40, 0, 1)
    l.Position               = UDim2.new(0, 20, 0, yOff)
    l.BackgroundColor3       = Color3.fromRGB(200, 190, 255)
    l.BackgroundTransparency = 0.82
    l.BorderSizePixel        = 0
    l.ZIndex                 = 6
    l.Parent                 = Card
    return l
end

local Header = Instance.new("Frame")
Header.Size                   = UDim2.new(1, 0, 0, 72)
Header.BackgroundColor3       = Color3.fromRGB(108, 80, 240)
Header.BackgroundTransparency = 0.78
Header.BorderSizePixel        = 0
Header.ZIndex                 = 6
Header.Parent                 = Card

local HGrad = Instance.new("UIGradient")
HGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(100, 60,  240)),
    ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80,  50,  200)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(60,  30,  160)),
})
HGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.72),
    NumberSequenceKeypoint.new(1, 0.80),
})
HGrad.Rotation = 135
HGrad.Parent   = Header

cardLine(72)

local LogoPill = Instance.new("Frame")
LogoPill.Size                   = UDim2.new(0, 32, 0, 32)
LogoPill.Position               = UDim2.new(0, 18, 0.5, -16)
LogoPill.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
LogoPill.BackgroundTransparency = 0.82
LogoPill.BorderSizePixel        = 0
LogoPill.ZIndex                 = 7
LogoPill.Parent                 = Header
round(LogoPill, 10)

local LogoTxt = Instance.new("TextLabel")
LogoTxt.Size                   = UDim2.new(1, 0, 1, 0)
LogoTxt.BackgroundTransparency = 1
LogoTxt.Text                   = "F"
LogoTxt.Font                   = Enum.Font.GothamBold
LogoTxt.TextSize               = 16
LogoTxt.TextColor3             = Color3.fromRGB(220, 210, 255)
LogoTxt.TextXAlignment         = Enum.TextXAlignment.Center
LogoTxt.TextYAlignment         = Enum.TextYAlignment.Center
LogoTxt.ZIndex                 = 8
LogoTxt.Parent                 = LogoPill

mkLabel(Header, {
    text  = "FALLENS HUB",
    font  = Enum.Font.GothamBold,
    size  = 17,
    color = C.text0,
    sz    = UDim2.new(1, -120, 0, 26),
    pos   = UDim2.new(0, 62, 0, 10),
    z     = 7,
})

mkLabel(Header, {
    text  = "Script Authentication",
    size  = 11,
    color = Color3.fromRGB(180, 170, 240),
    sz    = UDim2.new(1, -120, 0, 18),
    pos   = UDim2.new(0, 62, 0, 36),
    z     = 7,
})

local BadgeBG = Instance.new("Frame")
BadgeBG.Size                   = UDim2.new(0, 42, 0, 20)
BadgeBG.Position               = UDim2.new(1, -56, 0.5, -10)
BadgeBG.BackgroundColor3       = Color3.fromRGB(200, 190, 255)
BadgeBG.BackgroundTransparency = 0.78
BadgeBG.BorderSizePixel        = 0
BadgeBG.ZIndex                 = 7
BadgeBG.Parent                 = Header
round(BadgeBG, 10)

mkLabel(BadgeBG, {
    text  = "v2.0",
    size  = 11,
    color = Color3.fromRGB(220, 215, 255),
    sz    = UDim2.new(1, 0, 1, 0),
    align = Enum.TextXAlignment.Center,
    z     = 8,
})

local Body = Instance.new("Frame")
Body.Size                 = UDim2.new(1, 0, 1, -72)
Body.Position             = UDim2.new(0, 0, 0, 72)
Body.BackgroundTransparency = 1
Body.ZIndex               = 6
Body.Parent               = Card

mkLabel(Body, {
    text  = "Masukkan key untuk mengakses Fallens Hub.",
    size  = 12,
    color = C.text1,
    sz    = UDim2.new(1, -40, 0, 18),
    pos   = UDim2.new(0, 20, 0, 16),
    z     = 7,
})

local InputWrap = Instance.new("Frame")
InputWrap.Size                   = UDim2.new(1, -40, 0, 46)
InputWrap.Position               = UDim2.new(0, 20, 0, 42)
InputWrap.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
InputWrap.BackgroundTransparency = 0.90
InputWrap.BorderSizePixel        = 0
InputWrap.ZIndex                 = 7
InputWrap.Parent                 = Body
round(InputWrap, 12)

local InputStroke = Instance.new("UIStroke")
InputStroke.Color        = Color3.fromRGB(160, 150, 255)
InputStroke.Thickness    = 1
InputStroke.Transparency = 0.70
InputStroke.Parent       = InputWrap

mkLabel(InputWrap, {
    text  = "🔑",
    size  = 16,
    sz    = UDim2.new(0, 38, 1, 0),
    pos   = UDim2.new(0, 0, 0, 0),
    align = Enum.TextXAlignment.Center,
    z     = 8,
})

local Sep = Instance.new("Frame")
Sep.Size                   = UDim2.new(0, 1, 0, 22)
Sep.Position               = UDim2.new(0, 38, 0.5, -11)
Sep.BackgroundColor3       = Color3.fromRGB(160, 150, 220)
Sep.BackgroundTransparency = 0.65
Sep.BorderSizePixel        = 0
Sep.ZIndex                 = 8
Sep.Parent                 = InputWrap

local KeyBox = Instance.new("TextBox")
KeyBox.Size                   = UDim2.new(1, -50, 1, -4)
KeyBox.Position               = UDim2.new(0, 46, 0, 2)
KeyBox.BackgroundTransparency = 1
KeyBox.PlaceholderText        = "Paste key kamu di sini..."
KeyBox.PlaceholderColor3      = Color3.fromRGB(100, 95, 150)
KeyBox.TextColor3             = C.text0
KeyBox.Font                   = Enum.Font.Code
KeyBox.TextSize               = 13
KeyBox.TextXAlignment         = Enum.TextXAlignment.Left
KeyBox.ClearTextOnFocus       = false
KeyBox.MultiLine              = false
KeyBox.Text                   = ""
KeyBox.ZIndex                 = 8
KeyBox.Parent                 = InputWrap

task.defer(function() KeyBox:ReleaseFocus() end)

KeyBox.Focused:Connect(function()
    tween(InputWrap,  { BackgroundTransparency = 0.82 }, 0.2)
    tween(InputStroke,{ Transparency = 0.25 }, 0.2)
    tween(CardStroke, { Transparency = 0.20 }, 0.2)
end)
KeyBox.FocusLost:Connect(function()
    tween(InputWrap,  { BackgroundTransparency = 0.90 }, 0.2)
    tween(InputStroke,{ Transparency = 0.70 }, 0.2)
    tween(CardStroke, { Transparency = 0.55 }, 0.2)
end)

local StatusRow = Instance.new("Frame")
StatusRow.Size                   = UDim2.new(1, -40, 0, 18)
StatusRow.Position               = UDim2.new(0, 20, 0, 96)
StatusRow.BackgroundTransparency = 1
StatusRow.ZIndex                 = 7
StatusRow.Parent                 = Body

local StatusDot = Instance.new("Frame")
StatusDot.Size             = UDim2.new(0, 6, 0, 6)
StatusDot.Position         = UDim2.new(0, 0, 0.5, -3)
StatusDot.BackgroundColor3 = C.text2
StatusDot.BorderSizePixel  = 0
StatusDot.ZIndex           = 8
StatusDot.Visible          = false
StatusDot.Parent           = StatusRow
round(StatusDot, 3)

local StatusTxt = mkLabel(StatusRow, {
    text  = "",
    size  = 11,
    color = C.text1,
    sz    = UDim2.new(1, -14, 1, 0),
    pos   = UDim2.new(0, 14, 0, -3),
    z     = 8,
})

local function setStatus(msg, color)
    StatusTxt.Text             = msg
    StatusTxt.TextColor3       = color or C.text1
    StatusDot.BackgroundColor3 = color or C.text1
    StatusDot.Visible          = msg ~= ""
end

local BtnFrame = Instance.new("Frame")
BtnFrame.Size                   = UDim2.new(1, -40, 0, 44)
BtnFrame.Position               = UDim2.new(0, 20, 0, 122)
BtnFrame.BackgroundColor3       = C.accent
BtnFrame.BackgroundTransparency = 0.08
BtnFrame.BorderSizePixel        = 0
BtnFrame.ZIndex                 = 7
BtnFrame.Parent                 = Body
round(BtnFrame, 12)

local BtnGrad = Instance.new("UIGradient")
BtnGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 100, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(160,  80, 240)),
})
BtnGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.05),
    NumberSequenceKeypoint.new(1, 0.12),
})
BtnGrad.Rotation = 90
BtnGrad.Parent   = BtnFrame

local BtnStroke = Instance.new("UIStroke")
BtnStroke.Color        = Color3.fromRGB(200, 180, 255)
BtnStroke.Thickness    = 1
BtnStroke.Transparency = 0.5
BtnStroke.Parent       = BtnFrame

local Btn = Instance.new("TextButton")
Btn.Size                   = UDim2.new(1, 0, 1, 0)
Btn.BackgroundTransparency = 1
Btn.Text                   = "Authenticate  →"
Btn.TextColor3             = C.text0
Btn.Font                   = Enum.Font.GothamBold
Btn.TextSize               = 14
Btn.ZIndex                 = 8
Btn.Parent                 = BtnFrame

Btn.MouseEnter:Connect(function()
    tween(BtnFrame, { BackgroundTransparency = 0.0 }, 0.18)
    tween(BtnStroke,{ Transparency = 0.2 }, 0.18)
end)
Btn.MouseLeave:Connect(function()
    tween(BtnFrame, { BackgroundTransparency = 0.08 }, 0.18)
    tween(BtnStroke,{ Transparency = 0.5 }, 0.18)
end)
Btn.MouseButton1Down:Connect(function()
    tween(BtnFrame, { Size = UDim2.new(1, -44, 0, 42), Position = UDim2.new(0, 22, 0, 123) }, 0.1)
end)
Btn.MouseButton1Up:Connect(function()
    tween(BtnFrame, { Size = UDim2.new(1, -40, 0, 44), Position = UDim2.new(0, 20, 0, 122) }, 0.12)
end)

cardLine(240)

mkLabel(Body, {
    text  = "Key berlaku 24 jam  •  Jangan bagikan key kamu",
    size  = 10,
    color = C.text2,
    sz    = UDim2.new(1, -40, 0, 20),
    pos   = UDim2.new(0, 20, 0, 192),
    align = Enum.TextXAlignment.Center,
    z     = 7,
})

task.spawn(function()
    task.wait(0.7)
    local shimmer = Instance.new("Frame")
    shimmer.Size                   = UDim2.new(0, 60, 1, 0)
    shimmer.Position               = UDim2.new(-0.15, 0, 0, 0)
    shimmer.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
    shimmer.BackgroundTransparency = 0.78
    shimmer.BorderSizePixel        = 0
    shimmer.ZIndex                 = 9
    shimmer.Rotation               = 18
    shimmer.Parent                 = Card
    tween(shimmer, { Position = UDim2.new(1.15, 0, 0, 0) }, 0.55, Enum.EasingStyle.Linear)
    task.wait(0.6)
    shimmer:Destroy()
end)

local busy = false

local function lockBtn(state)
    busy       = state
    Btn.Active = not state
    if state then
        BtnGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 46, 110)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 40, 120)),
        })
        Btn.Text = "Checking..."
    else
        BtnGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 100, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(160,  80, 240)),
        })
        Btn.Text = "Authenticate  →"
    end
end

local function closeUI()
    for _, p in ipairs(particles) do pcall(function() p:Destroy() end) end
    table.clear(particles)
    tween(Card,    { Position = UDim2.new(0.5, 0, 1.6, 0) }, 0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    tween(Overlay, { BackgroundTransparency = 1 }, 0.45)
    tween(Blur,    { Size = 0 }, 0.45)
    task.wait(0.52)
    Gui:Destroy()
    Blur:Destroy()
end

local function authenticate()
    if busy then return end

    local key = KeyBox.Text:match("^%s*(.-)%s*$")

    if key == "" then
        setStatus("Key tidak boleh kosong.", C.yellow)
        return
    end

    if not key:match("^FALLENS%-") then
        setStatus("Format salah — harus diawali FALLENS-", C.red)
        return
    end

    lockBtn(true)
    setStatus("Menghubungi server validasi...", C.text1)

    local status = validateKeyRemote(key)

    if status == "error" then
        setStatus("Koneksi gagal. Coba lagi.", C.red)
        lockBtn(false)
        return
    end

    if status ~= "valid" then
        local msg = status == "expired" and "Key expired. Ambil key baru di Discord." or "Key tidak valid."
        setStatus(msg, C.red)
        lockBtn(false)
        return
    end

    -- valid → simpan ke file dengan timestamp sekarang
    saveKey(key, os.time() * 1000)

    setStatus("Key valid. Memuat script...", C.green)
    BtnGrad.Enabled = false
    tween(BtnFrame, { BackgroundColor3 = C.green }, 0.3)
    Btn.Text = "✓ Authenticated"
    task.wait(0.9)

    closeUI()
    task.wait(0.1)
    loadMainScript()
end

Btn.MouseButton1Click:Connect(authenticate)
KeyBox.FocusLost:Connect(function(enter)
    if enter then authenticate() end
end)

task.spawn(function()
    while Gui.Parent do
        tween(CardStroke, { Transparency = 0.30 }, 1.2)
        task.wait(1.2)
        tween(CardStroke, { Transparency = 0.70 }, 1.2)
        task.wait(1.2)
    end
end)
