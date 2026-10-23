-- File: combat.lua | Pure 360° No-FOV Rage Silent Aim, Displacement Resolver, Server Wallbang & 360° Aim Visuals
local GS = _G.GS
if not GS then return end

local Players = GS.Players
local RunService = GS.RunService
local UserInputService = GS.UserInputService
local Workspace = GS.Workspace
local Camera = GS.Camera
local LocalPlayer = GS.LocalPlayer
local LocalMouse = LocalPlayer:GetMouse()
local Config = GS.Config
local Skeet = GS.Skeet

-------------------------------------------------------------------------
-- НАСТРОЙКИ 360° RAGE SILENT AIM (БЕЗ ОГРАНИЧЕНИЙ FOV!)
-------------------------------------------------------------------------
Config.SilentAim = true
Config.ShowFOV = false -- Круг FOV отключён по умолчанию (работает полный 360° захват!)
Config.Wallbang = true

local CombatDefaults = {
    DirectClickInvoke = true,
    FixBulletDrop = true,
    TargetRolePriority = "Smart (Role-Based)", -- Smart (Role-Based), Any Closest, Murderer Only
    HitPart = "HumanoidRootPart",
    MultiPointAim = true,
    ResolverEnabled = true,
    Prediction = 13,
    HitChance = 100,
    TargetLine = true,
    ShowPredictionVisualizer = true,
    ShowTargetHighlightBox = true,
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

-- Игнорируем собственного персонажа для стандартной мыши
task.spawn(function()
    if LocalPlayer.Character then
        LocalMouse.TargetFilter = LocalPlayer.Character
    end
end)
GS.TrackConnection(LocalPlayer.CharacterAdded:Connect(function(ch)
    LocalMouse.TargetFilter = ch
end))

-------------------------------------------------------------------------
-- 1. ПРОВЕРКА ВИДИМОСТИ И ЛУЧЕЙ
-------------------------------------------------------------------------
local function GetTrueMouseScreenPos()
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
-- 2. DISPLACEMENT RESOLVER (ПРОТИВ ЧУЖОГО ДЕСИНКА И АНТИ-АИМОВ)
-------------------------------------------------------------------------
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

    return basePos + (vel * predTime) + Vector3.new(0, 0.12, 0)
end

-------------------------------------------------------------------------
-- 3. ЧИСТЫЙ 360° ПОИСК ЦЕЛИ БЕЗ FOV (БЕРЁТ ВРАГА ДАЖЕ ЗА СПИНОЙ И ЗА СТЕНАМИ!)
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

local function FindWallbangVantageCFrame(myRoot, targetPart)
    if not myRoot or not targetPart then return nil end
    local myPos = myRoot.Position
    local tPos = targetPart.Position

    -- 1. Проверяем точки обхода вокруг стрелка (вверх над препятствием и по бокам)
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

    -- 2. Если враг в другой комнате/за толстой стеной — берём точку прямой видимости прямо над ним
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

local CurrentTargetIsVisible = false

-- 360° TARGET SELECTOR: Игнорирует FOV для Silent Aim, выбирает лучшую цель на всей карте по 3D-дистанции и видимости!
function GS.GetBestTargetInRadius(fovRadius, requireVisible)
    local myRole = GS.GetRole(LocalPlayer)
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myPos = myRoot and myRoot.Position or Camera.CFrame.Position

    local bestPart, bestPlr, bestPos, bestVis = nil, nil, nil, false
    local bestScore = math.huge

    local priorityMurdererOnly = (Config.TargetRolePriority == "Murderer Only")
        or (Config.TargetRolePriority == "Smart (Role-Based)" and myRole == "Sheriff" and GS.FindByRole("Murderer") ~= nil)

    local function scan360Candidates(ignoreRole)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local char = plr.Character
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local role = GS.GetRole(plr)
                    if ignoreRole or (not priorityMurdererOnly) or (role == "Murderer") then
                        local part, isVis = FindOptimalTargetPart(char)
                        if part and ((not requireVisible) or Config.Wallbang or isVis) then
                            -- Считаем 3D дистанцию в мире (вообще без привязки к углу камеры или FOV!)
                            local worldDist = (part.Position - myPos).Magnitude

                            -- Если цель открыта (Visible), даём ей приоритет перед целью за стеной
                            local score = isVis and (worldDist * 0.5) or worldDist
                            -- Если цель — Мардер, даём максимальный приоритет!
                            if role == "Murderer" then
                                score = score * 0.1
                            end

                            if score < bestScore then
                                bestScore = score
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

    -- 1. Ищем приоритетную цель (Мардера или по роли) на все 360 градусов вокруг нас
    scan360Candidates(false)

    -- 2. Если Мардер ещё не выдан (например в лобби или кастомном режиме) — берём любого ближайшего врага на 360 градусов
    if not bestPart and Config.TargetRolePriority == "Smart (Role-Based)" then
        bestScore = math.huge
        scan360Candidates(true)
    end

    local aimPos = nil
    if bestPart and bestPlr then
        aimPos = GetTargetPredictedPosition(bestPlr, bestPart)
    end
    return bestPart, bestPlr, aimPos, bestVis
end

-------------------------------------------------------------------------
-- 4. ПОИСК ОРУЖИЯ И ГАРАНТИРОВАННЫЙ 360° ВЫСТРЕЛ
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
        elseif myRoot then
            -- Даже если стен нет, но враг стоит сзади нас (360°), на 1 микро-тик поворачиваем серверный CFrame лицом к врагу,
            -- чтобы пуля из дула пистолета не застряла в нашей собственной спине!
            savedCF = myRoot.CFrame
            myRoot.CFrame = CFrame.lookAt(myRoot.Position, Vector3.new(targetPos.X, myRoot.Position.Y, targetPos.Z))
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
        local _, tPlr, tPos = GS.GetBestTargetInRadius(9999, false)
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
-- 5. ХУК МЕТАТАБЛИЦЫ 360° SILENT AIM + WALLBANG (БЕЗ ЛАГОВ КАМЕРЫ!)
-------------------------------------------------------------------------
local LastWeaponClickTime = 0

GS.TrackConnection(UserInputService.InputBegan:Connect(function(inp, gp)
    if not gp and inp.UserInputType == Enum.UserInputType.MouseButton1 and not (GS.OuterWindow and GS.OuterWindow.Visible) then
        local myChar = LocalPlayer.Character
        if myChar and (myChar:FindFirstChild("Gun") or myChar:FindFirstChild("Knife")) then
            LastWeaponClickTime = tick()
            if myChar:FindFirstChild("Gun") and Config.SilentAim and Config.DirectClickInvoke then
                local tPart, tPlr, tPos = GS.GetBestTargetInRadius(9999, false)
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

    mt.__namecall = newcclosure(function(self, ...)
        if GS.Unhooked or checkcaller() or GS.RaycastBypass then
            return oldNamecall(self, ...)
        end

        local method = getnamecallmethod()
        local args = {...}

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

        if method == "FireServer" or method == "InvokeServer" then
            local isWep = IsWeaponRemote(self)
            local isOfficialCreateBeam = (method == "InvokeServer" and args[1] == 1 and typeof(args[2]) == "Vector3")

            if isWep or isOfficialCreateBeam then
                local tPart, tPlr, tPos, isVis = GS.GetBestTargetInRadius(9999, false)
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

                    local savedCF = nil
                    if Config.Wallbang and myRoot and not isVis then
                        savedCF = myRoot.CFrame
                        local vantageCF = FindWallbangVantageCFrame(myRoot, targetPart)
                        if vantageCF then myRoot.CFrame = vantageCF end
                    elseif myRoot then
                        -- Разворачиваем серверный хитбокс лицом к цели (для 360° выстрела назад без блокировки своим телом)
                        savedCF = myRoot.CFrame
                        myRoot.CFrame = CFrame.lookAt(myRoot.Position, Vector3.new(aimPos.X, myRoot.Position.Y, aimPos.Z))
                    end

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
-- 6. БОЕВЫЕ ВИЗУАЛЫ 360° SILENT AIM (БЕЗ КРУГА FOV + ИНДИКАТОР ЦЕЛИ ЗА СПИНОЙ!)
-------------------------------------------------------------------------
local AimSnaplineOutline = GS.TrackDrawing(Drawing and Drawing.new("Line"))
local AimSnapline = GS.TrackDrawing(Drawing and Drawing.new("Line"))
local PredLine = GS.TrackDrawing(Drawing and Drawing.new("Line"))
local PredCircle = GS.TrackDrawing(Drawing and Drawing.new("Circle"))
local TargetCross1 = GS.TrackDrawing(Drawing and Drawing.new("Line"))
local TargetCross2 = GS.TrackDrawing(Drawing and Drawing.new("Line"))
local AimStatusTag = GS.TrackDrawing(Drawing and Drawing.new("Text"))

if Drawing then
    AimSnaplineOutline.Thickness = 3; AimSnaplineOutline.Color = Color3.new(0, 0, 0)
    AimSnapline.Thickness = 1.5; AimSnapline.Color = Skeet.Accent

    PredLine.Thickness = 1.5; PredLine.Color = Skeet.Cyan
    PredCircle.Thickness = 2; PredCircle.Radius = 4.5; PredCircle.Filled = false; PredCircle.Color = Skeet.Murderer

    TargetCross1.Thickness = 1.8; TargetCross1.Color = Skeet.Accent
    TargetCross2.Thickness = 1.8; TargetCross2.Color = Skeet.Accent

    AimStatusTag.Size = 13; AimStatusTag.Center = true; AimStatusTag.Outline = true; AimStatusTag.Color = Skeet.Accent
end

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

local LastTriggerShot = 0
local LastAutoShoot = 0

GS.TrackConnection(RunService.RenderStepped:Connect(function(dt)
    if GS.Unhooked then return end

    UpdateResolver(dt)

    local myChar = LocalPlayer.Character
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if myHum and Camera.CameraSubject ~= myHum then
        Camera.CameraSubject = myHum
    end

    -- Ищем лучшую цель на все 360 градусов без ограничения FOV!
    local tPart, tPlr, tAimPos, isVis = GS.GetBestTargetInRadius(9999, false)
    GS.CurrentTargetPart = tPart
    GS.CurrentTargetPlr = tPlr
    GS.CurrentAimPos = tAimPos
    CurrentTargetIsVisible = isVis

    local mousePos = GetTrueMouseScreenPos()
    local vpSize = Camera.ViewportSize
    local vpCenter = vpSize / 2

    if Drawing then
        if Config.SilentAim and tPart and tAimPos then
            local partScreen, partOnScreen = Camera:WorldToViewportPoint(tPart.Position)
            local predScreen, predOnScreen = Camera:WorldToViewportPoint(tAimPos)
            local stateCol = isVis and Skeet.Accent or Skeet.Gold
            local dist3D = myRoot and math.floor((tPart.Position - myRoot.Position).Magnitude) or 0

            if predOnScreen then
                -- Цель перед нами на экране
                local aim2D = Vector2.new(predScreen.X, predScreen.Y)
                local p2D = Vector2.new(partScreen.X, partScreen.Y)

                AimSnaplineOutline.Visible = Config.TargetLine
                AimSnapline.Visible = Config.TargetLine
                if Config.TargetLine then
                    AimSnaplineOutline.From = mousePos
                    AimSnaplineOutline.To = aim2D
                    AimSnapline.From = mousePos
                    AimSnapline.To = aim2D
                    AimSnapline.Color = stateCol
                end

                local drawPred = Config.ShowPredictionVisualizer
                PredLine.Visible = drawPred and partOnScreen
                PredCircle.Visible = drawPred
                TargetCross1.Visible = drawPred
                TargetCross2.Visible = drawPred
                AimStatusTag.Visible = drawPred

                if drawPred then
                    PredLine.From = p2D
                    PredLine.To = aim2D
                    PredCircle.Position = aim2D

                    TargetCross1.From = aim2D - Vector2.new(6, 6)
                    TargetCross1.To = aim2D + Vector2.new(6, 6)
                    TargetCross1.Color = stateCol

                    TargetCross2.From = aim2D + Vector2.new(-6, 6)
                    TargetCross2.To = aim2D + Vector2.new(6, -6)
                    TargetCross2.Color = stateCol

                    AimStatusTag.Position = aim2D + Vector2.new(0, 10)
                    AimStatusTag.Text = string.format("[360° %s] %s (%dm)", isVis and "VISIBLE" or "WALLBANG", tPlr.Name, dist3D)
                    AimStatusTag.Color = stateCol
                end
            else
                -- Цель за спиной (вне экрана) — рисуем 360° радарный указатель направления от прицела!
                local relPos = Camera.CFrame:PointToObjectSpace(tAimPos)
                local angle = math.atan2(-relPos.Y, relPos.X)
                local edgePoint = vpCenter + Vector2.new(math.cos(angle) * 135, math.sin(angle) * 135)

                AimSnaplineOutline.Visible = Config.TargetLine
                AimSnapline.Visible = Config.TargetLine
                if Config.TargetLine then
                    AimSnaplineOutline.From = vpCenter
                    AimSnaplineOutline.To = edgePoint
                    AimSnapline.From = vpCenter
                    AimSnapline.To = edgePoint
                    AimSnapline.Color = stateCol
                end

                PredLine.Visible = false
                PredCircle.Visible = true
                PredCircle.Position = edgePoint
                TargetCross1.Visible = false
                TargetCross2.Visible = false

                AimStatusTag.Visible = true
                AimStatusTag.Position = edgePoint + Vector2.new(0, 10)
                AimStatusTag.Text = string.format("[360° BEHIND / %s] %s (%dm)", isVis and "VIS" or "WALL", tPlr.Name, dist3D)
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

    -- Авто-выстрел 360° за Шерифа (Стреляет мгновенно, даже если Мардер сзади или за стеной!)
    if Config.AutoFire and (tick() - LastAutoShoot) >= 0.45 then
        local gun = myChar:FindFirstChild("Gun")
        if gun and tPart and tPlr and tAimPos and (isVis or Config.Wallbang) then
            LastAutoShoot = tick()
            GS.DirectShootGunAt(tAimPos, tPlr, tPart)
        end
    end
end))
