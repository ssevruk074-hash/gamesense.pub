-- File: combat.lua | Verified MM2 Silent Aim (Post-Raycast Override), True Wallbang, 0px Ray Fix & Camera Legitbot
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

-- Игнорируем собственного персонажа и визуалы для нативной мыши
task.spawn(function()
    if LocalPlayer.Character then
        LocalMouse.TargetFilter = LocalPlayer.Character
    end
end)
GS.TrackConnection(LocalPlayer.CharacterAdded:Connect(function(ch)
    LocalMouse.TargetFilter = ch
end))

function GS.IsVisible(part, customOrigin)
    if not part or not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Head") then return false end
    GS.RaycastBypass = true
    local origin = customOrigin or LocalPlayer.Character.Head.Position
    local dir = (part.Position - origin)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera, GS.GhostModel, GS.QuickPeekPart, GS.BacktrackGhost}
    local res = Workspace:Raycast(origin, dir, params)
    GS.RaycastBypass = false
    return (not res) or res.Instance:IsDescendantOf(part.Parent)
end

-- ИСПРАВЛЕННЫЙ ЛУЧ ПРИЦЕЛА: Использует ScreenPointToRay(LocalMouse.X, LocalMouse.Y) без ошибки в 58 пикселей вниз!
function GS.GetExactCrosshairWorldPoint()
    local ray = Camera:ScreenPointToRay(LocalMouse.X, LocalMouse.Y)
    GS.RaycastBypass = true
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera, GS.GhostModel, GS.QuickPeekPart, GS.BacktrackGhost}
    local hit = Workspace:Raycast(ray.Origin, ray.Direction * 1500, params)
    GS.RaycastBypass = false
    return hit and hit.Position or (ray.Origin + ray.Direction * 600)
end

-- Мульти-поинт поиск открытой части тела врага (чтобы простреливать углы и укрытия)
local MultiPointParts = {"Head", "UpperTorso", "HumanoidRootPart", "LowerTorso", "RightHand", "LeftHand", "RightFoot", "LeftFoot", "Torso"}

local function GetBestVisiblePartOnCharacter(char)
    local mainPart = char:FindFirstChild(Config.HitPart) or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
    if mainPart and GS.IsVisible(mainPart) then
        return mainPart
    end
    for _, partName in ipairs(MultiPointParts) do
        local p = char:FindFirstChild(partName)
        if p and GS.IsVisible(p) then
            return p
        end
    end
    return mainPart
end

-- Точный поиск цели в радиусе FOV
function GS.GetBestTargetInRadius(fovRadius, requireVisible)
    local myRole = GS.GetRole(LocalPlayer)
    local bestPart, bestPlr, bestPos = nil, nil, nil
    local bestDist = fovRadius
    local mousePos = UserInputService:GetMouseLocation()

    local priorityMurdererOnly = (Config.TargetRolePriority == "Murderer Only")
        or (Config.TargetRolePriority == "Smart (Role-Based)" and myRole == "Sheriff" and GS.FindByRole("Murderer") ~= nil)

    local function checkList(ignoreRoleFilter)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                local part = GetBestVisiblePartOnCharacter(plr.Character)
                if hum and hum.Health > 0 and part then
                    local role = GS.GetRole(plr)
                    if ignoreRoleFilter or (not priorityMurdererOnly) or (role == "Murderer") then
                        local vis = GS.IsVisible(part)
                        if (not requireVisible) or Config.Wallbang or vis then
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
                            if Config.LegitBacktrack and GS.BacktrackHistory[plr] then
                                for _, record in ipairs(GS.BacktrackHistory[plr]) do
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
        local pred = Config.Prediction / 100
        -- Предсказание только по горизонтали (X, Z), чтобы прыжки врага не уводили пулю в пол!
        aimPos = baseP + Vector3.new(vel.X * pred, 0.25, vel.Z * pred)
    end
    return bestPart, bestPlr, aimPos
end

-- Поиск револьвера и его RemoteFunction (CreateBeam.RemoteFunction или ShootGun)
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
    local shootGun = gunInstance:FindFirstChild("ShootGun", true)
    if shootGun then return shootGun end
    return gunInstance:FindFirstChildOfClass("RemoteFunction", true)
end

-- Прямой выстрел с поддержкой Wallbang Line-Of-Sight Bypass
function GS.DirectShootGunAt(targetPos, targetPlr, targetPart)
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myGun = myChar and myChar:FindFirstChild("Gun")
    local rem = GS.FindGunShootRemote(myGun)
    if rem and targetPos then
        if targetPlr then
            GS.LastAttackData = {Player = targetPlr, Time = tick()}
        end
        task.spawn(function()
            -- Если враг за стеной и включён Wallbang, на 1 физический тик поднимаем серверный луч над препятствием
            local oldCF = nil
            if Config.Wallbang and myRoot and targetPart and not GS.IsVisible(targetPart) then
                oldCF = myRoot.CFrame
                local highOrigin = oldCF * CFrame.new(0, 12, 0)
                if GS.IsVisible(targetPart, highOrigin.Position) then
                    myRoot.CFrame = highOrigin
                end
            end
            pcall(function()
                rem:InvokeServer(1, targetPos, "AH2")
            end)
            if oldCF and myRoot then
                RunService.Heartbeat:Wait()
                myRoot.CFrame = oldCF
            end
        end)
        return true
    end
    return false
end

function GS.RemoteFireLivingSheriffGun(customTargetPos)
    local liveGun = GS.FindLivingSheriffGun()
    if not liveGun then
        local myChar = LocalPlayer.Character
        liveGun = myChar and myChar:FindFirstChild("Gun")
    end
    local remote = GS.FindGunShootRemote(liveGun)
    if remote then
        local m = GS.FindByRole("Murderer")
        local targetPos = customTargetPos
            or (m and m.Character and m.Character:FindFirstChild("HumanoidRootPart") and (m.Character.HumanoidRootPart.Position + Vector3.new(0, 0.25, 0)))
            or GS.GetExactCrosshairWorldPoint()
        if m then GS.LastAttackData = {Player = m, Time = tick()} end
        GS.PlayCSGOWeaponSound(true)
        task.spawn(function()
            pcall(function() remote:InvokeServer(1, targetPos, "AH2") end)
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
        GS.PushSkeetLog("Подобран выпавший револьвер Шерифа!", GS.Skeet.Accent)
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

        GS.TrackConnection(clonedGun.Activated:Connect(function()
            local _, tPlr, tPos = GS.GetBestTargetInRadius(Config.FOV, false)
            local shotPos = tPos or GS.GetExactCrosshairWorldPoint()
            local realRemote = GS.FindGunShootRemote(liveGun) or GS.FindGunShootRemote(clonedGun)
            if realRemote then
                GS.PlayCSGOWeaponSound(true)
                GS.SpawnHitVisuals(shotPos, tPlr and tPlr.Name or nil, 100, tPlr and tPlr.Character or nil)
                task.spawn(function()
                    pcall(function() realRemote:InvokeServer(1, shotPos, "AH2") end)
                end)
            end
        end))
        GS.PushSkeetLog(string.format("Клонирован револьвер живого Шерифа (%s)!", sheriffPlr.Name), GS.Skeet.Accent)
    end
end

-------------------------------------------------------------------------
-- СТОПРОЦЕНТНЫЙ ХУК МЕТАТАБЛИЦЫ MM2 (ОБХОД КЛИЕНТСКОГО РЕЙКАСТА KNIFELOCAL)
-------------------------------------------------------------------------
local mt = getrawmetatable and getrawmetatable(game)
GS.mt = mt

if mt and setreadonly then
    GS.oldNamecall = mt.__namecall
    GS.oldIndex = mt.__index
    local oldNamecall = GS.oldNamecall
    local oldIndex = GS.oldIndex
    setreadonly(mt, false)

    -- 1. Хук Mouse.Hit / Target / UnitRay (Возвращает CFrame.lookAt с правильным углом луча!)
    mt.__index = newcclosure(function(self, key)
        if not GS.Unhooked and not checkcaller() and self == LocalMouse then
            local orig = Camera.CFrame.Position
            if key == "Hit" or key == "hit" then
                if Config.SilentAim and GS.CurrentTargetPart and GS.CurrentAimPos then
                    GS.LastAttackData = {Player = GS.CurrentTargetPlr, Time = tick()}
                    local dir = (GS.CurrentAimPos - orig).Unit
                    return CFrame.lookAt(GS.CurrentAimPos, GS.CurrentAimPos + dir)
                elseif Config.FixBulletDrop then
                    local exactP = GS.GetExactCrosshairWorldPoint()
                    local dir = (exactP - orig).Unit
                    return CFrame.lookAt(exactP, exactP + dir)
                end
            elseif key == "Target" or key == "target" then
                if Config.SilentAim and GS.CurrentTargetPart then
                    return GS.CurrentTargetPart
                end
            elseif key == "UnitRay" or key == "unitRay" then
                if Config.SilentAim and GS.CurrentAimPos then
                    return Ray.new(orig, (GS.CurrentAimPos - orig).Unit)
                elseif Config.FixBulletDrop then
                    local exactP = GS.GetExactCrosshairWorldPoint()
                    return Ray.new(orig, (exactP - orig).Unit)
                end
            end
        end
        return oldIndex(self, key)
    end)

    -- 2. Хук InvokeServer (CreateBeam) + Клиентский Рейкаст KnifeLocal (FindPartOnRayWithIgnoreList)
    mt.__namecall = newcclosure(function(self, ...)
        if GS.Unhooked or checkcaller() or GS.RaycastBypass then
            return oldNamecall(self, ...)
        end

        local method = getnamecallmethod()
        local args = {...}

        -- КЛЮЧЕВОЙ ФИКС: Когда KnifeLocal пускает луч от бедра и втыкается в пол/рампу/стену перед тобой,
        -- мы перехватываем этот луч и возвращаем напрямую хитбокс врага (CurrentTargetPart, CurrentAimPos)!
        if method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRay" or method == "FindPartOnRayWithWhitelist" then
            local myChar = LocalPlayer.Character
            if myChar and myChar:FindFirstChild("Gun") then
                if Config.SilentAim and GS.CurrentTargetPart and GS.CurrentAimPos then
                    return GS.CurrentTargetPart, GS.CurrentAimPos, Vector3.new(0, 1, 0), Enum.Material.Plastic
                elseif Config.FixBulletDrop then
                    local exactP = GS.GetExactCrosshairWorldPoint()
                    return nil, exactP, Vector3.new(0, 1, 0), Enum.Material.Air
                end
            end
        end

        -- ПЕРЕХВАТ ВЫСТРЕЛА ПИСТОЛЕТА: CreateBeam.RemoteFunction:InvokeServer(1, hitPos, "AH2")
        if method == "InvokeServer" and (args[1] == 1 and typeof(args[2]) == "Vector3") then
            -- Звук AWP играет ТОЛЬКО здесь, когда пистолет реально стреляет (никаких ложных звуков на КД!)
            GS.PlayCSGOWeaponSound(true)

            if Config.SilentAim and GS.CurrentTargetPart and GS.CurrentAimPos and math.random(1, 100) <= Config.HitChance then
                GS.LastAttackData = {Player = GS.CurrentTargetPlr, Time = tick()}
                args[2] = GS.CurrentAimPos
                return oldNamecall(self, unpack(args))
            elseif Config.FixBulletDrop then
                args[2] = GS.GetExactCrosshairWorldPoint()
                return oldNamecall(self, unpack(args))
            end
        end

        -- ПЕРЕХВАТ БРОСКА НОЖА: Knife.Throw:FireServer(...)
        if method == "FireServer" and #args >= 1 and (typeof(args[1]) == "CFrame" or typeof(args[2]) == "Vector3") then
            local selfStr = tostring(self)
            if selfStr == "Throw" or selfStr == "KnifeThrown" then
                if (Config.SilentAim or Config.SilentKnifeThrow) and GS.CurrentTargetPart and GS.CurrentAimPos then
                    GS.LastAttackData = {Player = GS.CurrentTargetPlr, Time = tick()}
                    for i, v in ipairs(args) do
                        if typeof(v) == "Vector3" then
                            args[i] = GS.CurrentAimPos
                        elseif typeof(v) == "CFrame" then
                            args[i] = CFrame.lookAt(v.Position, GS.CurrentAimPos)
                        end
                    end
                    return oldNamecall(self, unpack(args))
                end
            end
        end

        return oldNamecall(self, ...)
    end)

    setreadonly(mt, true)
end

-- РАБОЧИЙ ЛЕГИТБОТ И ТРИГГЕРБОТ (Выполняется после скрипта камеры Roblox!)
local LastTriggerShot = 0

GS.BindRenderStep("GS_LegitAim", Enum.RenderPriority.Camera.Value + 1, function()
    if GS.Unhooked then return end

    GS.CurrentTargetPart, GS.CurrentTargetPlr, GS.CurrentAimPos = GS.GetBestTargetInRadius(Config.FOV, false)

    local myChar = LocalPlayer.Character
    if not myChar then return end

    -- Доводка камеры Легитбота
    if Config.LegitAim and not (GS.OuterWindow and GS.OuterWindow.Visible) then
        local activeKey = (Config.LegitAimKey == "Always On")
            or (Config.LegitAimKey == "MouseButton2 (RMB)" and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2))
            or (Config.LegitAimKey == "Key E" and UserInputService:IsKeyDown(Enum.KeyCode.E))

        if activeKey then
            local lPart, _, lPos = GS.GetBestTargetInRadius(Config.LegitFOV, Config.LegitVisibleOnly)
            if lPart and lPos then
                local camPos = Camera.CFrame.Position
                local goalCF = CFrame.lookAt(camPos, lPos)
                local alpha = math.clamp(1 / math.max(Config.LegitSmooth, 1), 0.04, 0.90)
                Camera.CFrame = Camera.CFrame:Lerp(goalCF, alpha)
            end
        end
    end

    -- Легит Триггербот
    if Config.LegitTriggerbot and (tick() - LastTriggerShot) >= (Config.TriggerbotDelay / 1000) then
        local gun = myChar:FindFirstChild("Gun")
        if gun and GS.CurrentTargetPart and GS.CurrentTargetPlr and GS.IsVisible(GS.CurrentTargetPart) then
            local sp, onScreen = Camera:WorldToViewportPoint(GS.CurrentTargetPart.Position)
            local mousePos = UserInputService:GetMouseLocation()
            if onScreen and (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude <= 35 then
                LastTriggerShot = tick()
                GS.DirectShootGunAt(GS.CurrentAimPos, GS.CurrentTargetPlr, GS.CurrentTargetPart)
            end
        end
    end
end)
