-- Language: Luau | Target: Roblox (Murder Mystery 2) | Architecture: 1:1 Skeet.cc V15 (Fixed Stack-Safe Hooks + Anti-Cheater Desync + Pro Visuals)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local SoundService = game:GetService("SoundService")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local LocalMouse = LocalPlayer:GetMouse()

local OriginalState = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
    FogColor = Lighting.FogColor,
    GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    CameraFOV = Camera.FieldOfView,
    MaxZoom = LocalPlayer.CameraMaxZoomDistance,
    MinZoom = LocalPlayer.CameraMinZoomDistance,
    WalkSpeed = 16,
    JumpPower = 50
}

local Connections = {}
local CreatedInstances = {}
local DrawingObjects = {}
local ESPObjects = {}
local SavedMotorC0 = {}
local XRayParts = {}
local BacktrackHistory = {}
local UIUpdaters = {}
local Unhooked = false

local function TrackConnection(conn)
    if conn then table.insert(Connections, conn) end
    return conn
end

local function TrackInstance(inst)
    if inst then table.insert(CreatedInstances, inst) end
    return inst
end

local function TrackDrawing(drawObj)
    if drawObj then table.insert(DrawingObjects, drawObj) end
    return drawObj
end

-- Премиум палитра оригинального Skeet / Gamesense
local Skeet = {
    OuterBorder = Color3.fromRGB(10, 10, 10),
    InnerBorder = Color3.fromRGB(48, 48, 48),
    MainBg = Color3.fromRGB(16, 16, 16),
    SidebarBg = Color3.fromRGB(11, 11, 11),
    GroupBg = Color3.fromRGB(20, 20, 20),
    GroupBorder = Color3.fromRGB(38, 38, 38),
    ControlBg = Color3.fromRGB(28, 28, 28),
    ControlBorder = Color3.fromRGB(8, 8, 8),
    Accent = Color3.fromRGB(149, 184, 6), -- Фирменный лаймовый #95b806
    Cyan = Color3.fromRGB(55, 185, 255),
    Purple = Color3.fromRGB(190, 85, 255),
    Danger = Color3.fromRGB(255, 60, 60),
    Gold = Color3.fromRGB(255, 215, 55),
    Text = Color3.fromRGB(210, 210, 210),
    TextActive = Color3.fromRGB(245, 245, 245),
    TextDim = Color3.fromRGB(115, 115, 115),
    IconIdle = Color3.fromRGB(90, 90, 90),
    IconActive = Color3.fromRGB(220, 220, 220),

    Murderer = Color3.fromRGB(255, 60, 65),
    Sheriff = Color3.fromRGB(60, 165, 255),
    Innocent = Color3.fromRGB(149, 184, 6),
    GunDrop = Color3.fromRGB(255, 220, 45)
}

local HitSounds = {
    ["Skeet"] = "rbxassetid://5447626464",
    ["Neverlose"] = "rbxassetid://8726881116",
    ["Rust"] = "rbxassetid://4764109000",
    ["Bell"] = "rbxassetid://6534947240"
}

-- Полный конфиг V15 (на русском и английском в стиле Скита)
local Config = {
    -- Вкладка 1: Ragebot & Silent Aim (Без рекурсии и блокировки кликов!)
    SilentAim = true,
    SilentAimMethod = "Dual (Remote + Mouse)", -- Dual (Remote + Mouse), Remote Only, Mouse.Hit Only
    FixBulletDrop = true,
    TargetRolePriority = "Smart (Role-Based)", -- Smart (Role-Based), Any Closest, Murderer Only
    HitPart = "HumanoidRootPart",
    AutoFire = false,
    Wallbang = false,
    HitChance = 100,
    Prediction = 13,
    FOV = 240,
    ShowFOV = true,
    TargetLine = true,
    DoubleTap = false,
    QuickStop = false,
    QuickPeek = false,
    LogMisses = true,

    -- Перехват револьвера у живого Шерифа
    AutoStealSheriffGun = false,
    RemoteShootFromSheriff = true,
    BreakSheriffGun = false,

    -- Вкладка 2: Рабочие Anti-Aim и Анти-Читер Десинк (Anti-Resolver)
    AA_Enabled = false,
    AA_LadderBypass = true,
    AA_Pitch = "Down",
    AA_YawBase = "Local view",
    AA_Yaw = "Spinbot", -- 180, Spinbot, Jitter, Crosshair
    AA_YawJitter = "Center", -- Off, Offset, Center, Random, 3-Way
    AA_JitterRange = 72,
    AA_SpinSpeed = 55,
    AA_BodyYaw = "Opposite",
    AA_RollLean = 0,
    AA_ManualKeys = false,
    AA_ShowArrows = true,
    AA_Freestanding = false,
    AA_DefensiveAir = true,

    -- Анти-Читер Десинк (Ломает чужой Silent Aim + CFrame рассинхрон с фиксацией камеры)
    Desync_Enabled = false,
    Desync_Mode = "Anti-Silent (CFrame + Vel)", -- Anti-Silent (CFrame + Vel), Velocity Breaker, Underground Dodge, Random Teleport
    Desync_VelocityPattern = "Inverse Prediction", -- Inverse Prediction, Zero Velocity, NaN/Inf Breaker, Chaotic Jitter
    Desync_Power = 350,
    Desync_Side = "Jitter", -- Jitter, Left, Right, Behind, Orbit
    Desync_Distance = 7, -- На сколько стадов серверный хитбокс уходит от реального
    Desync_ShowGhost = true,
    FakeLag = false,
    FakeLagLimit = 4,
    FakeDuck = false,

    -- Вкладка 3: Legitbot & Невесомый 3D Скинченджер (Не ломает удары ножом!)
    SkinChanger = false,
    GunSkinModel = "AWP Sniper", -- AWP Sniper, SSG-08 Scout, Desert Eagle
    GunSkinFinish = "Dragon Lore", -- Dragon Lore, Asiimov, Fade, Gungnir, Printstream, Redline
    KnifeSkinModel = "Karambit", -- Karambit, Butterfly Knife, M9 Bayonet, Skeleton Knife
    KnifeSkinFinish = "Doppler Ruby", -- Doppler Ruby, Sapphire, Emerald, Fade, Case Hardened Blue Gem, Lore
    KnifeInspectSpin = true,
    CSGOSounds = true,

    LegitAim = false,
    LegitAimKey = "MouseButton2 (RMB)",
    LegitSmooth = 16,
    LegitFOV = 95,
    ShowLegitFOV = false,
    LegitVisibleOnly = true,
    LegitTriggerbot = false,
    TriggerbotDelay = 40,
    LegitBacktrack = false,
    BacktrackMS = 220,
    LegitKnifeReach = true,
    KnifeReachDist = 11,
    HitboxExpander = false,
    HitboxSize = 7,
    HitboxTrans = 80,

    -- Вкладка 4: Дорогие Визуалы (Pro Skeet ESP, Угловые боксы, Градиенты)
    ESP_Enabled = true,
    ESP_Box = true,
    ESP_BoxStyle = "Corner", -- Corner (Угловой премиум), Full (Классический)
    ESP_BoxFill = true, -- Полупрозрачная заливка бокса
    ESP_Name = true,
    ESP_HealthBar = true,
    ESP_Distance = true,
    ESP_Flags = true,
    ESP_Skeleton = true,
    ESP_LookLine = false,
    ESP_OOFArrows = true,
    ESP_OOFRadius = 150,
    Chams = true,
    ChamsStyle = "ForceField Glow", -- ForceField Glow, Matte Flat, Neon Pulse
    ChamsAlpha = 55,
    ESP_GunDrop = true,
    ESP_Coins = false,

    Radar2D = true,
    RadarZoom = 18,
    TargetHUD = true,
    MurdererDangerRing = true,
    KnifeTrajectory = false,
    FloatingDamage = true,

    CustomScope = true,
    ScopeAlignMode = "Crosshair / Mouse",
    ScopeMode = "Gradient Cross",
    ScopeColorMode = "Skeet Green",
    ScopeLength = 90,
    ScopeGap = 12,
    ScopeThickness = 1,
    ScopeDynamicSpread = true,
    ScopeCenterDot = true,
    ScopeZoomRMB = false,
    ScopeZoomFOV = 42,

    ChinaHat = false,
    ChinaHatColor = "Skeet Green",
    ChinaHatRadius = 20,
    ChinaHatHeight = 11,
    HaloRing = true,
    LocalTrail = false,
    JumpCircles = true,
    HitChams = true,
    HitChamsDuration = 2,
    BulletImpacts = true,
    BulletTracers = true,
    HitMarker = true,
    HitSound = true,
    SoundType = "Skeet",
    SoundVol = 6,

    WorldAmbience = false,
    WorldTintMode = "Midnight Purple",
    WorldTime = 14,
    CustomTime = false,
    CustomFog = false,
    FogDist = 350,
    ColorSaturation = 15,
    Fullbright = false,
    NightMode = false,
    ThirdPerson = false,
    ThirdPersonDist = 14,
    CustomFOV = false,
    CameraFOV = 95,
    AspectRatio = false,
    AspectRatioVal = 75,
    Watermark = true,
    KeybindList = true,

    -- Вкладка 5: Движение и Утилиты MM2
    Speed_Enabled = false,
    SpeedMode = "WalkSpeed",
    SpeedVal = 32,
    BHop = false,
    AirStrafe = false,
    StrafeSpeed = 32,
    CircleStrafe = false,
    CircleRadius = 10,
    EdgeJump = false,
    InfiniteJump = false,
    HighJump = false,
    JumpPower = 70,
    Noclip = false,

    AutoGrabGun = false,
    CoinMagnet = false,
    CoinMagnetDist = 18,
    AutoCoinFarm = false,
    AutoDodgeMurderer = false,
    DodgeDistance = 13,
    XRayWalls = false,
    XRayTrans = 65,
    AntiAFK = true,

    -- Вкладка 6: Мардер (100% Регистрация Ударов)
    GuaranteedStabFix = true,
    KillAll = false,
    KnifeAura = false,
    AuraRange = 18,
    SilentKnifeThrow = true,
    AutoEquipKnife = false,
    FakeDead = false,

    SelectedConfigSlot = "Slot 1 (Rage)"
}

local DefaultConfigBackup = {}
for k, v in pairs(Config) do DefaultConfigBackup[k] = v end

local ManualDir = 0

local function GetThemeColor(mode, offset)
    if mode == "Rainbow" then
        return Color3.fromHSV((tick() * 0.30 + (offset or 0)) % 1, 0.75, 1)
    elseif mode == "Cyan" or mode == "Cyber Cyan" then
        return Skeet.Cyan
    elseif mode == "Purple" or mode == "Midnight Purple" then
        return Skeet.Purple
    elseif mode == "Crimson" then
        return Skeet.Murderer
    end
    return Skeet.Accent
end

local function GetDetailedSkinPalette(finish)
    if finish == "Dragon Lore" or finish == "Lore" then
        return {Chassis = Color3.fromRGB(228, 188, 62), Art = Color3.fromRGB(185, 42, 32), Trim = Color3.fromRGB(48, 68, 42), Metal = Color3.fromRGB(24, 26, 28), Lens = Color3.fromRGB(255, 175, 40), Mat = Enum.Material.Metal}
    elseif finish == "Asiimov" then
        return {Chassis = Color3.fromRGB(242, 242, 245), Art = Color3.fromRGB(255, 108, 18), Trim = Color3.fromRGB(26, 28, 32), Metal = Color3.fromRGB(32, 34, 38), Lens = Color3.fromRGB(255, 120, 30), Mat = Enum.Material.SmoothPlastic}
    elseif finish == "Fade" then
        return {Chassis = Color3.fromRGB(255, 55, 155), Art = Color3.fromRGB(255, 185, 25), Trim = Color3.fromRGB(115, 75, 255), Metal = Color3.fromRGB(28, 28, 34), Lens = Color3.fromRGB(255, 85, 200), Mat = Enum.Material.Glass}
    elseif finish == "Gungnir" or finish == "Sapphire" then
        return {Chassis = Color3.fromRGB(22, 98, 225), Art = Color3.fromRGB(145, 210, 255), Trim = Color3.fromRGB(215, 228, 245), Metal = Color3.fromRGB(25, 32, 48), Lens = Color3.fromRGB(80, 195, 255), Mat = Enum.Material.Glass}
    elseif finish == "Printstream" then
        return {Chassis = Color3.fromRGB(245, 245, 248), Art = Color3.fromRGB(22, 22, 26), Trim = Color3.fromRGB(215, 195, 255), Metal = Color3.fromRGB(20, 20, 24), Lens = Color3.fromRGB(210, 180, 255), Mat = Enum.Material.SmoothPlastic}
    elseif finish == "Redline" or finish == "Doppler Ruby" then
        return {Chassis = Color3.fromRGB(195, 16, 36), Art = Color3.fromRGB(255, 45, 65), Trim = Color3.fromRGB(22, 22, 26), Metal = Color3.fromRGB(18, 18, 22), Lens = Color3.fromRGB(255, 40, 60), Mat = Enum.Material.Glass}
    elseif finish == "Case Hardened Blue Gem" then
        return {Chassis = Color3.fromRGB(45, 155, 255), Art = Color3.fromRGB(215, 175, 75), Trim = Color3.fromRGB(135, 95, 195), Metal = Color3.fromRGB(35, 35, 40), Lens = Color3.fromRGB(65, 180, 255), Mat = Enum.Material.Metal}
    elseif finish == "Emerald" then
        return {Chassis = Color3.fromRGB(18, 195, 78), Art = Color3.fromRGB(65, 255, 130), Trim = Color3.fromRGB(12, 85, 38), Metal = Color3.fromRGB(22, 26, 24), Lens = Color3.fromRGB(50, 255, 120), Mat = Enum.Material.Glass}
    end
    return {Chassis = Skeet.Accent, Art = Skeet.Cyan, Trim = Color3.fromRGB(30, 30, 30), Metal = Color3.fromRGB(20, 20, 20), Lens = Skeet.Accent, Mat = Enum.Material.Metal}
end

-------------------------------------------------------------------------
-- ЗВУКОВОЙ ДВИЖОК, ПРЕМИУМ ТРЕЙСЕРЫ И ХИТЛОГИ
-------------------------------------------------------------------------
local ScreenGui = TrackInstance(Instance.new("ScreenGui"))
ScreenGui.Name = "gamesense_mm2_v15"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
if gethui then
    ScreenGui.Parent = gethui()
elseif syn and syn.protect_gui then
    syn.protect_gui(ScreenGui)
    ScreenGui.Parent = CoreGui
else
    ScreenGui.Parent = CoreGui
end

local ColorGrade = TrackInstance(Instance.new("ColorCorrectionEffect"))
ColorGrade.Name = "GS_ColorGrade"
ColorGrade.Parent = Lighting

local HitSoundChannel = TrackInstance(Instance.new("Sound"))
HitSoundChannel.Name = "GS_HitSound"
HitSoundChannel.Parent = SoundService

local WeaponSoundChannel = TrackInstance(Instance.new("Sound"))
WeaponSoundChannel.Name = "GS_WeaponSound"
WeaponSoundChannel.Parent = SoundService

local function PlayCSGOWeaponSound(isAWP)
    if Unhooked or not Config.CSGOSounds then return end
    WeaponSoundChannel.SoundId = isAWP and "rbxassetid://6067278314" or "rbxassetid://6534947240"
    WeaponSoundChannel.Volume = 1.6
    WeaponSoundChannel.TimePosition = 0
    WeaponSoundChannel:Play()
end

local LastSoundPlay = 0
local function PlayDamageHitSound()
    if Unhooked or not Config.HitSound then return end
    if tick() - LastSoundPlay < 0.07 then return end
    LastSoundPlay = tick()
    HitSoundChannel.SoundId = HitSounds[Config.SoundType] or HitSounds["Skeet"]
    HitSoundChannel.Volume = Config.SoundVol / 2
    HitSoundChannel.TimePosition = 0
    HitSoundChannel.Parent = SoundService
    HitSoundChannel:Play()
end

local HitlogHolder = Instance.new("Frame", ScreenGui)
HitlogHolder.Size = UDim2.new(0, 460, 0, 180)
HitlogHolder.Position = UDim2.new(0, 14, 0, 42)
HitlogHolder.BackgroundTransparency = 1
local hlLayout = Instance.new("UIListLayout", HitlogHolder)
hlLayout.Padding = UDim.new(0, 3)

local function PushSkeetLog(text, col)
    if Unhooked or not Config.LogMisses then return end
    local row = Instance.new("Frame", HitlogHolder)
    row.Size = UDim2.new(0, #text * 6.8 + 16, 0, 18)
    row.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
    row.BackgroundTransparency = 0.2
    row.BorderSizePixel = 0

    local bar = Instance.new("Frame", row)
    bar.Size = UDim2.new(0, 2, 1, 0)
    bar.BackgroundColor3 = col or Skeet.Accent
    bar.BorderSizePixel = 0

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -10, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 11
    lbl.TextColor3 = Color3.fromRGB(230, 230, 230)
    lbl.TextStrokeTransparency = 0.2
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = text

    task.delay(3.5, function()
        if row and row.Parent then row:Destroy() end
    end)
end

local function SpawnFloatingDamage(worldPos, dmg)
    if Unhooked or not Config.FloatingDamage or not worldPos then return end
    local anchor = TrackInstance(Instance.new("Part"))
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.Transparency = 1
    anchor.Size = Vector3.new(0.1, 0.1, 0.1)
    anchor.Position = worldPos + Vector3.new(math.random(-8, 8) / 10, 1.4, math.random(-8, 8) / 10)
    anchor.Parent = Workspace

    local bb = Instance.new("BillboardGui", anchor)
    bb.AlwaysOnTop = true
    bb.Size = UDim2.new(0, 70, 0, 24)
    local txt = Instance.new("TextLabel", bb)
    txt.Size = UDim2.new(1, 0, 1, 0)
    txt.BackgroundTransparency = 1
    txt.Font = Enum.Font.Code
    txt.TextSize = 14
    txt.TextColor3 = Skeet.Accent
    txt.TextStrokeTransparency = 0
    txt.Text = "-" .. tostring(math.floor(dmg or 100))

    task.spawn(function()
        for i = 1, 22 do
            if Unhooked or not anchor.Parent then break end
            anchor.Position = anchor.Position + Vector3.new(0, 0.07, 0)
            txt.TextTransparency = i / 22
            txt.TextStrokeTransparency = i / 22
            task.wait(0.025)
        end
        if anchor then anchor:Destroy() end
    end)
end

local function SpawnHitChamClone(victimChar)
    if Unhooked or not Config.HitChams or not victimChar then return end
    local folder = TrackInstance(Instance.new("Model"))
    folder.Name = "GS_HitCham"
    folder.Parent = Workspace
    for _, part in ipairs(victimChar:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local p = Instance.new("Part")
            p.Size = part.Size
            p.CFrame = part.CFrame
            p.Anchored = true
            p.CanCollide = false
            p.CastShadow = false
            p.Material = Enum.Material.ForceField
            p.Color = Skeet.Accent
            p.Transparency = 0.35
            p.Parent = folder
        end
    end
    task.delay(Config.HitChamsDuration, function()
        if folder and folder.Parent then folder:Destroy() end
    end)
end

-- Тонкий двухслойный лазерный трейсер (Внешнее свечение + яркое тонкое ядро)
local function SpawnProBulletTracer(origin, targetPos)
    if Unhooked or not Config.BulletTracers then return end
    local dist = (targetPos - origin).Magnitude
    if dist < 1 then return end
    local midCF = CFrame.lookAt(origin, targetPos) * CFrame.new(0, 0, -dist / 2)

    local core = TrackInstance(Instance.new("Part"))
    core.Anchored = true
    core.CanCollide = false
    core.CastShadow = false
    core.Material = Enum.Material.Neon
    core.Color = Color3.new(1, 1, 1)
    core.Transparency = 0.1
    core.Size = Vector3.new(0.05, 0.05, dist)
    core.CFrame = midCF
    core.Parent = Workspace

    local glow = TrackInstance(Instance.new("Part"))
    glow.Anchored = true
    glow.CanCollide = false
    glow.CastShadow = false
    glow.Material = Enum.Material.Neon
    glow.Color = Skeet.Accent
    glow.Transparency = 0.55
    glow.Size = Vector3.new(0.14, 0.14, dist)
    glow.CFrame = midCF
    glow.Parent = Workspace

    task.spawn(function()
        for i = 1, 15 do
            if Unhooked then break end
            local alpha = i / 15
            if core.Parent then core.Transparency = 0.1 + alpha * 0.9 end
            if glow.Parent then glow.Transparency = 0.55 + alpha * 0.45 end
            task.wait(0.02)
        end
        if core then core:Destroy() end
        if glow then glow:Destroy() end
    end)
end

local function SpawnHitVisuals(pos, plrName, dmg, victimChar)
    if Unhooked then return end
    PlayDamageHitSound()
    if plrName then
        PushSkeetLog(string.format("Hit %s in %s for %d dmg (0 remaining)", plrName, string.lower(Config.HitPart), math.floor(dmg or 100)), Skeet.Accent)
    end
    if pos then
        task.spawn(SpawnFloatingDamage, pos, dmg or 100)
    end
    if victimChar then
        task.spawn(SpawnHitChamClone, victimChar)
    end
    if Config.HitMarker then
        local mouseLoc = UserInputService:GetMouseLocation()
        local hm = Instance.new("Frame", ScreenGui)
        hm.Size = UDim2.new(0, 16, 0, 16)
        hm.Position = UDim2.new(0, mouseLoc.X - 8, 0, mouseLoc.Y - 8)
        hm.BackgroundTransparency = 1
        for _, rot in ipairs({45, -45}) do
            local line = Instance.new("Frame", hm)
            line.Size = UDim2.new(0, 12, 0, 1)
            line.Position = UDim2.new(0.5, -6, 0.5, 0)
            line.BackgroundColor3 = Skeet.Accent
            line.BorderSizePixel = 0
            line.Rotation = rot
        end
        task.delay(0.18, function() if hm then hm:Destroy() end end)
    end
    if pos then
        if Config.BulletImpacts then
            local box = TrackInstance(Instance.new("Part"))
            box.Anchored = true
            box.CanCollide = false
            box.Size = Vector3.new(0.32, 0.32, 0.32)
            box.CFrame = CFrame.new(pos)
            box.Material = Enum.Material.ForceField
            box.Color = Skeet.Danger
            box.Transparency = 0.2
            box.Parent = Workspace
            task.delay(1.8, function() if box then box:Destroy() end end)
        end
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head") then
            SpawnProBulletTracer(LocalPlayer.Character.Head.Position, pos)
        end
    end
end

local LastAttackData = {Player = nil, Time = 0}
local function BindDamageTracker(plr)
    if plr == LocalPlayer then return end
    local function watchChar(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if not hum then return end
        local lastHp = hum.Health
        TrackConnection(hum.HealthChanged:Connect(function(hp)
            if Unhooked then return end
            if hp < lastHp then
                local myChar = LocalPlayer.Character
                local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                local tRoot = char:FindFirstChild("HumanoidRootPart")
                local armed = myChar and (myChar:FindFirstChild("Knife") or myChar:FindFirstChild("Gun"))
                local near = (myRoot and tRoot and (tRoot.Position - myRoot.Position).Magnitude <= 25)
                local shot = (LastAttackData.Player == plr and (tick() - LastAttackData.Time) <= 1.8)
                if (armed and near) or shot then
                    SpawnHitVisuals(tRoot and tRoot.Position or nil, plr.Name, lastHp - hp, char)
                end
            end
            lastHp = hp
        end))
    end
    if plr.Character then task.spawn(watchChar, plr.Character) end
    TrackConnection(plr.CharacterAdded:Connect(watchChar))
end
for _, p in ipairs(Players:GetPlayers()) do BindDamageTracker(p) end
TrackConnection(Players.PlayerAdded:Connect(BindDamageTracker))

TrackConnection(LocalPlayer.Idled:Connect(function()
    if not Unhooked and Config.AntiAFK then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.zero)
        end)
    end
end))

-------------------------------------------------------------------------
-- БЕЗОПАСНЫЙ 3D СКИНЧЕНДЖЕР НА MOTOR6D (НЕ БЛОКИРУЕТ УДАРЫ НОЖОМ И ВЫСТРЕЛЫ!)
-------------------------------------------------------------------------
local ActiveSkinModels = {}
local InspectingUntil = 0

local function ClearCustomSkins()
    for tool, mdl in pairs(ActiveSkinModels) do
        if mdl and mdl.Parent then mdl:Destroy() end
        if tool and tool.Parent and tool:FindFirstChild("Handle") then
            tool.Handle.LocalTransparencyModifier = 0
            tool.Handle.Transparency = 0
        end
    end
    table.clear(ActiveSkinModels)
end

-- Используем Motor6D вместо жесткого WeldConstraint и LocalTransparencyModifier вместо серверного Transparency,
-- чтобы серверный и клиентский скрипт ножа/револьвера в MM2 никогда не ломал анимацию удара!
local function AddMicroPart(model, handle, sizeVec, offsetCF, color, mat, meshKind)
    local p = Instance.new("Part")
    p.Size = Vector3.new(0.2, 0.2, 0.2)
    p.Color = color
    p.Material = mat or Enum.Material.Metal
    p.Reflectance = (mat == Enum.Material.Glass or mat == Enum.Material.Metal) and 0.15 or 0
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.Massless = true
    p.Anchored = false
    p.CastShadow = false

    local sm = Instance.new("SpecialMesh", p)
    if meshKind == "Cylinder" then
        sm.MeshType = Enum.MeshType.Cylinder
    elseif meshKind == "Wedge" then
        sm.MeshType = Enum.MeshType.Wedge
    elseif meshKind == "Sphere" then
        sm.MeshType = Enum.MeshType.Sphere
    else
        sm.MeshType = Enum.MeshType.Brick
    end
    sm.Scale = sizeVec * 5

    p.CFrame = handle.CFrame * offsetCF
    p.Parent = model

    local m6d = Instance.new("Motor6D")
    m6d.Part0 = handle
    m6d.Part1 = p
    m6d.C0 = offsetCF
    m6d.Parent = p
    return p
end

local function ApplyAWPSkinToGun(gunTool)
    if not gunTool or not gunTool:FindFirstChild("Handle") then return end
    local handle = gunTool.Handle
    local tag = Config.GunSkinModel .. "_" .. Config.GunSkinFinish
    if ActiveSkinModels[gunTool] and ActiveSkinModels[gunTool].Name == "GS_Skin_" .. tag and ActiveSkinModels[gunTool].Parent == gunTool then
        handle.LocalTransparencyModifier = 1
        return
    end
    if ActiveSkinModels[gunTool] then ActiveSkinModels[gunTool]:Destroy() end

    handle.LocalTransparencyModifier = 1
    local pal = GetDetailedSkinPalette(Config.GunSkinFinish)
    local mdl = TrackInstance(Instance.new("Model"))
    mdl.Name = "GS_Skin_" .. tag
    mdl.Parent = gunTool

    if Config.GunSkinModel == "Desert Eagle" then
        AddMicroPart(mdl, handle, Vector3.new(0.18, 0.26, 1.38), CFrame.new(0, 0.20, -0.38), pal.Chassis, pal.Mat, "Brick")
        AddMicroPart(mdl, handle, Vector3.new(0.14, 0.12, 1.36), CFrame.new(0, 0.36, -0.38), pal.Art, Enum.Material.Neon, "Brick")
        AddMicroPart(mdl, handle, Vector3.new(0.16, 0.68, 0.30), CFrame.new(0, -0.18, 0.16) * CFrame.Angles(math.rad(-16), 0, 0), pal.Metal, Enum.Material.SmoothPlastic, "Brick")
    else
        local lenScale = (Config.GunSkinModel == "SSG-08 Scout") and 0.86 or 1.0
        AddMicroPart(mdl, handle, Vector3.new(0.20, 0.30, 2.35 * lenScale), CFrame.new(0, 0.08, -0.75 * lenScale), pal.Chassis, pal.Mat, "Brick")
        AddMicroPart(mdl, handle, Vector3.new(0.215, 0.12, 2.10 * lenScale), CFrame.new(0, 0.11, -0.70 * lenScale), pal.Art, Enum.Material.Neon, "Brick")
        AddMicroPart(mdl, handle, Vector3.new(0.18, 0.14, 1.15), CFrame.new(0, 0.14, 0.92), pal.Chassis, pal.Mat, "Brick")
        AddMicroPart(mdl, handle, Vector3.new(0.18, 0.11, 1.15), CFrame.new(0, -0.18, 0.92) * CFrame.Angles(math.rad(6), 0, 0), pal.Chassis, pal.Mat, "Brick")
        AddMicroPart(mdl, handle, Vector3.new(0.18, 0.44, 0.52), CFrame.new(0, -0.01, 1.38), pal.Chassis, pal.Mat, "Brick")
        AddMicroPart(mdl, handle, Vector3.new(0.20, 0.12, 0.62), CFrame.new(0, 0.24, 1.12), pal.Trim, Enum.Material.SmoothPlastic, "Brick")
        AddMicroPart(mdl, handle, Vector3.new(0.14, 0.42, 0.48), CFrame.new(0, -0.22, -0.35), pal.Metal, Enum.Material.Metal, "Brick")
        AddMicroPart(mdl, handle, Vector3.new(3.15 * lenScale, 0.11, 0.11), CFrame.new(0, 0.26, -2.35 * lenScale) * CFrame.Angles(0, math.rad(90), 0), pal.Metal, Enum.Material.Metal, "Cylinder")
        AddMicroPart(mdl, handle, Vector3.new(0.18, 0.18, 0.42), CFrame.new(0, 0.26, -4.02 * lenScale), pal.Metal, Enum.Material.Metal, "Brick")
        AddMicroPart(mdl, handle, Vector3.new(0.14, 0.22, 0.12), CFrame.new(0, 0.44, -0.58), pal.Metal, Enum.Material.Metal, "Brick")
        AddMicroPart(mdl, handle, Vector3.new(0.14, 0.22, 0.12), CFrame.new(0, 0.44, 0.05), pal.Metal, Enum.Material.Metal, "Brick")
        AddMicroPart(mdl, handle, Vector3.new(1.45, 0.16, 0.16), CFrame.new(0, 0.56, -0.32) * CFrame.Angles(0, math.rad(90), 0), pal.Metal, Enum.Material.Metal, "Cylinder")
        AddMicroPart(mdl, handle, Vector3.new(0.48, 0.28, 0.28), CFrame.new(0, 0.56, -1.18) * CFrame.Angles(0, math.rad(90), 0), pal.Trim, Enum.Material.Metal, "Cylinder")
        AddMicroPart(mdl, handle, Vector3.new(0.36, 0.24, 0.24), CFrame.new(0, 0.56, 0.48) * CFrame.Angles(0, math.rad(90), 0), pal.Trim, Enum.Material.Metal, "Cylinder")
        AddMicroPart(mdl, handle, Vector3.new(0.05, 0.24, 0.24), CFrame.new(0, 0.56, -1.41) * CFrame.Angles(0, math.rad(90), 0), pal.Lens, Enum.Material.Neon, "Cylinder")
    end

    ActiveSkinModels[gunTool] = mdl
end

local function ApplyCSGOKnifeSkin(knifeTool)
    if not knifeTool or not knifeTool:FindFirstChild("Handle") then return end
    local handle = knifeTool.Handle
    local tag = Config.KnifeSkinModel .. "_" .. Config.KnifeSkinFinish
    if ActiveSkinModels[knifeTool] and ActiveSkinModels[knifeTool].Name == "GS_Skin_" .. tag and ActiveSkinModels[knifeTool].Parent == knifeTool then
        handle.LocalTransparencyModifier = 1
        return
    end
    if ActiveSkinModels[knifeTool] then ActiveSkinModels[knifeTool]:Destroy() end

    handle.LocalTransparencyModifier = 1
    local pal = GetDetailedSkinPalette(Config.KnifeSkinFinish)
    local mdl = TrackInstance(Instance.new("Model"))
    mdl.Name = "GS_Skin_" .. tag
    mdl.Parent = knifeTool

    if Config.KnifeSkinModel == "Karambit" then
        AddMicroPart(mdl, handle, Vector3.new(0.09, 0.36, 0.36), CFrame.new(0, -0.62, 0.14), pal.Chassis, Enum.Material.Metal, "Cylinder")
        AddMicroPart(mdl, handle, Vector3.new(0.11, 0.24, 0.24), CFrame.new(0, -0.62, 0.14), Color3.fromRGB(10, 10, 12), Enum.Material.SmoothPlastic, "Cylinder")
        AddMicroPart(mdl, handle, Vector3.new(0.11, 0.62, 0.22), CFrame.new(0, -0.14, 0.06) * CFrame.Angles(math.rad(10), 0, 0), pal.Metal, Enum.Material.SmoothPlastic, "Brick")
        for i = 1, 6 do
            local prog = i / 6
            local angleRad = math.rad(-14 - (prog * 74))
            local radius = 0.70
            local yPos = 0.18 + math.sin(prog * 1.35) * radius
            local zPos = -0.02 - (1 - math.cos(prog * 1.35)) * radius
            local width = 0.25 * (1 - prog * 0.68)
            AddMicroPart(mdl, handle, Vector3.new(0.032, 0.18, width), CFrame.new(0, yPos, zPos) * CFrame.Angles(angleRad, 0, 0), pal.Chassis, Enum.Material.Neon, "Wedge")
        end
    elseif Config.KnifeSkinModel == "Butterfly Knife" then
        AddMicroPart(mdl, handle, Vector3.new(0.08, 0.82, 0.12), CFrame.new(0, -0.24, -0.09), pal.Metal, Enum.Material.Metal, "Brick")
        AddMicroPart(mdl, handle, Vector3.new(0.08, 0.82, 0.12), CFrame.new(0, -0.24, 0.09), pal.Metal, Enum.Material.Metal, "Brick")
        AddMicroPart(mdl, handle, Vector3.new(0.035, 1.15, 0.22), CFrame.new(0, 0.82, 0), pal.Chassis, Enum.Material.Neon, "Brick")
        AddMicroPart(mdl, handle, Vector3.new(0.035, 0.34, 0.22), CFrame.new(0, 1.48, 0) * CFrame.Angles(0, math.rad(180), 0), pal.Art, Enum.Material.Neon, "Wedge")
    else
        AddMicroPart(mdl, handle, Vector3.new(0.82, 0.22, 0.22), CFrame.new(0, -0.26, 0) * CFrame.Angles(0, 0, math.rad(90)), pal.Metal, Enum.Material.SmoothPlastic, "Cylinder")
        AddMicroPart(mdl, handle, Vector3.new(0.16, 0.10, 0.56), CFrame.new(0, 0.18, 0.04), pal.Metal, Enum.Material.Metal, "Brick")
        AddMicroPart(mdl, handle, Vector3.new(0.04, 1.25, 0.28), CFrame.new(0, 0.85, 0), pal.Chassis, Enum.Material.Neon, "Brick")
        AddMicroPart(mdl, handle, Vector3.new(0.04, 0.36, 0.28), CFrame.new(0, 1.62, 0) * CFrame.Angles(0, math.rad(180), 0), pal.Art, Enum.Material.Neon, "Wedge")
    end

    ActiveSkinModels[knifeTool] = mdl
end

-------------------------------------------------------------------------
-- РОЛИ И ПЕРЕХВАТ ОРУЖИЯ ШЕРИФА
-------------------------------------------------------------------------
local function GetRole(plr)
    if not plr then return "Innocent" end
    local bp = plr:FindFirstChild("Backpack")
    local ch = plr.Character
    if (bp and bp:FindFirstChild("Knife")) or (ch and ch:FindFirstChild("Knife")) then return "Murderer"
    elseif (bp and bp:FindFirstChild("Gun")) or (ch and ch:FindFirstChild("Gun")) then return "Sheriff" end
    return "Innocent"
end

local function FindByRole(r)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and GetRole(p) == r then
            local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 then return p end
        end
    end
    return nil
end

local function FindLivingSheriffGun()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local g = (plr.Character and plr.Character:FindFirstChild("Gun"))
                or (plr:FindFirstChild("Backpack") and plr.Backpack:FindFirstChild("Gun"))
            if g then return g, plr end
        end
    end
    return nil, nil
end

local function FindGunShootRemote(gunInstance)
    if not gunInstance then gunInstance = FindLivingSheriffGun() end
    if not gunInstance then return nil end
    local shootGun = gunInstance:FindFirstChild("ShootGun", true)
    if shootGun and shootGun.ClassName == "RemoteFunction" then return shootGun end
    local cb = gunInstance:FindFirstChild("CreateBeam", true)
    local rf = cb and cb:FindFirstChildOfClass("RemoteFunction")
    if rf then return rf end
    return gunInstance:FindFirstChildOfClass("RemoteFunction", true)
end

local function StealGunFromLivingSheriff()
    local myChar = LocalPlayer.Character
    local myBp = LocalPlayer:FindFirstChild("Backpack")
    if not myChar or not myBp then return end

    local gunDrop = Workspace:FindFirstChild("GunDrop", true)
    if gunDrop and gunDrop:IsA("BasePart") and myChar:FindFirstChild("HumanoidRootPart") then
        local hrp = myChar.HumanoidRootPart
        local old = hrp.CFrame
        hrp.CFrame = gunDrop.CFrame
        task.wait(0.08)
        hrp.CFrame = old
        PushSkeetLog("Подобран выпавший револьвер Шерифа!", Skeet.Accent)
        return
    end

    if myChar:FindFirstChild("Gun") or myBp:FindFirstChild("Gun") then return end

    local liveGun, sheriffPlr = FindLivingSheriffGun()
    if liveGun then
        local clonedGun = liveGun:Clone()
        clonedGun.Name = "Gun"
        clonedGun.Parent = myBp
        local hum = myChar:FindFirstChildOfClass("Humanoid")
        if hum then hum:EquipTool(clonedGun) end

        TrackConnection(clonedGun.Activated:Connect(function()
            PlayCSGOWeaponSound(true)
            local m = FindByRole("Murderer")
            local targetPos = (m and m.Character and m.Character:FindFirstChild("HumanoidRootPart") and m.Character.HumanoidRootPart.Position)
                or LocalMouse.Hit.Position
            SpawnHitVisuals(targetPos, m and m.Name or nil, 100, m and m.Character or nil)
            local realRemote = FindGunShootRemote(liveGun) or FindGunShootRemote(clonedGun)
            if realRemote then
                task.spawn(function()
                    pcall(function() realRemote:InvokeServer(1, targetPos, "AH2") end)
                end)
            end
        end))
        PushSkeetLog(string.format("Клонирован револьвер живого Шерифа (%s)!", sheriffPlr.Name), Skeet.Accent)
    end
end

local function RemoteFireLivingSheriffGun(customTargetPos)
    local liveGun = FindLivingSheriffGun()
    if not liveGun then
        local myChar = LocalPlayer.Character
        liveGun = myChar and myChar:FindFirstChild("Gun")
    end
    local remote = FindGunShootRemote(liveGun)
    if remote then
        local m = FindByRole("Murderer")
        local targetPos = customTargetPos
            or (m and m.Character and m.Character:FindFirstChild("HumanoidRootPart") and (m.Character.HumanoidRootPart.Position + m.Character.HumanoidRootPart.Velocity * 0.13))
            or LocalMouse.Hit.Position
        if m then LastAttackData = {Player = m, Time = tick()} end
        PlayCSGOWeaponSound(true)
        task.spawn(function()
            pcall(function() remote:InvokeServer(1, targetPos, "AH2") end)
        end)
        return true
    end
    return false
end

-------------------------------------------------------------------------
-- КАСТОМНЫЙ ПРИЦЕЛ СКИТА И 2D РАДАР
-------------------------------------------------------------------------
local ScopeHolder = Instance.new("Frame", ScreenGui)
ScopeHolder.Name = "GS_CustomScope"
ScopeHolder.Size = UDim2.new(1, 0, 1, 0)
ScopeHolder.BackgroundTransparency = 1
ScopeHolder.Active = false
ScopeHolder.Visible = false

local ScopeTop = Instance.new("Frame", ScopeHolder)
ScopeTop.BorderSizePixel = 0
ScopeTop.BackgroundColor3 = Color3.new(1, 1, 1)
local GradTop = Instance.new("UIGradient", ScopeTop)
GradTop.Rotation = -90
GradTop.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})

local ScopeBot = Instance.new("Frame", ScopeHolder)
ScopeBot.BorderSizePixel = 0
ScopeBot.BackgroundColor3 = Color3.new(1, 1, 1)
local GradBot = Instance.new("UIGradient", ScopeBot)
GradBot.Rotation = 90
GradBot.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})

local ScopeLeft = Instance.new("Frame", ScopeHolder)
ScopeLeft.BorderSizePixel = 0
ScopeLeft.BackgroundColor3 = Color3.new(1, 1, 1)
local GradLeft = Instance.new("UIGradient", ScopeLeft)
GradLeft.Rotation = 180
GradLeft.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})

local ScopeRight = Instance.new("Frame", ScopeHolder)
ScopeRight.BorderSizePixel = 0
ScopeRight.BackgroundColor3 = Color3.new(1, 1, 1)
local GradRight = Instance.new("UIGradient", ScopeRight)
GradRight.Rotation = 0
GradRight.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})

local ScopeDot = Instance.new("Frame", ScopeHolder)
ScopeDot.BorderSizePixel = 0
ScopeDot.BackgroundColor3 = Skeet.Accent

local RadarFrame = Instance.new("Frame", ScreenGui)
RadarFrame.Size = UDim2.new(0, 136, 0, 136)
RadarFrame.Position = UDim2.new(0, 14, 0, 195)
RadarFrame.BackgroundColor3 = Skeet.MainBg
RadarFrame.BorderColor3 = Skeet.GroupBorder
RadarFrame.BorderSizePixel = 1
RadarFrame.ClipsDescendants = true

local RadarTopLine = Instance.new("Frame", RadarFrame)
RadarTopLine.Size = UDim2.new(1, 0, 0, 2)
RadarTopLine.BackgroundColor3 = Skeet.Accent
RadarTopLine.BorderSizePixel = 0

local RadarCrossH = Instance.new("Frame", RadarFrame)
RadarCrossH.Size = UDim2.new(1, 0, 0, 1)
RadarCrossH.Position = UDim2.new(0, 0, 0.5, 0)
RadarCrossH.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
RadarCrossH.BorderSizePixel = 0

local RadarCrossV = Instance.new("Frame", RadarFrame)
RadarCrossV.Size = UDim2.new(0, 1, 1, 0)
RadarCrossV.Position = UDim2.new(0.5, 0, 0, 0)
RadarCrossV.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
RadarCrossV.BorderSizePixel = 0

local RadarCenterDot = Instance.new("Frame", RadarFrame)
RadarCenterDot.Size = UDim2.new(0, 4, 0, 4)
RadarCenterDot.Position = UDim2.new(0.5, -2, 0.5, -2)
RadarCenterDot.BackgroundColor3 = Color3.new(1, 1, 1)
RadarCenterDot.BorderSizePixel = 0

local RadarDots = {}

local TargetHudFrame = Instance.new("Frame", ScreenGui)
TargetHudFrame.Size = UDim2.new(0, 220, 0, 54)
TargetHudFrame.Position = UDim2.new(0.5, -110, 0.64, 0)
TargetHudFrame.BackgroundColor3 = Skeet.MainBg
TargetHudFrame.BorderColor3 = Skeet.GroupBorder
TargetHudFrame.BorderSizePixel = 1
TargetHudFrame.Visible = false

local thTop = Instance.new("Frame", TargetHudFrame)
thTop.Size = UDim2.new(1, 0, 0, 2)
thTop.BackgroundColor3 = Skeet.Accent
thTop.BorderSizePixel = 0

local thName = Instance.new("TextLabel", TargetHudFrame)
thName.Size = UDim2.new(1, -12, 0, 18)
thName.Position = UDim2.new(0, 6, 0, 4)
thName.BackgroundTransparency = 1
thName.Font = Enum.Font.Code
thName.TextSize = 12
thName.TextColor3 = Skeet.TextActive
thName.TextXAlignment = Enum.TextXAlignment.Left
thName.Text = "Target: None"

local thInfo = Instance.new("TextLabel", TargetHudFrame)
thInfo.Size = UDim2.new(1, -12, 0, 14)
thInfo.Position = UDim2.new(0, 6, 0, 21)
thInfo.BackgroundTransparency = 1
thInfo.Font = Enum.Font.Code
thInfo.TextSize = 11
thInfo.TextColor3 = Skeet.Text
thInfo.TextXAlignment = Enum.TextXAlignment.Left
thInfo.Text = "Role: Innocent | Dist: 0m"

local thBarBg = Instance.new("Frame", TargetHudFrame)
thBarBg.Size = UDim2.new(1, -12, 0, 7)
thBarBg.Position = UDim2.new(0, 6, 0, 40)
thBarBg.BackgroundColor3 = Skeet.ControlBg
thBarBg.BorderColor3 = Skeet.ControlBorder
thBarBg.BorderSizePixel = 1

local thBarFill = Instance.new("Frame", thBarBg)
thBarFill.Size = UDim2.new(1, 0, 1, 0)
thBarFill.BackgroundColor3 = Skeet.Accent
thBarFill.BorderSizePixel = 0

-------------------------------------------------------------------------
-- ВЕКТОРНЫЕ ИКОНКИ И МЕНЮ СКИТА 1:1
-------------------------------------------------------------------------
local function DrawVectorIcon(parent, iconType)
    local Canvas = Instance.new("Frame", parent)
    Canvas.Size = UDim2.new(0, 28, 0, 28)
    Canvas.Position = UDim2.new(0.5, -14, 0.5, -14)
    Canvas.BackgroundTransparency = 1
    local Parts = {}

    local function Bar(x, y, w, h, rot, radius)
        local f = Instance.new("Frame", Canvas)
        f.Size = UDim2.new(0, w, 0, h)
        f.Position = UDim2.new(0, x, 0, y)
        f.BackgroundColor3 = Skeet.IconIdle
        f.BorderSizePixel = 0
        if rot then f.Rotation = rot end
        if radius then
            local c = Instance.new("UICorner", f)
            c.CornerRadius = UDim.new(0, radius)
        end
        table.insert(Parts, f)
        return f
    end

    local function Ring(x, y, size, thick)
        local f = Instance.new("Frame", Canvas)
        f.Size = UDim2.new(0, size, 0, size)
        f.Position = UDim2.new(0, x, 0, y)
        f.BackgroundTransparency = 1
        local c = Instance.new("UICorner", f)
        c.CornerRadius = UDim.new(1, 0)
        local s = Instance.new("UIStroke", f)
        s.Color = Skeet.IconIdle
        s.Thickness = thick or 2
        table.insert(Parts, s)
        return f
    end

    if iconType == "Rage" then
        Bar(5, 6, 12, 14, 0, 5); Bar(7, 17, 7, 6, 0, 1); Bar(9, 10, 3, 2, 0); Bar(19, 10, 7, 2, 0); Bar(22, 7, 2, 8, 0)
    elseif iconType == "AntiAim" then
        Ring(2, 2, 24, 2.2); Bar(10, 7, 8, 9, 0, 4); Bar(9, 16, 10, 5, 0, 2); Bar(3, 13, 22, 2, -45)
    elseif iconType == "Legit" then
        Ring(3, 3, 22, 2); Bar(13, 0, 2, 8, 0); Bar(13, 20, 2, 8, 0); Bar(0, 13, 8, 2, 0); Bar(20, 13, 8, 2, 0); Bar(13, 13, 2, 2, 0)
    elseif iconType == "Visuals" then
        Ring(6, 6, 16, 2); Bar(14, 7, 7, 14, 0, 6); Bar(13, 1, 2, 3, 0); Bar(13, 24, 2, 3, 0); Bar(1, 13, 3, 2, 0); Bar(24, 13, 3, 2, 0)
    elseif iconType == "Misc" then
        Ring(3, 3, 14, 2.2); Bar(9, 0, 2, 4, 0); Bar(9, 16, 2, 4, 0); Bar(0, 9, 4, 2, 0); Bar(16, 9, 4, 2, 0); Ring(14, 14, 11, 2)
    elseif iconType == "Murderer" then
        Ring(3, 17, 7, 2); Bar(8, 12, 7, 4, -35, 1); Bar(13, 5, 12, 3, -50, 1); Bar(17, 4, 7, 2, -25, 1)
    elseif iconType == "Players" then
        Bar(9, 4, 10, 10, 0, 5); Bar(4, 16, 20, 9, 0, 4)
    elseif iconType == "Config" then
        Ring(3, 3, 22, 2); Bar(8, 3, 12, 7, 0, 1); Bar(7, 15, 14, 9, 0, 1)
    end

    return function(active)
        local col = active and Skeet.IconActive or Skeet.IconIdle
        for _, p in ipairs(Parts) do
            if p:IsA("UIStroke") then p.Color = col else p.BackgroundColor3 = col end
        end
    end
end

local OuterWindow = Instance.new("Frame", ScreenGui)
OuterWindow.Size = UDim2.new(0, 660, 0, 560)
OuterWindow.Position = UDim2.new(0.5, -330, 0.5, -280)
OuterWindow.BackgroundColor3 = Skeet.OuterBorder
OuterWindow.BorderSizePixel = 0
OuterWindow.Active = true
OuterWindow.Draggable = true

local MidBorder = Instance.new("Frame", OuterWindow)
MidBorder.Size = UDim2.new(1, -4, 1, -4)
MidBorder.Position = UDim2.new(0, 2, 0, 2)
MidBorder.BackgroundColor3 = Skeet.InnerBorder
MidBorder.BorderSizePixel = 0

local InnerWindow = Instance.new("Frame", MidBorder)
InnerWindow.Size = UDim2.new(1, -2, 1, -2)
InnerWindow.Position = UDim2.new(0, 1, 0, 1)
InnerWindow.BackgroundColor3 = Skeet.MainBg
InnerWindow.BorderSizePixel = 0

local RainbowBar = Instance.new("Frame", InnerWindow)
RainbowBar.Size = UDim2.new(1, 0, 0, 2)
RainbowBar.BackgroundColor3 = Color3.new(1, 1, 1)
RainbowBar.BorderSizePixel = 0
local RainbowGrad = Instance.new("UIGradient", RainbowBar)
RainbowGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(55, 175, 225)),
    ColorSequenceKeypoint.new(0.50, Color3.fromRGB(205, 70, 185)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(220, 225, 55))
})

local Sidebar = Instance.new("Frame", InnerWindow)
Sidebar.Size = UDim2.new(0, 64, 1, -2)
Sidebar.Position = UDim2.new(0, 0, 0, 2)
Sidebar.BackgroundColor3 = Skeet.SidebarBg
Sidebar.BorderSizePixel = 0

local SidebarDivider = Instance.new("Frame", Sidebar)
SidebarDivider.Size = UDim2.new(0, 1, 1, 0)
SidebarDivider.Position = UDim2.new(1, -1, 0, 0)
SidebarDivider.BackgroundColor3 = Skeet.GroupBorder
SidebarDivider.BorderSizePixel = 0

local PagesArea = Instance.new("Frame", InnerWindow)
PagesArea.Size = UDim2.new(1, -80, 1, -20)
PagesArea.Position = UDim2.new(0, 72, 0, 12)
PagesArea.BackgroundTransparency = 1

local Tabs = {}
local FirstTab = true

local function CreateSkeetTab(iconName)
    local idx = #Tabs
    local Btn = Instance.new("TextButton", Sidebar)
    Btn.Size = UDim2.new(1, -1, 0, 56)
    Btn.Position = UDim2.new(0, 0, 0, 8 + idx * 58)
    Btn.BackgroundColor3 = FirstTab and Skeet.MainBg or Skeet.SidebarBg
    Btn.BorderSizePixel = 0
    Btn.AutoButtonColor = false
    Btn.Text = ""

    local TopSelLine = Instance.new("Frame", Btn)
    TopSelLine.Size = UDim2.new(1, 0, 0, 1)
    TopSelLine.BackgroundColor3 = Skeet.GroupBorder
    TopSelLine.BorderSizePixel = 0
    TopSelLine.Visible = FirstTab

    local BotSelLine = Instance.new("Frame", Btn)
    BotSelLine.Size = UDim2.new(1, 0, 0, 1)
    BotSelLine.Position = UDim2.new(0, 0, 1, -1)
    BotSelLine.BackgroundColor3 = Skeet.GroupBorder
    BotSelLine.BorderSizePixel = 0
    BotSelLine.Visible = FirstTab

    local setIconActive = DrawVectorIcon(Btn, iconName)
    setIconActive(FirstTab)

    local Page = Instance.new("Frame", PagesArea)
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.BackgroundTransparency = 1
    Page.Visible = FirstTab

    local LeftCol = Instance.new("ScrollingFrame", Page)
    LeftCol.Size = UDim2.new(0.485, 0, 1, 0)
    LeftCol.BackgroundTransparency = 1
    LeftCol.BorderSizePixel = 0
    LeftCol.ScrollBarThickness = 0
    LeftCol.AutomaticCanvasSize = Enum.AutomaticSize.Y
    LeftCol.CanvasSize = UDim2.new(0, 0, 0, 0)
    local lList = Instance.new("UIListLayout", LeftCol)
    lList.Padding = UDim.new(0, 12)

    local RightCol = Instance.new("ScrollingFrame", Page)
    RightCol.Size = UDim2.new(0.485, 0, 1, 0)
    RightCol.Position = UDim2.new(0.515, 0, 0, 0)
    RightCol.BackgroundTransparency = 1
    RightCol.BorderSizePixel = 0
    RightCol.ScrollBarThickness = 0
    RightCol.AutomaticCanvasSize = Enum.AutomaticSize.Y
    RightCol.CanvasSize = UDim2.new(0, 0, 0, 0)
    local rList = Instance.new("UIListLayout", RightCol)
    rList.Padding = UDim.new(0, 12)

    TrackConnection(Btn.MouseButton1Click:Connect(function()
        for _, t in ipairs(Tabs) do
            t.Page.Visible = false
            t.Btn.BackgroundColor3 = Skeet.SidebarBg
            t.Top.Visible = false
            t.Bot.Visible = false
            t.SetIcon(false)
        end
        Page.Visible = true
        Btn.BackgroundColor3 = Skeet.MainBg
        TopSelLine.Visible = true
        BotSelLine.Visible = true
        setIconActive(true)
    end))

    FirstTab = false
    table.insert(Tabs, {Btn = Btn, Page = Page, Top = TopSelLine, Bot = BotSelLine, SetIcon = setIconActive})
    return LeftCol, RightCol
end

local function CreateGroupbox(column, title)
    local Wrapper = Instance.new("Frame", column)
    Wrapper.Size = UDim2.new(1, -2, 0, 40)
    Wrapper.BackgroundTransparency = 1
    Wrapper.AutomaticSize = Enum.AutomaticSize.Y

    local Box = Instance.new("Frame", Wrapper)
    Box.Size = UDim2.new(1, 0, 1, -6)
    Box.Position = UDim2.new(0, 0, 0, 6)
    Box.BackgroundColor3 = Skeet.GroupBg
    Box.BorderColor3 = Skeet.GroupBorder
    Box.BorderSizePixel = 1
    Box.AutomaticSize = Enum.AutomaticSize.Y

    local TitleBg = Instance.new("Frame", Wrapper)
    TitleBg.Position = UDim2.new(0, 10, 0, 0)
    TitleBg.Size = UDim2.new(0, #title * 7 + 8, 0, 13)
    TitleBg.BackgroundColor3 = Skeet.GroupBg
    TitleBg.BorderSizePixel = 0

    local TitleLbl = Instance.new("TextLabel", TitleBg)
    TitleLbl.Size = UDim2.new(1, 0, 1, 0)
    TitleLbl.BackgroundTransparency = 1
    TitleLbl.Font = Enum.Font.SourceSansBold
    TitleLbl.TextSize = 13
    TitleLbl.TextColor3 = Skeet.TextActive
    TitleLbl.Text = title

    local Content = Instance.new("Frame", Box)
    Content.Size = UDim2.new(1, -24, 0, 10)
    Content.Position = UDim2.new(0, 12, 0, 14)
    Content.BackgroundTransparency = 1
    Content.AutomaticSize = Enum.AutomaticSize.Y

    local cLayout = Instance.new("UIListLayout", Content)
    cLayout.Padding = UDim.new(0, 5)

    local Pad = Instance.new("UIPadding", Box)
    Pad.PaddingBottom = UDim.new(0, 12)

    return Content
end

local function RefreshAllUIControls()
    for _, fn in ipairs(UIUpdaters) do
        pcall(fn)
    end
end

local function AddCheckbox(group, label, key, hasBindTag)
    local Row = Instance.new("TextButton", group)
    Row.Size = UDim2.new(1, 0, 0, 16)
    Row.BackgroundTransparency = 1
    Row.Text = ""
    Row.AutoButtonColor = false

    local Box = Instance.new("Frame", Row)
    Box.Size = UDim2.new(0, 8, 0, 8)
    Box.Position = UDim2.new(0, 0, 0.5, -4)
    Box.BackgroundColor3 = Config[key] and Skeet.Accent or Skeet.ControlBg
    Box.BorderColor3 = Skeet.ControlBorder
    Box.BorderSizePixel = 1

    local Lbl = Instance.new("TextLabel", Row)
    Lbl.Size = UDim2.new(1, -40, 1, 0)
    Lbl.Position = UDim2.new(0, 18, 0, 0)
    Lbl.BackgroundTransparency = 1
    Lbl.Font = Enum.Font.SourceSans
    Lbl.TextSize = 13
    Lbl.TextColor3 = Config[key] and Skeet.TextActive or Skeet.Text
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.Text = label

    if hasBindTag then
        local BindTag = Instance.new("TextLabel", Row)
        BindTag.Size = UDim2.new(0, 22, 1, 0)
        BindTag.Position = UDim2.new(1, -22, 0, 0)
        BindTag.BackgroundTransparency = 1
        BindTag.Font = Enum.Font.Code
        BindTag.TextSize = 10
        BindTag.TextColor3 = Skeet.TextDim
        BindTag.TextXAlignment = Enum.TextXAlignment.Right
        BindTag.Text = "[-]"
    end

    local function sync()
        Box.BackgroundColor3 = Config[key] and Skeet.Accent or Skeet.ControlBg
        Lbl.TextColor3 = Config[key] and Skeet.TextActive or Skeet.Text
    end
    table.insert(UIUpdaters, sync)

    TrackConnection(Row.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        sync()
        if key == "SkinChanger" and not Config.SkinChanger then
            ClearCustomSkins()
        end
    end))
end

local function AddSlider(group, label, key, minVal, maxVal, suffix)
    suffix = suffix or ""
    local Wrap = Instance.new("Frame", group)
    Wrap.Size = UDim2.new(1, 0, 0, 28)
    Wrap.BackgroundTransparency = 1

    local Lbl = Instance.new("TextLabel", Wrap)
    Lbl.Size = UDim2.new(1, -18, 0, 14)
    Lbl.Position = UDim2.new(0, 18, 0, 0)
    Lbl.BackgroundTransparency = 1
    Lbl.Font = Enum.Font.SourceSans
    Lbl.TextSize = 13
    Lbl.TextColor3 = Skeet.Text
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.Text = label

    local Bar = Instance.new("TextButton", Wrap)
    Bar.Size = UDim2.new(1, -36, 0, 7)
    Bar.Position = UDim2.new(0, 18, 0, 16)
    Bar.BackgroundColor3 = Skeet.ControlBg
    Bar.BorderColor3 = Skeet.ControlBorder
    Bar.BorderSizePixel = 1
    Bar.AutoButtonColor = false
    Bar.Text = ""

    local Fill = Instance.new("Frame", Bar)
    local pct = math.clamp((Config[key] - minVal) / (maxVal - minVal), 0, 1)
    Fill.Size = UDim2.new(pct, 0, 1, 0)
    Fill.BackgroundColor3 = Skeet.Accent
    Fill.BorderSizePixel = 0

    local ValText = Instance.new("TextLabel", Bar)
    ValText.Size = UDim2.new(0, 50, 0, 14)
    ValText.AnchorPoint = Vector2.new(0.5, 0.5)
    ValText.Position = UDim2.new(pct, 0, 0.5, 1)
    ValText.BackgroundTransparency = 1
    ValText.Font = Enum.Font.SourceSansBold
    ValText.TextSize = 12
    ValText.TextColor3 = Skeet.TextActive
    ValText.TextStrokeTransparency = 0
    ValText.Text = tostring(Config[key]) .. suffix

    local function sync()
        local r = math.clamp((Config[key] - minVal) / (maxVal - minVal), 0, 1)
        Fill.Size = UDim2.new(r, 0, 1, 0)
        ValText.Position = UDim2.new(r, 0, 0.5, 1)
        ValText.Text = tostring(Config[key]) .. suffix
    end
    table.insert(UIUpdaters, sync)

    local dragging = false
    local function update(input)
        local rel = math.clamp((input.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
        local val = math.floor(minVal + (maxVal - minVal) * rel)
        Config[key] = val
        sync()
    end

    TrackConnection(Bar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; update(inp) end
    end))
    TrackConnection(UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))
    TrackConnection(UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then update(inp) end
    end))
end

local function AddDropdown(group, label, key, options)
    local Wrap = Instance.new("Frame", group)
    Wrap.Size = UDim2.new(1, 0, 0, 36)
    Wrap.BackgroundTransparency = 1

    local Lbl = Instance.new("TextLabel", Wrap)
    Lbl.Size = UDim2.new(1, -18, 0, 14)
    Lbl.Position = UDim2.new(0, 18, 0, 0)
    Lbl.BackgroundTransparency = 1
    Lbl.Font = Enum.Font.SourceSans
    Lbl.TextSize = 13
    Lbl.TextColor3 = Skeet.Text
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.Text = label

    local DropBtn = Instance.new("TextButton", Wrap)
    DropBtn.Size = UDim2.new(1, -36, 0, 18)
    DropBtn.Position = UDim2.new(0, 18, 0, 16)
    DropBtn.BackgroundColor3 = Skeet.ControlBg
    DropBtn.BorderColor3 = Skeet.ControlBorder
    DropBtn.BorderSizePixel = 1
    DropBtn.AutoButtonColor = false
    DropBtn.Text = ""

    local ValLbl = Instance.new("TextLabel", DropBtn)
    ValLbl.Size = UDim2.new(1, -20, 1, 0)
    ValLbl.Position = UDim2.new(0, 6, 0, 0)
    ValLbl.BackgroundTransparency = 1
    ValLbl.Font = Enum.Font.SourceSans
    ValLbl.TextSize = 13
    ValLbl.TextColor3 = Skeet.Text
    ValLbl.TextXAlignment = Enum.TextXAlignment.Left
    ValLbl.Text = tostring(Config[key])

    local Arrow = Instance.new("TextLabel", DropBtn)
    Arrow.Size = UDim2.new(0, 14, 1, 0)
    Arrow.Position = UDim2.new(1, -14, 0, 0)
    Arrow.BackgroundTransparency = 1
    Arrow.Font = Enum.Font.SourceSansBold
    Arrow.TextSize = 10
    Arrow.TextColor3 = Skeet.TextDim
    Arrow.Text = "v"

    local function sync()
        ValLbl.Text = tostring(Config[key])
    end
    table.insert(UIUpdaters, sync)

    TrackConnection(DropBtn.MouseButton1Click:Connect(function()
        local idx = table.find(options, Config[key]) or 1
        idx = idx % #options + 1
        Config[key] = options[idx]
        sync()
        if string.find(key, "Skin") then ClearCustomSkins() end
    end))
end

local function AddButton(group, label, callback, customTextColor)
    local Wrap = Instance.new("Frame", group)
    Wrap.Size = UDim2.new(1, 0, 0, 22)
    Wrap.BackgroundTransparency = 1

    local Btn = Instance.new("TextButton", Wrap)
    Btn.Size = UDim2.new(1, -36, 0, 20)
    Btn.Position = UDim2.new(0, 18, 0, 1)
    Btn.BackgroundColor3 = Skeet.ControlBg
    Btn.BorderColor3 = Skeet.ControlBorder
    Btn.BorderSizePixel = 1
    Btn.Font = Enum.Font.SourceSansBold
    Btn.TextSize = 13
    Btn.TextColor3 = customTextColor or Skeet.TextActive
    Btn.Text = label
    TrackConnection(Btn.MouseButton1Click:Connect(callback))
end

-------------------------------------------------------------------------
-- СБОРКА ВСЕХ 8 ВКЛАДОК SKEET.CC
-------------------------------------------------------------------------
local R_L, R_R = CreateSkeetTab("Rage")
local AA_L, AA_R = CreateSkeetTab("AntiAim")
local LG_L, LG_R = CreateSkeetTab("Legit")
local VS_L, VS_R = CreateSkeetTab("Visuals")
local MS_L, MS_R = CreateSkeetTab("Misc")
local MD_L, MD_R = CreateSkeetTab("Murderer")
local PL_L, PL_R = CreateSkeetTab("Players")
local CF_L, CF_R = CreateSkeetTab("Config")

-- ВКЛАДКА 1: RAGEBOT & SILENT AIM
local gAimbot = CreateGroupbox(R_L, "Aimbot (Stack-Safe MM2 Hook)")
AddCheckbox(gAimbot, "Enabled (Silent Aim)", "SilentAim", true)
AddDropdown(gAimbot, "Silent hook method", "SilentAimMethod", {"Dual (Remote + Mouse)", "Remote Only", "Mouse.Hit Only"})
AddCheckbox(gAimbot, "Fix Sheriff low bullet (GuiInset Fix)", "FixBulletDrop", false)
AddDropdown(gAimbot, "Target role priority", "TargetRolePriority", {"Smart (Role-Based)", "Any Closest", "Murderer Only"})
AddDropdown(gAimbot, "Target hitbox", "HitPart", {"HumanoidRootPart", "Head", "UpperTorso", "LowerTorso"})
AddCheckbox(gAimbot, "Automatic fire (Sheriff)", "AutoFire", true)
AddCheckbox(gAimbot, "Automatic penetration (Wallbang)", "Wallbang", false)
AddSlider(gAimbot, "Minimum hit chance", "HitChance", 1, 100, "%")
AddSlider(gAimbot, "Velocity prediction", "Prediction", 0, 35, "ms")
AddSlider(gAimbot, "Maximum FOV", "FOV", 20, 500, "px")
AddCheckbox(gAimbot, "Log hits & misses to screen", "LogMisses", false)

local gSheriffGun = CreateGroupbox(R_R, "Living Sheriff Gun Stealer")
AddButton(gSheriffGun, "STEAL / EQUIP SHERIFF GUN NOW", StealGunFromLivingSheriff, Skeet.Accent)
AddButton(gSheriffGun, "REMOTE SHOOT MURDERER [Key G]", function()
    RemoteFireLivingSheriffGun()
end, Skeet.Cyan)
AddCheckbox(gSheriffGun, "Auto-steal Gun while Sheriff alive", "AutoStealSheriffGun", false)
AddCheckbox(gSheriffGun, "Remote hijack shoot on [G] key", "RemoteShootFromSheriff", true)
AddCheckbox(gSheriffGun, "Break living Sheriff's Gun (Jam Cooldown)", "BreakSheriffGun", false)

local gOther = CreateGroupbox(R_R, "Other Rage")
AddCheckbox(gOther, "Display FOV circle", "ShowFOV", false)
AddCheckbox(gOther, "Target snapline (Locked Target)", "TargetLine", false)
AddCheckbox(gOther, "Quick stop", "QuickStop", true)
AddCheckbox(gOther, "Quick peek assist [E]", "QuickPeek", true)
AddCheckbox(gOther, "Double tap", "DoubleTap", true)

-- ВКЛАДКА 2: ИСПРАВЛЕННЫЕ ANTI-AIM И АНТИ-ЧИТЕР ДЕСИНК
local gAA = CreateGroupbox(AA_L, "Anti-aimbot angles (Fixed)")
AddCheckbox(gAA, "Enabled", "AA_Enabled", true)
AddCheckbox(gAA, "Auto-disable on ladders (Climb Fix)", "AA_LadderBypass", false)
AddDropdown(gAA, "Pitch (Head & Spine)", "AA_Pitch", {"Down", "Up", "Zero", "Jitter", "Flick Up", "None"})
AddDropdown(gAA, "Yaw base", "AA_YawBase", {"Local view", "At targets"})
AddDropdown(gAA, "Yaw mode", "AA_Yaw", {"Spinbot", "180", "Jitter", "Crosshair"})
AddDropdown(gAA, "Yaw jitter", "AA_YawJitter", {"Center", "Offset", "Random", "3-Way", "Off"})
AddSlider(gAA, "Yaw jitter angle", "AA_JitterRange", -180, 180, "°")
AddSlider(gAA, "Spinbot speed", "AA_SpinSpeed", 5, 120, "°")
AddDropdown(gAA, "Body yaw (Torso Twist)", "AA_BodyYaw", {"Opposite", "Static", "Jitter", "Off"})
AddSlider(gAA, "Roll lean angle (Body Tilt)", "AA_RollLean", -45, 45, "°")
AddCheckbox(gAA, "Manual AA binds [Z / X / C]", "AA_ManualKeys", true)
AddCheckbox(gAA, "Show Real / Fake AA arrows", "AA_ShowArrows", false)
AddCheckbox(gAA, "Edge freestanding", "AA_Freestanding", true)
AddCheckbox(gAA, "Air defensive flick", "AA_DefensiveAir", false)

local gFL = CreateGroupbox(AA_R, "Anti-Cheater Desync (Anti-Silent)")
AddCheckbox(gFL, "Enable Anti-Cheater Desync", "Desync_Enabled", true)
AddDropdown(gFL, "Desync architecture", "Desync_Mode", {"Anti-Silent (CFrame + Vel)", "Velocity Breaker", "Underground Dodge", "Random Teleport"})
AddDropdown(gFL, "Server hitbox side", "Desync_Side", {"Jitter", "Left", "Right", "Behind", "Orbit"})
AddSlider(gFL, "Server hitbox offset", "Desync_Distance", 3, 14, "st")
AddDropdown(gFL, "Velocity anti-prediction", "Desync_VelocityPattern", {"Inverse Prediction", "Zero Velocity", "NaN/Inf Breaker", "Chaotic Jitter"})
AddSlider(gFL, "Velocity spoof power", "Desync_Power", 50, 800, "")
AddCheckbox(gFL, "3D Clone Ghost Chams (Server Pos)", "Desync_ShowGhost", false)
AddCheckbox(gFL, "Smooth Fake lag (Network Sleep)", "FakeLag", true)
AddSlider(gFL, "Fake lag limit", "FakeLagLimit", 1, 12, "t")
AddCheckbox(gFL, "Infinite duck / Fake crouch", "FakeDuck", true)

-- ВКЛАДКА 3: СКИНЧЕНДЖЕР И LEGITBOT
local gSkins = CreateGroupbox(LG_L, "1:1 CS:GO 3D Skinchanger")
AddCheckbox(gSkins, "Enable 1:1 CS:GO Skinchanger", "SkinChanger", false)
AddDropdown(gSkins, "Gun model (Replaces Revolver)", "GunSkinModel", {"AWP Sniper", "SSG-08 Scout", "Desert Eagle"})
AddDropdown(gSkins, "Gun skin finish", "GunSkinFinish", {"Dragon Lore", "Asiimov", "Fade", "Gungnir", "Printstream", "Redline"})
AddDropdown(gSkins, "Knife model (Replaces Knife)", "KnifeSkinModel", {"Karambit", "Butterfly Knife", "M9 Bayonet"})
AddDropdown(gSkins, "Knife skin finish", "KnifeSkinFinish", {"Doppler Ruby", "Sapphire", "Emerald", "Fade", "Case Hardened Blue Gem", "Lore"})
AddCheckbox(gSkins, "Knife inspect spin [Key F]", "KnifeInspectSpin", true)
AddCheckbox(gSkins, "CS:GO AWP & Knife sounds", "CSGOSounds", false)
AddButton(gSkins, "Rebuild 1:1 Skins Now", ClearCustomSkins, Skeet.Accent)

local gLegitAim = CreateGroupbox(LG_R, "Legit Aimbot, Trigger & Backtrack")
AddCheckbox(gLegitAim, "Enable Smooth Camera Aimbot", "LegitAim", true)
AddDropdown(gLegitAim, "Legit aim activation", "LegitAimKey", {"MouseButton2 (RMB)", "Always On", "Key E"})
AddSlider(gLegitAim, "Camera smoothness", "LegitSmooth", 2, 50, "x")
AddSlider(gLegitAim, "Legit FOV radius", "LegitFOV", 20, 250, "px")
AddCheckbox(gLegitAim, "Draw Legit FOV circle", "ShowLegitFOV", false)
AddCheckbox(gLegitAim, "Visible check", "LegitVisibleOnly", false)
AddCheckbox(gLegitAim, "Legit Triggerbot", "LegitTriggerbot", true)
AddSlider(gLegitAim, "Triggerbot delay", "TriggerbotDelay", 0, 250, "ms")
AddCheckbox(gLegitAim, "Enable Position Backtrack", "LegitBacktrack", false)
AddSlider(gLegitAim, "Backtrack window", "BacktrackMS", 50, 400, "ms")
AddCheckbox(gLegitAim, "Legit Hitbox Expander", "HitboxExpander", false)
AddSlider(gLegitAim, "Expanded hitbox size", "HitboxSize", 3, 20, "st")

-- ВКЛАДКА 4: ДОРОГИЕ ВИЗУАЛЫ (PRO SKEET ESP)
local gPlayerESP = CreateGroupbox(VS_L, "Player ESP (Pro Skeet)")
AddCheckbox(gPlayerESP, "Enabled", "ESP_Enabled", false)
AddCheckbox(gPlayerESP, "Bounding box", "ESP_Box", false)
AddDropdown(gPlayerESP, "Box style", "ESP_BoxStyle", {"Corner", "Full"})
AddCheckbox(gPlayerESP, "Dark translucent box fill", "ESP_BoxFill", false)
AddCheckbox(gPlayerESP, "Health bar + HP text", "ESP_HealthBar", false)
AddCheckbox(gPlayerESP, "Name", "ESP_Name", false)
AddCheckbox(gPlayerESP, "Role & Weapon flags", "ESP_Flags", false)
AddCheckbox(gPlayerESP, "Distance", "ESP_Distance", false)
AddCheckbox(gPlayerESP, "Skeleton (Bone ESP)", "ESP_Skeleton", false)
AddCheckbox(gPlayerESP, "Out of FOV arrows", "ESP_OOFArrows", false)
AddSlider(gPlayerESP, "OOF arrow radius", "ESP_OOFRadius", 60, 320, "px")
AddCheckbox(gPlayerESP, "Colored models (Chams)", "Chams", false)
AddSlider(gPlayerESP, "Chams transparency", "ChamsAlpha", 0, 95, "%")

local gTacticalVis = CreateGroupbox(VS_L, "Radar & Tactical Overlays")
AddCheckbox(gTacticalVis, "2D Minimap Radar", "Radar2D", false)
AddSlider(gTacticalVis, "Radar zoom scale", "RadarZoom", 6, 40, "x")
AddCheckbox(gTacticalVis, "Target HUD card", "TargetHUD", false)
AddCheckbox(gTacticalVis, "Murderer 3D danger ring", "MurdererDangerRing", false)
AddCheckbox(gTacticalVis, "3D Floating damage numbers", "FloatingDamage", false)
AddCheckbox(gTacticalVis, "3D Floating Head Halo", "HaloRing", false)
AddCheckbox(gTacticalVis, "3D China Hat", "ChinaHat", false)
AddCheckbox(gTacticalVis, "3D Jump & landing circles", "JumpCircles", false)

local gScope = CreateGroupbox(VS_R, "Custom Scope (Pixel-Perfect)")
AddCheckbox(gScope, "Enable Custom Scope (Skeet)", "CustomScope", true)
AddDropdown(gScope, "Scope alignment", "ScopeAlignMode", {"Crosshair / Mouse", "Screen Center"})
AddDropdown(gScope, "Scope style", "ScopeMode", {"Gradient Cross", "Full Crosshair", "Dot Only"})
AddDropdown(gScope, "Scope color", "ScopeColorMode", {"Skeet Green", "Cyan", "Purple", "Rainbow"})
AddSlider(gScope, "Scope line length", "ScopeLength", 25, 260, "px")
AddSlider(gScope, "Scope center gap", "ScopeGap", 0, 65, "px")
AddSlider(gScope, "Scope thickness", "ScopeThickness", 1, 4, "px")
AddCheckbox(gScope, "Dynamic velocity gap (Spread)", "ScopeDynamicSpread", false)
AddCheckbox(gScope, "Center dot", "ScopeCenterDot", false)
AddCheckbox(gScope, "RMB Scope Zoom [RightClick]", "ScopeZoomRMB", true)
AddSlider(gScope, "Scope Zoom FOV", "ScopeZoomFOV", 20, 75, "°")

local gWorldESP = CreateGroupbox(VS_R, "World & Hit Effects")
AddCheckbox(gWorldESP, "Dropped gun ESP", "ESP_GunDrop", false)
AddCheckbox(gWorldESP, "Coin container ESP", "ESP_Coins", false)
AddCheckbox(gWorldESP, "Hit chams (On-shot skeleton)", "HitChams", false)
AddCheckbox(gWorldESP, "3D Bullet impact boxes", "BulletImpacts", false)
AddCheckbox(gWorldESP, "Dual-layer laser bullet tracers", "BulletTracers", false)
AddCheckbox(gWorldESP, "Hit marker & Sound", "HitSound", false)
AddDropdown(gWorldESP, "Sound type", "SoundType", {"Skeet", "Neverlose", "Rust", "Bell"})
AddCheckbox(gWorldESP, "World ambience tint", "WorldAmbience", false)
AddDropdown(gWorldESP, "Ambience palette", "WorldTintMode", {"Midnight Purple", "Skeet Green", "Cyber Cyan", "Crimson"})
AddSlider(gWorldESP, "Color saturation boost", "ColorSaturation", 0, 100, "%")
AddCheckbox(gWorldESP, "Force thirdperson zoom", "ThirdPerson", true)
AddSlider(gWorldESP, "Thirdperson distance", "ThirdPersonDist", 8, 45, "st")
AddCheckbox(gWorldESP, "Override FOV", "CustomFOV", false)
AddSlider(gWorldESP, "Camera FOV", "CameraFOV", 60, 120, "°")
AddCheckbox(gWorldESP, "Aspect ratio (4:3 Stretch)", "AspectRatio", false)
AddSlider(gWorldESP, "Aspect ratio width", "AspectRatioVal", 55, 100, "%")
AddCheckbox(gWorldESP, "Fullbright", "Fullbright", false)
AddCheckbox(gWorldESP, "Night mode", "NightMode", false)

-- ВКЛАДКА 5: ДВИЖЕНИЕ И MM2 УТИЛИТЫ
local gMove = CreateGroupbox(MS_L, "Movement & Strafes")
AddCheckbox(gMove, "Enable Speed", "Speed_Enabled", true)
AddDropdown(gMove, "Speed mode", "SpeedMode", {"WalkSpeed", "CFrame Bypass", "Velocity Impulse", "Pulse Boost"})
AddSlider(gMove, "Speed factor", "SpeedVal", 16, 110, "")
AddCheckbox(gMove, "Bunny hop", "BHop", false)
AddCheckbox(gMove, "Air autostrafe (WASD Directional)", "AirStrafe", false)
AddSlider(gMove, "Air strafe velocity", "StrafeSpeed", 18, 90, "")
AddCheckbox(gMove, "Circle strafe [Hold C]", "CircleStrafe", true)
AddSlider(gMove, "Circle strafe radius", "CircleRadius", 5, 22, "st")
AddCheckbox(gMove, "Jump at edge (EdgeJump)", "EdgeJump", true)
AddCheckbox(gMove, "Infinite jump", "InfiniteJump", false)
AddCheckbox(gMove, "Modify JumpPower", "HighJump", false)
AddSlider(gMove, "Jump power", "JumpPower", 50, 160, "")
AddCheckbox(gMove, "Noclip (Phase walls)", "Noclip", true)

local gMM2Util = CreateGroupbox(MS_R, "MM2 Special Utilities")
AddCheckbox(gMM2Util, "Auto grab dropped gun", "AutoGrabGun", false)
AddCheckbox(gMM2Util, "Coin magnet (Pull nearby coins)", "CoinMagnet", false)
AddSlider(gMM2Util, "Coin magnet radius", "CoinMagnetDist", 8, 35, "st")
AddCheckbox(gMM2Util, "Auto coin farm (Legit glide)", "AutoCoinFarm", false)
AddCheckbox(gMM2Util, "Auto-dodge Murderer (Evasion dash)", "AutoDodgeMurderer", false)
AddSlider(gMM2Util, "Auto-dodge trigger range", "DodgeDistance", 8, 22, "st")
AddCheckbox(gMM2Util, "Wall X-Ray (See through map)", "XRayWalls", true)
AddSlider(gMM2Util, "X-Ray wall transparency", "XRayTrans", 30, 90, "%")
AddCheckbox(gMM2Util, "Anti-AFK (No idle disconnect)", "AntiAFK", false)

AddButton(gMM2Util, "Expose Roles in Chat", function()
    local m = FindByRole("Murderer")
    local s = FindByRole("Sheriff")
    local msg = string.format("[MM2] Murderer: %s | Sheriff: %s", m and m.Name or "None", s and s.Name or "None")
    PushSkeetLog(msg, Skeet.Gold)
    pcall(function()
        local tcs = game:GetService("TextChatService")
        if tcs and tcs.ChatInputBarConfiguration and tcs.ChatInputBarConfiguration.TargetTextChannel then
            tcs.ChatInputBarConfiguration.TargetTextChannel:SendAsync(msg)
        else
            local chatEvents = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
            if chatEvents and chatEvents:FindFirstChild("SayMessageRequest") then
                chatEvents.SayMessageRequest:FireServer(msg, "All")
            end
        end
    end)
end)

-- ВКЛАДКА 6: МАРДЕР
local gMurd = CreateGroupbox(MD_L, "Murderer Rage & Stab Fix")
AddCheckbox(gMurd, "Guaranteed Stab Fix (100% Hit Reg)", "GuaranteedStabFix", false)
AddCheckbox(gMurd, "Legit Knife Reach Extender", "LegitKnifeReach", false)
AddSlider(gMurd, "Knife reach distance", "KnifeReachDist", 6, 18, "st")
AddCheckbox(gMurd, "Kill all players", "KillAll", true)
AddCheckbox(gMurd, "Knife aura", "KnifeAura", true)
AddSlider(gMurd, "Knife aura radius", "AuraRange", 6, 32, "st")
AddCheckbox(gMurd, "Silent knife throw", "SilentKnifeThrow", false)
AddCheckbox(gMurd, "Auto equip knife", "AutoEquipKnife", false)
AddCheckbox(gMurd, "Fake dead (Lay prone)", "FakeDead", false)

local gMurdAct = CreateGroupbox(MD_R, "Instant Teleports")
AddButton(gMurdAct, "Instant kill Sheriff", function()
    if GetRole(LocalPlayer) ~= "Murderer" then return end
    local sh = FindByRole("Sheriff")
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if sh and sh.Character and sh.Character:FindFirstChild("HumanoidRootPart") and myRoot then
        local knife = myChar:FindFirstChild("Knife") or LocalPlayer.Backpack:FindFirstChild("Knife")
        if knife and knife.Parent == LocalPlayer.Backpack then
            myChar:FindFirstChildOfClass("Humanoid"):EquipTool(knife)
        end
        LastAttackData = {Player = sh, Time = tick()}
        sh.Character.HumanoidRootPart.CFrame = myRoot.CFrame * CFrame.new(0, 0, -2)
        if knife and knife:FindFirstChild("Stab") then knife.Stab:FireServer("Down") end
        if firetouchinterest and knife and knife:FindFirstChild("Handle") then
            pcall(firetouchinterest, knife.Handle, sh.Character.HumanoidRootPart, 0)
            pcall(firetouchinterest, knife.Handle, sh.Character.HumanoidRootPart, 1)
        end
    end
end)

AddButton(gMurdAct, "Teleport to Map", function()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v.Name == "Spawns" and v:FindFirstChildOfClass("BasePart") then
            root.CFrame = v:FindFirstChildOfClass("BasePart").CFrame + Vector3.new(0, 4, 0)
            return
        end
    end
end)

AddButton(gMurdAct, "Teleport to Lobby", function()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root then root.CFrame = CFrame.new(-108, 138, 37) end
end)

-- ВКЛАДКА 7: ИГРОКИ
local gPlrInfo = CreateGroupbox(PL_L, "Round Scanner")
local RoleStatusLbl = Instance.new("TextLabel", gPlrInfo)
RoleStatusLbl.Size = UDim2.new(1, -18, 0, 44)
RoleStatusLbl.Position = UDim2.new(0, 18, 0, 0)
RoleStatusLbl.BackgroundTransparency = 1
RoleStatusLbl.Font = Enum.Font.Code
RoleStatusLbl.TextSize = 12
RoleStatusLbl.TextColor3 = Skeet.Text
RoleStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
RoleStatusLbl.TextYAlignment = Enum.TextYAlignment.Top
RoleStatusLbl.Text = "Murderer: Scanning...\nSheriff: Scanning..."

local gPlrTp = CreateGroupbox(PL_R, "Role Teleports")
AddButton(gPlrTp, "Teleport to Murderer", function()
    local m = FindByRole("Murderer")
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if m and m.Character and m.Character:FindFirstChild("HumanoidRootPart") and root then
        root.CFrame = m.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 4)
    end
end)
AddButton(gPlrTp, "Teleport to Sheriff", function()
    local s = FindByRole("Sheriff")
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if s and s.Character and s.Character:FindFirstChild("HumanoidRootPart") and root then
        root.CFrame = s.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 4)
    end
end)

-------------------------------------------------------------------------
-- ВКЛАДКА 8: СИСТЕМА КОНФИГОВ И ПОЛНЫЙ UNHOOK
-------------------------------------------------------------------------
local ConfigFolder = "gamesense_mm2_configs"
pcall(function()
    if makefolder and isfolder and not isfolder(ConfigFolder) then
        makefolder(ConfigFolder)
    end
end)

local function GetConfigPath(slotName)
    local clean = string.gsub(slotName, "[^%w_]", "_")
    return ConfigFolder .. "/" .. clean .. ".json"
end

local gCfgSys = CreateGroupbox(CF_L, "Presets & Configs")
AddDropdown(gCfgSys, "Configuration slot", "SelectedConfigSlot", {
    "Slot 1 (Rage)",
    "Slot 2 (HvH Desync)",
    "Slot 3 (Legit Sheriff)",
    "Slot 4 (Murderer Pro)",
    "Slot 5 (Custom)"
})

local ConfigStatusLbl = Instance.new("TextLabel", gCfgSys)
ConfigStatusLbl.Size = UDim2.new(1, -18, 0, 16)
ConfigStatusLbl.Position = UDim2.new(0, 18, 0, 0)
ConfigStatusLbl.BackgroundTransparency = 1
ConfigStatusLbl.Font = Enum.Font.Code
ConfigStatusLbl.TextSize = 11
ConfigStatusLbl.TextColor3 = Skeet.Accent
ConfigStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
ConfigStatusLbl.Text = "Status: Ready"

AddButton(gCfgSys, "Save config", function()
    local slot = Config.SelectedConfigSlot
    local ok, encoded = pcall(function() return HttpService:JSONEncode(Config) end)
    if ok and encoded then
        if writefile then
            pcall(writefile, GetConfigPath(slot), encoded)
            ConfigStatusLbl.Text = "Saved: " .. slot
            PushSkeetLog("Saved config to " .. GetConfigPath(slot), Skeet.Accent)
        else
            _G.GS_SavedConfigs = _G.GS_SavedConfigs or {}
            _G.GS_SavedConfigs[slot] = encoded
            ConfigStatusLbl.Text = "Saved (Memory): " .. slot
        end
    end
end)

AddButton(gCfgSys, "Load config", function()
    local slot = Config.SelectedConfigSlot
    local raw = nil
    if readfile and isfile and isfile(GetConfigPath(slot)) then
        local ok, data = pcall(readfile, GetConfigPath(slot))
        if ok then raw = data end
    elseif _G.GS_SavedConfigs and _G.GS_SavedConfigs[slot] then
        raw = _G.GS_SavedConfigs[slot]
    end
    if raw then
        local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
        if ok and type(decoded) == "table" then
            for k, v in pairs(decoded) do
                if Config[k] ~= nil and k ~= "SelectedConfigSlot" then
                    Config[k] = v
                end
            end
            RefreshAllUIControls()
            ClearCustomSkins()
            ConfigStatusLbl.Text = "Loaded: " .. slot
            PushSkeetLog("Loaded config: " .. slot, Skeet.Accent)
        end
    else
        ConfigStatusLbl.Text = "Empty slot: " .. slot
    end
end)

AddButton(gCfgSys, "Delete config", function()
    local slot = Config.SelectedConfigSlot
    if delfile and isfile and isfile(GetConfigPath(slot)) then
        pcall(delfile, GetConfigPath(slot))
    end
    if _G.GS_SavedConfigs then _G.GS_SavedConfigs[slot] = nil end
    ConfigStatusLbl.Text = "Deleted: " .. slot
end)

AddButton(gCfgSys, "Export to clipboard", function()
    local ok, encoded = pcall(function() return HttpService:JSONEncode(Config) end)
    if ok and setclipboard then
        pcall(setclipboard, encoded)
        ConfigStatusLbl.Text = "Copied JSON to clipboard!"
    end
end)

AddButton(gCfgSys, "Reset to default", function()
    for k, v in pairs(DefaultConfigBackup) do
        Config[k] = v
    end
    RefreshAllUIControls()
    ClearCustomSkins()
    ConfigStatusLbl.Text = "Reset to defaults"
end)

local gUnload = CreateGroupbox(CF_R, "Overlay & Unhook")
AddCheckbox(gUnload, "Watermark", "Watermark", false)
AddCheckbox(gUnload, "Keybind list", "KeybindList", false)

-------------------------------------------------------------------------
-- ВОТЕРМАРКА, КЕЙБИНДЫ И СТРЕЛКИ АНТИ-АИМА
-------------------------------------------------------------------------
local Watermark = Instance.new("Frame", ScreenGui)
Watermark.Size = UDim2.new(0, 310, 0, 22)
Watermark.Position = UDim2.new(1, -322, 0, 12)
Watermark.BackgroundColor3 = Skeet.MainBg
Watermark.BorderColor3 = Skeet.GroupBorder
Watermark.BorderSizePixel = 1
local wmBar = Instance.new("Frame", Watermark)
wmBar.Size = UDim2.new(1, 0, 0, 2)
wmBar.BackgroundColor3 = Skeet.Accent
wmBar.BorderSizePixel = 0
local wmTxt = Instance.new("TextLabel", Watermark)
wmTxt.Size = UDim2.new(1, -10, 1, -2)
wmTxt.Position = UDim2.new(0, 5, 0, 2)
wmTxt.BackgroundTransparency = 1
wmTxt.Font = Enum.Font.Code
wmTxt.TextSize = 11
wmTxt.TextColor3 = Skeet.TextActive
wmTxt.Text = "gamesense | mm2 | 60 fps"

local KeybindBox = Instance.new("Frame", ScreenGui)
KeybindBox.Size = UDim2.new(0, 185, 0, 24)
KeybindBox.Position = UDim2.new(0, 14, 0.44, 0)
KeybindBox.BackgroundColor3 = Skeet.MainBg
KeybindBox.BorderColor3 = Skeet.GroupBorder
KeybindBox.BorderSizePixel = 1
KeybindBox.AutomaticSize = Enum.AutomaticSize.Y
local kbBar = Instance.new("Frame", KeybindBox)
kbBar.Size = UDim2.new(1, 0, 0, 2)
kbBar.BackgroundColor3 = Skeet.Accent
kbBar.BorderSizePixel = 0
local kbHdr = Instance.new("TextLabel", KeybindBox)
kbHdr.Size = UDim2.new(1, 0, 0, 18)
kbHdr.Position = UDim2.new(0, 0, 0, 2)
kbHdr.BackgroundTransparency = 1
kbHdr.Font = Enum.Font.Code
kbHdr.TextSize = 11
kbHdr.TextColor3 = Skeet.TextActive
kbHdr.Text = "Keybinds"
local kbBody = Instance.new("TextLabel", KeybindBox)
kbBody.Size = UDim2.new(1, -12, 0, 14)
kbBody.Position = UDim2.new(0, 6, 0, 20)
kbBody.BackgroundTransparency = 1
kbBody.Font = Enum.Font.Code
kbBody.TextSize = 11
kbBody.TextColor3 = Skeet.Text
kbBody.TextXAlignment = Enum.TextXAlignment.Left
kbBody.TextYAlignment = Enum.TextYAlignment.Top
kbBody.AutomaticSize = Enum.AutomaticSize.Y

local ArrowLeft = Instance.new("TextLabel", ScreenGui)
ArrowLeft.Size = UDim2.new(0, 30, 0, 30)
ArrowLeft.Position = UDim2.new(0.5, -55, 0.5, -15)
ArrowLeft.BackgroundTransparency = 1
ArrowLeft.Font = Enum.Font.SourceSansBold
ArrowLeft.TextSize = 24
ArrowLeft.TextColor3 = Skeet.TextDim
ArrowLeft.TextStrokeTransparency = 0.2
ArrowLeft.Text = "<"
ArrowLeft.Visible = false

local ArrowRight = Instance.new("TextLabel", ScreenGui)
ArrowRight.Size = UDim2.new(0, 30, 0, 30)
ArrowRight.Position = UDim2.new(0.5, 25, 0.5, -15)
ArrowRight.BackgroundTransparency = 1
ArrowRight.Font = Enum.Font.SourceSansBold
ArrowLeft.TextSize = 24
ArrowRight.TextColor3 = Skeet.TextDim
ArrowRight.TextStrokeTransparency = 0.2
ArrowRight.Text = ">"
ArrowRight.Visible = false

local ArrowDown = Instance.new("TextLabel", ScreenGui)
ArrowDown.Size = UDim2.new(0, 30, 0, 30)
ArrowDown.Position = UDim2.new(0.5, -15, 0.5, 25)
ArrowDown.BackgroundTransparency = 1
ArrowDown.Font = Enum.Font.SourceSansBold
ArrowDown.TextSize = 20
ArrowDown.TextColor3 = Skeet.TextDim
ArrowDown.TextStrokeTransparency = 0.2
ArrowDown.Text = "v"
ArrowDown.Visible = false

-------------------------------------------------------------------------
-- 3D ОВЕРЛЕИ И 3D CLONE GHOST
-------------------------------------------------------------------------
local HatLines = {}
local HaloLines = {}
local DangerLines = {}
local HatSegments = 24

if Drawing then
    for i = 1, HatSegments do
        local rim = TrackDrawing(Drawing.new("Line"))
        rim.Thickness = 1.5; rim.Visible = false
        local rib = TrackDrawing(Drawing.new("Line"))
        rib.Thickness = 1.1; rib.Visible = false
        table.insert(HatLines, {Rim = rim, Rib = rib})

        local hLine = TrackDrawing(Drawing.new("Line"))
        hLine.Thickness = 1.8; hLine.Visible = false
        table.insert(HaloLines, hLine)

        local dLine = TrackDrawing(Drawing.new("Line"))
        dLine.Thickness = 1.8; dLine.Visible = false
        table.insert(DangerLines, dLine)
    end
end

local GhostModel = TrackInstance(Instance.new("Model"))
GhostModel.Name = "GS_DesyncClone"
GhostModel.Parent = Workspace

local GhostParts = {}
local function RebuildGhostModel()
    GhostModel:ClearAllChildren()
    table.clear(GhostParts)
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local clone = Instance.new("Part")
            clone.Name = part.Name
            clone.Size = part.Size
            clone.Anchored = true
            clone.CanCollide = false
            clone.CanTouch = false
            clone.CanQuery = false
            clone.CastShadow = false
            clone.Material = Enum.Material.ForceField
            clone.Color = Skeet.Accent
            clone.Transparency = 1
            clone.Parent = GhostModel
            GhostParts[part.Name] = clone
        end
    end
end
if LocalPlayer.Character then task.spawn(RebuildGhostModel) end
TrackConnection(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if not Unhooked then RebuildGhostModel() end
end))

local BacktrackGhost = TrackInstance(Instance.new("Part"))
BacktrackGhost.Name = "GS_BacktrackGhost"
BacktrackGhost.Anchored = true
BacktrackGhost.CanCollide = false
BacktrackGhost.CanTouch = false
BacktrackGhost.CanQuery = false
BacktrackGhost.CastShadow = false
BacktrackGhost.Size = Vector3.new(2, 4.5, 1)
BacktrackGhost.Material = Enum.Material.ForceField
BacktrackGhost.Color = Skeet.Cyan
BacktrackGhost.Transparency = 1
BacktrackGhost.Parent = Workspace

local function SpawnJumpRing(pos)
    if Unhooked or not Config.JumpCircles then return end
    local ring = TrackInstance(Instance.new("Part"))
    ring.Anchored = true
    ring.CanCollide = false
    ring.CanTouch = false
    ring.CanQuery = false
    ring.CastShadow = false
    ring.Shape = Enum.PartType.Cylinder
    ring.Orientation = Vector3.new(0, 0, 90)
    ring.Material = Enum.Material.Neon
    ring.Color = Skeet.Accent
    ring.Size = Vector3.new(0.12, 1.5, 1.5)
    ring.Position = pos - Vector3.new(0, 2.7, 0)
    ring.Transparency = 0.25
    ring.Parent = Workspace
    task.spawn(function()
        for i = 1, 20 do
            if Unhooked or not ring.Parent then break end
            local sz = 1.5 + (i * 0.50)
            ring.Size = Vector3.new(0.10, sz, sz)
            ring.Transparency = 0.25 + (i / 20) * 0.75
            task.wait(0.025)
        end
        if ring then ring:Destroy() end
    end)
end

-------------------------------------------------------------------------
-- ПОЛНЫЙ UNHOOK
-------------------------------------------------------------------------
local mt = getrawmetatable and getrawmetatable(game)
local oldNamecall = nil
local oldIndex = nil
localMotorsModified = false

local function RestoreMotors()
    if not localMotorsModified then return end
    for motor, c0 in pairs(SavedMotorC0) do
        if motor and motor.Parent then motor.C0 = c0 end
    end
    localMotorsModified = false
end

local function RestoreXRay()
    for part, origTrans in pairs(XRayParts) do
        if part and part.Parent then
            part.LocalTransparencyModifier = origTrans
        end
    end
    table.clear(XRayParts)
end

local function FullUnhook()
    if Unhooked then return end
    Unhooked = true

    for _, c in ipairs(Connections) do
        if c and c.Connected then c:Disconnect() end
    end
    table.clear(Connections)

    if mt and setreadonly then
        pcall(function()
            setreadonly(mt, false)
            if oldNamecall then mt.__namecall = oldNamecall end
            if oldIndex then mt.__index = oldIndex end
            setreadonly(mt, true)
        end)
    end

    localMotorsModified = true
    RestoreMotors()
    RestoreXRay()
    ClearCustomSkins()

    for _, d in ipairs(DrawingObjects) do
        pcall(function() if d and d.Remove then d:Remove() end end)
    end
    table.clear(DrawingObjects)

    for _, esp in pairs(ESPObjects) do
        pcall(function()
            for _, item in pairs(esp) do
                if type(item) == "table" then
                    for _, sub in pairs(item) do
                        if sub and sub.Remove then sub:Remove() end
                    end
                elseif item and item.Remove then
                    item:Remove()
                end
            end
        end)
    end
    table.clear(ESPObjects)

    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            if p.Character:FindFirstChild("GS_Chams") then p.Character.GS_Chams:Destroy() end
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.Size = Vector3.new(2, 2, 1); hrp.Transparency = 1 end
        end
    end

    local myChar = LocalPlayer.Character
    if myChar then
        local hum = myChar:FindFirstChildOfClass("Humanoid")
        local hrp = myChar:FindFirstChild("HumanoidRootPart")
        if hum then
            hum.WalkSpeed = OriginalState.WalkSpeed
            hum.JumpPower = OriginalState.JumpPower
            hum.AutoRotate = true
            hum.CameraOffset = Vector3.zero
            hum.PlatformStand = false
        end
        if hrp then
            hrp.Anchored = false
            pcall(function()
                if sethiddenproperty then sethiddenproperty(hrp, "NetworkIsSleeping", false) end
            end)
        end
        for _, part in ipairs(myChar:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end
    end

    LocalPlayer.CameraMaxZoomDistance = OriginalState.MaxZoom
    LocalPlayer.CameraMinZoomDistance = OriginalState.MinZoom
    Lighting.Brightness = OriginalState.Brightness
    Lighting.ClockTime = OriginalState.ClockTime
    Lighting.FogEnd = OriginalState.FogEnd
    Lighting.FogStart = OriginalState.FogStart
    Lighting.FogColor = OriginalState.FogColor
    Lighting.GlobalShadows = OriginalState.GlobalShadows
    Lighting.Ambient = OriginalState.Ambient
    Lighting.OutdoorAmbient = OriginalState.OutdoorAmbient
    Camera.FieldOfView = OriginalState.CameraFOV

    for _, inst in ipairs(CreatedInstances) do
        pcall(function() if inst then inst:Destroy() end end)
    end
    table.clear(CreatedInstances)
end

AddButton(gUnload, "UNHOOK / UNLOAD [END]", FullUnhook, Skeet.Danger)

local SidebarUnhookBtn = Instance.new("TextButton", Sidebar)
SidebarUnhookBtn.Size = UDim2.new(1, -9, 0, 22)
SidebarUnhookBtn.Position = UDim2.new(0, 4, 1, -28)
SidebarUnhookBtn.BackgroundColor3 = Skeet.ControlBg
SidebarUnhookBtn.BorderColor3 = Skeet.Danger
SidebarUnhookBtn.BorderSizePixel = 1
SidebarUnhookBtn.Font = Enum.Font.Code
SidebarUnhookBtn.TextSize = 10
SidebarUnhookBtn.TextColor3 = Skeet.Danger
SidebarUnhookBtn.Text = "UNHOOK"
TrackConnection(SidebarUnhookBtn.MouseButton1Click:Connect(FullUnhook))

-------------------------------------------------------------------------
-- ТАРГЕТИНГ, БЕЗОПАСНЫЙ РЕЙКАСТ И УДАР НОЖОМ БЕЗ РЕКУРСИИ
-------------------------------------------------------------------------
local QuickPeekOrigin = nil
local QuickPeekPart = TrackInstance(Instance.new("Part"))
QuickPeekPart.Anchored = true
QuickPeekPart.CanCollide = false
QuickPeekPart.CanTouch = false
QuickPeekPart.CanQuery = false
QuickPeekPart.Shape = Enum.PartType.Cylinder
QuickPeekPart.Size = Vector3.new(0.2, 4.5, 4.5)
QuickPeekPart.Orientation = Vector3.new(0, 0, 90)
QuickPeekPart.Material = Enum.Material.Neon
QuickPeekPart.Color = Skeet.Accent
QuickPeekPart.Transparency = 1
QuickPeekPart.Parent = Workspace

local RaycastBypass = false
local CurrentTargetPart, CurrentTargetPlr, CurrentAimPos = nil, nil, nil

-- Точная детекция лестницы (проверяет только настоящее состояние Climbing или TrussPart вплотную, чтобы анти-аимы никогда не отключались возле обычных стен!)
local function IsClimbingLadder(char, hum, hrp)
    if not Config.AA_LadderBypass then return false end
    if hum:GetState() == Enum.HumanoidStateType.Climbing then return true end
    RaycastBypass = true
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char, Camera, GhostModel, QuickPeekPart, BacktrackGhost}
    local hit = Workspace:Raycast(hrp.Position, hrp.CFrame.LookVector * 2.2, params)
    RaycastBypass = false
    if hit and hit.Instance and hit.Instance:IsA("TrussPart") then
        return true
    end
    return false
end

local function IsVisible(part)
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Head") then return false end
    RaycastBypass = true
    local origin = Camera.CFrame.Position
    local dir = (part.Position - origin)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera, GhostModel, QuickPeekPart, BacktrackGhost}
    local res = Workspace:Raycast(origin, dir, params)
    RaycastBypass = false
    return (not res) or res.Instance:IsDescendantOf(part.Parent)
end

local function GetExactCrosshairWorldPoint()
    local mouseLoc = UserInputService:GetMouseLocation()
    local ray = Camera:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)
    RaycastBypass = true
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera, GhostModel, QuickPeekPart, BacktrackGhost}
    local hit = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
    RaycastBypass = false
    return hit and hit.Position or (ray.Origin + ray.Direction * 500)
end

local function GetBestTargetInRadius(fovRadius, requireVisible)
    local myRole = GetRole(LocalPlayer)
    local bestPart, bestPlr, bestPos = nil, nil, nil
    local bestDist = fovRadius
    local mousePos = UserInputService:GetMouseLocation()

    local priorityMurdererOnly = (Config.TargetRolePriority == "Murderer Only")
        or (Config.TargetRolePriority == "Smart (Role-Based)" and myRole == "Sheriff" and FindByRole("Murderer") ~= nil)

    local function checkList(ignoreRoleFilter)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                local part = plr.Character:FindFirstChild(Config.HitPart)
                    or plr.Character:FindFirstChild("HumanoidRootPart")
                    or plr.Character:FindFirstChild("Torso")
                if hum and hum.Health > 0 and part then
                    local role = GetRole(plr)
                    if ignoreRoleFilter or (not priorityMurdererOnly) or (role == "Murderer") then
                        if (not requireVisible) or IsVisible(part) then
                            local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                            if onScreen then
                                local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                                if dist < bestDist then
                                    bestDist = dist
                                    bestPart = part
                                    bestPlr = plr
                                    bestPos = part.Position
                                end
                            end
                            if Config.LegitBacktrack and BacktrackHistory[plr] then
                                for _, record in ipairs(BacktrackHistory[plr]) do
                                    local bScreen, bVis = Camera:WorldToViewportPoint(record.Pos)
                                    if bVis then
                                        local bDist = (Vector2.new(bScreen.X, bScreen.Y) - mousePos).Magnitude
                                        if bDist < bestDist then
                                            bestDist = bDist
                                            bestPart = part
                                            bestPlr = plr
                                            bestPos = record.Pos
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    checkList(false)
    if not bestPart and Config.TargetRolePriority == "Smart (Role-Based)" then
        checkList(true)
    end

    local aimPos = nil
    if bestPart then
        local baseP = bestPos or bestPart.Position
        local vel = bestPart.AssemblyLinearVelocity or bestPart.Velocity or Vector3.zero
        aimPos = baseP + (vel * (Config.Prediction / 100)) + Vector3.new(0, 0.12, 0)
    end
    return bestPart, bestPlr, aimPos
end

TrackConnection(UserInputService.InputBegan:Connect(function(inp, gp)
    if not gp then
        if inp.KeyCode == Enum.KeyCode.Insert or inp.KeyCode == Enum.KeyCode.RightShift then
            OuterWindow.Visible = not OuterWindow.Visible
        elseif inp.KeyCode == Enum.KeyCode.End then
            FullUnhook()
        elseif inp.KeyCode == Enum.KeyCode.F and Config.SkinChanger and Config.KnifeInspectSpin then
            InspectingUntil = tick() + 1.25
        elseif inp.KeyCode == Enum.KeyCode.G and Config.RemoteShootFromSheriff then
            RemoteFireLivingSheriffGun(CurrentAimPos)
        elseif inp.KeyCode == Enum.KeyCode.Space then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hum and hrp then
                if Config.InfiniteJump then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
                if Config.JumpCircles and hum.FloorMaterial ~= Enum.Material.Air then
                    SpawnJumpRing(hrp.Position)
                end
            end
        elseif inp.KeyCode == Enum.KeyCode.E and Config.QuickPeek then
            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then
                if not QuickPeekOrigin then
                    QuickPeekOrigin = root.Position
                else
                    root.CFrame = CFrame.new(QuickPeekOrigin)
                    QuickPeekOrigin = nil
                end
            end
        elseif Config.AA_Enabled and Config.AA_ManualKeys then
            if inp.KeyCode == Enum.KeyCode.Z then
                ManualDir = (ManualDir == -90) and 0 or -90
            elseif inp.KeyCode == Enum.KeyCode.X then
                ManualDir = (ManualDir == 180) and 0 or 180
            elseif inp.KeyCode == Enum.KeyCode.C and not Config.CircleStrafe then
                ManualDir = (ManualDir == 90) and 0 or 90
            end
        elseif inp.UserInputType == Enum.UserInputType.MouseButton1 and not OuterWindow.Visible then
            local myChar = LocalPlayer.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not myChar or not myRoot then return end

            -- 1. ФИКС УДАРА НОЖОМ: Игра разрешает нативный взмах ножом + мы дополнительно регистрируем TouchInterest на всех врагов в радиусе!
            local knife = myChar:FindFirstChild("Knife")
            if knife then
                PlayCSGOWeaponSound(false)
                if Config.GuaranteedStabFix then
                    if sethiddenproperty then
                        pcall(function() sethiddenproperty(myRoot, "NetworkIsSleeping", false) end)
                    end
                    local handle = knife:FindFirstChild("Handle")
                    local reach = Config.LegitKnifeReach and Config.KnifeReachDist or 7.5
                    if handle then
                        for _, plr in ipairs(Players:GetPlayers()) do
                            if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                                local tHum = plr.Character:FindFirstChildOfClass("Humanoid")
                                local tRoot = plr.Character.HumanoidRootPart
                                if tHum and tHum.Health > 0 and (tRoot.Position - myRoot.Position).Magnitude <= reach then
                                    LastAttackData = {Player = plr, Time = tick()}
                                    if firetouchinterest then
                                        pcall(firetouchinterest, handle, tRoot, 0)
                                        pcall(firetouchinterest, handle, tRoot, 1)
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- 2. ЗВУК ВЫСТРЕЛА AWP ПРИ КЛИКЕ С ПИСТОЛЕТОМ
            local gun = myChar:FindFirstChild("Gun")
            if gun then
                PlayCSGOWeaponSound(true)
            end
        end
    end
end))

-------------------------------------------------------------------------
-- ИСПРАВЛЕННЫЙ ХУК МЕТАТАБЛИЦЫ (БЕЗ self:IsA И БЕЗ ПЕРЕПОЛНЕНИЯ СТЕКА!)
-------------------------------------------------------------------------
-- КРИТИЧЕСКИЙ ФИКС: В прошлом билде внутри `__namecall` вызывался `self:IsA(...)`, что само является namecall-вызовом!
-- Это вызывало бесконечную рекурсию (C-stack overflow) и полностью блокировало стрельбу пистолета и удар ножа.
-- Теперь мы читаем свойства напрямую через `oldIndex(self, "ClassName")` и `oldIndex(self, "Name")` — 0% риска рекурсии!
if mt and setreadonly then
    oldNamecall = mt.__namecall
    oldIndex = mt.__index
    setreadonly(mt, false)

    mt.__index = newcclosure(function(self, key)
        if not Unhooked and not checkcaller() and self == LocalMouse then
            if key == "Hit" or key == "hit" then
                if Config.SilentAim and (Config.SilentAimMethod == "Dual (Remote + Mouse)" or Config.SilentAimMethod == "Mouse.Hit Only") then
                    if CurrentTargetPart and CurrentAimPos and math.random(1, 100) <= Config.HitChance then
                        LastAttackData = {Player = CurrentTargetPlr, Time = tick()}
                        return CFrame.new(CurrentAimPos)
                    end
                end
                if Config.FixBulletDrop then
                    return CFrame.new(GetExactCrosshairWorldPoint())
                end
            elseif key == "Target" or key == "target" then
                if Config.SilentAim and (Config.SilentAimMethod == "Dual (Remote + Mouse)" or Config.SilentAimMethod == "Mouse.Hit Only") then
                    if CurrentTargetPart and math.random(1, 100) <= Config.HitChance then
                        return CurrentTargetPart
                    end
                end
            end
        end
        return oldIndex(self, key)
    end)

    mt.__namecall = newcclosure(function(self, ...)
        if Unhooked or checkcaller() or RaycastBypass then
            return oldNamecall(self, ...)
        end

        local method = getnamecallmethod()
        if method == "InvokeServer" or method == "FireServer" then
            local ok, className = pcall(oldIndex, self, "ClassName")
            if ok and (className == "RemoteFunction" or className == "RemoteEvent") then
                local _, selfName = pcall(oldIndex, self, "Name")
                local _, selfParent = pcall(oldIndex, self, "Parent")
                local parentName = ""
                if selfParent then
                    local _, pName = pcall(oldIndex, selfParent, "Name")
                    parentName = pName or ""
                end

                local args = {...}

                -- Точное определение выстрела револьвера в MM2 (CreateBeam.RemoteFunction или ShootGun)
                local isMM2GunRemote = (selfName == "ShootGun")
                    or (parentName == "CreateBeam")
                    or (method == "InvokeServer" and args[1] == 1 and typeof(args[2]) == "Vector3")

                -- Точное определение броска ножа (НИКОГДА не трогаем "Stab", чтобы обычный удар ножом работал идеально!)
                local isMM2KnifeThrow = (selfName == "Throw" or selfName == "KnifeThrown")

                if isMM2GunRemote or isMM2KnifeThrow then
                    local useSilent = (isMM2GunRemote and Config.SilentAim and Config.SilentAimMethod ~= "Mouse.Hit Only")
                        or (isMM2KnifeThrow and (Config.SilentAim or Config.SilentKnifeThrow))

                    if useSilent and CurrentTargetPart and CurrentAimPos and math.random(1, 100) <= Config.HitChance then
                        LastAttackData = {Player = CurrentTargetPlr, Time = tick()}
                        if isMM2GunRemote and typeof(args[2]) == "Vector3" then
                            args[2] = CurrentAimPos
                        else
                            for i, v in ipairs(args) do
                                if typeof(v) == "Vector3" then
                                    args[i] = CurrentAimPos
                                elseif typeof(v) == "CFrame" then
                                    args[i] = CFrame.new(v.Position, CurrentAimPos)
                                end
                            end
                        end

                        if Config.QuickPeek and QuickPeekOrigin and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            task.delay(0.08, function()
                                if QuickPeekOrigin and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(QuickPeekOrigin)
                                end
                            end)
                        end

                        return oldNamecall(self, unpack(args))
                    elseif isMM2GunRemote and Config.FixBulletDrop then
                        local exactPos = GetExactCrosshairWorldPoint()
                        if typeof(args[2]) == "Vector3" then
                            args[2] = exactPos
                        end
                        return oldNamecall(self, unpack(args))
                    end
                end
            end
        end

        return oldNamecall(self, ...)
    end)

    setreadonly(mt, true)
end

-------------------------------------------------------------------------
-- АНТИ-ЧИТЕР ДЕСИНК (SERVER CFRAME + ANTI-PREDICTION СО СТАБИЛИЗАЦИЕЙ КАМЕРЫ!)
-------------------------------------------------------------------------
-- Как сделать так, чтобы другой читер НЕ МОГ в тебя попасть в MM2, и при этом камера НЕ тряслась:
-- 1) На Heartbeat мы смещаем твой серверный `HumanoidRootPart.CFrame` в сторону на 6-12 стадов (или под пол)
--    И отправляем инвертированный вектор скорости `AssemblyLinearVelocity` (-Velocity * Power), чтобы чужой Silent Aim
--    стрелял в противоположную сторону от твоего движения!
-- 2) Чтобы твой экран и камера вообще не тряслись от смещения CFrame, мы запоминаем реальный CFrame и возвращаем его
--    на RenderStepped ДО рендера кадра, удерживая камеру идеально плавной!
local RealClientCFrame = nil
local RealClientVelocity = Vector3.zero
local ServerGhostCFrame = CFrame.new()
local DesyncFlip = false
local DesyncOrbitAngle = 0
local ChokeTick = 0
local LastTrailPos = nil
local LastGunBreakTick = 0

-- Возвращаем реальный клиентский CFrame перед рендером камеры (0% тряски экрана!)
RunService:BindToRenderStep("GS_DesyncRestore", Enum.RenderPriority.Camera.Value - 1, function()
    if Unhooked then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and RealClientCFrame then
        hrp.CFrame = RealClientCFrame
        hrp.AssemblyLinearVelocity = RealClientVelocity
        RealClientCFrame = nil
    end
end)

TrackConnection(RunService.Heartbeat:Connect(function(dt)
    if Unhooked then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not char or not hum or not hrp or hum.Health <= 0 then return end

    if Config.AutoStealSheriffGun and GetRole(LocalPlayer) == "Innocent" then
        if not char:FindFirstChild("Gun") and not (LocalPlayer:FindFirstChild("Backpack") and LocalPlayer.Backpack:FindFirstChild("Gun")) then
            StealGunFromLivingSheriff()
        end
    end

    if Config.BreakSheriffGun and (tick() - LastGunBreakTick) > 0.25 then
        LastGunBreakTick = tick()
        local liveGun = FindLivingSheriffGun()
        local rem = FindGunShootRemote(liveGun)
        if rem then
            task.spawn(function()
                pcall(function() rem:InvokeServer(1, 0, "AH2") end)
            end)
        end
    end

    if Config.SkinChanger then
        local myGun = char:FindFirstChild("Gun") or (LocalPlayer:FindFirstChild("Backpack") and LocalPlayer.Backpack:FindFirstChild("Gun"))
        if myGun then ApplyAWPSkinToGun(myGun) end
        local myKnife = char:FindFirstChild("Knife") or (LocalPlayer:FindFirstChild("Backpack") and LocalPlayer.Backpack:FindFirstChild("Knife"))
        if myKnife then ApplyCSGOKnifeSkin(myKnife) end
    end

    local now = tick()
    local maxAge = Config.BacktrackMS / 1000
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            BacktrackHistory[plr] = BacktrackHistory[plr] or {}
            table.insert(BacktrackHistory[plr], {Time = now, Pos = plr.Character.HumanoidRootPart.Position})
            while #BacktrackHistory[plr] > 0 and (now - BacktrackHistory[plr][1].Time) > maxAge do
                table.remove(BacktrackHistory[plr], 1)
            end
        end
    end

    if Config.LocalTrail and hum.MoveDirection.Magnitude > 0 then
        local footPos = hrp.Position - Vector3.new(0, 2.6, 0)
        if LastTrailPos and (footPos - LastTrailPos).Magnitude >= 1.2 and (footPos - LastTrailPos).Magnitude <= 18 then
            local dist = (footPos - LastTrailPos).Magnitude
            local seg = TrackInstance(Instance.new("Part"))
            seg.Anchored = true
            seg.CanCollide = false
            seg.CastShadow = false
            seg.Material = Enum.Material.Neon
            seg.Color = GetThemeColor(Config.ChinaHatColor)
            seg.Transparency = 0.25
            seg.Size = Vector3.new(0.10, 0.10, dist)
            seg.CFrame = CFrame.lookAt(LastTrailPos, footPos) * CFrame.new(0, 0, -dist / 2)
            seg.Parent = Workspace
            task.delay(1.0, function() if seg then seg:Destroy() end end)
        end
        LastTrailPos = footPos
    else
        LastTrailPos = nil
    end

    if IsClimbingLadder(char, hum, hrp) then
        if sethiddenproperty then pcall(function() sethiddenproperty(hrp, "NetworkIsSleeping", false) end) end
        return
    end

    if Config.FakeLag then
        ChokeTick = (ChokeTick + 1) % (Config.FakeLagLimit + 1)
        if sethiddenproperty then
            pcall(function() sethiddenproperty(hrp, "NetworkIsSleeping", ChokeTick ~= 0) end)
        end
    elseif sethiddenproperty then
        pcall(function() sethiddenproperty(hrp, "NetworkIsSleeping", false) end)
    end

    -- АНТИ-ЧИТЕР ДЕСИНК (СЕРВЕРНЫЙ ХИТБОКС УХОДИТ В СТОРОНУ + АНТИ-ПРЕДИКШН ВЕЛОСИТИ)
    if Config.Desync_Enabled then
        RealClientCFrame = hrp.CFrame
        RealClientVelocity = hrp.AssemblyLinearVelocity
        DesyncFlip = not DesyncFlip
        DesyncOrbitAngle = (DesyncOrbitAngle + dt * 11) % (math.pi * 2)

        local dist = Config.Desync_Distance
        local worldOffset = Vector3.zero

        if Config.Desync_Mode == "Underground Dodge" then
            worldOffset = Vector3.new(0, -4.5, 0)
        elseif Config.Desync_Mode == "Random Teleport" then
            worldOffset = Vector3.new(math.random(-dist, dist), 0, math.random(-dist, dist))
        else
            if Config.Desync_Side == "Left" then
                worldOffset = -RealClientCFrame.RightVector * dist
            elseif Config.Desync_Side == "Right" then
                worldOffset = RealClientCFrame.RightVector * dist
            elseif Config.Desync_Side == "Behind" then
                worldOffset = -RealClientCFrame.LookVector * dist
            elseif Config.Desync_Side == "Jitter" then
                worldOffset = RealClientCFrame.RightVector * (DesyncFlip and dist or -dist)
            elseif Config.Desync_Side == "Orbit" then
                worldOffset = Vector3.new(math.cos(DesyncOrbitAngle) * dist, 0, math.sin(DesyncOrbitAngle) * dist)
            end
        end

        local pwr = Config.Desync_Power
        local spoofVel = RealClientVelocity
        if Config.Desync_VelocityPattern == "Inverse Prediction" then
            -- Если ты бежишь вправо, вражеский чит видит что ты летишь влево со скоростью 350 и стреляет мимо!
            if RealClientVelocity.Magnitude > 1 then
                spoofVel = Vector3.new(-RealClientVelocity.X * (pwr / 12), RealClientVelocity.Y, -RealClientVelocity.Z * (pwr / 12))
            else
                spoofVel = Vector3.new(DesyncFlip and pwr or -pwr, 0, not DesyncFlip and pwr or -pwr)
            end
        elseif Config.Desync_VelocityPattern == "Zero Velocity" then
            spoofVel = Vector3.zero
        elseif Config.Desync_VelocityPattern == "NaN/Inf Breaker" then
            spoofVel = Vector3.new(DesyncFlip and 9999 or -9999, 4500, not DesyncFlip and -9999 or 9999)
        elseif Config.Desync_VelocityPattern == "Chaotic Jitter" then
            spoofVel = Vector3.new(math.random(-pwr, pwr), math.random(-120, 120), math.random(-pwr, pwr))
        end

        if Config.Desync_Mode ~= "Velocity Breaker" then
            ServerGhostCFrame = RealClientCFrame + worldOffset
            hrp.CFrame = ServerGhostCFrame
        else
            ServerGhostCFrame = RealClientCFrame + (spoofVel.Unit * math.min(dist, 8))
        end

        hrp.AssemblyLinearVelocity = spoofVel
    else
        RealClientCFrame = nil
    end
end))

-------------------------------------------------------------------------
-- ДОРОГИЕ ВИЗУАЛЫ (CORNER BOXES, PIXEL-PERFECT 1PX OUTLINES, SKELETONS)
-------------------------------------------------------------------------
local FOVCircle = TrackDrawing(Drawing and Drawing.new("Circle"))
if FOVCircle then
    FOVCircle.Thickness = 1
    FOVCircle.Color = Skeet.Accent
    FOVCircle.Filled = false
end

local LegitFOVCircle = TrackDrawing(Drawing and Drawing.new("Circle"))
if LegitFOVCircle then
    LegitFOVCircle.Thickness = 1
    LegitFOVCircle.Color = Skeet.Cyan
    LegitFOVCircle.Filled = false
end

local SnapLine = TrackDrawing(Drawing and Drawing.new("Line"))
if SnapLine then
    SnapLine.Thickness = 1.2
    SnapLine.Color = Skeet.Accent
end

local TargetDot = TrackDrawing(Drawing and Drawing.new("Circle"))
if TargetDot then
    TargetDot.Thickness = 1
    TargetDot.Radius = 3.5
    TargetDot.Filled = true
    TargetDot.Color = Skeet.Murderer
end

local BonePairsR15 = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"}
}

local BonePairsR6 = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"}
}

TrackConnection(Players.PlayerRemoving:Connect(function(plr)
    BacktrackHistory[plr] = nil
    if RadarDots[plr] then
        RadarDots[plr]:Destroy()
        RadarDots[plr] = nil
    end
    if ESPObjects[plr] then
        for _, item in pairs(ESPObjects[plr]) do
            if type(item) == "table" then
                for _, sub in pairs(item) do
                    if sub and sub.Remove then sub:Remove() end
                end
            elseif item and item.Remove then
                item:Remove()
            end
        end
        ESPObjects[plr] = nil
    end
end))

local SpinYaw = 0
local JitterStep = 1
local CircleAngle = 0
local LastTriggerShot = 0
local LastXRayCheck = 0

local function GetThreatTarget(myPos)
    local murd = FindByRole("Murderer")
    if murd and murd ~= LocalPlayer and murd.Character and murd.Character:FindFirstChild("HumanoidRootPart") then
        return murd.Character.HumanoidRootPart
    end
    local sher = FindByRole("Sheriff")
    if sher and sher ~= LocalPlayer and sher.Character and sher.Character:FindFirstChild("HumanoidRootPart") then
        return sher.Character.HumanoidRootPart
    end
    local closest, minDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local h = p.Character:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 then
                local d = (p.Character.HumanoidRootPart.Position - myPos).Magnitude
                if d < minDist then minDist = d; closest = p.Character.HumanoidRootPart end
            end
        end
    end
    return closest
end

TrackConnection(RunService.RenderStepped:Connect(function(dt)
    if Unhooked then return end

    CurrentTargetPart, CurrentTargetPlr, CurrentAimPos = GetBestTargetInRadius(Config.FOV, false)

    local myChar = LocalPlayer.Character
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local mousePos = UserInputService:GetMouseLocation()

    Watermark.Visible = Config.Watermark
    KeybindBox.Visible = Config.KeybindList
    RadarFrame.Visible = Config.Radar2D

    if Config.Watermark then
        local fps = math.floor(1 / math.max(dt, 0.001))
        local desyncState = Config.Desync_Enabled and " | anti-silent" or ""
        wmTxt.Text = string.format("gamesense | %s [%s]%s | %d fps", LocalPlayer.Name, GetRole(LocalPlayer), desyncState, fps)
    end

    if Config.KeybindList then
        local list = {}
        if Config.SilentAim then
            local tName = CurrentTargetPlr and CurrentTargetPlr.Name or "ready"
            table.insert(list, "Silent aim       [" .. string.sub(tName, 1, 7) .. "]")
        end
        if Config.Desync_Enabled then
            table.insert(list, "Anti-Silent      [" .. Config.Desync_Side .. "]")
        end
        if Config.AA_Enabled then
            local dirStr = (ManualDir == -90 and "LEFT") or (ManualDir == 90 and "RIGHT") or (ManualDir == 180 and "BACK") or Config.AA_Yaw
            table.insert(list, "Anti-aim         [" .. dirStr .. "]")
        end
        if Config.LegitKnifeReach then
            table.insert(list, "Knife reach      [" .. Config.KnifeReachDist .. "st]")
        end
        if Config.Speed_Enabled then
            table.insert(list, "Speed (" .. Config.SpeedMode .. ")")
        end
        if Config.KillAll then
            table.insert(list, "Kill all         [on]")
        end
        kbBody.Text = #list > 0 and table.concat(list, "\n") or "No active binds"
    end

    if Config.TargetHUD and CurrentTargetPlr and CurrentTargetPart and CurrentTargetPlr.Character then
        local tHum = CurrentTargetPlr.Character:FindFirstChildOfClass("Humanoid")
        if tHum and tHum.Health > 0 then
            TargetHudFrame.Visible = true
            local role = GetRole(CurrentTargetPlr)
            local dist = myRoot and math.floor((CurrentTargetPart.Position - myRoot.Position).Magnitude) or 0
            thName.Text = "Target: " .. CurrentTargetPlr.Name
            thInfo.Text = string.format("Role: %s | Dist: %dft", role, dist)
            local hpPct = math.clamp(tHum.Health / math.max(tHum.MaxHealth, 1), 0, 1)
            thBarFill.Size = UDim2.new(hpPct, 0, 1, 0)
            thBarFill.BackgroundColor3 = (role == "Murderer" and Skeet.Murderer) or (role == "Sheriff" and Skeet.Sheriff) or Skeet.Accent
        else
            TargetHudFrame.Visible = false
        end
    else
        TargetHudFrame.Visible = false
    end

    if Config.LegitBacktrack and CurrentTargetPlr and BacktrackHistory[CurrentTargetPlr] and #BacktrackHistory[CurrentTargetPlr] > 0 then
        local oldest = BacktrackHistory[CurrentTargetPlr][1]
        BacktrackGhost.Transparency = 0.55
        BacktrackGhost.Position = oldest.Pos
    else
        BacktrackGhost.Transparency = 1
    end

    local showArrows = Config.AA_Enabled and Config.AA_ShowArrows
    ArrowLeft.Visible = showArrows
    ArrowRight.Visible = showArrows
    ArrowDown.Visible = showArrows
    if showArrows then
        ArrowLeft.TextColor3 = (ManualDir == -90) and Skeet.Accent or (DesyncFlip and Skeet.Cyan or Skeet.TextDim)
        ArrowRight.TextColor3 = (ManualDir == 90) and Skeet.Accent or (not DesyncFlip and Skeet.Cyan or Skeet.TextDim)
        ArrowDown.TextColor3 = (ManualDir == 180) and Skeet.Accent or Skeet.TextDim
    end

    -- Custom Scope Update
    ScopeHolder.Visible = Config.CustomScope
    if Config.CustomScope then
        local scopeCol = GetThemeColor(Config.ScopeColorMode)
        local scopeCenter = (Config.ScopeAlignMode == "Crosshair / Mouse") and mousePos or (Camera.ViewportSize / 2)
        local velMag = myRoot and Vector3.new(myRoot.AssemblyLinearVelocity.X, 0, myRoot.AssemblyLinearVelocity.Z).Magnitude or 0
        local dynAdd = Config.ScopeDynamicSpread and math.clamp(velMag * 0.70, 0, 42) or 0
        local gap = Config.ScopeGap + math.floor(dynAdd)
        local len = Config.ScopeLength
        local thick = Config.ScopeThickness

        local showLines = (Config.ScopeMode ~= "Dot Only")
        ScopeTop.Visible = showLines
        ScopeBot.Visible = showLines
        ScopeLeft.Visible = showLines
        ScopeRight.Visible = showLines

        if showLines then
            local gradTrans = (Config.ScopeMode == "Gradient Cross")
                and NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
                or NumberSequence.new(0)
            GradTop.Transparency = gradTrans
            GradBot.Transparency = gradTrans
            GradLeft.Transparency = gradTrans
            GradRight.Transparency = gradTrans

            ScopeTop.BackgroundColor3 = scopeCol
            ScopeBot.BackgroundColor3 = scopeCol
            ScopeLeft.BackgroundColor3 = scopeCol
            ScopeRight.BackgroundColor3 = scopeCol

            ScopeTop.Size = UDim2.new(0, thick, 0, len)
            ScopeTop.Position = UDim2.new(0, scopeCenter.X - math.floor(thick / 2), 0, scopeCenter.Y - gap - len)

            ScopeBot.Size = UDim2.new(0, thick, 0, len)
            ScopeBot.Position = UDim2.new(0, scopeCenter.X - math.floor(thick / 2), 0, scopeCenter.Y + gap)

            ScopeLeft.Size = UDim2.new(0, len, 0, thick)
            ScopeLeft.Position = UDim2.new(0, scopeCenter.X - gap - len, 0, scopeCenter.Y - math.floor(thick / 2))

            ScopeRight.Size = UDim2.new(0, len, 0, thick)
            ScopeRight.Position = UDim2.new(0, scopeCenter.X + gap, 0, scopeCenter.Y - math.floor(thick / 2))
        end

        ScopeDot.Visible = Config.ScopeCenterDot or (Config.ScopeMode == "Dot Only")
        ScopeDot.BackgroundColor3 = scopeCol
        ScopeDot.Size = UDim2.new(0, thick + 1, 0, thick + 1)
        ScopeDot.Position = UDim2.new(0, scopeCenter.X - math.floor((thick + 1) / 2), 0, scopeCenter.Y - math.floor((thick + 1) / 2))
    end

    local mPlr = FindByRole("Murderer")
    local sPlr = FindByRole("Sheriff")
    RoleStatusLbl.Text = string.format("Murderer: %s\nSheriff: %s", mPlr and mPlr.Name or "None", sPlr and sPlr.Name or "None")

    -- LEGIT SMOOTH CAMERA AIMBOT
    if Config.LegitAim then
        local activeKey = (Config.LegitAimKey == "Always On")
            or (Config.LegitAimKey == "MouseButton2 (RMB)" and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2))
            or (Config.LegitAimKey == "Key E" and UserInputService:IsKeyDown(Enum.KeyCode.E))
        if activeKey then
            local lPart, _, lPos = GetBestTargetInRadius(Config.LegitFOV, Config.LegitVisibleOnly)
            if lPart and lPos then
                local goalCF = CFrame.new(Camera.CFrame.Position, lPos)
                Camera.CFrame = Camera.CFrame:Lerp(goalCF, math.clamp(1 / math.max(Config.LegitSmooth, 1), 0.02, 1))
            end
        end
    end

    -- LEGIT TRIGGERBOT
    if Config.LegitTriggerbot and myChar and (tick() - LastTriggerShot) >= (Config.TriggerbotDelay / 1000) then
        local gun = myChar:FindFirstChild("Gun")
        if gun and LocalMouse.Target then
            local hitModel = LocalMouse.Target:FindFirstAncestorOfClass("Model")
            local hitPlr = hitModel and Players:GetPlayerFromCharacter(hitModel)
            if hitPlr and hitPlr ~= LocalPlayer then
                local myRole = GetRole(LocalPlayer)
                if myRole ~= "Sheriff" or GetRole(hitPlr) == "Murderer" then
                    LastTriggerShot = tick()
                    LastAttackData = {Player = hitPlr, Time = tick()}
                    local rem = FindGunShootRemote(gun)
                    if rem then
                        local pos = hitPlr.Character and hitPlr.Character:FindFirstChild("HumanoidRootPart") and hitPlr.Character.HumanoidRootPart.Position or LocalMouse.Hit.Position
                        task.spawn(function() pcall(function() rem:InvokeServer(1, pos, "AH2") end) end)
                    end
                end
            end
        end
    end

    local rmbZooming = Config.CustomScope and Config.ScopeZoomRMB and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    if rmbZooming then
        Camera.FieldOfView = Config.ScopeZoomFOV
    elseif Config.CustomFOV then
        Camera.FieldOfView = Config.CameraFOV
    else
        Camera.FieldOfView = OriginalState.CameraFOV
    end

    if Config.ThirdPerson then
        LocalPlayer.CameraMaxZoomDistance = Config.ThirdPersonDist
        LocalPlayer.CameraMinZoomDistance = Config.ThirdPersonDist
    else
        LocalPlayer.CameraMaxZoomDistance = OriginalState.MaxZoom
        LocalPlayer.CameraMinZoomDistance = OriginalState.MinZoom
    end

    if Config.AspectRatio then
        local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = Camera.CFrame:GetComponents()
        local scale = Config.AspectRatioVal / 100
        Camera.CFrame = CFrame.new(x, y, z, r00, r01 * scale, r02, r10, r11 * scale, r12, r20, r21 * scale, r22)
    end

    ColorGrade.Saturation = Config.ColorSaturation / 100
    if Config.WorldAmbience then
        local ambCol = GetThemeColor(Config.WorldTintMode)
        Lighting.Ambient = ambCol
        Lighting.OutdoorAmbient = ambCol
    else
        Lighting.Ambient = OriginalState.Ambient
        Lighting.OutdoorAmbient = OriginalState.OutdoorAmbient
    end

    if Config.CustomTime then
        Lighting.ClockTime = Config.WorldTime
    elseif Config.NightMode then
        Lighting.ClockTime = 0
        Lighting.Brightness = 0.5
    elseif Config.Fullbright then
        Lighting.ClockTime = 14
        Lighting.Brightness = 2.2
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
    end

    if Config.CustomFog then
        Lighting.FogEnd = Config.FogDist
        Lighting.FogStart = 10
        Lighting.FogColor = Config.WorldAmbience and GetThemeColor(Config.WorldTintMode) or OriginalState.FogColor
    end

    if tick() - LastXRayCheck > 0.8 then
        LastXRayCheck = tick()
        if Config.XRayWalls then
            for _, v in ipairs(Workspace:GetDescendants()) do
                if v:IsA("BasePart") and not v:IsDescendantOf(myChar or Instance.new("Folder")) then
                    local model = v:FindFirstAncestorOfClass("Model")
                    local isPlayer = model and Players:GetPlayerFromCharacter(model)
                    if not isPlayer and v.Transparency < 0.8 and v.Size.Magnitude > 5 then
                        if not XRayParts[v] then XRayParts[v] = v.LocalTransparencyModifier end
                        v.LocalTransparencyModifier = Config.XRayTrans / 100
                    end
                end
            end
        elseif next(XRayParts) ~= nil then
            RestoreXRay()
        end
    end

    -- 3D China Hat, Halo & Danger Ring
    local head = myChar and myChar:FindFirstChild("Head")
    if Drawing and #HatLines > 0 then
        if head and Config.ChinaHat then
            local tipWorld = head.Position + Vector3.new(0, 0.75 + (Config.ChinaHatHeight / 10), 0)
            local baseCenter = head.Position + Vector3.new(0, 0.75, 0)
            local rad = Config.ChinaHatRadius / 10
            local tipScreen, tipVis = Camera:WorldToViewportPoint(tipWorld)

            for i = 1, HatSegments do
                local a1 = (i / HatSegments) * math.pi * 2
                local a2 = ((i + 1) / HatSegments) * math.pi * 2
                local p1 = baseCenter + Vector3.new(math.cos(a1) * rad, 0, math.sin(a1) * rad)
                local p2 = baseCenter + Vector3.new(math.cos(a2) * rad, 0, math.sin(a2) * rad)
                local s1, v1 = Camera:WorldToViewportPoint(p1)
                local s2, v2 = Camera:WorldToViewportPoint(p2)
                local segCol = GetThemeColor(Config.ChinaHatColor, i / HatSegments)

                local rim = HatLines[i].Rim
                local rib = HatLines[i].Rib
                if v1 and v2 and tipVis then
                    rim.Visible = true
                    rim.From = Vector2.new(s1.X, s1.Y)
                    rim.To = Vector2.new(s2.X, s2.Y)
                    rim.Color = segCol

                    rib.Visible = (i % 2 == 0)
                    rib.From = Vector2.new(tipScreen.X, tipScreen.Y)
                    rib.To = Vector2.new(s1.X, s1.Y)
                    rib.Color = segCol
                else
                    rim.Visible = false
                    rib.Visible = false
                end
            end
        else
            for i = 1, HatSegments do
                HatLines[i].Rim.Visible = false
                HatLines[i].Rib.Visible = false
            end
        end

        if head and Config.HaloRing then
            local haloCenter = head.Position + Vector3.new(0, 1.55 + math.sin(tick() * 2.5) * 0.10, 0)
            for i = 1, HatSegments do
                local a1 = (i / HatSegments) * math.pi * 2
                local a2 = ((i + 1) / HatSegments) * math.pi * 2
                local p1 = haloCenter + Vector3.new(math.cos(a1) * 0.95, 0, math.sin(a1) * 0.95)
                local p2 = haloCenter + Vector3.new(math.cos(a2) * 0.95, 0, math.sin(a2) * 0.95)
                local s1, v1 = Camera:WorldToViewportPoint(p1)
                local s2, v2 = Camera:WorldToViewportPoint(p2)
                local hLine = HaloLines[i]
                if v1 and v2 then
                    hLine.Visible = true
                    hLine.From = Vector2.new(s1.X, s1.Y)
                    hLine.To = Vector2.new(s2.X, s2.Y)
                    hLine.Color = Skeet.Accent
                else
                    hLine.Visible = false
                end
            end
        else
            for i = 1, HatSegments do HaloLines[i].Visible = false end
        end

        local murdRoot = mPlr and mPlr.Character and mPlr.Character:FindFirstChild("HumanoidRootPart")
        if murdRoot and Config.MurdererDangerRing then
            local ringCenter = murdRoot.Position - Vector3.new(0, 2.5, 0)
            for i = 1, HatSegments do
                local a1 = (i / HatSegments) * math.pi * 2
                local a2 = ((i + 1) / HatSegments) * math.pi * 2
                local p1 = ringCenter + Vector3.new(math.cos(a1) * 10, 0, math.sin(a1) * 10)
                local p2 = ringCenter + Vector3.new(math.cos(a2) * 10, 0, math.sin(a2) * 10)
                local s1, v1 = Camera:WorldToViewportPoint(p1)
                local s2, v2 = Camera:WorldToViewportPoint(p2)
                local dLine = DangerLines[i]
                if v1 and v2 then
                    dLine.Visible = true
                    dLine.From = Vector2.new(s1.X, s1.Y)
                    dLine.To = Vector2.new(s2.X, s2.Y)
                    dLine.Color = Skeet.Murderer
                else
                    dLine.Visible = false
                end
            end
        else
            for i = 1, HatSegments do DangerLines[i].Visible = false end
        end
    end

    if FOVCircle then
        FOVCircle.Visible = Config.SilentAim and Config.ShowFOV
        FOVCircle.Radius = Config.FOV
        FOVCircle.Position = mousePos
    end

    if LegitFOVCircle then
        LegitFOVCircle.Visible = Config.LegitAim and Config.ShowLegitFOV
        LegitFOVCircle.Radius = Config.LegitFOV
        LegitFOVCircle.Position = mousePos
    end

    if SnapLine and TargetDot then
        if Config.SilentAim and Config.TargetLine and CurrentAimPos then
            local sp, vis = Camera:WorldToViewportPoint(CurrentAimPos)
            SnapLine.Visible = vis
            SnapLine.From = mousePos
            SnapLine.To = Vector2.new(sp.X, sp.Y)
            TargetDot.Visible = vis
            TargetDot.Position = Vector2.new(sp.X, sp.Y)
        else
            SnapLine.Visible = false
            TargetDot.Visible = false
        end
    end

    -- ПРЕМИУМ SKEET ESP (Угловые боксы, 1px обводка, полупрозрачный фон, тонкий скелет)
    local vpCenter = Camera.ViewportSize / 2
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local alive = hum and hum.Health > 0
            local role = GetRole(plr)
            local col = (role == "Murderer" and Skeet.Murderer) or (role == "Sheriff" and Skeet.Sheriff) or Skeet.Innocent

            if Config.Radar2D and hrp and alive and myRoot then
                if not RadarDots[plr] then
                    local dot = Instance.new("Frame", RadarFrame)
                    dot.Size = UDim2.new(0, 5, 0, 5)
                    dot.BorderSizePixel = 0
                    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
                    RadarDots[plr] = dot
                end
                local rel = Camera.CFrame:PointToObjectSpace(hrp.Position)
                local scale = Config.RadarZoom / 10
                local rx = math.clamp(68 + (rel.X * scale), 4, 132)
                local ry = math.clamp(68 + (rel.Z * scale), 4, 132)
                RadarDots[plr].Visible = true
                RadarDots[plr].BackgroundColor3 = col
                RadarDots[plr].Position = UDim2.new(0, rx - 2, 0, ry - 2)
            elseif RadarDots[plr] then
                RadarDots[plr].Visible = false
            end

            if hrp and alive then
                if Config.HitboxExpander then
                    hrp.Size = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
                    hrp.Transparency = Config.HitboxTrans / 100
                    hrp.Color = col
                    hrp.CanCollide = false
                else
                    hrp.Size = Vector3.new(2, 2, 1)
                    hrp.Transparency = 1
                end
            end

            if char and hrp and alive and Config.ESP_Enabled then
                local hl = char:FindFirstChild("GS_Chams")
                if Config.Chams then
                    if not hl then
                        hl = Instance.new("Highlight", char)
                        hl.Name = "GS_Chams"
                        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    end
                    hl.FillColor = col
                    hl.OutlineColor = Color3.fromRGB(15, 15, 15)
                    hl.FillTransparency = Config.ChamsAlpha / 100
                    hl.OutlineTransparency = 0.35
                elseif hl then
                    hl:Destroy()
                end

                if Drawing then
                    if not ESPObjects[plr] then
                        local bones = {}
                        for i = 1, 10 do
                            local b = Drawing.new("Line")
                            b.Thickness = 1
                            b.Transparency = 0.85
                            b.Visible = false
                            bones[i] = b
                        end
                        local corners = {}
                        for i = 1, 8 do
                            local c = Drawing.new("Line")
                            c.Thickness = 1.5
                            c.Visible = false
                            corners[i] = c
                        end
                        ESPObjects[plr] = {
                            BoxFill = Drawing.new("Square"),
                            BoxOutline = Drawing.new("Square"),
                            Box = Drawing.new("Square"),
                            Corners = corners,
                            HpOutline = Drawing.new("Line"),
                            HpBar = Drawing.new("Line"),
                            Name = Drawing.new("Text"),
                            Flag = Drawing.new("Text"),
                            OOF1 = Drawing.new("Line"),
                            OOF2 = Drawing.new("Line"),
                            OOF3 = Drawing.new("Line"),
                            Bones = bones
                        }
                        ESPObjects[plr].BoxFill.Filled = true
                        ESPObjects[plr].BoxFill.Color = Color3.fromRGB(10, 10, 12)
                        ESPObjects[plr].BoxFill.Transparency = 0.35
                        ESPObjects[plr].BoxOutline.Thickness = 2.5
                        ESPObjects[plr].BoxOutline.Color = Color3.new(0, 0, 0)
                        ESPObjects[plr].Box.Thickness = 1
                        ESPObjects[plr].HpOutline.Thickness = 3
                        ESPObjects[plr].HpOutline.Color = Color3.new(0, 0, 0)
                        ESPObjects[plr].HpBar.Thickness = 1.5
                        ESPObjects[plr].Name.Size = 12
                        ESPObjects[plr].Name.Center = true
                        ESPObjects[plr].Name.Outline = true
                        ESPObjects[plr].Flag.Size = 11
                        ESPObjects[plr].Flag.Center = true
                        ESPObjects[plr].Flag.Outline = true
                        ESPObjects[plr].OOF1.Thickness = 1.8
                        ESPObjects[plr].OOF2.Thickness = 1.8
                        ESPObjects[plr].OOF3.Thickness = 1.8
                    end

                    local esp = ESPObjects[plr]
                    local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                    if onScreen then
                        esp.OOF1.Visible = false; esp.OOF2.Visible = false; esp.OOF3.Visible = false

                        local scale = 2000 / math.max(pos.Z, 1)
                        local w, h = math.floor(scale * 1.75), math.floor(scale * 2.55)
                        local x, y = math.floor(pos.X - w / 2), math.floor(pos.Y - h / 2)

                        esp.BoxFill.Visible = Config.ESP_Box and Config.ESP_BoxFill
                        esp.BoxFill.Size = Vector2.new(w, h)
                        esp.BoxFill.Position = Vector2.new(x, y)

                        if Config.ESP_Box and Config.ESP_BoxStyle == "Corner" then
                            esp.BoxOutline.Visible = false
                            esp.Box.Visible = false
                            local cw = math.max(math.floor(w * 0.26), 4)
                            local ch = math.max(math.floor(h * 0.22), 4)
                            local cPts = {
                                {Vector2.new(x, y), Vector2.new(x + cw, y)},
                                {Vector2.new(x, y), Vector2.new(x, y + ch)},
                                {Vector2.new(x + w, y), Vector2.new(x + w - cw, y)},
                                {Vector2.new(x + w, y), Vector2.new(x + w, y + ch)},
                                {Vector2.new(x, y + h), Vector2.new(x + cw, y + h)},
                                {Vector2.new(x, y + h), Vector2.new(x, y + h - ch)},
                                {Vector2.new(x + w, y + h), Vector2.new(x + w - cw, y + h)},
                                {Vector2.new(x + w, y + h), Vector2.new(x + w, y + h - ch)}
                            }
                            for idx, pt in ipairs(cPts) do
                                local ln = esp.Corners[idx]
                                ln.Visible = true
                                ln.From = pt[1]
                                ln.To = pt[2]
                                ln.Color = col
                            end
                        else
                            for idx = 1, 8 do esp.Corners[idx].Visible = false end
                            esp.BoxOutline.Visible = Config.ESP_Box
                            esp.BoxOutline.Size = Vector2.new(w, h)
                            esp.BoxOutline.Position = Vector2.new(x, y)

                            esp.Box.Visible = Config.ESP_Box
                            esp.Box.Size = Vector2.new(w, h)
                            esp.Box.Position = Vector2.new(x, y)
                            esp.Box.Color = col
                        end

                        local hpPct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                        esp.HpOutline.Visible = Config.ESP_HealthBar
                        esp.HpOutline.From = Vector2.new(x - 5, y - 1)
                        esp.HpOutline.To = Vector2.new(x - 5, y + h + 1)

                        esp.HpBar.Visible = Config.ESP_HealthBar
                        esp.HpBar.From = Vector2.new(x - 5, y + h)
                        esp.HpBar.To = Vector2.new(x - 5, y + h - (h * hpPct))
                        esp.HpBar.Color = Color3.fromRGB(255 - math.floor(hpPct * 150), math.floor(hpPct * 225), 40)

                        esp.Name.Visible = Config.ESP_Name
                        esp.Name.Position = Vector2.new(pos.X, y - 14)
                        esp.Name.Text = plr.Name
                        esp.Name.Color = Color3.fromRGB(240, 240, 240)

                        local d = myRoot and math.floor((hrp.Position - myRoot.Position).Magnitude) or 0
                        esp.Flag.Visible = Config.ESP_Flags or Config.ESP_Distance
                        esp.Flag.Position = Vector2.new(pos.X, y + h + 2)
                        esp.Flag.Text = string.upper(role) .. (Config.ESP_Distance and string.format(" · %dM", d) or "")
                        esp.Flag.Color = col

                        if Config.ESP_Skeleton then
                            local pairsList = char:FindFirstChild("UpperTorso") and BonePairsR15 or BonePairsR6
                            for idx, pair in ipairs(pairsList) do
                                local b1 = char:FindFirstChild(pair[1])
                                local b2 = char:FindFirstChild(pair[2])
                                local line = esp.Bones[idx]
                                if b1 and b2 and line then
                                    local p1, v1 = Camera:WorldToViewportPoint(b1.Position)
                                    local p2, v2 = Camera:WorldToViewportPoint(b2.Position)
                                    if v1 and v2 then
                                        line.Visible = true
                                        line.From = Vector2.new(p1.X, p1.Y)
                                        line.To = Vector2.new(p2.X, p2.Y)
                                        line.Color = Color3.fromRGB(230, 230, 230)
                                    else
                                        line.Visible = false
                                    end
                                elseif line then
                                    line.Visible = false
                                end
                            end
                            for idx = #pairsList + 1, 10 do esp.Bones[idx].Visible = false end
                        else
                            for idx = 1, 10 do esp.Bones[idx].Visible = false end
                        end
                    else
                        esp.BoxFill.Visible = false
                        esp.BoxOutline.Visible = false
                        esp.Box.Visible = false
                        esp.HpOutline.Visible = false
                        esp.HpBar.Visible = false
                        esp.Name.Visible = false
                        esp.Flag.Visible = false
                        for idx = 1, 8 do esp.Corners[idx].Visible = false end
                        for idx = 1, 10 do esp.Bones[idx].Visible = false end

                        if Config.ESP_OOFArrows then
                            local relPos = Camera.CFrame:PointToObjectSpace(hrp.Position)
                            local angle = math.atan2(-relPos.Y, relPos.X)
                            local rad = Config.ESP_OOFRadius
                            local dirVec = Vector2.new(math.cos(angle), math.sin(angle))
                            local perpVec = Vector2.new(-dirVec.Y, dirVec.X)

                            local tip = vpCenter + (dirVec * rad)
                            local baseL = vpCenter + (dirVec * (rad - 12)) + (perpVec * 5)
                            local baseR = vpCenter + (dirVec * (rad - 12)) - (perpVec * 5)

                            esp.OOF1.Visible = true; esp.OOF1.From = tip; esp.OOF1.To = baseL; esp.OOF1.Color = col
                            esp.OOF2.Visible = true; esp.OOF2.From = tip; esp.OOF2.To = baseR; esp.OOF2.Color = col
                            esp.OOF3.Visible = true; esp.OOF3.From = baseL; esp.OOF3.To = baseR; esp.OOF3.Color = col
                        else
                            esp.OOF1.Visible = false; esp.OOF2.Visible = false; esp.OOF3.Visible = false
                        end
                    end
                end
            else
                if char and char:FindFirstChild("GS_Chams") then char.GS_Chams:Destroy() end
                if ESPObjects[plr] then
                    for _, item in pairs(ESPObjects[plr]) do
                        if type(item) == "table" then
                            for _, sub in pairs(item) do sub.Visible = false end
                        else
                            item.Visible = false
                        end
                    end
                end
            end
        end
    end

    -- Монетки и GunDrop
    local coinContainer = Workspace:FindFirstChild("CoinContainer", true)
    if coinContainer then
        local closestCoin, minCoinDist = nil, math.huge
        for _, coin in ipairs(coinContainer:GetChildren()) do
            local coinPart = coin:IsA("BasePart") and coin or coin:FindFirstChildOfClass("BasePart")
            if coinPart then
                local cHl = coinPart:FindFirstChild("GS_CoinChams")
                if Config.ESP_Enabled and Config.ESP_Coins then
                    if not cHl then
                        cHl = Instance.new("Highlight", coinPart)
                        cHl.Name = "GS_CoinChams"
                        cHl.FillColor = Skeet.GunDrop
                        cHl.OutlineColor = Skeet.Accent
                        cHl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    end
                elseif cHl then
                    cHl:Destroy()
                end

                if myRoot then
                    local d = (coinPart.Position - myRoot.Position).Magnitude
                    if Config.CoinMagnet and d <= Config.CoinMagnetDist then
                        coinPart.CFrame = myRoot.CFrame
                    end
                    if d < minCoinDist then
                        minCoinDist = d
                        closestCoin = coinPart
                    end
                end
            end
        end

        if Config.AutoCoinFarm and closestCoin and myRoot and minCoinDist <= 120 then
            local dir = (closestCoin.Position - myRoot.Position)
            if dir.Magnitude > 1.5 then
                myRoot.CFrame = myRoot.CFrame + (dir.Unit * math.min(28 * dt, dir.Magnitude))
            end
        end
    end

    local gunDrop = Workspace:FindFirstChild("GunDrop", true)
    if gunDrop and gunDrop:IsA("BasePart") then
        local gHl = gunDrop:FindFirstChild("GS_GunChams")
        if Config.ESP_Enabled and Config.ESP_GunDrop then
            if not gHl then
                gHl = Instance.new("Highlight", gunDrop)
                gHl.Name = "GS_GunChams"
                gHl.FillColor = Skeet.GunDrop
                gHl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            end
        elseif gHl then
            gHl:Destroy()
        end

        if Config.AutoGrabGun and myRoot then
            if GetRole(LocalPlayer) == "Innocent" then
                local old = myRoot.CFrame
                myRoot.CFrame = gunDrop.CFrame
                task.wait(0.06)
                myRoot.CFrame = old
            end
        end
    end

    -- ЛОКАЛЬНЫЙ ИГРОК: WORKING HVH ANTI-AIM, CLONE GHOST, MOVEMENT & MURDERER RAGE
    if myChar and myHum and myRoot and myHum.Health > 0 then
        if Config.QuickPeek and QuickPeekOrigin then
            QuickPeekPart.Transparency = 0.35
            QuickPeekPart.Position = QuickPeekOrigin - Vector3.new(0, 2.5, 0)
        else
            QuickPeekPart.Transparency = 1
        end

        if Config.AutoDodgeMurderer and GetRole(LocalPlayer) ~= "Murderer" and mPlr and mPlr.Character and mPlr.Character:FindFirstChild("HumanoidRootPart") then
            local mRoot = mPlr.Character.HumanoidRootPart
            local diff = (myRoot.Position - mRoot.Position)
            if diff.Magnitude <= Config.DodgeDistance and diff.Magnitude > 0.5 then
                local evadeDir = Vector3.new(diff.X, 0, diff.Z).Unit
                myRoot.CFrame = myRoot.CFrame + (evadeDir * 8)
            end
        end

        local showGhost = Config.Desync_Enabled and Config.Desync_ShowGhost
        local deltaCF = myRoot.CFrame:Inverse() * ServerGhostCFrame
        for partName, clonePart in pairs(GhostParts) do
            local realPart = myChar:FindFirstChild(partName)
            if realPart and showGhost then
                clonePart.Transparency = 0.55
                clonePart.Color = Skeet.Accent
                clonePart.CFrame = realPart.CFrame * deltaCF
            else
                clonePart.Transparency = 1
            end
        end

        if Config.FakeDuck then
            myHum.CameraOffset = Vector3.new(0, -1.5, 0)
        else
            myHum.CameraOffset = Vector3.zero
        end

        local onLadder = IsClimbingLadder(myChar, myHum, myRoot)

        -- РАБОЧИЕ HVH ANTI-AIMS (Починены: не блокируются стенами и не сбрасываются каждый кадр)
        if Config.AA_Enabled and not Config.FakeDead and not onLadder then
            localMotorsModified = true
            myHum.AutoRotate = false

            local baseYaw = 0
            if Config.AA_YawBase == "At targets" then
                local threat = GetThreatTarget(myRoot.Position)
                if threat then
                    local dir = (threat.Position - myRoot.Position)
                    baseYaw = math.atan2(-dir.X, -dir.Z)
                else
                    local look = Camera.CFrame.LookVector
                    baseYaw = math.atan2(-look.X, -look.Z)
                end
            else
                local look = Camera.CFrame.LookVector
                baseYaw = math.atan2(-look.X, -look.Z)
            end

            local yawOffset = 0
            if Config.AA_ManualKeys and ManualDir ~= 0 then
                yawOffset = math.rad(ManualDir)
            elseif Config.AA_Yaw == "180" then
                yawOffset = math.rad(180)
            elseif Config.AA_Yaw == "Spinbot" then
                SpinYaw = (SpinYaw + Config.AA_SpinSpeed * dt * 12) % 360
                baseYaw = 0
                yawOffset = math.rad(SpinYaw)
            elseif Config.AA_Yaw == "Jitter" then
                yawOffset = math.rad(180)
            elseif Config.AA_Yaw == "Crosshair" then
                yawOffset = 0
            end

            local jitRange = Config.AA_JitterRange
            local jitAdd = 0
            JitterStep = (JitterStep % 3) + 1
            if Config.AA_YawJitter == "Offset" then
                if JitterStep % 2 == 0 then jitAdd = math.rad(jitRange) end
            elseif Config.AA_YawJitter == "Center" or Config.AA_Yaw == "Jitter" then
                jitAdd = math.rad((JitterStep % 2 == 0) and (jitRange / 2) or -(jitRange / 2))
            elseif Config.AA_YawJitter == "Random" then
                jitAdd = math.rad(math.random(-math.abs(jitRange), math.abs(jitRange)))
            elseif Config.AA_YawJitter == "3-Way" then
                local ways = {-jitRange, 0, jitRange}
                jitAdd = math.rad(ways[JitterStep])
            end

            if Config.AA_DefensiveAir and myHum.FloorMaterial == Enum.Material.Air and (JitterStep == 1) then
                jitAdd = jitAdd + math.rad(135)
            end

            local finalYaw = baseYaw + yawOffset + jitAdd
            myRoot.CFrame = CFrame.new(myRoot.Position) * CFrame.Angles(0, finalYaw, 0)

            local neck = myChar:FindFirstChild("Neck", true)
            if neck and neck:IsA("Motor6D") then
                if not SavedMotorC0[neck] then SavedMotorC0[neck] = neck.C0 end
                local pDeg = 0
                if Config.AA_Pitch == "Down" then pDeg = -68
                elseif Config.AA_Pitch == "Up" then pDeg = 68
                elseif Config.AA_Pitch == "Zero" then pDeg = 0
                elseif Config.AA_Pitch == "Jitter" then pDeg = (JitterStep % 2 == 0) and -68 or 68
                elseif Config.AA_Pitch == "Flick Up" then pDeg = (JitterStep == 1) and 68 or -68
                end
                neck.C0 = SavedMotorC0[neck] * CFrame.Angles(math.rad(pDeg), 0, 0)
            end

            local waist = myChar:FindFirstChild("Waist", true) or myChar:FindFirstChild("RootJoint", true)
            if waist and waist:IsA("Motor6D") then
                if not SavedMotorC0[waist] then SavedMotorC0[waist] = waist.C0 end
                local bodyYawDeg = 0
                if Config.AA_BodyYaw == "Opposite" then bodyYawDeg = 58
                elseif Config.AA_BodyYaw == "Static" then bodyYawDeg = -58
                elseif Config.AA_BodyYaw == "Jitter" then bodyYawDeg = (JitterStep % 2 == 0) and 58 or -58
                end
                local rollRad = math.rad(Config.AA_RollLean)
                waist.C0 = SavedMotorC0[waist] * CFrame.Angles(0, math.rad(bodyYawDeg), rollRad)
            end
        else
            if not Config.FakeDead then
                myHum.AutoRotate = true
            end
            RestoreMotors()
        end

        if Config.Speed_Enabled then
            local moveDir = myHum.MoveDirection
            if Config.SpeedMode == "WalkSpeed" then
                myHum.WalkSpeed = Config.SpeedVal
            elseif Config.SpeedMode == "CFrame Bypass" then
                myHum.WalkSpeed = 16
                if moveDir.Magnitude > 0 and not onLadder then
                    myRoot.CFrame = myRoot.CFrame + (moveDir * ((Config.SpeedVal - 16) * dt))
                end
            elseif Config.SpeedMode == "Velocity Impulse" then
                myHum.WalkSpeed = 16
                if moveDir.Magnitude > 0 and not onLadder then
                    myRoot.AssemblyLinearVelocity = Vector3.new(moveDir.X * Config.SpeedVal, myRoot.AssemblyLinearVelocity.Y, moveDir.Z * Config.SpeedVal)
                end
            elseif Config.SpeedMode == "Pulse Boost" then
                local boost = (math.sin(tick() * 10) > 0.2) and (Config.SpeedVal * 1.35) or 16
                myHum.WalkSpeed = boost
            end
        else
            myHum.WalkSpeed = 16
        end

        if Config.QuickStop and myHum.MoveDirection.Magnitude == 0 and myHum.FloorMaterial ~= Enum.Material.Air and not onLadder then
            myRoot.AssemblyLinearVelocity = Vector3.new(0, myRoot.AssemblyLinearVelocity.Y, 0)
        end

        if Config.BHop and UserInputService:IsKeyDown(Enum.KeyCode.Space) and not onLadder then
            if myHum.FloorMaterial ~= Enum.Material.Air then
                myHum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end

        if Config.AirStrafe and myHum.FloorMaterial == Enum.Material.Air and not onLadder then
            local moveDir = myHum.MoveDirection
            if moveDir.Magnitude > 0 then
                myRoot.AssemblyLinearVelocity = Vector3.new(
                    moveDir.X * Config.StrafeSpeed,
                    myRoot.AssemblyLinearVelocity.Y,
                    moveDir.Z * Config.StrafeSpeed
                )
            end
        end

        if Config.CircleStrafe and UserInputService:IsKeyDown(Enum.KeyCode.C) and CurrentTargetPart and not onLadder then
            CircleAngle = CircleAngle + (dt * 6)
            local offset = Vector3.new(math.cos(CircleAngle) * Config.CircleRadius, 0, math.sin(CircleAngle) * Config.CircleRadius)
            myRoot.CFrame = CFrame.new(CurrentTargetPart.Position + offset, CurrentTargetPart.Position)
        end

        if Config.EdgeJump and myHum.FloorMaterial ~= Enum.Material.Air and myHum.MoveDirection.Magnitude > 0 and not onLadder then
            RaycastBypass = true
            local edgeParams = RaycastParams.new()
            edgeParams.FilterType = Enum.RaycastFilterType.Exclude
            edgeParams.FilterDescendantsInstances = {myChar}
            local lookAhead = myRoot.Position + (myHum.MoveDirection * 2.5)
            local groundCheck = Workspace:Raycast(lookAhead, Vector3.new(0, -5, 0), edgeParams)
            RaycastBypass = false
            if not groundCheck then
                myHum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end

        if Config.HighJump then
            myHum.UseJumpPower = true
            myHum.JumpPower = Config.JumpPower
        end

        if Config.Noclip then
            for _, p in ipairs(myChar:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
            end
        end

        -- Авто-выстрел за Шерифа
        if Config.AutoFire and GetRole(LocalPlayer) == "Sheriff" then
            local murd = FindByRole("Murderer")
            local mRoot = murd and murd.Character and murd.Character:FindFirstChild("HumanoidRootPart")
            if mRoot and IsVisible(mRoot) then
                local gun = myChar:FindFirstChild("Gun")
                local rem = FindGunShootRemote(gun)
                if rem then
                    LastAttackData = {Player = murd, Time = tick()}
                    task.spawn(function()
                        pcall(function()
                            rem:InvokeServer(1, mRoot.Position + (mRoot.Velocity * 0.13) + Vector3.new(0, 0.12, 0), "AH2")
                        end)
                    end)
                end
            end
        end

        -- Функции Мардера: KillAll & KnifeAura
        if GetRole(LocalPlayer) == "Murderer" then
            local knife = myChar:FindFirstChild("Knife") or (LocalPlayer:FindFirstChild("Backpack") and LocalPlayer.Backpack:FindFirstChild("Knife"))
            if Config.AutoEquipKnife and knife and knife.Parent == LocalPlayer.Backpack then
                myHum:EquipTool(knife)
            end

            if (Config.KillAll or Config.KnifeAura) and knife then
                if knife.Parent == LocalPlayer.Backpack then myHum:EquipTool(knife) end
                local handle = knife:FindFirstChild("Handle")
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                        local tHum = plr.Character:FindFirstChildOfClass("Humanoid")
                        local tRoot = plr.Character.HumanoidRootPart
                        if tHum and tHum.Health > 0 then
                            local d = (tRoot.Position - myRoot.Position).Magnitude
                            if Config.KillAll or (Config.KnifeAura and d <= Config.AuraRange) then
                                LastAttackData = {Player = plr, Time = tick()}
                                tRoot.CFrame = myRoot.CFrame * CFrame.new(0, 0, -2)
                                if knife:FindFirstChild("Stab") then
                                    pcall(function() knife.Stab:FireServer("Slash") end)
                                    pcall(function() knife.Stab:FireServer("Down") end)
                                end
                                if firetouchinterest and handle then
                                    pcall(firetouchinterest, handle, tRoot, 0)
                                    pcall(firetouchinterest, handle, tRoot, 1)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end))
