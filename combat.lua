-- File: combat.lua | Universal Rage Silent Aim + Wallbang (Works on Official MM2 & All Modded MM2 Servers)
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

-- Игнорируем собственного персонажа и скинченджер для мыши
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
    local origin = customOrigin or Camera.CFrame.Position
    local dir = (part.Position - origin)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera, GS.GhostModel, GS.QuickPeekPart, GS.BacktrackGhost}
    local res = Workspace:Raycast(origin, dir, params)
    GS.RaycastBypass = false
    return (not res) or res.Instance:IsDescendantOf(part.Parent)
end

-- Идеальный 3D луч из прицела без смещения вниз на 58px
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
-- УЛУЧШЕННЫЙ ПОИСК ЦЕЛИ (ОБЪЕДИНЁН С ТВОИМ GETRAGETARGET — БЕРЁТ ДАЖЕ СКВОЗЬ СТЕНЫ И ВНЕ FOV!)
-------------------------------------------------------------------------
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
                local part = char:FindFirstChild(Config.HitPart)
                    or char:FindFirstChild("Head")
                    or char:FindFirstChild("HumanoidRootPart")
                    or char:FindFirstChild("UpperTorso")
                    or char:FindFirstChild("Torso")

                if hum and hum.Health > 0 and part then
                    local role = GS.GetRole(plr)
                    if ignoreRole or (not priorityMurdererOnly) or (role == "Murderer") then
                        if (not requireVisible) or Config.Wallbang or GS.IsVisible(part) then
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
                                -- RAGE FALLBACK ИЗ ТВОЕГО КОДА: Если в круге FOV никого нет, берём ближайшего живого врага на карте (игнорируя стены и FOV)!
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

    -- 1. Сначала ищем в радиусе прицела (по роли)
    scanPlayers(false, false)
    -- 2. Если не нашли в прицеле (или враг за спиной/за стеной), в Rage-режиме берём по всей карте как в твоём GetRageTarget()!
    if not bestPart and not requireVisible then
        bestScore = math.huge
        scanPlayers(false, true)
    end
    -- 3. Если Мардер ещё не выбран (или тест в лобби/на обычных игроках) — берём любого ближайшего игрока!
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
        -- Точка попадания точно в центр выбранной части тела (Head / HumanoidRootPart) с упреждением
        aimPos = baseP + Vector3.new(vel.X * pred, 0, vel.Z * pred)
    end
    return bestPart, bestPlr, aimPos
end

-------------------------------------------------------------------------
-- УНИВЕРСАЛЬНЫЙ ПОИСК И ЗАПУСК ЛЮБОГО РЕМОУТА ОРУЖИЯ
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

function GS.DirectShootGunAt(targetPos, targetPlr, targetPart)
    local myChar = LocalPlayer.Character
    local myGun = myChar and myChar:FindFirstChild("Gun")
    local rem = GS.FindGunShootRemote(myGun)
    if rem and targetPos then
        if targetPlr then
            GS.LastAttackData = {Player = targetPlr, Time = tick()}
        end
        task.spawn(function()
            pcall(function()
                if rem:IsA("RemoteFunction") then
                    rem:InvokeServer(1, targetPos, "AH2")
                elseif rem:IsA("RemoteEvent") then
                    rem:FireServer(CFrame.new(targetPos), targetPos)
                end
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
        local _, tPlr, tPos = GS.GetBestTargetInRadius(Config.FOV, false)
        local targetPos = customTargetPos or tPos or GS.GetExactCrosshairWorldPoint()
        if tPlr then GS.LastAttackData = {Player = tPlr, Time = tick()} end
        GS.PlayCSGOWeaponSound(true)
        task.spawn(function()
            pcall(function()
                if remote:IsA("RemoteFunction") then
                    remote:InvokeServer(1, targetPos, "AH2")
                elseif remote:IsA("RemoteEvent") then
                    remote:FireServer(CFrame.new(targetPos), targetPos)
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
        GS.PushSkeetLog(string.format("Клонирован револьвер живого Шерифа (%s)!", sheriffPlr.Name), GS.Skeet.Accent)
    end
end

-------------------------------------------------------------------------
-- УНИВЕРСАЛЬНЫЙ ХУК МЕТАТАБЛИЦЫ (ОБЪЕДИНЯЕТ ТВОЙ RAGE-КОД + ОФИЦИАЛЬНЫЙ MM2 + МОДЫ!)
-------------------------------------------------------------------------
local mt = getrawmetatable and getrawmetatable(game)
GS.mt = mt

-- Проверяет, принадлежит ли вызываемый RemoteEvent / RemoteFunction твоему оружию в руках
local function IsWeaponRemote(obj, method)
    local name = tostring(obj)
    if name == "Shoot" or name == "ShootGun" or name == "UseTool" or name == "Fire" or name == "CreateBeam" or name == "Throw" or name == "KnifeThrown" then
        return true
    end
    -- Проверяем, лежит ли этот Remote внутри нашего Персонажа / Tool (Gun или Knife)
    local myChar = LocalPlayer.Character
    if myChar then
        local ok, isDesc = pcall(function()
            return obj:IsDescendantOf(myChar)
        end)
        if ok and isDesc and name ~= "Stab" then
            return true
        end
    end
    return false
end

if mt and setreadonly then
    GS.oldNamecall = mt.__namecall
    GS.oldIndex = mt.__index
    local oldNamecall = GS.oldNamecall
    local oldIndex = GS.oldIndex
    setreadonly(mt, false)

    -- 1. Хук Mouse.Hit / Mouse.Target / Mouse.UnitRay (Подменяет точку прицеливания до выстрела)
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

    -- 2. Универсальный перехватчик выстрелов и лучей (Silent Aim + Wallbang)
    mt.__namecall = newcclosure(function(self, ...)
        if GS.Unhooked or checkcaller() or GS.RaycastBypass then
            return oldNamecall(self, ...)
        end

        local method = getnamecallmethod()
        local args = {...}

        -- WALLBANG ДЛЯ ЛУЧЕЙ ROBLOX (Пробивает стены в старых и новых скриптах револьвера)
        if method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRay" or method == "FindPartOnRayWithWhitelist" then
            local myChar = LocalPlayer.Character
            if myChar and myChar:FindFirstChildOfClass("Tool") then
                if Config.SilentAim and GS.CurrentTargetPart and GS.CurrentAimPos then
                    return GS.CurrentTargetPart, GS.CurrentAimPos, Vector3.new(0, 1, 0), Enum.Material.Plastic
                elseif Config.FixBulletDrop then
                    local exactP = GS.GetExactCrosshairWorldPoint()
                    return nil, exactP, Vector3.new(0, 1, 0), Enum.Material.Air
                end
            end
        elseif method == "Raycast" and self == Workspace and Config.Wallbang and Config.SilentAim then
            local myChar = LocalPlayer.Character
            if myChar and myChar:FindFirstChild("Gun") and GS.CurrentTargetPart and GS.CurrentAimPos then
                -- Подменяем направление луча Workspace:Raycast прямо в голову/торс врага
                local orig = typeof(args[1]) == "Vector3" and args[1] or Camera.CFrame.Position
                args[2] = (GS.CurrentAimPos - orig).Unit * 1000
                return oldNamecall(self, unpack(args))
            end
        end

        -- УНИВЕРСАЛЬНЫЙ ПЕРЕХВАТ ВЫСТРЕЛА (FireServer И InvokeServer для любого MM2 и модов!)
        if method == "FireServer" or method == "InvokeServer" then
            local isWep = IsWeaponRemote(self, method)
            local isOfficialCreateBeam = (method == "InvokeServer" and args[1] == 1 and typeof(args[2]) == "Vector3")

            if isWep or isOfficialCreateBeam then
                local tPart, tPlr, tPos = GS.GetBestTargetInRadius(Config.FOV, false)
                local targetPart = tPart or GS.CurrentTargetPart
                local targetPlr = tPlr or GS.CurrentTargetPlr
                local aimPos = tPos or GS.CurrentAimPos

                local myChar = LocalPlayer.Character
                if myChar and myChar:FindFirstChild("Gun") then
                    GS.PlayCSGOWeaponSound(true)
                end

                if Config.SilentAim and targetPart and aimPos and math.random(1, 100) <= Config.HitChance then
                    GS.LastAttackData = {Player = targetPlr, Time = tick()}

                    -- Подсчитываем, сколько координат (Vector3/CFrame) передаётся в аргументах:
                    -- Если передаётся 1 координата (как в твоём коде Args[1] или в CreateBeam Args[2]) — ставим туда aimPos.
                    -- Если передаётся 2 координаты (Origin, TargetPosition) — первую не трогаем, а вторую ставим в aimPos!
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
                        -- Первая координата может быть точкой старта (или CFrame броска), а последняя — точкой попадания!
                        local firstIdx = coordIndices[1]
                        local lastIdx = coordIndices[#coordIndices]
                        if typeof(args[firstIdx]) == "CFrame" then
                            args[firstIdx] = CFrame.lookAt(args[firstIdx].Position, aimPos)
                        end
                        if typeof(args[lastIdx]) == "Vector3" then
                            args[lastIdx] = aimPos
                        elseif typeof(args[lastIdx]) == "CFrame" then
                            args[lastIdx] = CFrame.lookAt(aimPos, aimPos + (aimPos - Camera.CFrame.Position).Unit)
                        end
                    else
                        -- Если ремоут вызван вообще без координат (например UseTool()), докидываем позицию врага в Args[1] как в твоём скрипте!
                        args[1] = aimPos
                    end

                    -- Дополнительно подменяем Instance-цель, если ремоут передаёт BasePart врага
                    for i, v in ipairs(args) do
                        if typeof(v) == "Instance" and v:IsA("BasePart") then
                            args[i] = targetPart
                        end
                    end

                    return oldNamecall(self, unpack(args))
                elseif Config.FixBulletDrop then
                    local exactPos = GS.GetExactCrosshairWorldPoint()
                    for i, v in ipairs(args) do
                        if typeof(v) == "Vector3" then
                            args[i] = exactPos
                        elseif typeof(v) == "CFrame" then
                            args[i] = CFrame.lookAt(exactPos, exactPos + (exactPos - Camera.CFrame.Position).Unit)
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

-- РАБОЧИЙ ЛЕГИТБОТ И ТРИГГЕРБОТ (После обновления камеры Roblox)
local LastTriggerShot = 0

GS.BindRenderStep("GS_LegitAim", Enum.RenderPriority.Camera.Value + 1, function()
    if GS.Unhooked then return end

    GS.CurrentTargetPart, GS.CurrentTargetPlr, GS.CurrentAimPos = GS.GetBestTargetInRadius(Config.FOV, false)

    local myChar = LocalPlayer.Character
    if not myChar then return end

    if Config.LegitAim and not (GS.OuterWindow and GS.OuterWindow.Visible) then
        local activeKey = (Config.LegitAimKey == "Always On")
            or (Config.LegitAimKey == "MouseButton2 (RMB)" and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2))
            or (Config.LegitAimKey == "Key E" and UserInputService:IsKeyDown(Enum.KeyCode.E))

        if activeKey then
            local lPart, _, lPos = GS.GetBestTargetInRadius(Config.LegitFOV, Config.LegitVisibleOnly)
            if lPart and lPos then
                local camPos = Camera.CFrame.Position
                local goalCF = CFrame.lookAt(camPos, lPos)
                local alpha = math.clamp(1 / math.max(Config.LegitSmooth, 1), 0.05, 0.95)
                Camera.CFrame = Camera.CFrame:Lerp(goalCF, alpha)
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
