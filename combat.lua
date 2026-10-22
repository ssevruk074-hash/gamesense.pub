-- File: combat.lua | Zero-Freeze Silent Aim, 100% Wallbang, Anti-Fling & Target Fling (Rage Suite)
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

local LastWeaponClickTime = 0

function GS.IsVisible(part, customOrigin)
    if not part or not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Head") then return false end
    GS.RaycastBypass = true
    local origin = customOrigin or Camera.CFrame.Position
    local dir = (part.Position - origin)
    if dir.Magnitude < 0.1 then GS.RaycastBypass = false; return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera, GS.GhostModel, GS.QuickPeekPart, GS.BacktrackGhost}
    local res = Workspace:Raycast(origin, dir, params)
    GS.RaycastBypass = false
    return (not res) or res.Instance:IsDescendantOf(part.Parent)
end

function GS.GetExactCrosshairWorldPoint()
    local ray = Camera:ScreenPointToRay(LocalMouse.X, LocalMouse.Y)
    GS.RaycastBypass = true
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera, GS.GhostModel, GS.QuickPeekPart, GS.BacktrackGhost}
    local hit = Workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
    GS.RaycastBypass = false
    return hit and hit.Position or (ray.Origin + ray.Direction * 800)
end

-------------------------------------------------------------------------
-- УМНЫЙ ПОИСК ЦЕЛИ (МУЛЬТИ-ПОИНТ + 360° RAGE)
-------------------------------------------------------------------------
local MultiPointList = {"HumanoidRootPart", "Head", "UpperTorso", "LowerTorso", "Torso", "RightHand", "LeftHand"}

local function GetBestCharacterPart(char)
    local preferred = char:FindFirstChild(Config.HitPart) or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
    if preferred and GS.IsVisible(preferred) then return preferred end
    for _, name in ipairs(MultiPointList) do
        local p = char:FindFirstChild(name)
        if p and GS.IsVisible(p) then return p end
    end
    return preferred
end

function GS.GetBestTargetInRadius(fovRadius, requireVisible)
    local myRole = GS.GetRole(LocalPlayer)
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local mousePos = UserInputService:GetMouseLocation()

    local bestPart, bestPlr, bestPos = nil, nil, nil
    local bestScore = math.huge

    local priorityMurdererOnly = (Config.TargetRolePriority == "Murderer Only")
        or (Config.TargetRolePriority == "Smart (Role-Based)" and myRole == "Sheriff" and GS.FindByRole("Murderer") ~= nil)

    local function scanPlayers(ignoreRole, ignoreScreenFOV)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local char = plr.Character
                local hum = char:FindFirstChildOfClass("Humanoid")
                local part = GetBestCharacterPart(char)

                if hum and hum.Health > 0 and part then
                    local role = GS.GetRole(plr)
                    if ignoreRole or (not priorityMurdererOnly) or (role == "Murderer") then
                        local isVis = GS.IsVisible(part)
                        if (not requireVisible) or Config.Wallbang or isVis then
                            local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                            local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude

                            if onScreen and screenDist <= fovRadius then
                                if screenDist < bestScore then
                                    bestScore = screenDist
                                    bestPart = part
                                    bestPlr = plr
                                    bestPos = part.Position
                                end
                            elseif ignoreScreenFOV then
                                local worldDist = myRoot and (part.Position - myRoot.Position).Magnitude or 999
                                if worldDist < bestScore then
                                    bestScore = worldDist
                                    bestPart = part
                                    bestPlr = plr
                                    bestPos = part.Position
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    scanPlayers(false, false)
    if not bestPart and not requireVisible then
        bestScore = math.huge
        scanPlayers(false, true)
    end
    if not bestPart and Config.TargetRolePriority == "Smart (Role-Based)" then
        bestScore = math.huge
        scanPlayers(true, false)
        if not bestPart and not requireVisible then
            bestScore = math.huge
            scanPlayers(true, true)
        end
    end

    local aimPos = nil
    if bestPart then
        local baseP = bestPos or bestPart.Position
        local vel = bestPart.AssemblyLinearVelocity or bestPart.Velocity or Vector3.zero
        local pred = Config.Prediction / 100
        aimPos = baseP + Vector3.new(vel.X * pred, 0.15, vel.Z * pred)
    end
    return bestPart, bestPlr, aimPos
end

-------------------------------------------------------------------------
-- ПОИСК РЕМОУТОВ И 100% СЕРВЕРНЫЙ WALLBANG (MICRO-LOS BYPASS)
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

local function GetWallbangVantageCFrame(myRoot, targetPart)
    if not myRoot or not targetPart then return nil end
    local tPos = targetPart.Position
    local offsets = {
        Vector3.new(0, 6, 0),
        Vector3.new(0, 3, 4),
        Vector3.new(0, 3, -4),
        Vector3.new(4, 3, 0),
        Vector3.new(-4, 3, 0)
    }
    for _, off in ipairs(offsets) do
        local testOrigin = tPos + off
        if GS.IsVisible(targetPart, testOrigin) then
            return CFrame.lookAt(testOrigin, tPos)
        end
    end
    return CFrame.lookAt(tPos + Vector3.new(0, 4, 2), tPos)
end

function GS.DirectShootGunAt(targetPos, targetPlr, targetPart)
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myGun = myChar and myChar:FindFirstChild("Gun")
    local rem = GS.FindGunShootRemote(myGun)
    if not rem or not targetPos then return false end

    if targetPlr then
        GS.LastAttackData = {Player = targetPlr, Time = tick()}
    end

    task.spawn(function()
        local savedCF = nil
        local needWallbangBypass = Config.Wallbang and myRoot and targetPart and (not GS.IsVisible(targetPart))

        if needWallbangBypass then
            savedCF = myRoot.CFrame
            local vantageCF = GetWallbangVantageCFrame(myRoot, targetPart)
            if vantageCF then myRoot.CFrame = vantageCF end
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
            if myRoot and myRoot.Parent then myRoot.CFrame = savedCF end
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

-------------------------------------------------------------------------
-- ХУК МЕТАТАБЛИЦЫ (БЕЗ ЗАВИСАНИЯ КАМЕРЫ + 100% WALLBANG РЕЙКАСТЫ)
-------------------------------------------------------------------------
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

    -- Подмена Mouse.Hit ТОЛЬКО при активном клике с оружием в руках (0% лагов камеры!)
    mt.__index = newcclosure(function(self, key)
        if not GS.Unhooked and not checkcaller() and self == LocalMouse then
            if key == "Hit" or key == "hit" or key == "Target" or key == "target" then
                local myChar = LocalPlayer.Character
                local holdingWeapon = myChar and (myChar:FindFirstChild("Gun") or myChar:FindFirstChild("Knife"))
                if holdingWeapon then
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

        if (tick() - LastWeaponClickTime) <= 0.18 then
            if method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRay" or method == "FindPartOnRayWithWhitelist" then
                if Config.SilentAim and GS.CurrentTargetPart and GS.CurrentAimPos then
                    return GS.CurrentTargetPart, GS.CurrentAimPos, Vector3.new(0, 1, 0), Enum.Material.Plastic
                elseif Config.FixBulletDrop then
                    local exactP = GS.GetExactCrosshairWorldPoint()
                    return nil, exactP, Vector3.new(0, 1, 0), Enum.Material.Air
                end
            end
        end

        if method == "FireServer" or method == "InvokeServer" then
            local isWep = IsWeaponRemote(self)
            local isOfficialCreateBeam = (method == "InvokeServer" and args[1] == 1 and typeof(args[2]) == "Vector3")

            if isWep or isOfficialCreateBeam then
                local tPart, tPlr, tPos = GS.GetBestTargetInRadius(Config.FOV, false)
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
                    if Config.Wallbang and myRoot and not GS.IsVisible(targetPart) then
                        savedCF = myRoot.CFrame
                        local vantageCF = GetWallbangVantageCFrame(myRoot, targetPart)
                        if vantageCF then myRoot.CFrame = vantageCF end
                    end

                    local coordIndices = {}
                    for i, v in ipairs(args) do
                        if typeof(v) == "Vector3" or typeof(v) == "CFrame" then
                            table.insert(coordIndices, i)
                        end
                    end

                    if #coordIndices == 1 then
                        local idx = coordIndices[1]
                        if typeof(args[idx]) == "Vector3" then args[idx] = aimPos
                        elseif typeof(args[idx]) == "CFrame" then args[idx] = CFrame.new(aimPos) end
                    elseif #coordIndices >= 2 then
                        local firstIdx = coordIndices[1]
                        local lastIdx = coordIndices[#coordIndices]
                        if typeof(args[firstIdx]) == "CFrame" then args[firstIdx] = CFrame.lookAt(args[firstIdx].Position, aimPos) end
                        if typeof(args[lastIdx]) == "Vector3" then args[lastIdx] = aimPos
                        elseif typeof(args[lastIdx]) == "CFrame" then args[lastIdx] = CFrame.new(aimPos) end
                    else
                        args[1] = aimPos
                    end

                    for i, v in ipairs(args) do
                        if typeof(v) == "Instance" and v:IsA("BasePart") then
                            args[i] = targetPart
                        end
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
-- АНТИ-ФЛИНГ И ТАРГЕТ ФЛИНГ (АНТИ-ТОЛЧОК + УДАЛЕНИЕ ИГРОКОВ ИЗ СЕРВЕРА)
-------------------------------------------------------------------------
local AntiFlingActive = true
local TargetFlingTarget = nil

-- 1. АНТИ-ФЛИНГ: Полностью отключает столкновения с телами других игроков, чтобы тебя не могли закинуть за карту читеры!
RunService.Stepped:Connect(function()
    if GS.Unhooked or not AntiFlingActive then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            for _, part in ipairs(p.Character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end
end)

-- 2. ТАРГЕТ ФЛИНГ (Раскручивает и улетает в пустоту выбранную цель из Target HUD / ближайшего врага)
function GS.ToggleTargetFling()
    TargetFlingTarget = GS.CurrentTargetPlr
    if not TargetFlingTarget then
        GS.PushSkeetLog("Target Fling: Нет цели в прицеле!", Skeet.Danger)
        return
    end
    GS.PushSkeetLog("Target Fling активирован на: " .. TargetFlingTarget.Name, Skeet.Gold)
    task.spawn(function()
        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local tChar = TargetFlingTarget.Character
        local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
        if not myRoot or not tRoot then return end

        local bav = Instance.new("BodyAngularVelocity", myRoot)
        bav.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bav.AngularVelocity = Vector3.new(0, 99999, 0) -- Мгновенное вращение со скоростью света

        local startTime = tick()
        while tick() - startTime < 1.2 and not GS.Unhooked do
            if tRoot and tRoot.Parent then
                myRoot.CFrame = tRoot.CFrame
                myRoot.AssemblyLinearVelocity = Vector3.new(99999, 99999, 99999)
            end
            RunService.RenderStepped:Wait()
        end
        bav:Destroy()
        if myRoot then myRoot.AssemblyLinearVelocity = Vector3.zero end
        GS.PushSkeetLog("Target Fling завершён!", Skeet.Accent)
    end)
end

local LastTriggerShot = 0

GS.BindRenderStep("GS_LegitAim", Enum.RenderPriority.Camera.Value + 1, function()
    if GS.Unhooked then return end

    local myChar = LocalPlayer.Character
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")

    if myHum and Camera.CameraSubject ~= myHum then
        Camera.CameraSubject = myHum
    end

    GS.CurrentTargetPart, GS.CurrentTargetPlr, GS.CurrentAimPos = GS.GetBestTargetInRadius(Config.FOV, false)

    if not myChar then return end

    if Config.LegitAim and not (GS.OuterWindow and GS.OuterWindow.Visible) then
        local activeKey = (Config.LegitAimKey == "Always On")
            or (Config.LegitAimKey == "MouseButton2 (RMB)" and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2))
            or (Config.LegitAimKey == "Key E" and UserInputService:IsKeyDown(Enum.KeyCode.E))

        if activeKey then
            local lPart, _, lPos = GS.GetBestTargetInRadius(Config.LegitFOV, Config.LegitVisibleOnly)
            if lPart and lPos then
                local camPos = Camera.CFrame.Position
                local dist = (lPos - camPos).Magnitude
                if dist > 0.5 then
                    local goalCF = CFrame.lookAt(camPos, lPos)
                    local alpha = math.clamp(1 / math.max(Config.LegitSmooth, 2), 0.05, 0.95)
                    Camera.CFrame = Camera.CFrame:Lerp(goalCF, alpha)
                end
            end
        end
    end

    if Config.LegitTriggerbot and (tick() - LastTriggerShot) >= (Config.TriggerbotDelay / 1000) then
        local gun = myChar:FindFirstChild("Gun")
        if gun and GS.CurrentTargetPart and GS.CurrentTargetPlr and GS.IsVisible(GS.CurrentTargetPart) then
            local sp, onScreen = Camera:WorldToViewportPoint(GS.CurrentTargetPart.Position)
            local mousePos = UserInputService:GetMouseLocation()
            if onScreen and (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude <= 38 then
                LastTriggerShot = tick()
                GS.DirectShootGunAt(GS.CurrentAimPos, GS.CurrentTargetPlr, GS.CurrentTargetPart)
            end
        end
    end
end)
