--[[
    OBSIDIAN UI LIBRARY - MODIFIED
    Modifikasi:
    1. Custom header: Tab name + Search bar berdampingan di header (seperti gambar)
    2. Animasi glow teks tab dari kanan ke kiri (sweep animation)
    3. Animasi glow accent bar di atas header
    
    Cara patch ke library asli:
    Tambahkan kode ini SETELAH Library:CreateWindow() dipanggil,
    atau integrasikan langsung ke dalam fungsi CreateWindow.
    
    Patch ini menggunakan monkey-patching pada Library yang sudah ada.
    
    PENGGUNAAN:
        local Library = loadstring(game:HttpGet("..."))()
        local Patch = loadstring(game:HttpGet("URL_PATCH_INI"))()
        Patch:Apply(Library)
        
        local Window = Library:CreateWindow({ ... })
        -- Semua fitur custom aktif otomatis
]]

local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

local Patch = {}

-- ──────────────────────────────────────────────────────────────
-- UTILITY
-- ──────────────────────────────────────────────────────────────
local function New(className, props)
    local inst = Instance.new(className)
    for k, v in props do
        pcall(function() inst[k] = v end)
    end
    return inst
end

local function Lerp(a, b, t)
    return a + (b - a) * t
end

-- ──────────────────────────────────────────────────────────────
-- ACCENT GLOW BAR  (strip tipis di atas header)
-- ──────────────────────────────────────────────────────────────
local function CreateAccentGlowBar(parent, accentColor, cornerRadius)
    cornerRadius = cornerRadius or 4

    -- Container (lebar penuh, tinggi 3px, menempel di atas MainFrame)
    local Bar = New("Frame", {
        Name           = "AccentGlowBar",
        BackgroundColor3 = accentColor,
        BorderSizePixel  = 0,
        Position         = UDim2.fromOffset(0, 0),
        Size             = UDim2.new(1, 0, 0, 3),
        ZIndex           = 100,
        ClipsDescendants = true,
        Parent           = parent,
    })
    New("UICorner", {
        CornerRadius = UDim.new(0, cornerRadius),
        Parent = Bar,
    })

    -- Gradient dasar (accent ke transparan ke accent)
    New("UIGradient", {
        Color       = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   accentColor),
            ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1,   accentColor),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0.3),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1,   0.3),
        }),
        Rotation = 0,
        Parent   = Bar,
    })

    -- Shine overlay yang bergerak dari kiri ke kanan
    local Shine = New("Frame", {
        Name             = "Shine",
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel  = 0,
        AnchorPoint      = Vector2.new(0, 0.5),
        Position         = UDim2.new(-0.3, 0, 0.5, 0),
        Size             = UDim2.new(0.3, 0, 1, 0),
        ZIndex           = 101,
        Parent           = Bar,
    })
    New("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   1),
            NumberSequenceKeypoint.new(0.5, 0.2),
            NumberSequenceKeypoint.new(1,   1),
        }),
        Rotation = 0,
        Parent   = Shine,
    })

    -- Loop animasi shine
    local function AnimateShine()
        while Bar and Bar.Parent do
            -- Reset posisi
            Shine.Position = UDim2.new(-0.35, 0, 0.5, 0)
            -- Tween dari kiri ke kanan
            local t = TweenService:Create(
                Shine,
                TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                { Position = UDim2.new(1.05, 0, 0.5, 0) }
            )
            t:Play()
            t.Completed:Wait()
            task.wait(0.8) -- jeda sebelum ulang
        end
    end
    task.spawn(AnimateShine)

    -- Pulse brightness bar itu sendiri
    local function PulseBar()
        local baseAlpha = 0
        local dir = 1
        while Bar and Bar.Parent do
            baseAlpha = baseAlpha + dir * 0.015
            if baseAlpha >= 0.15 then dir = -1
            elseif baseAlpha <= 0   then dir =  1 end
            Bar.BackgroundTransparency = baseAlpha
            RunService.RenderStepped:Wait()
        end
    end
    task.spawn(PulseBar)

    return Bar
end

-- ──────────────────────────────────────────────────────────────
-- TAB LABEL GLOW (sweep kanan → kiri pada teks tab aktif)
-- ──────────────────────────────────────────────────────────────
local ActiveGlowConnection = nil

local function StopGlow()
    if ActiveGlowConnection then
        task.cancel(ActiveGlowConnection)
        ActiveGlowConnection = nil
    end
end

local function StartTabGlow(label, accentColor)
    StopGlow()
    if not label then return end

    -- Pastikan label bisa di-clone dengan ClipsDescendants
    local overlay = New("Frame", {
        Name             = "GlowOverlay",
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
        Size             = UDim2.fromScale(1, 1),
        Position         = UDim2.fromScale(0, 0),
        ClipsDescendants = true,
        ZIndex           = label.ZIndex + 1,
        Parent           = label,
    })

    local shine = New("Frame", {
        Name             = "TextShine",
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel  = 0,
        AnchorPoint      = Vector2.new(1, 0.5),      -- pivot di kanan
        Position         = UDim2.new(1.5, 0, 0.5, 0), -- mulai dari kanan luar
        Size             = UDim2.new(0.45, 0, 2, 0),
        ZIndex           = label.ZIndex + 2,
        Parent           = overlay,
    })
    New("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   1),
            NumberSequenceKeypoint.new(0.3, 0.1),
            NumberSequenceKeypoint.new(0.7, 0.1),
            NumberSequenceKeypoint.new(1,   1),
        }),
        Rotation = 0,
        Parent   = shine,
    })

    local function Loop()
        while overlay and overlay.Parent do
            -- Kanan → Kiri
            shine.Position = UDim2.new(1.5, 0, 0.5, 0)
            local t = TweenService:Create(
                shine,
                TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                { Position = UDim2.new(-0.5, 0, 0.5, 0) }
            )
            t:Play()
            t.Completed:Wait()
            task.wait(1.2)
        end
    end

    ActiveGlowConnection = task.spawn(Loop)

    return overlay
end

-- ──────────────────────────────────────────────────────────────
-- CUSTOM HEADER LAYOUT
-- Mengatur ulang TopBar agar: [Icon][TabName]  [Search]  [Move]
-- Mirip gambar: "Settings  |  Theme, config & menu settings  [🔍 Search]  [⊹]"
-- ──────────────────────────────────────────────────────────────
local function RebuildTopBar(topBar, titleHolder, rightWrapper, searchBox, windowTitle, windowIcon, moveIcon)
    -- Sembunyikan layout lama
    if titleHolder then titleHolder.Visible = false end
    if rightWrapper then rightWrapper.Visible = false end

    -- ── New Top Bar Layout ──────────────────────────────────
    -- [ IconArea ][ TabName + SubDesc ] ────── [ Search ] [ MoveBtn ]

    local CustomTopBar = New("Frame", {
        Name             = "CustomTopBar",
        BackgroundTransparency = 1,
        Size             = UDim2.new(1, 0, 1, 0),
        Position         = UDim2.fromOffset(0, 0),
        ZIndex           = topBar.ZIndex,
        Parent           = topBar,
    })

    New("UIListLayout", {
        FillDirection      = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment  = Enum.VerticalAlignment.Center,
        Padding            = UDim.new(0, 0),
        Parent             = CustomTopBar,
    })

    -- LEFT: icon + tab text (tetap lebar sidebar)
    local LeftSection = New("Frame", {
        Name             = "LeftSection",
        BackgroundTransparency = 1,
        Size             = UDim2.new(0.3, 0, 1, 0),
        ZIndex           = topBar.ZIndex,
        Parent           = CustomTopBar,
    })
    New("UIListLayout", {
        FillDirection      = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment  = Enum.VerticalAlignment.Center,
        Padding            = UDim.new(0, 6),
        Parent             = LeftSection,
    })
    New("UIPadding", {
        PaddingLeft = UDim.new(0, 12),
        Parent      = LeftSection,
    })

    -- clone icon sederhana (label teks inisial fallback)
    local IconDisplay = New("TextLabel", {
        Name             = "IconDisplay",
        BackgroundTransparency = 1,
        Size             = UDim2.fromOffset(28, 28),
        Text             = "",          -- diisi dari window icon bila ada
        TextSize         = 18,
        ZIndex           = topBar.ZIndex + 1,
        Parent           = LeftSection,
    })

    -- Tab Name label (dinamis diperbarui tiap tab Show)
    local TabNameLabel = New("TextLabel", {
        Name             = "TabNameLabel",
        BackgroundTransparency = 1,
        Size             = UDim2.new(1, -46, 1, 0),
        Text             = "—",
        TextSize         = 16,
        TextXAlignment   = Enum.TextXAlignment.Left,
        ClipsDescendants = true,
        ZIndex           = topBar.ZIndex + 1,
        Parent           = LeftSection,
    })

    -- RIGHT: search + move icon
    local RightSection = New("Frame", {
        Name             = "RightSection",
        BackgroundTransparency = 1,
        Size             = UDim2.new(0.7, -8, 1, 0),
        ZIndex           = topBar.ZIndex,
        Parent           = CustomTopBar,
    })
    New("UIListLayout", {
        FillDirection      = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment  = Enum.VerticalAlignment.Center,
        Padding            = UDim.new(0, 8),
        Parent             = RightSection,
    })
    New("UIPadding", {
        PaddingRight = UDim.new(0, 8),
        Parent       = RightSection,
    })

    -- Move icon placeholder (visual saja)
    if moveIcon then
        New("ImageLabel", {
            Image            = moveIcon.Url,
            ImageColor3      = Color3.fromRGB(80, 80, 80),
            ImageRectOffset  = moveIcon.ImageRectOffset,
            ImageRectSize    = moveIcon.ImageRectSize,
            Size             = UDim2.fromOffset(28, 28),
            BackgroundTransparency = 1,
            ZIndex           = topBar.ZIndex + 1,
            LayoutOrder      = 10,
            Parent           = RightSection,
        })
    end

    -- Search box (referensi ke searchBox asli disembunyikan; buat baru)
    local NewSearchBox = New("TextBox", {
        Name             = "CustomSearchBox",
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        PlaceholderText  = "Search",
        Size             = UDim2.new(0.55, 0, 0, 26),
        TextSize         = 14,
        TextColor3       = Color3.new(1, 1, 1),
        PlaceholderColor3 = Color3.fromRGB(120, 120, 120),
        ClearTextOnFocus = false,
        LayoutOrder      = 5,
        ZIndex           = topBar.ZIndex + 1,
        Parent           = RightSection,
    })
    New("UIPadding", {
        PaddingLeft  = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        Parent       = NewSearchBox,
    })
    New("UICorner", {
        CornerRadius = UDim.new(0, 4),
        Parent       = NewSearchBox,
    })
    New("UIStroke", {
        Color = Color3.fromRGB(60, 60, 60),
        Parent = NewSearchBox,
    })

    -- Sync search ke library
    NewSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        if searchBox then
            searchBox.Text = NewSearchBox.Text
        end
    end)

    return CustomTopBar, TabNameLabel, IconDisplay, NewSearchBox
end

-- ──────────────────────────────────────────────────────────────
-- PATCH UTAMA
-- ──────────────────────────────────────────────────────────────
function Patch:Apply(Library)
    -- Simpan CreateWindow asli
    local OriginalCreateWindow = Library.CreateWindow

    Library.CreateWindow = function(self, WindowInfo)
        -- Panggil CreateWindow asli
        local Window = OriginalCreateWindow(self, WindowInfo)

        -- Temukan MainFrame
        local ScreenGui = Library.ScreenGui
        if not ScreenGui then return Window end

        local MainFrame = ScreenGui:FindFirstChild("Main")
        if not MainFrame then return Window end

        local accentColor = Library.Scheme.AccentColor or Color3.fromRGB(125, 85, 255)
        local cornerRadius = Library.CornerRadius or 4

        -- ── 1. Accent Glow Bar ──────────────────────────────
        CreateAccentGlowBar(MainFrame, accentColor, cornerRadius)

        -- ── 2. Rebuild Header ───────────────────────────────
        local TopBar = MainFrame:FindFirstChildOfClass("Frame")  -- TopBar ada sebagai Frame pertama
        -- Cari lebih spesifik
        for _, child in MainFrame:GetChildren() do
            if child:IsA("Frame") and child.Size.Y.Offset == 48 and child.Position.Y.Offset == 0 then
                TopBar = child
                break
            end
        end

        local titleHolder  = TopBar and TopBar:FindFirstChild("Frame")
        local rightWrapper = nil
        local searchBox    = nil
        local moveIconImg  = nil

        if TopBar then
            for _, c in TopBar:GetChildren() do
                if c:IsA("Frame") then
                    if c.AnchorPoint == Vector2.new(1, 0.5) then
                        rightWrapper = c
                        searchBox    = c:FindFirstChildOfClass("TextBox")
                    elseif c.AnchorPoint == Vector2.new(0, 0) then
                        titleHolder = c
                    end
                end
                if c:IsA("ImageLabel") then
                    moveIconImg = c  -- move icon
                end
            end
        end

        local moveIcon = Library:GetIcon("move")

        local _customBar, TabNameLabel, _IconDisplay, NewSearchBox =
            RebuildTopBar(TopBar, titleHolder, rightWrapper, searchBox,
                          nil, nil, moveIcon)

        -- ── 3. Hook Tab Show untuk update TabName + Glow ───
        local currentGlowOverlay = nil

        local function HookTab(tab, name)
            if not tab or not tab.Show then return end
            local origShow = tab.Show

            tab.Show = function(...)
                origShow(...)

                -- Update label nama tab di header
                if TabNameLabel then
                    TabNameLabel.Text = name or "—"
                end

                -- Hapus overlay glow lama
                if currentGlowOverlay and currentGlowOverlay.Parent then
                    currentGlowOverlay:Destroy()
                    currentGlowOverlay = nil
                end
                StopGlow()

                -- Buat glow baru pada label ini
                if TabNameLabel then
                    currentGlowOverlay = StartTabGlow(TabNameLabel, accentColor)
                end
            end
        end

        -- Hook semua tab yang sudah ada
        for name, tab in Library.Tabs do
            HookTab(tab, name)
        end

        -- Hook AddTab agar tab baru juga kena glow
        local origAddTab = Window.AddTab
        Window.AddTab = function(win, ...)
            local tab = origAddTab(win, ...)

            -- Ambil nama dari argumen
            local nameArg
            local firstArg = select(1, ...)
            if typeof(firstArg) == "table" then
                nameArg = firstArg.Name or "Tab"
            else
                nameArg = firstArg or "Tab"
            end

            HookTab(tab, nameArg)
            return tab
        end

        -- ── 4. Sync accent color jika berubah ───────────────
        -- (opsional: jika Library.Scheme.AccentColor diubah runtime)
        -- Bisa tambah listener di sini bila diperlukan

        return Window
    end

    return self
end

-- ──────────────────────────────────────────────────────────────
-- STANDALONE PATCH FUNCTIONS (bisa dipanggil manual)
-- ──────────────────────────────────────────────────────────────

--- Tambah accent glow bar secara manual ke MainFrame yang sudah ada
function Patch:AddAccentBar(mainFrame, accentColor, cornerRadius)
    return CreateAccentGlowBar(mainFrame, accentColor or Color3.fromRGB(125, 85, 255), cornerRadius or 4)
end

--- Mulai glow pada label tertentu
function Patch:GlowLabel(label, accentColor)
    return StartTabGlow(label, accentColor or Color3.fromRGB(125, 85, 255))
end

--- Hentikan semua glow
function Patch:StopAllGlow()
    StopGlow()
end

return Patch

--[[
══════════════════════════════════════════════════════════════════
CONTOH PENGGUNAAN LENGKAP:
══════════════════════════════════════════════════════════════════

local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua"
))()

-- Load patch ini
local Patch = loadstring(game:HttpGet("URL_FILE_INI"))()

-- Terapkan patch ke Library
Patch:Apply(Library)

-- Buat window seperti biasa — semua fitur custom aktif otomatis
local Window = Library:CreateWindow({
    Title   = "My Cheat",
    Footer  = "v1.0",
    Center  = true,
    Size    = UDim2.fromOffset(720, 600),
    -- dll
})

local Tab1 = Window:AddTab("Settings", "settings")
local Tab2 = Window:AddTab("Combat",   "swords")

local Left = Tab1:AddLeftGroupbox("General")
Left:AddToggle("MyToggle", { Text = "Aimbot", Default = false })

══════════════════════════════════════════════════════════════════
PENJELASAN FITUR:
══════════════════════════════════════════════════════════════════

1. ACCENT GLOW BAR
   - Strip 3px di paling atas window
   - Warna mengikuti Library.Scheme.AccentColor
   - Shine bergerak dari kiri ke kanan (loop 2.2 detik, jeda 0.8 detik)
   - Pulse brightness halus terus-menerus

2. TAB NAME GLOW (kanan → kiri)
   - Saat tab aktif, nama tab di header dapat efek shine
   - Shine bergerak dari KANAN ke KIRI (1.6 detik)
   - Jeda 1.2 detik antar iterasi
   - Glow lama dihapus otomatis saat pindah tab

3. CUSTOM HEADER LAYOUT
   - Kiri: [Icon] [Nama Tab]
   - Kanan: [Search Box] [Move Icon]
   - Mirip tampilan pada gambar referensi
   - Search box custom terhubung ke sistem search library asli
]]
