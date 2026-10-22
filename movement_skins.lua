-- File: movement_skins.lua | Pro HvH Movement (Fly, Dash, ClickTP, Spider, Moonwalk) + StatTrak 1:1 CS:GO Skinchanger
local GS = _G.GS
if not GS then return end

local Players = GS.Players
local RunService = GS.RunService
local UserInputService = GS.UserInputService
local Workspace = GS.Workspace
local Camera = GS.Camera
local LocalPlayer = GS.LocalPlayer
local LocalMouse = GS.LocalMouse
local Config = GS.Config
local Skeet = GS.Skeet

-- Расширяем конфиг новыми функциями Мувмента и Скинов
local MovementSkinDefaults = {
    -- New Movement Features
    Fly_Enabled = false,
    Fly_Speed = 55,
    Dash_Enabled = true,       -- Рывок вперёд по направлению камеры на клавишу [Q]
    Dash_Power = 18,
    Dash_Cooldown = 1,
    ClickTP = true,            -- Телепорт в точку курсора по [LeftCtrl + ЛКМ]
    SpiderClimb = true,        -- Лазание по любым вертикальным стенам как по лестнице
    SpiderSpeed = 26,
    Moonwalk = false,          -- Персонаж идёт спиной вперёд / скользит боком при обычной ходьбе
    LowGravity = false,        -- Лунная гравитация для длинных стрейф-прыжков
    GravityVal = 85,           -- Стандарт 196.2
    AntiVoid = true,           -- Спасает от падения за карту (телепортирует обратно наверх)
    TargetStrafe = false,      -- Автоматическое вращение вокруг текущей цели Silent Aim

    -- New Skinchanger Features
    SkinChanger = true,
    GunSkinModel = "AWP Sniper",       -- AWP Sniper, AK-47 Kalash, M4A1-S Silencer, SSG-08 Scout, Desert Eagle
    GunSkinFinish = "Dragon Lore",     -- Dragon Lore, Asiimov, Fade, Gungnir, Printstream, Chroma Wave (Animated)
    KnifeSkinModel = "Karambit",       -- Karambit, Butterfly Knife, M9 Bayonet, Talon Knife, Skeleton Knife
    KnifeSkinFinish = "Doppler Ruby",  -- Doppler Ruby, Sapphire, Emerald, Fade, Case Hardened Blue Gem, Chroma Wave (Animated)
    StatTrakCounter = true,            -- 3D цифровой LED-счётчик убийств прямо сбоку оружия как в CS:GO!
    StatTrakKills = 67,                -- Начальное число на счётчике StatTrak (увеличивается при каждом хите/килле!)
    WeaponBladeTrail = true,           -- Неоновый шлейф за клинком ножа и стволом AWP
    WeaponSparkles = false,            -- Эффект искр/энергии вокруг кастомного оружия
    KnifeInspectSpin = true,           -- Анимация осмотра и вращения ножа на пальце по клавише [F]
    CustomViewmodelOffset = false,     -- Сдвиг оружия в руках (FOV рук)
    ViewmodelX = 0,
    ViewmodelY = 0,
    ViewmodelZ = 0
}

for k, v in pairs(MovementSkinDefaults) do
    if Config[k] == nil then Config[k] = v end
    if GS.DefaultConfigBackup and GS.DefaultConfigBackup[k] == nil then
        GS.DefaultConfigBackup[k] = v
    end
end

local RealClientCFrame = nil
local RealClientVelocity = Vector3.zero
local DesyncFlip = false
local DesyncOrbitAngle = 0
local ChokeTick = 0
local LastGunBreakTick = 0
local InspectingUntil = 0
local SpinYaw = 0
local JitterStep = 1
local CircleAngle = 0
local LastDashTime = 0
local LastSafeGroundPos = nil
local MotorsDirty = false
local AnimatedSkinParts = {}
local StatTrakLabels = {}

-------------------------------------------------------------------------
-- ПАЛИТРЫ CS:GO СКИНОВ + АНИМИРОВАННЫЙ CHROMA WAVE
-------------------------------------------------------------------------
local function GetDetailedSkinPalette(finish)
    if finish == "Chroma Wave (Animated)" then
        local c1 = Color3.fromHSV((tick() * 0.25) % 1, 0.85, 1)
        local c2 = Color3.fromHSV(((tick() * 0.25) + 0.35) % 1, 0.85, 1)
        return {Chassis = c1, Art = c2, Trim = Color3.fromRGB(20, 20, 25), Metal = Color3.fromRGB(18, 18, 22), Lens = c2, Mat = Enum.Material.Glass, Animated = true}
    elseif finish == "Dragon Lore" or finish == "Lore" then
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
-- МИКРО-СБОРЩИК 3D ДЕТАЛЕЙ + STATTRAK™ МОДУЛЬ + TRAIL ШЛЕЙФЫ
-------------------------------------------------------------------------
local function AddMicroPart(model, handle, sizeVec, offsetCF, color, mat, meshKind, isAnimatedTag)
    local p = Instance.new("Part")
    p.Size = Vector3.new(0.2, 0.2, 0.2)
    p.Color = color
    p.Material = mat or Enum.Material.Metal
    p.Reflectance = (mat == Enum.Material.Glass or mat == Enum.Material.Metal) and 0.18 or 0
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.Massless = true
    p.Anchored = false
    p.CastShadow = false

    local sm = Instance.new("SpecialMesh", p)
    if meshKind == "Cylinder" then sm.MeshType = Enum.MeshType.Cylinder
    elseif meshKind == "Wedge" then sm.MeshType = Enum.MeshType.Wedge
    elseif meshKind == "Sphere" then sm.MeshType = Enum.MeshType.Sphere
    else sm.MeshType = Enum.MeshType.Brick end
    sm.Scale = sizeVec * 5

    p.CFrame = handle.CFrame * offsetCF
    p.Parent = model

    local m6d = Instance.new("Motor6D")
    m6d.Part0 = handle
    m6d.Part1 = p
    m6d.C0 = offsetCF
    m6d.Parent = p

    if isAnimatedTag then
        table.insert(AnimatedSkinParts, {Part = p, Role = isAnimatedTag})
    end
    return p
end

-- Создаёт настоящий 3D цифровой модуль StatTrak™ с оранжевым LED-дисплеем сбоку оружия!
local function AttachStatTrakModule(model, handle, offsetCF)
    if not Config.StatTrakCounter then return end
    local box = AddMicroPart(model, handle, Vector3.new(0.06, 0.14, 0.28), offsetCF, Color3.fromRGB(20, 20, 24), Enum.Material.Metal, "Brick")
    local screen = AddMicroPart(model, handle, Vector3.new(0.065, 0.10, 0.24), offsetCF, Color3.fromRGB(8, 8, 10), Enum.Material.SmoothPlastic, "Brick")

    local sGui = Instance.new("SurfaceGui", screen)
    sGui.Face = Enum.NormalId.Left
    sGui.AlwaysOnTop = true
    sGui.LightInfluence = 0
    sGui.CanvasSize = Vector2.new(120, 50)

    local lbl = Instance.new("TextLabel", sGui)
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Code
    lbl.TextScaled = true
    lbl.TextColor3 = Color3.fromRGB(255, 115, 20) -- Фирменный оранжевый цвет CS:GO StatTrak™
    lbl.Text = string.format("%06d", Config.StatTrakKills or 67)
    table.insert(StatTrakLabels, lbl)

    -- Дублируем дисплей на правую грань на случай инверсии рук
    local sGuiR = sGui:Clone()
    sGuiR.Face = Enum.NormalId.Right
    sGuiR.Parent = screen
    table.insert(StatTrakLabels, sGuiR:FindFirstChildOfClass("TextLabel"))
end

-- Добавляет неоновый шлейф (Trail) и искры (Sparkles) к оружию
local function AttachWeaponEffects(targetPart, color)
    if Config.WeaponBladeTrail then
        local a0 = Instance.new("Attachment", targetPart)
        a0.Position = Vector3.new(0, 0.45, 0)
        local a1 = Instance.new("Attachment", targetPart)
        a1.Position = Vector3.new(0, -0.45, 0)
        local tr = Instance.new("Trail", targetPart)
        tr.Attachment0 = a0
        tr.Attachment1 = a1
        tr.Lifetime = 0.22
        tr.LightEmission = 1
        tr.Color = ColorSequence.new(color)
        tr.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1)})
    end
    if Config.WeaponSparkles then
        local sp = Instance.new("Sparkles", targetPart)
        sp.SparkleColor = color
    end
end

-------------------------------------------------------------------------
-- СБОРКА ОРУЖИЯ: AWP, AK-47, M4A1-S, SSG-08, DEAGLE
-------------------------------------------------------------------------
function GS.ApplyAWPSkinToGun(gunTool)
    if not gunTool or not gunTool:FindFirstChild("Handle") then return end
    local handle = gunTool.Handle
    local tag = Config.GunSkinModel .. "_" .. Config.GunSkinFinish .. "_" .. tostring(Config.StatTrakCounter) .. "_" .. tostring(Config.WeaponBladeTrail)
    if GS.ActiveSkinModels[gunTool] and GS.ActiveSkinModels[gunTool].Name == "GS_Skin_" .. tag and GS.ActiveSkinModels[gunTool].Parent == gunTool then
        handle.LocalTransparencyModifier = 1
        return
    end
    if GS.ActiveSkinModels[gunTool] then GS.ActiveSkinModels[gunTool]:Destroy() end

    handle.LocalTransparencyModifier = 1
    local pal = GetDetailedSkinPalette(Config.GunSkinFinish)
    local mdl = GS.TrackInstance(Instance.new("Model"))
    mdl.Name = "GS_Skin_" .. tag
    mdl.Parent = gunTool

    if Config.GunSkinModel == "Desert Eagle" then
        local slide = AddMicroPart(mdl, handle, Vector3.new(0.18, 0.26, 1.38), CFrame.new(0, 0.20, -0.38), pal.Chassis, pal.Mat, "Brick", "Chassis")
        AddMicroPart(mdl, handle, Vector3.new(0.14, 0.12, 1.36), CFrame.new(0, 0.36, -0.38), pal.Art, Enum.Material.Neon, "Brick", "Art")
        AddMicroPart(mdl, handle, Vector3.new(0.16, 0.68, 0.30), CFrame.new(0, -0.18, 0.16) * CFrame.Angles(math.rad(-16), 0, 0), pal.Metal, Enum.Material.SmoothPlastic, "Brick")
        AttachStatTrakModule(mdl, handle, CFrame.new(-0.10, 0.18, -0.25))
        AttachWeaponEffects(slide, pal.Art)

    elseif Config.GunSkinModel == "AK-47 Kalash" then
        -- 1:1 CS:GO AK-47 (Ресивер, Деревянное/Кастомное цевьё, Газовая трубка, Изогнутый рожок "Банан", Приклад и Мушка)
        AddMicroPart(mdl, handle, Vector3.new(0.18, 0.28, 1.55), CFrame.new(0, 0.12, -0.35), pal.Chassis, pal.Mat, "Brick", "Chassis")
        AddMicroPart(mdl, handle, Vector3.new(0.19, 0.14, 1.45), CFrame.new(0, 0.20, -0.35), pal.Art, Enum.Material.Neon, "Brick", "Art")
        -- Цевьё и газовая трубка
        AddMicroPart(mdl, handle, Vector3.new(0.20, 0.22, 0.95), CFrame.new(0, 0.14, -1.55), pal.Trim, pal.Mat, "Brick")
        AddMicroPart(mdl, handle, Vector3.new(0.85, 0.10, 0.10), CFrame.new(0, 0.28, -1.55) * CFrame.Angles(0, math.rad(90), 0), pal.Metal, Enum.Material.Metal, "Cylinder")
        -- Ствол и мушка AK-47
        local barrel = AddMicroPart(mdl, handle, Vector3.new(1.65, 0.09, 0.09), CFrame.new(0, 0.16, -2.55) * CFrame.Angles(0, math.rad(90), 0), pal.Metal, Enum.Material.Metal, "Cylinder")
        AddMicroPart(mdl, handle, Vector3.new(0.08, 0.24, 0.12), CFrame.new(0, 0.26, -3.15), pal.Metal, Enum.Material.Metal, "Brick")
        -- Изогнутый рожок AK-47 ( из 3 сегментов )
        AddMicroPart(mdl, handle, Vector3.new(0.14, 0.38, 0.26), CFrame.new(0, -0.18, -0.58) * CFrame.Angles(math.rad(16), 0, 0), pal.Art, pal.Mat, "Brick", "Art")
        AddMicroPart(mdl, handle, Vector3.new(0.14, 0.38, 0.25), CFrame.new(0, -0.48, -0.72) * CFrame.Angles(math.rad(34), 0, 0), pal.Chassis, pal.Mat, "Brick", "Chassis")
        -- Приклад и пистолетная рукоять
        AddMicroPart(mdl, handle, Vector3.new(0.17, 0.38, 1.05), CFrame.new(0, 0.02, 0.90) * CFrame.Angles(math.rad(-6), 0, 0), pal.Chassis, pal.Mat, "Brick", "Chassis")
        AddMicroPart(mdl, handle, Vector3.new(0.15, 0.48, 0.24), CFrame.new(0, -0.20, 0.15) * CFrame.Angles(math.rad(-18), 0, 0), pal.Metal, Enum.Material.SmoothPlastic, "Brick")
        AttachStatTrakModule(mdl, handle, CFrame.new(-0.11, 0.14, -0.45))
        AttachWeaponEffects(barrel, pal.Art)

    elseif Config.GunSkinModel == "M4A1-S Silencer" then
        -- 1:1 CS:GO M4A1-S (Карабин с длинным глушителем, ручкой переноски и телескопическим прикладом)
        AddMicroPart(mdl, handle, Vector3.new(0.18, 0.28, 1.45), CFrame.new(0, 0.12, -0.30), pal.Chassis, pal.Mat, "Brick", "Chassis")
        AddMicroPart(mdl, handle, Vector3.new(0.19, 0.10, 1.35), CFrame.new(0, 0.16, -0.30), pal.Art, Enum.Material.Neon, "Brick", "Art")
        -- Цевьё с планками Пикатинни
        AddMicroPart(mdl, handle, Vector3.new(0.20, 0.22, 1.05), CFrame.new(0, 0.16, -1.50) * CFrame.Angles(0, math.rad(90), 0), pal.Trim, Enum.Material.Metal, "Cylinder")
        -- Фирменный массивный глушитель M4A1-S
        local supp = AddMicroPart(mdl, handle, Vector3.new(1.55, 0.16, 0.16), CFrame.new(0, 0.16, -2.95) * CFrame.Angles(0, math.rad(90), 0), pal.Metal, Enum.Material.Metal, "Cylinder")
        AddMicroPart(mdl, handle, Vector3.new(0.15, 0.18, 0.18), CFrame.new(0, 0.16, -2.35) * CFrame.Angles(0, math.rad(90), 0), pal.Art, Enum.Material.Neon, "Cylinder", "Art")
        -- Магазин STANAG и телескопический приклад
        AddMicroPart(mdl, handle, Vector3.new(0.13, 0.55, 0.26), CFrame.new(0, -0.25, -0.45) * CFrame.Angles(math.rad(8), 0, 0), pal.Metal, Enum.Material.Metal, "Brick")
        AddMicroPart(mdl, handle, Vector3.new(0.16, 0.42, 0.85), CFrame.new(0, 0.08, 0.85), pal.Chassis, pal.Mat, "Brick", "Chassis")
        AttachStatTrakModule(mdl, handle, CFrame.new(-0.11, 0.14, -0.35))
        AttachWeaponEffects(supp, pal.Art)

    else
        -- 1:1 CS:GO AWP / SSG-08 SNIPER
        local lenScale = (Config.GunSkinModel == "SSG-08 Scout") and 0.86 or 1.0
        AddMicroPart(mdl, handle, Vector3.new(0.20, 0.30, 2.35 * lenScale), CFrame.new(0, 0.08, -0.75 * lenScale), pal.Chassis, pal.Mat, "Brick", "Chassis")
        AddMicroPart(mdl, handle, Vector3.new(0.215, 0.12, 2.10 * lenScale), CFrame.new(0, 0.11, -0.70 * lenScale), pal.Art, Enum.Material.Neon, "Brick", "Art")
        AddMicroPart(mdl, handle, Vector3.new(0.18, 0.14, 1.15), CFrame.new(0, 0.14, 0.92), pal.Chassis, pal.Mat, "Brick", "Chassis")
        AddMicroPart(mdl, handle, Vector3.new(0.18, 0.11, 1.15), CFrame.new(0, -0.18, 0.92) * CFrame.Angles(math.rad(6), 0, 0), pal.Chassis, pal.Mat, "Brick", "Chassis")
        AddMicroPart(mdl, handle, Vector3.new(0.18, 0.44, 0.52), CFrame.new(0, -0.01, 1.38), pal.Chassis, pal.Mat, "Brick", "Chassis")
        AddMicroPart(mdl, handle, Vector3.new(0.20, 0.12, 0.62), CFrame.new(0, 0.24, 1.12), pal.Trim, Enum.Material.SmoothPlastic, "Brick")
        AddMicroPart(mdl, handle, Vector3.new(0.14, 0.42, 0.48), CFrame.new(0, -0.22, -0.35), pal.Metal, Enum.Material.Metal, "Brick")
        local barrel = AddMicroPart(mdl, handle, Vector3.new(3.15 * lenScale, 0.11, 0.11), CFrame.new(0, 0.26, -2.35 * lenScale) * CFrame.Angles(0, math.rad(90), 0), pal.Metal, Enum.Material.Metal, "Cylinder")
        AddMicroPart(mdl, handle, Vector3.new(0.18, 0.18, 0.42), CFrame.new(0, 0.26, -4.02 * lenScale), pal.Metal, Enum.Material.Metal, "Brick")
        AddMicroPart(mdl, handle, Vector3.new(1.45, 0.16, 0.16), CFrame.new(0, 0.56, -0.32) * CFrame.Angles(0, math.rad(90), 0), pal.Metal, Enum.Material.Metal, "Cylinder")
        AddMicroPart(mdl, handle, Vector3.new(0.48, 0.28, 0.28), CFrame.new(0, 0.56, -1.18) * CFrame.Angles(0, math.rad(90), 0), pal.Trim, Enum.Material.Metal, "Cylinder")
        AddMicroPart(mdl, handle, Vector3.new(0.36, 0.24, 0.24), CFrame.new(0, 0.56, 0.48) * CFrame.Angles(0, math.rad(90), 0), pal.Trim, Enum.Material.Metal, "Cylinder")
        AddMicroPart(mdl, handle, Vector3.new(0.05, 0.24, 0.24), CFrame.new(0, 0.56, -1.41) * CFrame.Angles(0, math.rad(90), 0), pal.Lens, Enum.Material.Neon, "Cylinder", "Art")
        AttachStatTrakModule(mdl, handle, CFrame.new(-0.12, 0.12, -0.55))
        AttachWeaponEffects(barrel, pal.Art)
    end

    GS.ActiveSkinModels[gunTool] = mdl
end

-------------------------------------------------------------------------
-- СБОРКА НОЖЕЙ: KARAMBIT, BUTTERFLY, M9 BAYONET, TALON, SKELETON
-------------------------------------------------------------------------
function GS.ApplyCSGOKnifeSkin(knifeTool)
    if not knifeTool or not knifeTool:FindFirstChild("Handle") then return end
    local handle = knifeTool.Handle
    local tag = Config.KnifeSkinModel .. "_" .. Config.KnifeSkinFinish .. "_" .. tostring(Config.StatTrakCounter) .. "_" .. tostring(Config.WeaponBladeTrail)
    if GS.ActiveSkinModels[knifeTool] and GS.ActiveSkinModels[knifeTool].Name == "GS_Skin_" .. tag and GS.ActiveSkinModels[knifeTool].Parent == knifeTool then
        handle.LocalTransparencyModifier = 1
        return
    end
    if GS.ActiveSkinModels[knifeTool] then GS.ActiveSkinModels[knifeTool]:Destroy() end

    handle.LocalTransparencyModifier = 1
    local pal = GetDetailedSkinPalette(Config.KnifeSkinFinish)
    local mdl = GS.TrackInstance(Instance.new("Model"))
    mdl.Name = "GS_Skin_" .. tag
    mdl.Parent = knifeTool

    local tipPart = nil

    if Config.KnifeSkinModel == "Karambit" or Config.KnifeSkinModel == "Talon Knife" then
        local isTalon = (Config.KnifeSkinModel == "Talon Knife")
        local gripCol = isTalon and Color3.fromRGB(235, 225, 200) or pal.Metal -- Слоновая кость у Talon Knife!
        AddMicroPart(mdl, handle, Vector3.new(0.09, 0.36, 0.36), CFrame.new(0, -0.62, 0.14), pal.Chassis, Enum.Material.Metal, "Cylinder", "Chassis")
        AddMicroPart(mdl, handle, Vector3.new(0.11, 0.24, 0.24), CFrame.new(0, -0.62, 0.14), Color3.fromRGB(10, 10, 12), Enum.Material.SmoothPlastic, "Cylinder")
        AddMicroPart(mdl, handle, Vector3.new(0.11, 0.62, 0.22), CFrame.new(0, -0.14, 0.06) * CFrame.Angles(math.rad(10), 0, 0), gripCol, Enum.Material.SmoothPlastic, "Brick")
        for i = 1, 6 do
            local prog = i / 6
            local angleRad = math.rad(-14 - (prog * 74))
            local radius = 0.72
            local yPos = 0.18 + math.sin(prog * 1.35) * radius
            local zPos = -0.02 - (1 - math.cos(prog * 1.35)) * radius
            local width = (isTalon and 0.30 or 0.25) * (1 - prog * 0.65)
            tipPart = AddMicroPart(mdl, handle, Vector3.new(0.035, 0.18, width), CFrame.new(0, yPos, zPos) * CFrame.Angles(angleRad, 0, 0), pal.Chassis, Enum.Material.Neon, "Wedge", "Chassis")
        end

    elseif Config.KnifeSkinModel == "Butterfly Knife" then
        AddMicroPart(mdl, handle, Vector3.new(0.08, 0.82, 0.12), CFrame.new(0, -0.24, -0.09), pal.Metal, Enum.Material.Metal, "Brick")
        AddMicroPart(mdl, handle, Vector3.new(0.08, 0.82, 0.12), CFrame.new(0, -0.24, 0.09), pal.Metal, Enum.Material.Metal, "Brick")
        AddMicroPart(mdl, handle, Vector3.new(0.035, 1.15, 0.22), CFrame.new(0, 0.82, 0), pal.Chassis, Enum.Material.Neon, "Brick", "Chassis")
        tipPart = AddMicroPart(mdl, handle, Vector3.new(0.035, 0.34, 0.22), CFrame.new(0, 1.48, 0) * CFrame.Angles(0, math.rad(180), 0), pal.Art, Enum.Material.Neon, "Wedge", "Art")

    elseif Config.KnifeSkinModel == "Skeleton Knife" then
        AddMicroPart(mdl, handle, Vector3.new(0.07, 0.65, 0.20), CFrame.new(0, -0.32, 0), pal.Metal, Enum.Material.SmoothPlastic, "Brick")
        AddMicroPart(mdl, handle, Vector3.new(0.08, 0.40, 0.40), CFrame.new(0, 0.12, 0), pal.Chassis, Enum.Material.Metal, "Cylinder", "Chassis")
        AddMicroPart(mdl, handle, Vector3.new(0.10, 0.25, 0.25), CFrame.new(0, 0.12, 0), Color3.fromRGB(10, 10, 12), Enum.Material.SmoothPlastic, "Cylinder")
        AddMicroPart(mdl, handle, Vector3.new(0.04, 1.05, 0.28), CFrame.new(0, 0.78, 0), pal.Chassis, Enum.Material.Neon, "Brick", "Chassis")
        tipPart = AddMicroPart(mdl, handle, Vector3.new(0.04, 0.38, 0.28), CFrame.new(0, 1.48, 0), pal.Art, Enum.Material.Neon, "Wedge", "Art")

    else
        AddMicroPart(mdl, handle, Vector3.new(0.82, 0.22, 0.22), CFrame.new(0, -0.26, 0) * CFrame.Angles(0, 0, math.rad(90)), pal.Metal, Enum.Material.SmoothPlastic, "Cylinder")
        AddMicroPart(mdl, handle, Vector3.new(0.16, 0.10, 0.56), CFrame.new(0, 0.18, 0.04), pal.Metal, Enum.Material.Metal, "Brick")
        AddMicroPart(mdl, handle, Vector3.new(0.04, 1.25, 0.28), CFrame.new(0, 0.85, 0), pal.Chassis, Enum.Material.Neon, "Brick", "Chassis")
        tipPart = AddMicroPart(mdl, handle, Vector3.new(0.04, 0.36, 0.28), CFrame.new(0, 1.62, 0) * CFrame.Angles(0, math.rad(180), 0), pal.Art, Enum.Material.Neon, "Wedge", "Art")
    end

    AttachStatTrakModule(mdl, handle, CFrame.new(-0.06, 0.45, 0))
    if tipPart then AttachWeaponEffects(tipPart, pal.Art) end

    GS.ActiveSkinModels[knifeTool] = mdl
end

-- Возврат клиентского CFrame перед рендером камеры (0% тряски при десинке!)
GS.BindRenderStep("GS_DesyncRestore", Enum.RenderPriority.Camera.Value - 1, function()
    if GS.Unhooked then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and RealClientCFrame then
        hrp.CFrame = RealClientCFrame
        hrp.AssemblyLinearVelocity = RealClientVelocity
        RealClientCFrame = nil
    end
end)

local function IsClimbingLadder(char, hum, hrp)
    if not Config.AA_LadderBypass then return false end
    if hum:GetState() == Enum.HumanoidStateType.Climbing then return true end
    GS.RaycastBypass = true
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char, Camera}
    local hit = Workspace:Raycast(hrp.Position, hrp.CFrame.LookVector * 2.2, params)
    GS.RaycastBypass = false
    return (hit and hit.Instance and hit.Instance:IsA("TrussPart")) or false
end

-------------------------------------------------------------------------
-- HEARTBEAT: ДЕСИНК, СКИНЧЕНДЖЕР, АНИМАЦИЯ CHROMA WAVE И STATTRAK
-------------------------------------------------------------------------
local LastKnownAttackTime = 0

GS.TrackConnection(RunService.Heartbeat:Connect(function(dt)
    if GS.Unhooked then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not char or not hum or not hrp or hum.Health <= 0 then return end

    -- Авто-увеличение счётчика StatTrak™ при каждом попадании/убийстве!
    if GS.LastAttackData and GS.LastAttackData.Time > LastKnownAttackTime then
        LastKnownAttackTime = GS.LastAttackData.Time
        Config.StatTrakKills = (Config.StatTrakKills or 67) + 1
        for _, lbl in ipairs(StatTrakLabels) do
            if lbl and lbl.Parent then
                lbl.Text = string.format("%06d", Config.StatTrakKills)
            end
        end
    end

    -- Обновление анимированного скина Chroma Wave
    if Config.GunSkinFinish == "Chroma Wave (Animated)" or Config.KnifeSkinFinish == "Chroma Wave (Animated)" then
        local c1 = Color3.fromHSV((tick() * 0.28) % 1, 0.85, 1)
        local c2 = Color3.fromHSV(((tick() * 0.28) + 0.35) % 1, 0.85, 1)
        for i = #AnimatedSkinParts, 1, -1 do
            local item = AnimatedSkinParts[i]
            if item.Part and item.Part.Parent then
                item.Part.Color = (item.Role == "Art") and c2 or c1
            else
                table.remove(AnimatedSkinParts, i)
            end
        end
    end

    if Config.AutoStealSheriffGun and GS.GetRole(LocalPlayer) == "Innocent" then
        if not char:FindFirstChild("Gun") and not (LocalPlayer:FindFirstChild("Backpack") and LocalPlayer.Backpack:FindFirstChild("Gun")) then
            GS.StealGunFromLivingSheriff()
        end
    end

    if Config.BreakSheriffGun and (tick() - LastGunBreakTick) > 0.25 then
        LastGunBreakTick = tick()
        local liveGun = GS.FindLivingSheriffGun()
        local rem = GS.FindGunShootRemote(liveGun)
        if rem then
            task.spawn(function() pcall(function() rem:InvokeServer(1, 0, "AH2") end) end)
        end
    end

    if Config.SkinChanger then
        local myGun = char:FindFirstChild("Gun") or (LocalPlayer:FindFirstChild("Backpack") and LocalPlayer.Backpack:FindFirstChild("Gun"))
        if myGun then GS.ApplyAWPSkinToGun(myGun) end
        local myKnife = char:FindFirstChild("Knife") or (LocalPlayer:FindFirstChild("Backpack") and LocalPlayer.Backpack:FindFirstChild("Knife"))
        if myKnife then GS.ApplyCSGOKnifeSkin(myKnife) end

        -- Анимация осмотра и вращения ножа/пистолета на клавишу [F] + Viewmodel Offset
        local rGrip = char:FindFirstChild("RightGrip", true)
        if rGrip and (rGrip:IsA("Motor6D") or rGrip:IsA("Weld")) then
            if not GS.SavedMotorC0[rGrip] then GS.SavedMotorC0[rGrip] = rGrip.C0 end
            local vmOffset = Config.CustomViewmodelOffset
                and CFrame.new(Config.ViewmodelX / 10, Config.ViewmodelY / 10, Config.ViewmodelZ / 10)
                or CFrame.new()
            if tick() < InspectingUntil and Config.KnifeInspectSpin then
                rGrip.C0 = GS.SavedMotorC0[rGrip] * vmOffset * CFrame.Angles(math.rad((tick() * 820) % 360), 0, 0)
            else
                rGrip.C0 = GS.SavedMotorC0[rGrip] * vmOffset
            end
        end
    end

    -- Запоминаем последнюю безопасную точку на земле для Anti-Void
    if hum.FloorMaterial ~= Enum.Material.Air then
        LastSafeGroundPos = hrp.Position
    elseif Config.AntiVoid and hrp.Position.Y < -65 and LastSafeGroundPos then
        hrp.CFrame = CFrame.new(LastSafeGroundPos + Vector3.new(0, 5, 0))
        hrp.AssemblyLinearVelocity = Vector3.zero
        GS.PushSkeetLog("Anti-Void: Спасён от падения за карту!", Skeet.Accent)
    end

    local now = tick()
    local maxAge = Config.BacktrackMS / 1000
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            GS.BacktrackHistory[plr] = GS.BacktrackHistory[plr] or {}
            table.insert(GS.BacktrackHistory[plr], {Time = now, Pos = plr.Character.HumanoidRootPart.Position})
            while #GS.BacktrackHistory[plr] > 0 and (now - GS.BacktrackHistory[plr][1].Time) > maxAge do
                table.remove(GS.BacktrackHistory[plr], 1)
            end
        end
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
            if Config.Desync_Side == "Left" then worldOffset = -RealClientCFrame.RightVector * dist
            elseif Config.Desync_Side == "Right" then worldOffset = RealClientCFrame.RightVector * dist
            elseif Config.Desync_Side == "Behind" then worldOffset = -RealClientCFrame.LookVector * dist
            elseif Config.Desync_Side == "Jitter" then worldOffset = RealClientCFrame.RightVector * (DesyncFlip and dist or -dist)
            elseif Config.Desync_Side == "Orbit" then worldOffset = Vector3.new(math.cos(DesyncOrbitAngle) * dist, 0, math.sin(DesyncOrbitAngle) * dist) end
        end

        local pwr = Config.Desync_Power
        local spoofVel = RealClientVelocity
        if Config.Desync_VelocityPattern == "Inverse Prediction" then
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
            GS.ServerGhostCFrame = RealClientCFrame + worldOffset
            hrp.CFrame = GS.ServerGhostCFrame
        else
            GS.ServerGhostCFrame = RealClientCFrame + (spoofVel.Unit * math.min(dist, 8))
        end

        hrp.AssemblyLinearVelocity = spoofVel
    else
        RealClientCFrame = nil
    end
end))

-------------------------------------------------------------------------
-- БИНДЫ ДЛЯ НОВЫХ МУВМЕНТ-ФИШЕК: [F] INSPECT, [Q] PHASE DASH, [V] FLY, [CTRL+CLICK] TP
-------------------------------------------------------------------------
GS.TrackConnection(UserInputService.InputBegan:Connect(function(inp, gp)
    if gp or GS.Unhooked then return end
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myChar or not myRoot then return end

    if inp.KeyCode == Enum.KeyCode.F and Config.SkinChanger and Config.KnifeInspectSpin then
        InspectingUntil = tick() + 1.35
    elseif inp.KeyCode == Enum.KeyCode.V then
        Config.Fly_Enabled = not Config.Fly_Enabled
        GS.PushSkeetLog("Camera Fly [V]: " .. (Config.Fly_Enabled and "ON" or "OFF"), Config.Fly_Enabled and Skeet.Accent or Skeet.Danger)
        for _, fn in ipairs(GS.UIUpdaters) do pcall(fn) end
    elseif inp.KeyCode == Enum.KeyCode.Q and Config.Dash_Enabled then
        if (tick() - LastDashTime) >= Config.Dash_Cooldown then
            LastDashTime = tick()
            local lookDir = Camera.CFrame.LookVector
            local dashPos = myRoot.Position + (lookDir * Config.Dash_Power)
            myRoot.CFrame = CFrame.new(dashPos, dashPos + Vector3.new(lookDir.X, 0, lookDir.Z))
            GS.SpawnProBulletTracer(myRoot.Position - (lookDir * Config.Dash_Power), myRoot.Position)
        end
    elseif inp.UserInputType == Enum.UserInputType.MouseButton1 and Config.ClickTP then
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
            local targetPos = GS.GetExactCrosshairWorldPoint()
            if targetPos then
                myRoot.CFrame = CFrame.new(targetPos + Vector3.new(0, 3.2, 0))
                GS.PushSkeetLog("Click-TP: Mгновенный телепорт в точку прицела!", Skeet.Cyan)
            end
        end
    end
end))

-------------------------------------------------------------------------
-- RENDERSTEPPED: FLY, SPIDER CLIMB, MOONWALK, TARGET STRAFE & ANTI-AIM
-------------------------------------------------------------------------
GS.TrackConnection(RunService.RenderStepped:Connect(function(dt)
    if GS.Unhooked then return end
    local myChar = LocalPlayer.Character
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myChar or not myHum or not myRoot or myHum.Health <= 0 then return end

    -- 1. Lунная гравитация (Low Gravity)
    Workspace.Gravity = Config.LowGravity and Config.GravityVal or 196.2

    -- 2. Полноценный Camera Fly (Полет через WASD + Space / LeftShift)
    if Config.Fly_Enabled then
        local flyVec = Vector3.zero
        local camCF = Camera.CFrame
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then flyVec = flyVec + camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then flyVec = flyVec - camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then flyVec = flyVec - camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then flyVec = flyVec + camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then flyVec = flyVec + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then flyVec = flyVec - Vector3.new(0, 1, 0) end

        myRoot.AssemblyLinearVelocity = Vector3.zero
        if flyVec.Magnitude > 0 then
            myRoot.CFrame = myRoot.CFrame + (flyVec.Unit * (Config.Fly_Speed * dt))
        end
    end

    -- 3. Spider Wall-Climb (Лазание по любым вертикальным стенам как Человек-Паук)
    if Config.SpiderClimb and myHum.MoveDirection.Magnitude > 0 and not Config.Fly_Enabled then
        GS.RaycastBypass = true
        local spParams = RaycastParams.new()
        spParams.FilterType = Enum.RaycastFilterType.Exclude
        spParams.FilterDescendantsInstances = {myChar, Camera}
        local wallHit = Workspace:Raycast(myRoot.Position, myHum.MoveDirection * 2.4, spParams)
        GS.RaycastBypass = false
        if wallHit and wallHit.Instance and wallHit.Instance.CanCollide then
            myRoot.AssemblyLinearVelocity = Vector3.new(myRoot.AssemblyLinearVelocity.X, Config.SpiderSpeed, myRoot.AssemblyLinearVelocity.Z)
        end
    end

    -- 4. Target Orbit Strafe (Авто-вращение вокруг текущей цели Silent Aim)
    if Config.TargetStrafe and GS.CurrentTargetPart and not Config.Fly_Enabled then
        CircleAngle = (CircleAngle + dt * 7.5) % (math.pi * 2)
        local rad = Config.CircleRadius or 10
        local tPos = GS.CurrentTargetPart.Position
        local orbitPos = tPos + Vector3.new(math.cos(CircleAngle) * rad, 0, math.sin(CircleAngle) * rad)
        myRoot.CFrame = CFrame.lookAt(orbitPos, tPos)
    end

    local onLadder = IsClimbingLadder(myChar, myHum, myRoot)

    -- 5. Moonwalk (Лунная походка спиной вперёд) или HvH Anti-Aims
    if Config.Moonwalk and myHum.MoveDirection.Magnitude > 0 and not Config.AA_Enabled and not onLadder then
        myHum.AutoRotate = false
        local moveDir = myHum.MoveDirection
        myRoot.CFrame = CFrame.lookAt(myRoot.Position, myRoot.Position - Vector3.new(moveDir.X, 0, moveDir.Z))
    elseif Config.AA_Enabled and not Config.FakeDead and not onLadder then
        MotorsDirty = true
        myHum.AutoRotate = false

        local look = Camera.CFrame.LookVector
        local baseYaw = math.atan2(-look.X, -look.Z)
        local yawOffset = 0

        if Config.AA_ManualKeys and GS.ManualDir ~= 0 then
            yawOffset = math.rad(GS.ManualDir)
        elseif Config.AA_Yaw == "180" then
            yawOffset = math.rad(180)
        elseif Config.AA_Yaw == "Spinbot" then
            SpinYaw = (SpinYaw + Config.AA_SpinSpeed * dt * 12) % 360
            baseYaw = 0
            yawOffset = math.rad(SpinYaw)
        elseif Config.AA_Yaw == "Jitter" then
            yawOffset = math.rad(180)
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

        myRoot.CFrame = CFrame.new(myRoot.Position) * CFrame.Angles(0, baseYaw + yawOffset + jitAdd, 0)

        local neck = myChar:FindFirstChild("Neck", true)
        if neck and neck:IsA("Motor6D") then
            if not GS.SavedMotorC0[neck] then GS.SavedMotorC0[neck] = neck.C0 end
            local pDeg = (Config.AA_Pitch == "Down" and -68) or (Config.AA_Pitch == "Up" and 68) or (Config.AA_Pitch == "Jitter" and ((JitterStep % 2 == 0) and -68 or 68)) or 0
            neck.C0 = GS.SavedMotorC0[neck] * CFrame.Angles(math.rad(pDeg), 0, 0)
        end

        local waist = myChar:FindFirstChild("Waist", true) or myChar:FindFirstChild("RootJoint", true)
        if waist and waist:IsA("Motor6D") then
            if not GS.SavedMotorC0[waist] then GS.SavedMotorC0[waist] = waist.C0 end
            local bodyYawDeg = (Config.AA_BodyYaw == "Opposite" and 58) or (Config.AA_BodyYaw == "Static" and -58) or (Config.AA_BodyYaw == "Jitter" and ((JitterStep % 2 == 0) and 58 or -58)) or 0
            waist.C0 = GS.SavedMotorC0[waist] * CFrame.Angles(0, math.rad(bodyYawDeg), math.rad(Config.AA_RollLean))
        end
    else
        if not Config.FakeDead then myHum.AutoRotate = true end
        if MotorsDirty then
            GS.RestoreMotors()
            MotorsDirty = false
        end
    end

    if Config.Speed_Enabled and not Config.Fly_Enabled then
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
            myHum.WalkSpeed = (math.sin(tick() * 10) > 0.2) and (Config.SpeedVal * 1.35) or 16
        end
    else
        myHum.WalkSpeed = 16
    end

    if Config.BHop and UserInputService:IsKeyDown(Enum.KeyCode.Space) and not onLadder and not Config.Fly_Enabled then
        if myHum.FloorMaterial ~= Enum.Material.Air then
            myHum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end

    if Config.AirStrafe and myHum.FloorMaterial == Enum.Material.Air and not onLadder and not Config.Fly_Enabled then
        local moveDir = myHum.MoveDirection
        if moveDir.Magnitude > 0 then
            myRoot.AssemblyLinearVelocity = Vector3.new(moveDir.X * Config.StrafeSpeed, myRoot.AssemblyLinearVelocity.Y, moveDir.Z * Config.StrafeSpeed)
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

    if Config.AutoFire and GS.GetRole(LocalPlayer) == "Sheriff" then
        local murd = GS.FindByRole("Murderer")
        local mRoot = murd and murd.Character and murd.Character:FindFirstChild("HumanoidRootPart")
        if mRoot and GS.IsVisible(mRoot) then
            GS.DirectShootGunAt(mRoot.Position + Vector3.new(mRoot.Velocity.X * 0.12, 0.25, mRoot.Velocity.Z * 0.12), murd, mRoot)
        end
    end

    if GS.GetRole(LocalPlayer) == "Murderer" then
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
                            GS.LastAttackData = {Player = plr, Time = tick()}
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
end))

-------------------------------------------------------------------------
-- АВТО-ВСТРАИВАНИЕ НОВЫХ ПЕРЕКЛЮЧАТЕЛЕЙ ПРЯМО В МЕНЮ SKEET (БЕЗ ПРАВКИ VISUALS_UI.LUA!)
-------------------------------------------------------------------------
task.spawn(function()
    task.wait(0.35)
    if GS.Unhooked or not GS.OuterWindow then return end

    -- Находим вкладки Legit (3-я) и Misc (5-я) внутри GS.OuterWindow и автоматически добавляем туда новые переключатели!
    local pages = {}
    for _, desc in ipairs(GS.OuterWindow:GetDescendants()) do
        if desc:IsA("ScrollingFrame") then
            table.insert(pages, desc)
        end
    end

    local function QuickInjectCheck(parentContent, text, key)
        local row = Instance.new("TextButton", parentContent)
        row.Size = UDim2.new(1, 0, 0, 16); row.BackgroundTransparency = 1; row.Text = ""; row.AutoButtonColor = false
        local box = Instance.new("Frame", row)
        box.Size = UDim2.new(0, 8, 0, 8); box.Position = UDim2.new(0, 0, 0.5, -4)
        box.BackgroundColor3 = Config[key] and Skeet.Accent or Skeet.ControlBg
        box.BorderColor3 = Skeet.ControlBorder; box.BorderSizePixel = 1
        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(1, -20, 1, 0); lbl.Position = UDim2.new(0, 18, 0, 0); lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.SourceSans; lbl.TextSize = 13
        lbl.TextColor3 = Config[key] and Skeet.TextActive or Skeet.Text
        lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Text = text
        local function sync()
            box.BackgroundColor3 = Config[key] and Skeet.Accent or Skeet.ControlBg
            lbl.TextColor3 = Config[key] and Skeet.TextActive or Skeet.Text
        end
        table.insert(GS.UIUpdaters, sync)
        GS.TrackConnection(row.MouseButton1Click:Connect(function()
            Config[key] = not Config[key]
            sync()
            if string.find(key, "Skin") or string.find(key, "StatTrak") or string.find(key, "Trail") then
                GS.ClearCustomSkins()
            end
        end))
    end

    local function QuickInjectDropdown(parentContent, text, key, options)
        local wrap = Instance.new("Frame", parentContent)
        wrap.Size = UDim2.new(1, 0, 0, 36); wrap.BackgroundTransparency = 1
        local lbl = Instance.new("TextLabel", wrap)
        lbl.Size = UDim2.new(1, -18, 0, 14); lbl.Position = UDim2.new(0, 18, 0, 0); lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.SourceSans; lbl.TextSize = 13; lbl.TextColor3 = Skeet.Text
        lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Text = text
        local btn = Instance.new("TextButton", wrap)
        btn.Size = UDim2.new(1, -36, 0, 18); btn.Position = UDim2.new(0, 18, 0, 16)
        btn.BackgroundColor3 = Skeet.ControlBg; btn.BorderColor3 = Skeet.ControlBorder; btn.BorderSizePixel = 1; btn.Text = ""
        local valLbl = Instance.new("TextLabel", btn)
        valLbl.Size = UDim2.new(1, -12, 1, 0); valLbl.Position = UDim2.new(0, 6, 0, 0); valLbl.BackgroundTransparency = 1
        valLbl.Font = Enum.Font.SourceSans; valLbl.TextSize = 13; valLbl.TextColor3 = Skeet.Text
        valLbl.TextXAlignment = Enum.TextXAlignment.Left; valLbl.Text = tostring(Config[key])
        GS.TrackConnection(btn.MouseButton1Click:Connect(function()
            local idx = table.find(options, Config[key]) or 1
            idx = idx % #options + 1
            Config[key] = options[idx]
            valLbl.Text = tostring(Config[key])
            GS.ClearCustomSkins()
        end))
    end

    -- Ищем Groupbox скинченджера и Groupbox мувмента по заголовкам и докидываем туда новые фишки!
    for _, lbl in ipairs(GS.OuterWindow:GetDescendants()) do
        if lbl:IsA("TextLabel") and string.find(lbl.Text, "Skinchanger") then
            local boxFrame = lbl.Parent and lbl.Parent.Parent and lbl.Parent.Parent:FindFirstChildOfClass("Frame")
            local content = boxFrame and boxFrame:FindFirstChildOfClass("Frame")
            if content then
                QuickInjectDropdown(content, "Pro Gun Model (+AK47 / M4A1-S)", "GunSkinModel", {"AWP Sniper", "AK-47 Kalash", "M4A1-S Silencer", "SSG-08 Scout", "Desert Eagle"})
                QuickInjectDropdown(content, "Pro Knife (+Talon / Skeleton)", "KnifeSkinModel", {"Karambit", "Butterfly Knife", "M9 Bayonet", "Talon Knife", "Skeleton Knife"})
                QuickInjectDropdown(content, "Animated & Pro Finish", "GunSkinFinish", {"Chroma Wave (Animated)", "Dragon Lore", "Asiimov", "Fade", "Gungnir", "Printstream"})
                QuickInjectCheck(content, "3D StatTrak™ LED Kill Counter", "StatTrakCounter")
                QuickInjectCheck(content, "Neon Blade & Barrel Trail", "WeaponBladeTrail")
                QuickInjectCheck(content, "Weapon Energy Sparkles", "WeaponSparkles")
                QuickInjectCheck(content, "Inspect Spin Animation [Key F]", "KnifeInspectSpin")
            end
        elseif lbl:IsA("TextLabel") and string.find(lbl.Text, "Movement & Strafes") then
            local boxFrame = lbl.Parent and lbl.Parent.Parent and lbl.Parent.Parent:FindFirstChildOfClass("Frame")
            local content = boxFrame and boxFrame:FindFirstChildOfClass("Frame")
            if content then
                QuickInjectCheck(content, "Camera Fly Mode [Key V]", "Fly_Enabled")
                QuickInjectCheck(content, "Phase Dash Blink [Key Q]", "Dash_Enabled")
                QuickInjectCheck(content, "Ctrl + Click Teleport", "ClickTP")
                QuickInjectCheck(content, "Spider Wall-Climb (Climb Anything)", "SpiderClimb")
                QuickInjectCheck(content, "Moonwalk (Slide Backwards)", "Moonwalk")
                QuickInjectCheck(content, "Target Orbit Strafe (Lock Orbit)", "TargetStrafe")
                QuickInjectCheck(content, "Low Moon Gravity", "LowGravity")
                QuickInjectCheck(content, "Anti-Void Protection", "AntiVoid")
            end
        end
    end
end)
