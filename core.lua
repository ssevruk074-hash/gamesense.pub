-- File: core.lua | Core State, Theme, Sound Engine & Full Unhook
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local SoundService = game:GetService("SoundService")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local LocalMouse = LocalPlayer:GetMouse()

_G.GS = {
    Players = Players,
    RunService = RunService,
    UserInputService = UserInputService,
    HttpService = HttpService,
    VirtualUser = VirtualUser,
    Workspace = Workspace,
    Lighting = Lighting,
    CoreGui = CoreGui,
    SoundService = SoundService,
    Camera = Camera,
    LocalPlayer = LocalPlayer,
    LocalMouse = LocalMouse,

    Connections = {},
    CreatedInstances = {},
    DrawingObjects = {},
    ESPObjects = {},
    SavedMotorC0 = {},
    XRayParts = {},
    BacktrackHistory = {},
    UIUpdaters = {},
    ActiveSkinModels = {},
    RenderStepNames = {},
    Unhooked = false,
    RaycastBypass = false,
    ManualDir = 0,
    CurrentTargetPart = nil,
    CurrentTargetPlr = nil,
    CurrentAimPos = nil,
    ServerGhostCFrame = CFrame.new(),
    LastAttackData = {Player = nil, Time = 0}
}

local GS = _G.GS

GS.OriginalState = {
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

function GS.TrackConnection(conn)
    if conn then table.insert(GS.Connections, conn) end
    return conn
end

function GS.TrackInstance(inst)
    if inst then table.insert(GS.CreatedInstances, inst) end
    return inst
end

function GS.TrackDrawing(drawObj)
    if drawObj then table.insert(GS.DrawingObjects, drawObj) end
    return drawObj
end

function GS.BindRenderStep(name, priority, fn)
    table.insert(GS.RenderStepNames, name)
    RunService:BindToRenderStep(name, priority, fn)
end

GS.Skeet = {
    OuterBorder = Color3.fromRGB(10, 10, 10),
    InnerBorder = Color3.fromRGB(48, 48, 48),
    MainBg = Color3.fromRGB(16, 16, 16),
    SidebarBg = Color3.fromRGB(11, 11, 11),
    GroupBg = Color3.fromRGB(20, 20, 20),
    GroupBorder = Color3.fromRGB(38, 38, 38),
    ControlBg = Color3.fromRGB(28, 28, 28),
    ControlBorder = Color3.fromRGB(8, 8, 8),
    Accent = Color3.fromRGB(149, 184, 6),
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

GS.HitSounds = {
    ["Skeet"] = "rbxassetid://5447626464",
    ["Neverlose"] = "rbxassetid://8726881116",
    ["Rust"] = "rbxassetid://4764109000",
    ["Bell"] = "rbxassetid://6534947240"
}

GS.Config = {
    -- Tab 1: Rage & Silent Aim
    SilentAim = true,
    DirectClickInvoke = true, -- Гарантированный вызов CreateBeam при клике ЛКМ с пистолетом!
    FixBulletDrop = true,
    TargetRolePriority = "Smart (Role-Based)", -- Smart (Role-Based), Any Closest, Murderer Only
    HitPart = "HumanoidRootPart",
    AutoFire = false,
    Wallbang = true,
    HitChance = 100,
    Prediction = 12,
    FOV = 280,
    ShowFOV = true,
    TargetLine = true,
    DoubleTap = false,
    QuickStop = false,
    QuickPeek = false,
    LogMisses = true,

    AutoStealSheriffGun = false,
    RemoteShootFromSheriff = true,
    BreakSheriffGun = false,

    -- Tab 2: Anti-Aim & Anti-Cheater Desync
    AA_Enabled = false,
    AA_LadderBypass = true,
    AA_Pitch = "Down",
    AA_YawBase = "Local view",
    AA_Yaw = "Spinbot",
    AA_YawJitter = "Center",
    AA_JitterRange = 72,
    AA_SpinSpeed = 55,
    AA_BodyYaw = "Opposite",
    AA_RollLean = 0,
    AA_ManualKeys = false,
    AA_ShowArrows = true,
    AA_DefensiveAir = true,

    Desync_Enabled = false,
    Desync_Mode = "Anti-Silent (CFrame + Vel)",
    Desync_VelocityPattern = "Inverse Prediction",
    Desync_Power = 350,
    Desync_Side = "Jitter",
    Desync_Distance = 7,
    Desync_ShowGhost = true,
    FakeLag = false,
    FakeLagLimit = 4,
    FakeDuck = false,

    -- Tab 3: Legitbot & 1:1 Skinchanger
    SkinChanger = false,
    GunSkinModel = "AWP Sniper",
    GunSkinFinish = "Dragon Lore",
    KnifeSkinModel = "Karambit",
    KnifeSkinFinish = "Doppler Ruby",
    KnifeInspectSpin = true,
    CSGOSounds = true,

    LegitAim = false,
    LegitAimKey = "Always On", -- Поставлено Always On по умолчанию, чтобы сразу видеть доводку!
    LegitSmooth = 12,
    LegitFOV = 160,
    ShowLegitFOV = true,
    LegitVisibleOnly = false,
    LegitTriggerbot = false,
    TriggerbotDelay = 30,
    LegitBacktrack = false,
    BacktrackMS = 220,
    LegitKnifeReach = true,
    KnifeReachDist = 11,
    HitboxExpander = false,
    HitboxSize = 8,
    HitboxTrans = 75,

    -- Tab 4: Visuals & Custom Scope
    ESP_Enabled = true,
    ESP_Box = true,
    ESP_BoxStyle = "Corner",
    ESP_BoxFill = true,
    ESP_Name = true,
    ESP_HealthBar = true,
    ESP_Distance = true,
    ESP_Flags = true,
    ESP_Skeleton = true,
    ESP_OOFArrows = true,
    ESP_OOFRadius = 150,
    Chams = true,
    ChamsAlpha = 55,
    ESP_GunDrop = true,
    ESP_Coins = false,

    Radar2D = true,
    RadarZoom = 18,
    TargetHUD = true,
    MurdererDangerRing = true,
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

    -- Tab 5: Movement & MM2 Utils
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

    -- Tab 6: Murderer
    GuaranteedStabFix = true,
    KillAll = false,
    KnifeAura = false,
    AuraRange = 18,
    SilentKnifeThrow = true,
    AutoEquipKnife = false,
    FakeDead = false,

    SelectedConfigSlot = "Slot 1 (Rage)"
}

GS.DefaultConfigBackup = {}
for k, v in pairs(GS.Config) do GS.DefaultConfigBackup[k] = v end

function GS.GetThemeColor(mode, offset)
    if mode == "Rainbow" then
        return Color3.fromHSV((tick() * 0.30 + (offset or 0)) % 1, 0.75, 1)
    elseif mode == "Cyan" or mode == "Cyber Cyan" then
        return GS.Skeet.Cyan
    elseif mode == "Purple" or mode == "Midnight Purple" then
        return GS.Skeet.Purple
    elseif mode == "Crimson" then
        return GS.Skeet.Murderer
    end
    return GS.Skeet.Accent
end

function GS.GetRole(plr)
    if not plr then return "Innocent" end
    local bp = plr:FindFirstChild("Backpack")
    local ch = plr.Character
    if (bp and bp:FindFirstChild("Knife")) or (ch and ch:FindFirstChild("Knife")) then return "Murderer"
    elseif (bp and bp:FindFirstChild("Gun")) or (ch and ch:FindFirstChild("Gun")) then return "Sheriff" end
    return "Innocent"
end

function GS.FindByRole(r)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and GS.GetRole(p) == r then
            local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 then return p end
        end
    end
    return nil
end

-- ScreenGui Creation
local ScreenGui = GS.TrackInstance(Instance.new("ScreenGui"))
ScreenGui.Name = "gamesense_mm2_modular"
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
GS.ScreenGui = ScreenGui

GS.ColorGrade = GS.TrackInstance(Instance.new("ColorCorrectionEffect"))
GS.ColorGrade.Name = "GS_ColorGrade"
GS.ColorGrade.Parent = Lighting

local HitSoundChannel = GS.TrackInstance(Instance.new("Sound"))
HitSoundChannel.Name = "GS_HitSound"
HitSoundChannel.Parent = SoundService

local WeaponSoundChannel = GS.TrackInstance(Instance.new("Sound"))
WeaponSoundChannel.Name = "GS_WeaponSound"
WeaponSoundChannel.Parent = SoundService

function GS.PlayCSGOWeaponSound(isAWP)
    if GS.Unhooked or not GS.Config.CSGOSounds then return end
    WeaponSoundChannel.SoundId = isAWP and "rbxassetid://6067278314" or "rbxassetid://6534947240"
    WeaponSoundChannel.Volume = 1.6
    WeaponSoundChannel.TimePosition = 0
    WeaponSoundChannel:Play()
end

local LastSoundPlay = 0
function GS.PlayDamageHitSound()
    if GS.Unhooked or not GS.Config.HitSound then return end
    if tick() - LastSoundPlay < 0.07 then return end
    LastSoundPlay = tick()
    HitSoundChannel.SoundId = GS.HitSounds[GS.Config.SoundType] or GS.HitSounds["Skeet"]
    HitSoundChannel.Volume = GS.Config.SoundVol / 2
    HitSoundChannel.TimePosition = 0
    HitSoundChannel:Play()
end

local HitlogHolder = Instance.new("Frame", ScreenGui)
HitlogHolder.Size = UDim2.new(0, 460, 0, 180)
HitlogHolder.Position = UDim2.new(0, 14, 0, 42)
HitlogHolder.BackgroundTransparency = 1
local hlLayout = Instance.new("UIListLayout", HitlogHolder)
hlLayout.Padding = UDim.new(0, 3)

function GS.PushSkeetLog(text, col)
    if GS.Unhooked or not GS.Config.LogMisses then return end
    local row = Instance.new("Frame", HitlogHolder)
    row.Size = UDim2.new(0, #text * 6.8 + 16, 0, 18)
    row.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
    row.BackgroundTransparency = 0.2
    row.BorderSizePixel = 0

    local bar = Instance.new("Frame", row)
    bar.Size = UDim2.new(0, 2, 1, 0)
    bar.BackgroundColor3 = col or GS.Skeet.Accent
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

function GS.SpawnProBulletTracer(origin, targetPos)
    if GS.Unhooked or not GS.Config.BulletTracers then return end
    local dist = (targetPos - origin).Magnitude
    if dist < 1 then return end
    local midCF = CFrame.lookAt(origin, targetPos) * CFrame.new(0, 0, -dist / 2)

    local core = GS.TrackInstance(Instance.new("Part"))
    core.Anchored = true; core.CanCollide = false; core.CanQuery = false; core.CanTouch = false; core.CastShadow = false
    core.Material = Enum.Material.Neon
    core.Color = Color3.new(1, 1, 1)
    core.Transparency = 0.1
    core.Size = Vector3.new(0.05, 0.05, dist)
    core.CFrame = midCF
    core.Parent = Workspace

    local glow = GS.TrackInstance(Instance.new("Part"))
    glow.Anchored = true; glow.CanCollide = false; glow.CanQuery = false; glow.CanTouch = false; glow.CastShadow = false
    glow.Material = Enum.Material.Neon
    glow.Color = GS.Skeet.Accent
    glow.Transparency = 0.55
    glow.Size = Vector3.new(0.14, 0.14, dist)
    glow.CFrame = midCF
    glow.Parent = Workspace

    task.spawn(function()
        for i = 1, 15 do
            if GS.Unhooked then break end
            local alpha = i / 15
            if core.Parent then core.Transparency = 0.1 + alpha * 0.9 end
            if glow.Parent then glow.Transparency = 0.55 + alpha * 0.45 end
            task.wait(0.02)
        end
        if core then core:Destroy() end
        if glow then glow:Destroy() end
    end)
end

function GS.SpawnHitVisuals(pos, plrName, dmg, victimChar)
    if GS.Unhooked then return end
    GS.PlayDamageHitSound()
    if plrName then
        GS.PushSkeetLog(string.format("Hit %s in %s for %d dmg", plrName, string.lower(GS.Config.HitPart), math.floor(dmg or 100)), GS.Skeet.Accent)
    end
    if pos and GS.Config.FloatingDamage then
        task.spawn(function()
            local anchor = GS.TrackInstance(Instance.new("Part"))
            anchor.Anchored = true; anchor.CanCollide = false; anchor.CanQuery = false; anchor.Transparency = 1
            anchor.Size = Vector3.new(0.1, 0.1, 0.1)
            anchor.Position = pos + Vector3.new(math.random(-8, 8) / 10, 1.4, math.random(-8, 8) / 10)
            anchor.Parent = Workspace
            local bb = Instance.new("BillboardGui", anchor)
            bb.AlwaysOnTop = true; bb.Size = UDim2.new(0, 70, 0, 24)
            local txt = Instance.new("TextLabel", bb)
            txt.Size = UDim2.new(1, 0, 1, 0); txt.BackgroundTransparency = 1
            txt.Font = Enum.Font.Code; txt.TextSize = 14; txt.TextColor3 = GS.Skeet.Accent
            txt.TextStrokeTransparency = 0; txt.Text = "-" .. tostring(math.floor(dmg or 100))
            for i = 1, 22 do
                if GS.Unhooked or not anchor.Parent then break end
                anchor.Position = anchor.Position + Vector3.new(0, 0.07, 0)
                txt.TextTransparency = i / 22; txt.TextStrokeTransparency = i / 22
                task.wait(0.025)
            end
            if anchor then anchor:Destroy() end
        end)
    end
    if victimChar and GS.Config.HitChams then
        task.spawn(function()
            local folder = GS.TrackInstance(Instance.new("Model"))
            folder.Name = "GS_HitCham"; folder.Parent = Workspace
            for _, part in ipairs(victimChar:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    local p = Instance.new("Part")
                    p.Size = part.Size; p.CFrame = part.CFrame
                    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CastShadow = false
                    p.Material = Enum.Material.ForceField; p.Color = GS.Skeet.Accent; p.Transparency = 0.35
                    p.Parent = folder
                end
            end
            task.delay(GS.Config.HitChamsDuration, function()
                if folder and folder.Parent then folder:Destroy() end
            end)
        end)
    end
    if GS.Config.HitMarker then
        local mouseLoc = UserInputService:GetMouseLocation()
        local hm = Instance.new("Frame", ScreenGui)
        hm.Size = UDim2.new(0, 16, 0, 16)
        hm.Position = UDim2.new(0, mouseLoc.X - 8, 0, mouseLoc.Y - 8)
        hm.BackgroundTransparency = 1
        for _, rot in ipairs({45, -45}) do
            local line = Instance.new("Frame", hm)
            line.Size = UDim2.new(0, 12, 0, 1)
            line.Position = UDim2.new(0.5, -6, 0.5, 0)
            line.BackgroundColor3 = GS.Skeet.Accent; line.BorderSizePixel = 0; line.Rotation = rot
        end
        task.delay(0.18, function() if hm then hm:Destroy() end end)
    end
    if pos then
        if GS.Config.BulletImpacts then
            local box = GS.TrackInstance(Instance.new("Part"))
            box.Anchored = true; box.CanCollide = false; box.CanQuery = false
            box.Size = Vector3.new(0.32, 0.32, 0.32); box.CFrame = CFrame.new(pos)
            box.Material = Enum.Material.ForceField; box.Color = GS.Skeet.Danger; box.Transparency = 0.2
            box.Parent = Workspace
            task.delay(1.8, function() if box then box:Destroy() end end)
        end
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head") then
            GS.SpawnProBulletTracer(LocalPlayer.Character.Head.Position, pos)
        end
    end
end

local function BindDamageTracker(plr)
    if plr == LocalPlayer then return end
    local function watchChar(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if not hum then return end
        local lastHp = hum.Health
        GS.TrackConnection(hum.HealthChanged:Connect(function(hp)
            if GS.Unhooked then return end
            if hp < lastHp then
                local myChar = LocalPlayer.Character
                local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                local tRoot = char:FindFirstChild("HumanoidRootPart")
                local armed = myChar and (myChar:FindFirstChild("Knife") or myChar:FindFirstChild("Gun"))
                local near = (myRoot and tRoot and (tRoot.Position - myRoot.Position).Magnitude <= 25)
                local shot = (GS.LastAttackData.Player == plr and (tick() - GS.LastAttackData.Time) <= 1.8)
                if (armed and near) or shot then
                    GS.SpawnHitVisuals(tRoot and tRoot.Position or nil, plr.Name, lastHp - hp, char)
                end
            end
            lastHp = hp
        end))
    end
    if plr.Character then task.spawn(watchChar, plr.Character) end
    GS.TrackConnection(plr.CharacterAdded:Connect(watchChar))
end
for _, p in ipairs(Players:GetPlayers()) do BindDamageTracker(p) end
GS.TrackConnection(Players.PlayerAdded:Connect(BindDamageTracker))

GS.TrackConnection(LocalPlayer.Idled:Connect(function()
    if not GS.Unhooked and GS.Config.AntiAFK then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.zero)
        end)
    end
end))

function GS.ClearCustomSkins()
    for tool, mdl in pairs(GS.ActiveSkinModels) do
        if mdl and mdl.Parent then mdl:Destroy() end
        if tool and tool.Parent and tool:FindFirstChild("Handle") then
            tool.Handle.LocalTransparencyModifier = 0
            tool.Handle.Transparency = 0
        end
    end
    table.clear(GS.ActiveSkinModels)
end

function GS.RestoreMotors()
    for motor, c0 in pairs(GS.SavedMotorC0) do
        if motor and motor.Parent then motor.C0 = c0 end
    end
end

function GS.RestoreXRay()
    for part, origTrans in pairs(GS.XRayParts) do
        if part and part.Parent then
            part.LocalTransparencyModifier = origTrans
        end
    end
    table.clear(GS.XRayParts)
end

function GS.FullUnhook()
    if GS.Unhooked then return end
    GS.Unhooked = true

    for _, name in ipairs(GS.RenderStepNames) do
        pcall(function() RunService:UnbindFromRenderStep(name) end)
    end
    table.clear(GS.RenderStepNames)

    for _, c in ipairs(GS.Connections) do
        if c and c.Connected then c:Disconnect() end
    end
    table.clear(GS.Connections)

    if GS.mt and setreadonly then
        pcall(function()
            setreadonly(GS.mt, false)
            if GS.oldNamecall then GS.mt.__namecall = GS.oldNamecall end
            if GS.oldIndex then GS.mt.__index = GS.oldIndex end
            setreadonly(GS.mt, true)
        end)
    end

    GS.RestoreMotors()
    GS.RestoreXRay()
    GS.ClearCustomSkins()

    for _, d in ipairs(GS.DrawingObjects) do
        pcall(function() if d and d.Remove then d:Remove() end end)
    end
    table.clear(GS.DrawingObjects)

    for _, esp in pairs(GS.ESPObjects) do
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
    table.clear(GS.ESPObjects)

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
            hum.WalkSpeed = GS.OriginalState.WalkSpeed
            hum.JumpPower = GS.OriginalState.JumpPower
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

    LocalPlayer.CameraMaxZoomDistance = GS.OriginalState.MaxZoom
    LocalPlayer.CameraMinZoomDistance = GS.OriginalState.MinZoom
    Lighting.Brightness = GS.OriginalState.Brightness
    Lighting.ClockTime = GS.OriginalState.ClockTime
    Lighting.FogEnd = GS.OriginalState.FogEnd
    Lighting.FogStart = GS.OriginalState.FogStart
    Lighting.FogColor = GS.OriginalState.FogColor
    Lighting.GlobalShadows = GS.OriginalState.GlobalShadows
    Lighting.Ambient = GS.OriginalState.Ambient
    Lighting.OutdoorAmbient = GS.OriginalState.OutdoorAmbient
    Camera.FieldOfView = GS.OriginalState.CameraFOV

    for _, inst in ipairs(GS.CreatedInstances) do
        pcall(function() if inst then inst:Destroy() end end)
    end
    table.clear(GS.CreatedInstances)
end
