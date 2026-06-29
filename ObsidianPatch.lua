-- ╔══════════════════════════════════════════════════════════════════╗
-- ║           OBSIDIAN LIBRARY — RAINBOW + GLOW PATCH              ║
-- ║                                                                ║
-- ║  CARA PAKAI:                                                   ║
-- ║                                                                ║
-- ║     local Library = loadstring(game:HttpGet("..."))()          ║
-- ║     local Window = Library:CreateWindow({                      ║
-- ║         Title = "MyScript",                                    ║
-- ║         Description = "v1.0",  -- wajib ada untuk glow!       ║
-- ║     })                                                         ║
-- ║                                                                ║
-- ║     -- Tempel patch                                            ║
-- ║     loadstring(game:HttpGet("URL_PATCH_INI"))()                ║
-- ║                                                                ║
-- ║     -- Aktifkan rainbow bar                                    ║
-- ║     Library:SetRainbowAccentBar(true)                          ║
-- ║                                                                ║
-- ║     -- Shimmer glow otomatis aktif tiap tab (punya Desc) buka  ║
-- ╚══════════════════════════════════════════════════════════════════╝

local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

-- Pastikan Library dan Window sudah ada di scope global / getgenv
local Library = getgenv and getgenv().Library or _G.Library
assert(Library,         "[ObsidianPatch] Library tidak ditemukan di getgenv()")
assert(Library.Window,  "[ObsidianPatch] Library.Window belum dibuat, panggil CreateWindow dulu")

local Window    = Library.Window
local ScreenGui = Library.ScreenGui
local MainFrame = ScreenGui and ScreenGui:FindFirstChild("Main")
assert(MainFrame, "[ObsidianPatch] MainFrame ('Main') tidak ditemukan di ScreenGui")

-- ══════════════════════════════════════════════════════════════
-- [1]  RAINBOW ACCENT BAR
--      Bar 3px sliding pelangi, tepat di bawah garis top bar
-- ══════════════════════════════════════════════════════════════

local RainbowBarContainer = Instance.new("Frame")
RainbowBarContainer.Name               = "RainbowAccentBar"
RainbowBarContainer.BackgroundTransparency = 1
RainbowBarContainer.Position           = UDim2.fromOffset(0, 47)
RainbowBarContainer.Size               = UDim2.new(1, 0, 0, 3)
RainbowBarContainer.ZIndex             = 6
RainbowBarContainer.ClipsDescendants   = true
RainbowBarContainer.Visible            = false
RainbowBarContainer.Parent             = MainFrame

-- Runner 2x lebar → posisi-x digeser untuk seamless loop
local RainbowRunner = Instance.new("Frame")
RainbowRunner.Name           = "Runner"
RainbowRunner.BackgroundColor3 = Color3.new(1, 1, 1)
RainbowRunner.BorderSizePixel = 0
RainbowRunner.Position       = UDim2.fromScale(0, 0)
RainbowRunner.Size           = UDim2.fromScale(2, 1)
RainbowRunner.ZIndex         = 6
RainbowRunner.Parent         = RainbowBarContainer

-- Build pelangi 12-stop seamless (merah → ... → merah)
local rainbowKP = {}
for i = 0, 12 do
    rainbowKP[i + 1] = ColorSequenceKeypoint.new(
        i / 12,
        Color3.fromHSV((i / 12) % 1, 1, 1)
    )
end

local RainbowGradient = Instance.new("UIGradient")
RainbowGradient.Color  = ColorSequence.new(rainbowKP)
RainbowGradient.Parent = RainbowRunner

-- State
local _rainbowConn = nil
local _rainbowT    = 0

--- Nyalakan / matikan rainbow accent bar
--- @param enabled  boolean
--- @param speed    number?   (default 0.35; makin besar = makin cepat)
function Library:SetRainbowAccentBar(enabled, speed)
    speed = tonumber(speed) or 0.35
    RainbowBarContainer.Visible = enabled == true

    if enabled then
        if _rainbowConn then return end          -- sudah berjalan
        _rainbowT  = 0
        _rainbowConn = RunService.RenderStepped:Connect(function(dt)
            _rainbowT = (_rainbowT + dt * speed) % 1
            -- _rainbowT 0→1 ↔ geser Runner 0→-50% (setengah lebarnya)
            RainbowRunner.Position = UDim2.fromScale(-_rainbowT, 0)
        end)
        Library:GiveSignal(_rainbowConn)
    else
        if _rainbowConn then
            _rainbowConn:Disconnect()
            _rainbowConn = nil
        end
    end
end

-- ══════════════════════════════════════════════════════════════
-- [2]  TAB HEADER SHIMMER  (glow kiri → kanan)
--      Shimmer muncul di label nama tab di header kanan
--      Trigger: Window:ShowTabInfo() / HideTabInfo()
-- ══════════════════════════════════════════════════════════════

-- Cari CurrentTabLabel (dibuat di dalam CreateWindow sebagai upvalue)
-- Node: Frame[CurrentTabInfo] > TextLabel[CurrentTabLabel]
local CurrentTabLabel = nil
for _, desc in MainFrame:GetDescendants() do
    -- Penanda unik: TextLabel, TextSize 14, TextXAlignment Left,
    -- parent-nya Frame yang punya UIListLayout Vertical
    if  desc:IsA("TextLabel")
    and desc.TextSize == 14
    and desc.TextXAlignment == Enum.TextXAlignment.Left
    then
        local p = desc.Parent
        if p and p:IsA("Frame") then
            local hasVList = false
            for _, pc in p:GetChildren() do
                if pc:IsA("UIListLayout")
                and pc.FillDirection == Enum.FillDirection.Vertical then
                    hasVList = true
                    break
                end
            end
            if hasVList then
                CurrentTabLabel = desc
                break
            end
        end
    end
end

local _shimmerActive = false
local _shimmerTween  = nil
local ShimmerClip    = nil
local ShimmerBeam    = nil

if CurrentTabLabel then
    -- Clip container (ClipsDescendants = beam tak bocor ke luar label)
    ShimmerClip = Instance.new("Frame")
    ShimmerClip.Name                  = "ShimmerClip"
    ShimmerClip.BackgroundTransparency = 1
    ShimmerClip.ClipsDescendants      = true
    ShimmerClip.Size                  = UDim2.fromScale(1, 1)
    ShimmerClip.ZIndex                = CurrentTabLabel.ZIndex + 2
    ShimmerClip.Visible               = false
    ShimmerClip.Parent                = CurrentTabLabel

    -- Beam (balok cahaya yang bergerak)
    ShimmerBeam = Instance.new("Frame")
    ShimmerBeam.Name             = "ShimmerBeam"
    ShimmerBeam.BackgroundColor3 = Color3.new(1, 1, 1)
    ShimmerBeam.BorderSizePixel  = 0
    ShimmerBeam.AnchorPoint      = Vector2.new(0.5, 0)
    ShimmerBeam.Position         = UDim2.fromScale(-0.35, 0)
    ShimmerBeam.Size             = UDim2.fromScale(0.30, 1)
    ShimmerBeam.ZIndex           = CurrentTabLabel.ZIndex + 2
    ShimmerBeam.Parent           = ShimmerClip

    -- Gradient: transparan di pinggir, opaque di tengah
    local beamGrad = Instance.new("UIGradient")
    beamGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,    1   ),
        NumberSequenceKeypoint.new(0.22, 0.58),
        NumberSequenceKeypoint.new(0.50, 0.08),
        NumberSequenceKeypoint.new(0.78, 0.58),
        NumberSequenceKeypoint.new(1,    1   ),
    })
    beamGrad.Rotation = 0
    beamGrad.Parent   = ShimmerBeam

    -- Sudut membulat supaya beam lebih lembut
    local beamCorner = Instance.new("UICorner")
    beamCorner.CornerRadius = UDim.new(0, 8)
    beamCorner.Parent       = ShimmerBeam
else
    warn("[ObsidianPatch] CurrentTabLabel tidak ditemukan — shimmer dilewati.")
    warn("  Pastikan tab yang dibuat memiliki 'Description' agar ShowTabInfo dipanggil.")
end

-- Loop shimmer
local function _runShimmer()
    if not _shimmerActive or Library.Unloaded then
        if ShimmerClip then ShimmerClip.Visible = false end
        return
    end

    ShimmerBeam.Position  = UDim2.fromScale(-0.35, 0)
    ShimmerClip.Visible   = true

    _shimmerTween = TweenService:Create(
        ShimmerBeam,
        TweenInfo.new(0.72, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
        { Position = UDim2.fromScale(1.22, 0) }
    )
    _shimmerTween:Play()
    _shimmerTween.Completed:Connect(function(state)
        if state ~= Enum.PlaybackState.Completed then return end
        if not _shimmerActive or Library.Unloaded then
            if ShimmerClip then ShimmerClip.Visible = false end
            return
        end
        task.delay(1.4, _runShimmer)   -- jeda 1.4 detik antar shimmer
    end)
end

function Library:_StartTabShimmer()
    if not ShimmerClip then return end
    _shimmerActive = true
    _runShimmer()
end

function Library:_StopTabShimmer()
    _shimmerActive = false
    if _shimmerTween then
        _shimmerTween:Cancel()
        _shimmerTween = nil
    end
    if ShimmerClip then
        ShimmerClip.Visible = false
    end
end

-- ── Hook ShowTabInfo / HideTabInfo ──────────────────────────
local _origShow = Window.ShowTabInfo
local _origHide = Window.HideTabInfo

function Window:ShowTabInfo(Name, Desc)
    _origShow(self, Name, Desc)
    Library:_StartTabShimmer()
end

function Window:HideTabInfo()
    _origHide(self)
    Library:_StopTabShimmer()
end

-- ══════════════════════════════════════════════════════════════
-- [3]  CLEANUP saat Library di-Unload
-- ══════════════════════════════════════════════════════════════

Library:OnUnload(function()
    Library:_StopTabShimmer()
    Library:SetRainbowAccentBar(false)
end)

-- ══════════════════════════════════════════════════════════════
-- [4]  HELPER: AddRainbowToggle
--      Tambahkan toggle "Rainbow Accent Bar" ke groupbox Settings
--
--      CONTOH:
--          local SettingsTab = Window:AddTab("Settings")
--          local MenuGroup = SettingsTab:AddLeftGroupbox("Menu")
--          Library:AddRainbowToggle(MenuGroup)
-- ══════════════════════════════════════════════════════════════

function Library:AddRainbowToggle(Groupbox, Idx, DefaultOn)
    Idx = Idx or "RainbowAccentBar"
    return Groupbox:AddToggle(Idx, {
        Text    = "Rainbow Accent Bar",
        Default = DefaultOn == true,
        Callback = function(Value)
            Library:SetRainbowAccentBar(Value)
        end,
    })
end

-- ══════════════════════════════════════════════════════════════
-- SELESAI
-- ══════════════════════════════════════════════════════════════
print("[ObsidianPatch] ✓ Patch berhasil!")
print("  Rainbow bar  →  Library:SetRainbowAccentBar(true)")
print("  Tab shimmer  →  otomatis saat tab punya Description")

