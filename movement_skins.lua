-- File: movement_skins.lua | Anti-Cheater Desync, Working HvH Anti-Aims, 1:1 CS:GO Skinchanger & Movement
local GS = _G.GS
if not GS then return end

local Players = GS.Players
local RunService = GS.RunService
local UserInputService = GS.UserInputService
local Workspace = GS.Workspace
local Camera = GS.Camera
local LocalPlayer = GS.LocalPlayer
local Config = GS.Config

local RealClientCFrame = nil
local RealClientVelocity = Vector3.zero
local DesyncFlip = false
local DesyncOrbitAngle = 0
local ChokeTick = 0
local LastTrailPos = nil
local LastGunBreakTick = 0
local InspectingUntil = 0
local SpinYaw = 0
local JitterStep = 1
local CircleAngle = 0
local MotorsDirty = false

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
    return {Chassis = GS.Skeet.Accent, Art = GS.Skeet.Cyan, Trim = Color3.fromRGB(30, 30, 30), Metal = Color3.fromRGB(20, 20, 20), Lens = GS.Skeet.Accent, Mat = Enum.Material.Metal}
end

-- Все детали скинченджера имеют CanQuery = false, CanTouch = false, CanCollide = false (Никогда не блокируют пули!)
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
    return p
end

function GS.ApplyAWPSkinToGun(gunTool)
    if not gunTool or not gunTool:FindFirstChild("Handle") then return end
    local handle = gunTool.Handle
    local tag = Config.GunSkinModel .. "_" .. Config.GunSkinFinish
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
        AddMicroPart(mdl, handle, Vector3.new(1.45, 0.16, 0.16), CFrame.new(0, 0.56, -0.32) * CFrame.Angles(0, math.rad(90), 0), pal.Metal, Enum.Material.Metal, "Cylinder")
        AddMicroPart(mdl, handle, Vector3.new(0.48, 0.28, 0.28), CFrame.new(0, 0.56, -1.18) * CFrame.Angles(0, math.rad(90), 0), pal.Trim, Enum.Material.Metal, "Cylinder")
        AddMicroPart(mdl, handle, Vector3.new(0.36, 0.24, 0.24), CFrame.new(0, 0.56, 0.48) * CFrame.Angles(0, math.rad(90), 0), pal.Trim, Enum.Material.Metal, "Cylinder")
        AddMicroPart(mdl, handle, Vector3.new(0.05, 0.24, 0.24), CFrame.new(0, 0.56, -1.41) * CFrame.Angles(0, math.rad(90), 0), pal.Lens, Enum.Material.Neon, "Cylinder")
    end

    GS.ActiveSkinModels[gunTool] = mdl
end

function GS.ApplyCSGOKnifeSkin(knifeTool)
    if not knifeTool or not knifeTool:FindFirstChild("Handle") then return end
    local handle = knifeTool.Handle
    local tag = Config.KnifeSkinModel .. "_" .. Config.KnifeSkinFinish
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

GS.TrackConnection(RunService.Heartbeat:Connect(function(dt)
    if GS.Unhooked then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not char or not hum or not hrp or hum.Health <= 0 then return end

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

-- Цикл движения, рабочих Анти-Аимов и функций Мардера
GS.TrackConnection(RunService.RenderStepped:Connect(function(dt)
    if GS.Unhooked then return end
    local myChar = LocalPlayer.Character
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myChar or not myHum or not myRoot or myHum.Health <= 0 then return end

    local onLadder = IsClimbingLadder(myChar, myHum, myRoot)

    -- РАБОЧИЕ HVH ANTI-AIMS
    if Config.AA_Enabled and not Config.FakeDead and not onLadder then
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
            myHum.WalkSpeed = (math.sin(tick() * 10) > 0.2) and (Config.SpeedVal * 1.35) or 16
        end
    else
        myHum.WalkSpeed = 16
    end

    if Config.BHop and UserInputService:IsKeyDown(Enum.KeyCode.Space) and not onLadder then
        if myHum.FloorMaterial ~= Enum.Material.Air then
            myHum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end

    if Config.AirStrafe and myHum.FloorMaterial == Enum.Material.Air and not onLadder then
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
            GS.DirectShootGunAt(mRoot.Position + Vector3.new(mRoot.Velocity.X * 0.12, 0.35, mRoot.Velocity.Z * 0.12), murd)
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
