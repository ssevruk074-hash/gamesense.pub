-- File: combat.lua | Pro MM2 Silent Aim, Displacement Resolver, 4-Layer Wallbang & Dedicated Aim Visuals Engine
local GS = _G.GS
if not GS then return end

local Players = GS.Players
local RunService = GS.RunService
local UserInputService = GS.UserInputService
local GuiService = game:GetService("GuiService")
local Workspace = GS.Workspace
local Camera = GS.Camera
local LocalPlayer = GS.LocalPlayer
local LocalMouse = LocalPlayer:GetMouse()
local Config = GS.Config
local Skeet = GS.Skeet

-------------------------------------------------------------------------
-- ДОПОЛНИТЕЛЬНЫЕ НАСТРОЙКИ ПРОФЕССИОНАЛЬНОГО АИМА И БОЕВЫХ ВИЗУАЛОВ
-------------------------------------------------------------------------
local CombatDefaults = {
    SilentAim = true,
    DirectClickInvoke = true,
    FixBulletDrop = true,
    TargetRolePriority = "Smart (Role-Based)", -- Smart (Role-Based), Any Closest, Murderer Only
    HitPart = "HumanoidRootPart",              -- HumanoidRootPart, Head, UpperTorso, Multi-Point Auto
    MultiPointAim = true,                      -- Автоматически выбирает открытую часть тела (руку/голову), если торс за стеной
    ResolverEnabled = true,                    -- Вычисляет реальную скорость по смещению координат (пробивает чужой Desync!)
    Prediction = 13,                           -- Множитель упреждения (13 = 0.135с)
    JumpOffset = 0.08,                         -- Компенсация гравитации в прыжке
    Wallbang = true,                           -- Прострел сквозь стены (Raycast Spoof + Micro-Corner Peak)
    AutoWallbangShoot = false,                 -- Автоматически стрелять через стены, как только Мардер в радиусе досягаемости
    HitChance = 100,
    FOV = 260,
    ShowFOV = true,
    FOVFilled = false,
    TargetLine = true,
    ShowPredictionVisualizer = true,           -- Показывает точку упреждения и вектор движения врага
    ShowTargetHighlightBox = true,             -- 3D неоновый маркер на захваченном хитбоксе врага
    AutoFire = false,
    LegitAim = false,
    LegitAimKey = "MouseButton2 (RMB)",
    LegitSmooth = 14,
    LegitFOV = 140,
    ShowLegitFOV = false,
    LegitVisibleOnly = true,
    LegitTriggerbot = false,
    TriggerbotDelay = 35
}

for k, v in pairs(CombatDefaults) do
    if Config[k] == nil then Config[k] = v end
    if GS.DefaultConfigBackup and GS.DefaultConfigBackup[k] == nil then
        GS.DefaultConfigBackup[k] = v
    end
end

-- Игнорируем модельку нашего персонажа для стандартной мыши
task.spawn(function()
    if LocalPlayer.Character then
        LocalMouse.TargetFilter = LocalPlayer.Character
    end
end)
GS.TrackConnection(LocalPlayer.CharacterAdded:Connect(function(ch)
    LocalMouse.TargetFilter = ch
end))

-------------------------------------------------------------------------
-- 1. ТОЧНАЯ МАТЕМАТИКА ЭКРАНА И ЛУЧЕЙ (БЕЗ СМЕЩЕНИЯ GUIINSET НА 58 ПИКСЕЛЕЙ!)
-------------------------------------------------------------------------
local function GetTrueMouseScreenPos()
    -- UserInputService:GetMouseLocation() возвращает точные экранные координаты, совместимые с Camera:WorldToViewportPoint и Drawing!
    return UserInputService:GetMouseLocation()
end

function GS.IsVisible(part, customOrigin)
    if not part or not LocalPlayer.Character then return false end
    local myHead = LocalPlayer.Character:FindFirstChild("Head") or LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHead then return false end

    GS.RaycastBypass = true
    local origin = customOrigin or Camera.CFrame.Position
    local delta = (part.Position - origin)
    if delta.Magnitude < 0.5 then
        GS.RaycastBypass = false
        return true
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true
    local ignoreList = {LocalPlayer.Character, Camera}
    if GS.GhostModel then table.insert(ignoreList, GS.GhostModel) end
    if GS.QuickPeekPart then table.insert(ignoreList, GS.QuickPeekPart) end
    if GS.BacktrackGhost then table.insert(ignoreList, GS.BacktrackGhost) end
    params.FilterDescendantsInstances = ignoreList

    local res = Workspace:Raycast(origin, delta, params)
    GS.RaycastBypass = false
    return (not res) or res.Instance:IsDescendantOf(part.Parent)
end

-- Точка пересечения луча из центра прицела с миром (0 пикселей погрешности!)
function GS.GetExactCrosshairWorldPoint()
    local mPos = GetTrueMouseScreenPos()
    local ray = Camera:ViewportPointToRay(mPos.X, mPos.Y)
    GS.RaycastBypass = true
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera, GS.GhostModel, GS.QuickPeekPart, GS.BacktrackGhost}
    local hit = Workspace:Raycast(ray.Origin, ray.Direction * 2500, params)
    GS.RaycastBypass = false
    return hit and hit.Position or (ray.Origin + ray.Direction * 900)
end

-------------------------------------------------------------------------
-- 2. DISPLACEMENT RESOLVER (ВЫЧИСЛЕНИЕ РЕАЛЬНОЙ СКОРОСТИ ПРОТИВ ЧУЖОГО ДЕСИНКА!)
-------------------------------------------------------------------------
-- Если враг использует Velocity Spoof / Anti-Aim Desync, его AssemblyLinearVelocity врёт.
-- Мы считаем реальную скорость по изменению его координат (Pos - OldPos) / dt!
local ResolverData = {}

local function UpdateResolver(dt)
    if dt <= 0.0001 then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local curPos = hrp.Position
                local data = ResolverData[plr]
                if not data then
                    ResolverData[plr] = {
                        LastPos = curPos,
                        ResolvedVel = Vector3.zero,
                        LastUpdate = tick()
                    }
                else
                    local displacement = curPos - data.LastPos
                    local rawVel = displacement / dt
                    -- Отсекаем телепорты свыше 200 стадов за кадр, сглаживаем через Lerp(0.45)
                    if displacement.Magnitude < 35 then
                        data.ResolvedVel = data.ResolvedVel:Lerp(Vector3.new(rawVel.X, rawVel.Y * 0.35, rawVel.Z), 0.45)
                    else
                        data.ResolvedVel = Vector3.zero
                    end
                    data.LastPos = curPos
                    data.LastUpdate = tick()
                end
            end
        else
            ResolverData[plr] = nil
        end
    end
end

local function GetTargetPredictedPosition(plr, part)
    if not part then return nil end
    local basePos = part.Position
    local predTime = (Config.Prediction or 13) / 100
    local vel = Vector3.zero

    if Config.ResolverEnabled and ResolverData[plr] then
        vel = ResolverData[plr].ResolvedVel
    else
        vel = part.AssemblyLinearVelocity or part.Velocity or Vector3.zero
        vel = Vector3.new(vel.X, vel.Y * 0.35, vel.Z)
    end

    -- Добавляем микро-компенсацию высоты дула (+0.12 стада), чтобы пуля шла строго в центр хитбокса
    return basePos + (vel * predTime) + Vector3.new(0, 0.12, 0)
end

-------------------------------------------------------------------------
-- 3. МУЛЬТИ-ПОИНТ СКАНЕР И УМНЫЙ СЕРВЕРНЫЙ WALLBANG (CORNER / HIGH PEAK)
-------------------------------------------------------------------------
local MultiPointParts = {
    "HumanoidRootPart",
    "Head",
    "UpperTorso",
    "LowerTorso",
    "RightUpperArm",
    "LeftUpperArm",
    "RightFoot",
    "LeftFoot",
    "Torso"
}

-- Ищет открытую точку на теле врага, а если враг полностью за стеной — ищет лучшую точку для прострела Wallbang!
local function FindOptimalTargetPart(char)
    if not char then return nil, false end
    local mainName = (Config.HitPart == "Multi-Point Auto") and "HumanoidRootPart" or (Config.HitPart or "HumanoidRootPart")
    local primary = char:FindFirstChild(mainName) or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")

    if primary and GS.IsVisible(primary) then
        return primary, true
    end

    if Config.MultiPointAim or Config.HitPart == "Multi-Point Auto" then
        for _, pName in ipairs(MultiPointParts) do
            local p = char:FindFirstChild(pName)
            if p and GS.IsVisible(p) then
                return p, true
            end
        end
    end

    return primary, false
end

-- Ищет обходную точку прямой видимости (Vantage Point) для серверного прострела сквозь стены!
local function FindWallbangVantageCFrame(myRoot, targetPart)
    if not myRoot or not targetPart then return nil end
    local myPos = myRoot.Position
    local tPos = targetPart.Position

    -- 1. Сначала проверяем смещения около самого стрелка (Corner Peak: влево, вправо, вверх над крышей/забором),
    -- чтобы сервер засчитал выстрел с минимальным смещением!
    local camRight = Camera.CFrame.RightVector
    local localOffsets = {
        Vector3.new(0, 8, 0),
        Vector3.new(0, 14, 0),
        camRight * 7,
        -camRight * 7,
        (camRight * 7) + Vector3.new(0, 6, 0),
        (-camRight * 7) + Vector3.new(0, 6, 0)
    }
    for _, off in ipairs(localOffsets) do
        local testOrigin = myPos + off
        if GS.IsVisible(targetPart, testOrigin) then
            return CFrame.lookAt(testOrigin, tPos)
        end
    end

    -- 2. Если враг в закрытой комнате — берём точку прямо над/рядом с врагом (Micro-LOS Vantage)
    local targetOffsets = {
        Vector3.new(0, 5.5, 0),
        Vector3.new(0, 2.5, 4.5),
        Vector3.new(0, 2.5, -4.5),
        Vector3.new(4.5, 2.5, 0),
        Vector3.new(-4.5, 2.5, 0)
    }
    for _, off in ipairs(targetOffsets) do
        local testOrigin = tPos + off
        if GS.IsVisible(targetPart, testOrigin) then
            return CFrame.lookAt(testOrigin, tPos)
        end
    end

    return CFrame.lookAt(tPos + Vector3.new(0, 4, 2), tPos)
end

-- Главная функция выбора лучшей цели в радиусе FOV (с фоллбэком на 360° Rage)
local CurrentTargetIsVisible = false

function GS.GetBestTargetInRadius(fovRadius, requireVisible)
    local myRole = GS.GetRole(LocalPlayer)
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local mousePos = GetTrueMouseScreenPos()

    local bestPart, bestPlr, bestPos, bestVis = nil, nil, nil, false
    local bestScore = math.huge

    local priorityMurdererOnly = (Config.TargetRolePriority == "Murderer Only")
        or (Config.TargetRolePriority == "Smart (Role-Based)" and myRole == "Sheriff" and GS.FindByRole("Murderer") ~= nil)

    local function scanCandidates(ignoreRole, ignoreScreenFOV)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local char = plr.Character
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local role = GS.GetRole(plr)
                    if ignoreRole or (not priorityMurdererOnly) or (role == "Murderer") then
                        local part, isVis = FindOptimalTargetPart(char)
                        if part and ((not requireVisible) or Config.Wallbang or isVis) then
                            local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                            local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude

                            -- Приоритет видимым целям (бонус к дистанции)
                            local scoreMod = isVis and 0.75 or 1.0

                            if onScreen and screenDist <= fovRadius then
                                local weighted = screenDist * scoreMod
                                if weighted < bestScore then
                                    bestScore = weighted
                                    bestPart = part
                                    bestPlr = plr
                                    bestPos = part.Position
                                    bestVis = isVis
                                end
                            elseif ignoreScreenFOV then
                                local worldDist = myRoot and (part.Position - myRoot.Position).Magnitude or 999
                                local weighted = worldDist * scoreMod
                                if weighted < bestScore then
                                    bestScore = weighted
                                    bestPart = part
                                    bestPlr = plr
                                    bestPos = part.Position
                                    bestVis = isVis
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- 1. Ищем в круге FOV
    scanCandidates(false, false)
    -- 2. Если в круге FOV никого нет (например, Мардер сзади) и это не жесткий Legit — ищем на 360°
    if not bestPart and not requireVisible then
        bestScore = math.huge
        scanCandidates(false, true)
    end
    -- 3. Если Мардер еще не определен (или тест в лобби) — берем ближайшего игрока
    if not bestPart and Config.TargetRolePriority == "Smart (Role-Based)" then
        bestScore = math.huge
        scanCandidates(true, false)
    end

    local aimPos = nil
    if bestPart and bestPlr then
        aimPos = GetTargetPredictedPosition(bestPlr, bestPart)
    end
    return bestPart, bestPlr, aimPos, bestVis
end

-------------------------------------------------------------------------
-- 4. ПОИСК ОРУЖИЯ И ГАРАНТИРОВАННЫЙ ВЫСТРЕЛ (DIRECT + WALLBANG)
-------------------------------------------------------------------------
function GS.FindLivingSheriffGun()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local g = (plr.Character and plr.Character:FindFirstChild("Gun"))
                or (plr:FindFirstChild("Backpack") and plr.Backpack:FindFirstChild("Gun"))
            if g then return g, plr end
        end
    end
    return nil, nil
end

function GS.FindGunShootRemote(gunInstance)
    if not gunInstance then
        local myChar = LocalPlayer.Character
        gunInstance = (myChar and myChar:FindFirstChild("Gun"))
            or (LocalPlayer:FindFirstChild("Backpack") and LocalPlayer.Backpack:FindFirstChild("Gun"))
            or GS.FindLivingSheriffGun()
    end
    if not gunInstance then return nil end
    local kl = gunInstance:FindFirstChild("KnifeLocal")
    local cb = kl and kl:FindFirstChild("CreateBeam")
    local rf = cb and cb:FindFirstChild("RemoteFunction")
    if rf then return rf end
    local shoot = gunInstance:FindFirstChild("ShootGun", true) or gunInstance:FindFirstChild("Shoot", true) or gunInstance:FindFirstChild("Fire", true)
    if shoot then return shoot end
    return gunInstance:FindFirstChildOfClass("RemoteFunction", true) or gunInstance:FindFirstChildOfClass("RemoteEvent", true)
end

local LastDirectShotTick = 0

function GS.DirectShootGunAt(targetPos, targetPlr, targetPart)
    if (tick() - LastDirectShotTick) < 0.08 then return false end
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myGun = myChar and myChar:FindFirstChild("Gun")
    local rem = GS.FindGunShootRemote(myGun)
    if not rem or not targetPos then return false end

    LastDirectShotTick = tick()
    if targetPlr then
        GS.LastAttackData = {Player = targetPlr, Time = tick()}
    end

    task.spawn(function()
        local savedCF = nil
        local needWallbang = Config.Wallbang and myRoot and targetPart and (not GS.IsVisible(targetPart))

        if needWallbang then
            savedCF = myRoot.CFrame
            local vantageCF = FindWallbangVantageCFrame(myRoot, targetPart)
            if vantageCF then
                myRoot.CFrame = vantageCF
            end
        end

        pcall(function()
            if rem:IsA("RemoteFunction") then
                rem:InvokeServer(1, targetPos, "AH2")
            elseif rem:IsA("RemoteEvent") then
                rem:FireServer(CFrame.lookAt(Camera.CFrame.Position, targetPos), targetPos)
                rem:FireServer(targetPos)
            end
        end)

        if savedCF and myRoot then
            RunService.RenderStepped:Wait()
            if myRoot and myRoot.Parent then
                myRoot.CFrame = savedCF
            end
        end
    end)
    return true
end

function GS.RemoteFireLivingSheriffGun(customTargetPos)
    local liveGun = GS.FindLivingSheriffGun()
    if not liveGun then
        local myChar = LocalPlayer.Character
        liveGun = myChar and myChar:FindFirstChild("Gun")
    end
    local remote = GS.FindGunShootRemote(liveGun)
    if remote then
        local tPart, tPlr, tPos = GS.GetBestTargetInRadius(Config.FOV, false)
        local targetPos = customTargetPos or tPos or GS.GetExactCrosshairWorldPoint()
        if tPlr then GS.LastAttackData = {Player = tPlr, Time = tick()} end
        GS.PlayCSGOWeaponSound(true)
        task.spawn(function()
            pcall(function()
                if remote:IsA("RemoteFunction") then
                    remote:InvokeServer(1, targetPos, "AH2")
                elseif remote:IsA("RemoteEvent") then
                    remote:FireServer(CFrame.lookAt(Camera.CFrame.Position, targetPos), targetPos)
                end
            end)
        end)
        return true
    end
    return false
end

function GS.StealGunFromLivingSheriff()
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
        GS.PushSkeetLog("Подобран выпавший револьвер Шерифа!", Skeet.Accent)
        return
    end

    if myChar:FindFirstChild("Gun") or myBp:FindFirstChild("Gun") then return end

    local liveGun, sheriffPlr = GS.FindLivingSheriffGun()
    if liveGun then
        local clonedGun = liveGun:Clone()
        clonedGun.Name = "Gun"
        clonedGun.Parent = myBp
        local hum = myChar:FindFirstChildOfClass("Humanoid")
        if hum then hum:EquipTool(clonedGun) end
        GS.PushSkeetLog(string.format("Клонирован револьвер живого Шерифа (%s)!", sheriffPlr.Name), Skeet.Accent)
    end
end

-------------------------------------------------------------------------
-- 5. ЧЕТЫРЁХСЛОЙНЫЙ ХУК МЕТАТАБЛИЦЫ (БЕЗ ЛАГОВ КАМЕРЫ И С 100% ПРОБИТИЕМ)
-------------------------------------------------------------------------
local LastWeaponClickTime = 0

GS.TrackConnection(UserInputService.InputBegan:Connect(function(inp, gp)
    if not gp and inp.UserInputType == Enum.UserInputType.MouseButton1 and not (GS.OuterWindow and GS.OuterWindow.Visible) then
        local myChar = LocalPlayer.Character
        if myChar and (myChar:FindFirstChild("Gun") or myChar:FindFirstChild("Knife")) then
            LastWeaponClickTime = tick()
            if myChar:FindFirstChild("Gun") and Config.SilentAim and Config.DirectClickInvoke then
                local tPart, tPlr, tPos = GS.GetBestTargetInRadius(Config.FOV, false)
                if tPart and tPos and math.random(1, 100) <= Config.HitChance then
                    GS.DirectShootGunAt(tPos, tPlr, tPart)
                end
            end
        end
    end
end))

local mt = getrawmetatable and getrawmetatable(game)
GS.mt = mt

local function IsWeaponRemote(obj)
    local name = tostring(obj)
    if name == "Shoot" or name == "ShootGun" or name == "UseTool" or name == "Fire" or name == "CreateBeam" or name == "Throw" or name == "KnifeThrown" then
        return true
    end
    local myChar = LocalPlayer.Character
    if myChar then
        local ok, isDesc = pcall(function() return obj:IsDescendantOf(myChar) end)
        if ok and isDesc and name ~= "Stab" then return true end
    end
    return false
end

if mt and setreadonly then
    GS.oldNamecall = mt.__namecall
    GS.oldIndex = mt.__index
    local oldNamecall = GS.oldNamecall
    local oldIndex = GS.oldIndex
    setreadonly(mt, false)

    -- Слой 1: Безопасный для камеры перехват Mouse.Hit и Mouse.Target (только с оружием в руках!)
    mt.__index = newcclosure(function(self, key)
        if not GS.Unhooked and not checkcaller() and self == LocalMouse then
            if key == "Hit" or key == "hit" or key == "Target" or key == "target" then
                local myChar = LocalPlayer.Character
                local holdingWeapon = myChar and (myChar:FindFirstChild("Gun") or myChar:FindFirstChild("Knife"))
                if holdingWeapon then
                    if key == "Hit" or key == "hit" then
                        if Config.SilentAim and GS.CurrentTargetPart and GS.CurrentAimPos then
                            GS.LastAttackData = {Player = GS.CurrentTargetPlr, Time = tick()}
                            local orig = Camera.CFrame.Position
                            local dir = (GS.CurrentAimPos - orig)
                            if dir.Magnitude > 0.1 then
                                return CFrame.lookAt(GS.CurrentAimPos, GS.CurrentAimPos + dir.Unit)
                            end
                            return CFrame.new(GS.CurrentAimPos)
                        elseif Config.FixBulletDrop then
                            return CFrame.new(GS.GetExactCrosshairWorldPoint())
                        end
                    elseif key == "Target" or key == "target" then
                        if Config.SilentAim and GS.CurrentTargetPart then
                            return GS.CurrentTargetPart
                        end
                    end
                end
            end
        end
        return oldIndex(self, key)
    end)

    -- Слой 2: Перехват Raycast + FindPartOnRay + InvokeServer / FireServer
    mt.__namecall = newcclosure(function(self, ...)
        if GS.Unhooked or checkcaller() or GS.RaycastBypass then
            return oldNamecall(self, ...)
        end

        local method = getnamecallmethod()
        local args = {...}

        -- Перехват клиентского луча оружия в момент клика (чтобы пуля не втыкалась в пол/стену перед тобой!)
        if (tick() - LastWeaponClickTime) <= 0.20 then
            if method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRay" or method == "FindPartOnRayWithWhitelist" then
                if Config.SilentAim and GS.CurrentTargetPart and GS.CurrentAimPos then
                    return GS.CurrentTargetPart, GS.CurrentAimPos, Vector3.new(0, 1, 0), Enum.Material.Plastic
                elseif Config.FixBulletDrop then
                    local exactP = GS.GetExactCrosshairWorldPoint()
                    return nil, exactP, Vector3.new(0, 1, 0), Enum.Material.Air
                end
            elseif method == "Raycast" and self == Workspace and Config.SilentAim and GS.CurrentTargetPart and GS.CurrentAimPos then
                local orig = typeof(args[1]) == "Vector3" and args[1] or Camera.CFrame.Position
                local delta = (GS.CurrentAimPos - orig)
                if delta.Magnitude > 0.1 then
                    args[2] = delta.Unit * 1500
                    return oldNamecall(self, unpack(args))
                end
            end
        end

        -- Перехват сетевого пакета выстрела (CreateBeam / ShootGun / Shoot / Throw)
        if method == "FireServer" or method == "InvokeServer" then
            local isWep = IsWeaponRemote(self)
            local isOfficialCreateBeam = (method == "InvokeServer" and args[1] == 1 and typeof(args[2]) == "Vector3")

            if isWep or isOfficialCreateBeam then
                local tPart, tPlr, tPos, isVis = GS.GetBestTargetInRadius(Config.FOV, false)
                local targetPart = tPart or GS.CurrentTargetPart
                local targetPlr = tPlr or GS.CurrentTargetPlr
                local aimPos = tPos or GS.CurrentAimPos

                local myChar = LocalPlayer.Character
                local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if myChar and myChar:FindFirstChild("Gun") then
                    GS.PlayCSGOWeaponSound(true)
                end

                if Config.SilentAim and targetPart and aimPos and math.random(1, 100) <= Config.HitChance then
                    GS.LastAttackData = {Player = targetPlr, Time = tick()}

                    -- Если враг за стеной и включён Wallbang — на время сетевого вызова ставим серверный CFrame в точку обхода стены
                    local savedCF = nil
                    if Config.Wallbang and myRoot and not isVis then
                        savedCF = myRoot.CFrame
                        local vantageCF = FindWallbangVantageCFrame(myRoot, targetPart)
                        if vantageCF then myRoot.CFrame = vantageCF end
                    end

                    -- Подменяем координаты выстрела во всех форматах (Vector3 / CFrame)
                    local coordIndices = {}
                    for i, v in ipairs(args) do
                        if typeof(v) == "Vector3" or typeof(v) == "CFrame" then
                            table.insert(coordIndices, i)
                        end
                    end

                    if #coordIndices == 1 then
                        local idx = coordIndices[1]
                        if typeof(args[idx]) == "Vector3" then
                            args[idx] = aimPos
                        elseif typeof(args[idx]) == "CFrame" then
                            args[idx] = CFrame.lookAt(aimPos, aimPos + (aimPos - Camera.CFrame.Position).Unit)
                        end
                    elseif #coordIndices >= 2 then
                        local firstIdx = coordIndices[1]
                        local lastIdx = coordIndices[#coordIndices]
                        if typeof(args[firstIdx]) == "CFrame" then
                            args[firstIdx] = CFrame.lookAt(args[firstIdx].Position, aimPos)
                        end
                        if typeof(args[lastIdx]) == "Vector3" then
                            args[lastIdx] = aimPos
                        elseif typeof(args[lastIdx]) == "CFrame" then
                            args[lastIdx] = CFrame.new(aimPos)
                        end
                    else
                        args[1] = aimPos
                    end

                    for i, v in ipairs(args) do
                        if typeof(v) == "Instance" and v:IsA("BasePart") then
                            args[i] = targetPart
                        end
                    end

                    -- Визуальный лазерный след до точки попадания!
                    if myChar and myChar:FindFirstChild("Head") then
                        GS.SpawnProBulletTracer(myChar.Head.Position, aimPos)
                    end

                    if savedCF and myRoot then
                        task.delay(0.03, function()
                            if myRoot and myRoot.Parent then myRoot.CFrame = savedCF end
                        end)
                    end

                    return oldNamecall(self, unpack(args))
                elseif Config.FixBulletDrop then
                    local exactPos = GS.GetExactCrosshairWorldPoint()
                    for i, v in ipairs(args) do
                        if typeof(v) == "Vector3" then args[i] = exactPos
                        elseif typeof(v) == "CFrame" then args[i] = CFrame.new(exactPos) end
                    end
                    return oldNamecall(self, unpack(args))
                end
            end
        end

        return oldNamecall(self, ...)
    end)

    setreadonly(mt, true)
end

-------------------------------------------------------------------------
-- 6. ВСТРОЕННЫЙ ДВИЖОК БОЕВЫХ ВИЗУАЛОВ АИМА (FOV, SNAPLINE, PREDICTION DOT, 3D LOCK BOX)
-------------------------------------------------------------------------
-- Рисует все визуалы Сайлент Аима и Валлбанга прямо из combat.lua, чтобы они 100% работали!
local AimFOVOutline = GS.TrackDrawing(Drawing and Drawing.new("Circle"))
local AimFOVCircle = GS.TrackDrawing(Drawing and Drawing.new("Circle"))
local LegitFOVDrawing = GS.TrackDrawing(Drawing and Drawing.new("Circle"))
local AimSnaplineOutline = GS.TrackDrawing(Drawing and Drawing.new("Line"))
local AimSnapline = GS.TrackDrawing(Drawing and Drawing.new("Line"))
local PredLine = GS.TrackDrawing(Drawing and Drawing.new("Line"))
local PredCircle = GS.TrackDrawing(Drawing and Drawing.new("Circle"))
local TargetCross1 = GS.TrackDrawing(Drawing and Drawing.new("Line"))
local TargetCross2 = GS.TrackDrawing(Drawing and Drawing.new("Line"))
local AimStatusTag = GS.TrackDrawing(Drawing and Drawing.new("Text"))

if Drawing then
    AimFOVOutline.Thickness = 3; AimFOVOutline.Color = Color3.new(0, 0, 0); AimFOVOutline.Filled = false; AimFOVOutline.NumSides = 64
    AimFOVCircle.Thickness = 1.5; AimFOVCircle.Color = Skeet.Accent; AimFOVCircle.Filled = false; AimFOVCircle.NumSides = 64
    LegitFOVDrawing.Thickness = 1.2; LegitFOVDrawing.Color = Skeet.Cyan; LegitFOVDrawing.Filled = false; LegitFOVDrawing.NumSides = 64

    AimSnaplineOutline.Thickness = 3; AimSnaplineOutline.Color = Color3.new(0, 0, 0)
    AimSnapline.Thickness = 1.5; AimSnapline.Color = Skeet.Accent

    PredLine.Thickness = 1.5; PredLine.Color = Skeet.Cyan
    PredCircle.Thickness = 2; PredCircle.Radius = 4.5; PredCircle.Filled = false; PredCircle.Color = Skeet.Murderer

    TargetCross1.Thickness = 1.8; TargetCross1.Color = Skeet.Accent
    TargetCross2.Thickness = 1.8; TargetCross2.Color = Skeet.Accent

    AimStatusTag.Size = 13; AimStatusTag.Center = true; AimStatusTag.Outline = true; AimStatusTag.Color = Skeet.Accent
end

-- 3D Неоновый Бокс-Маркер на хитбоксе захваченной цели
local TargetBox3D = GS.TrackInstance(Instance.new("Part"))
TargetBox3D.Name = "GS_AimTargetBox"
TargetBox3D.Anchored = true; TargetBox3D.CanCollide = false; TargetBox3D.CanQuery = false; TargetBox3D.CanTouch = false; TargetBox3D.CastShadow = false
TargetBox3D.Size = Vector3.new(2.3, 2.3, 1.3)
TargetBox3D.Material = Enum.Material.ForceField
TargetBox3D.Color = Skeet.Murderer
TargetBox3D.Transparency = 1
TargetBox3D.Parent = Workspace

local TargetBoxSelection = Instance.new("SelectionBox", TargetBox3D)
TargetBoxSelection.Adornee = TargetBox3D
TargetBoxSelection.LineThickness = 0.03
TargetBoxSelection.Color3 = Skeet.Accent
TargetBoxSelection.SurfaceTransparency = 0.75
TargetBoxSelection.SurfaceColor3 = Skeet.Murderer
TargetBoxSelection.Visible = false

-------------------------------------------------------------------------
-- 7. ГЛАВНЫЙ БОЕВОЙ ЦИКЛ (RESOLVER + AIM VISUALS + LEGITBOT + AUTO-WALLBANG)
-------------------------------------------------------------------------
local LastTriggerShot = 0
local LastAutoShoot = 0

GS.TrackConnection(RunService.RenderStepped:Connect(function(dt)
    if GS.Unhooked then return end

    -- 1. Обновляем Resolver скоростей врагов
    UpdateResolver(dt)

    -- 2. Держим камеру стабильно привязанной к нашему Humanoid
    local myChar = LocalPlayer.Character
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if myHum and Camera.CameraSubject ~= myHum then
        Camera.CameraSubject = myHum
    end

    -- 3. Находим лучшую цель для Silent Aim
    local tPart, tPlr, tAimPos, isVis = GS.GetBestTargetInRadius(Config.FOV, false)
    GS.CurrentTargetPart = tPart
    GS.CurrentTargetPlr = tPlr
    GS.CurrentAimPos = tAimPos
    CurrentTargetIsVisible = isVis

    local mousePos = GetTrueMouseScreenPos()

    -- 4. Отрисовка боевых визуалов аима (FOV, Snapline, Prediction Dot, 3D Hitbox Box, Status Tag)
    if Drawing then
        local showRageFOV = Config.SilentAim and Config.ShowFOV
        AimFOVOutline.Visible = showRageFOV
        AimFOVOutline.Radius = Config.FOV
        AimFOVOutline.Position = mousePos

        AimFOVCircle.Visible = showRageFOV
        AimFOVCircle.Radius = Config.FOV
        AimFOVCircle.Position = mousePos
        AimFOVCircle.Color = tPart and (isVis and Skeet.Accent or Skeet.Gold) or Color3.fromRGB(200, 200, 200)

        LegitFOVDrawing.Visible = Config.LegitAim and Config.ShowLegitFOV
        LegitFOVDrawing.Radius = Config.LegitFOV
        LegitFOVDrawing.Position = mousePos

        if Config.SilentAim and tPart and tAimPos then
            local partScreen, partOnScreen = Camera:WorldToViewportPoint(tPart.Position)
            local predScreen, predOnScreen = Camera:WorldToViewportPoint(tAimPos)
            local stateCol = isVis and Skeet.Accent or Skeet.Gold

            -- Snapline от курсора к точке упреждения
            local drawSnap = Config.TargetLine and predOnScreen
            AimSnaplineOutline.Visible = drawSnap
            AimSnapline.Visible = drawSnap
            if drawSnap then
                AimSnaplineOutline.From = mousePos
                AimSnaplineOutline.To = Vector2.new(predScreen.X, predScreen.Y)
                AimSnapline.From = mousePos
                AimSnapline.To = Vector2.new(predScreen.X, predScreen.Y)
                AimSnapline.Color = stateCol
            end

            -- Визуализатор Предикшна (Линия от реального тела врага до точки упреждения + кружок попадания + крестик)
            local drawPred = Config.ShowPredictionVisualizer and partOnScreen and predOnScreen
            PredLine.Visible = drawPred
            PredCircle.Visible = drawPred
            TargetCross1.Visible = drawPred
            TargetCross2.Visible = drawPred
            AimStatusTag.Visible = drawPred

            if drawPred then
                local p2D = Vector2.new(partScreen.X, partScreen.Y)
                local aim2D = Vector2.new(predScreen.X, predScreen.Y)

                PredLine.From = p2D
                PredLine.To = aim2D
                PredLine.Color = Skeet.Cyan

                PredCircle.Position = aim2D
                PredCircle.Color = Skeet.Murderer

                TargetCross1.From = aim2D - Vector2.new(6, 6)
                TargetCross1.To = aim2D + Vector2.new(6, 6)
                TargetCross1.Color = stateCol

                TargetCross2.From = aim2D + Vector2.new(-6, 6)
                TargetCross2.To = aim2D + Vector2.new(6, -6)
                TargetCross2.Color = stateCol

                AimStatusTag.Position = aim2D + Vector2.new(0, 10)
                AimStatusTag.Text = string.format("[%s] %s", isVis and "VISIBLE" or "WALLBANG", tPlr.Name)
                AimStatusTag.Color = stateCol
            end
        else
            AimSnaplineOutline.Visible = false
            AimSnapline.Visible = false
            PredLine.Visible = false
            PredCircle.Visible = false
            TargetCross1.Visible = false
            TargetCross2.Visible = false
            AimStatusTag.Visible = false
        end
    end

    -- 3D Box-маркер на самом хитбоксе цели в мире
    if Config.SilentAim and Config.ShowTargetHighlightBox and tPart then
        TargetBox3D.CFrame = tPart.CFrame
        TargetBox3D.Size = tPart.Size + Vector3.new(0.25, 0.25, 0.25)
        TargetBox3D.Transparency = 0.55
        TargetBox3D.Color = isVis and Skeet.Accent or Skeet.Gold
        TargetBoxSelection.Visible = true
        TargetBoxSelection.Color3 = isVis and Skeet.Accent or Skeet.Gold
    else
        TargetBox3D.Transparency = 1
        TargetBoxSelection.Visible = false
    end

    if not myChar then return end

    -- 5. Плавный Легитбот
    if Config.LegitAim and not (GS.OuterWindow and GS.OuterWindow.Visible) then
        local activeKey = (Config.LegitAimKey == "Always On")
            or (Config.LegitAimKey == "MouseButton2 (RMB)" and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2))
            or (Config.LegitAimKey == "Key E" and UserInputService:IsKeyDown(Enum.KeyCode.E))

        if activeKey then
            local lPart, _, lPos = GS.GetBestTargetInRadius(Config.LegitFOV, Config.LegitVisibleOnly)
            if lPart and lPos then
                local camPos = Camera.CFrame.Position
                if (lPos - camPos).Magnitude > 0.5 then
                    local goalCF = CFrame.lookAt(camPos, lPos)
                    local alpha = math.clamp(1 / math.max(Config.LegitSmooth, 2), 0.04, 0.45)
                    Camera.CFrame = Camera.CFrame:Lerp(goalCF, alpha)
                end
            end
        end
    end

    -- 6. Авто-выстрел за Шерифа (AutoFire + AutoWallbang)
    if Config.AutoFire and (tick() - LastAutoShoot) >= 0.45 then
        local gun = myChar:FindFirstChild("Gun")
        if gun and tPart and tPlr and tAimPos and (isVis or Config.Wallbang) then
            LastAutoShoot = tick()
            GS.DirectShootGunAt(tAimPos, tPlr, tPart)
        end
    end

    -- 7. Легит Триггербот
    if Config.LegitTriggerbot and (tick() - LastTriggerShot) >= (Config.TriggerbotDelay / 1000) then
        local gun = myChar:FindFirstChild("Gun")
        if gun and tPart and tPlr and isVis then
            local sp, onScreen = Camera:WorldToViewportPoint(tPart.Position)
            if onScreen and (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude <= 38 then
                LastTriggerShot = tick()
                GS.DirectShootGunAt(tAimPos, tPlr, tPart)
            end
        end
    end
end))
