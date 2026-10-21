-- File: combat.lua | 100% Working MM2 Silent Aim, Low-Bullet Fix, Camera-Priority Legitbot & Murderer Suite
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

-- Игнорируем собственного персонажа и скинченджер для Mouse.Hit / Mouse.Target (Убирает баг стрельбы в свои ноги!)
task.spawn(function()
    if LocalPlayer.Character then
        LocalMouse.TargetFilter = LocalPlayer.Character
    end
end)
GS.TrackConnection(LocalPlayer.CharacterAdded:Connect(function(ch)
    LocalMouse.TargetFilter = ch
end))

function GS.IsVisible(part)
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Head") then return false end
    GS.RaycastBypass = true
    local origin = Camera.CFrame.Position
    local dir = (part.Position - origin)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera, GS.GhostModel, GS.QuickPeekPart, GS.BacktrackGhost}
    local res = Workspace:Raycast(origin, dir, params)
    GS.RaycastBypass = false
    return (not res) or res.Instance:IsDescendantOf(part.Parent)
end

-- Точный 3D луч из перекрестия прицела (Игнорирует персонажа и скинченджер, чтобы пуля НИКОГДА не летела ниже!)
function GS.GetExactCrosshairWorldPoint()
    local mouseLoc = UserInputService:GetMouseLocation()
    local ray = Camera:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)
    GS.RaycastBypass = true
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera, GS.GhostModel, GS.QuickPeekPart, GS.BacktrackGhost}
    local hit = Workspace:Raycast(ray.Origin, ray.Direction * 1500, params)
    GS.RaycastBypass = false
    return hit and hit.Position or (ray.Origin + ray.Direction * 600)
end

-- Универсальный поиск лучшей цели в радиусе FOV (для Сайлента и Легитбота)
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
                local part = plr.Character:FindFirstChild(Config.HitPart)
                    or plr.Character:FindFirstChild("HumanoidRootPart")
                    or plr.Character:FindFirstChild("UpperTorso")
                    or plr.Character:FindFirstChild("Torso")
                if hum and hum.Health > 0 and part then
                    local role = GS.GetRole(plr)
                    if ignoreRoleFilter or (not priorityMurdererOnly) or (role == "Murderer") then
                        if (not requireVisible) or Config.Wallbang or GS.IsVisible(part) then
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
        -- +0.35 стада вверх компенсирует высоту дула револьвера в MM2, чтобы луч шёл строго в центр торса/головы!
        aimPos = baseP + Vector3.new(vel.X * (Config.Prediction / 100), 0.35, vel.Z * (Config.Prediction / 100))
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

-- Прямой выстрел через CreateBeam.RemoteFunction:InvokeServer(1, targetPos, "AH2")
function GS.DirectShootGunAt(targetPos, targetPlr)
    local myChar = LocalPlayer.Character
    local myGun = myChar and myChar:FindFirstChild("Gun")
    local rem = GS.FindGunShootRemote(myGun)
    if rem and targetPos then
        if targetPlr then
            GS.LastAttackData = {Player = targetPlr, Time = tick()}
        end
        task.spawn(function()
            pcall(function()
                rem:InvokeServer(1, targetPos, "AH2")
            end)
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
            or (m and m.Character and m.Character:FindFirstChild("HumanoidRootPart") and (m.Character.HumanoidRootPart.Position + Vector3.new(0, 0.35, 0)))
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
            GS.PlayCSGOWeaponSound(true)
            local _, tPlr, tPos = GS.GetBestTargetInRadius(Config.FOV, false)
            local shotPos = tPos or GS.GetExactCrosshairWorldPoint()
            GS.SpawnHitVisuals(shotPos, tPlr and tPlr.Name or nil, 100, tPlr and tPlr.Character or nil)
            local realRemote = GS.FindGunShootRemote(liveGun) or GS.FindGunShootRemote(clonedGun)
            if realRemote then
                task.spawn(function()
                    pcall(function() realRemote:InvokeServer(1, shotPos, "AH2") end)
                end)
            end
        end))
        GS.PushSkeetLog(string.format("Клонирован револьвер живого Шерифа (%s)!", sheriffPlr.Name), GS.Skeet.Accent)
    end
end

-- Авто-привязка к нативному событию Gun.Activated (чтобы выстрел срабатывал ДАЖЕ если инжектор плохо держит __namecall!)
local HookedGuns = {}
local function HookGunTool(tool)
    if not tool or tool.Name ~= "Gun" or HookedGuns[tool] then return end
    HookedGuns[tool] = true
    GS.TrackConnection(tool.Activated:Connect(function()
        if GS.Unhooked then return end
        GS.PlayCSGOWeaponSound(true)
        local tPart, tPlr, tPos = GS.GetBestTargetInRadius(Config.FOV, false)
        if Config.SilentAim and Config.DirectClickInvoke and tPart and tPos and math.random(1, 100) <= Config.HitChance then
            GS.DirectShootGunAt(tPos, tPlr)
        elseif Config.FixBulletDrop then
            GS.DirectShootGunAt(GS.GetExactCrosshairWorldPoint(), nil)
        end
    end))
end

-------------------------------------------------------------------------
-- ПРОВЕРЕННЫЙ 3-СЛОЙНЫЙ ХУК МЕТАТАБЛИЦЫ (YOUGAME / V3RMILLION MM2 FORMAT)
-------------------------------------------------------------------------
local mt = getrawmetatable and getrawmetatable(game)
GS.mt = mt

if mt and setreadonly then
    GS.oldNamecall = mt.__namecall
    GS.oldIndex = mt.__index
    local oldNamecall = GS.oldNamecall
    local oldIndex = GS.oldIndex
    setreadonly(mt, false)

    -- Слой 1: Подмена Mouse.Hit / Mouse.Target / UnitRay (То, что читает сам Gun.KnifeLocal перед выстрелом!)
    mt.__index = newcclosure(function(self, key)
        if not GS.Unhooked and not checkcaller() and self == LocalMouse then
            if key == "Hit" or key == "hit" then
                if Config.SilentAim and GS.CurrentTargetPart and GS.CurrentAimPos then
                    GS.LastAttackData = {Player = GS.CurrentTargetPlr, Time = tick()}
                    return CFrame.new(GS.CurrentAimPos)
                elseif Config.FixBulletDrop then
                    return CFrame.new(GS.GetExactCrosshairWorldPoint())
                end
            elseif key == "Target" or key == "target" then
                if Config.SilentAim and GS.CurrentTargetPart then
                    return GS.CurrentTargetPart
                end
            elseif key == "UnitRay" or key == "unitRay" then
                if Config.SilentAim and GS.CurrentAimPos then
                    local orig = Camera.CFrame.Position
                    return Ray.new(orig, (GS.CurrentAimPos - orig).Unit)
                end
            end
        end
        return oldIndex(self, key)
    end)

    -- Слой 2: Перехват InvokeServer / FireServer + Wallbang Raycast (Без вызовов self:IsA!)
    mt.__namecall = newcclosure(function(self, ...)
        if GS.Unhooked or checkcaller() or GS.RaycastBypass then
            return oldNamecall(self, ...)
        end

        local method = getnamecallmethod()
        local args = {...}
        local selfStr = tostring(self)

        -- Перехват выстрела пистолета: Gun.KnifeLocal.CreateBeam.RemoteFunction:InvokeServer(1, Vector3, "AH2")
        if method == "InvokeServer" and (selfStr == "RemoteFunction" or selfStr == "ShootGun" or (args[1] == 1 and typeof(args[2]) == "Vector3")) then
            if Config.SilentAim and GS.CurrentTargetPart and GS.CurrentAimPos and math.random(1, 100) <= Config.HitChance then
                GS.LastAttackData = {Player = GS.CurrentTargetPlr, Time = tick()}
                for i, v in ipairs(args) do
                    if typeof(v) == "Vector3" then
                        args[i] = GS.CurrentAimPos
                    elseif typeof(v) == "CFrame" then
                        args[i] = CFrame.new(v.Position, GS.CurrentAimPos)
                    end
                end
                return oldNamecall(self, unpack(args))
            elseif Config.FixBulletDrop then
                local exactPos = GS.GetExactCrosshairWorldPoint()
                for i, v in ipairs(args) do
                    if typeof(v) == "Vector3" then
                        args[i] = exactPos
                    end
                end
                return oldNamecall(self, unpack(args))
            end
        end

        -- Перехват броска ножа: Knife.Throw:FireServer(...)
        if method == "FireServer" and (selfStr == "Throw" or selfStr == "KnifeThrown") then
            if (Config.SilentAim or Config.SilentKnifeThrow) and GS.CurrentTargetPart and GS.CurrentAimPos then
                GS.LastAttackData = {Player = GS.CurrentTargetPlr, Time = tick()}
                for i, v in ipairs(args) do
                    if typeof(v) == "Vector3" then
                        args[i] = GS.CurrentAimPos
                    elseif typeof(v) == "CFrame" then
                        args[i] = CFrame.new(v.Position, GS.CurrentAimPos)
                    end
                end
                return oldNamecall(self, unpack(args))
            end
        end

        -- Wallbang: Подмена клиентского луча (FindPartOnRayWithIgnoreList / FindPartOnRay), чтобы пуля револьвера проходила сквозь стены!
        if Config.Wallbang and Config.SilentAim and GS.CurrentTargetPart and GS.CurrentAimPos then
            if method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRay" or method == "FindPartOnRayWithWhitelist" then
                return GS.CurrentTargetPart, GS.CurrentAimPos, Vector3.new(0, 1, 0), Enum.Material.Plastic
            end
        end

        return oldNamecall(self, ...)
    end)

    setreadonly(mt, true)
end

-- РАБОЧИЙ ЛЕГИТБОТ: Выполняется на приоритете Camera.Value + 1 (ПОСЛЕ скрипта камеры Roblox!)
GS.BindRenderStep("GS_LegitAim", Enum.RenderPriority.Camera.Value + 1, function()
    if GS.Unhooked then return end

    -- Обновляем текущую цель для Сайлента каждый кадр
    GS.CurrentTargetPart, GS.CurrentTargetPlr, GS.CurrentAimPos = GS.GetBestTargetInRadius(Config.FOV, false)

    local myChar = LocalPlayer.Character
    if myChar then
        local g = myChar:FindFirstChild("Gun")
        if g then HookGunTool(g) end
    end

    if Config.LegitAim and not (GS.OuterWindow and GS.OuterWindow.Visible) then
        local activeKey = (Config.LegitAimKey == "Always On")
            or (Config.LegitAimKey == "MouseButton2 (RMB)" and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2))
            or (Config.LegitAimKey == "Key E" and UserInputService:IsKeyDown(Enum.KeyCode.E))

        if activeKey then
            local lPart, _, lPos = GS.GetBestTargetInRadius(Config.LegitFOV, Config.LegitVisibleOnly)
            if lPart and lPos then
                local camPos = Camera.CFrame.Position
                local goalCF = CFrame.lookAt(camPos, lPos)
                local alpha = math.clamp(1 / math.max(Config.LegitSmooth, 1), 0.03, 0.85)
                Camera.CFrame = Camera.CFrame:Lerp(goalCF, alpha)
            end
        end
    end
end)
