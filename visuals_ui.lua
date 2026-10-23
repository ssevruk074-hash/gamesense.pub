-- File: visuals_ui.lua | 1:1 Skeet.cc UI with Built-In Pro Movement, StatTrak Skins, Anti-Fling, Target Fling & Forum Visuals
local GS = _G.GS
if not GS then return end

local Players = GS.Players
local RunService = GS.RunService
local UserInputService = GS.UserInputService
local HttpService = GS.HttpService
local Workspace = GS.Workspace
local Lighting = GS.Lighting
local Camera = GS.Camera
local LocalPlayer = GS.LocalPlayer
local LocalMouse = GS.LocalMouse
local Config = GS.Config
local Skeet = GS.Skeet
local ScreenGui = GS.ScreenGui

-- Гарантируем наличие всех настроек Нового Мувмента, Скинов, Анти-Флинга и Визуалов
local AllNewDefaults = {
    -- New Movement
    Fly_Enabled = false,
    Fly_Speed = 55,
    Dash_Enabled = true,
    Dash_Power = 18,
    Dash_Cooldown = 1,
    ClickTP = true,
    SpiderClimb = true,
    SpiderSpeed = 26,
    Moonwalk = false,
    LowGravity = false,
    GravityVal = 85,
    AntiVoid = true,
    TargetStrafe = false,
    CircleRadius = 10,

    -- Fling & Anti-Fling
    AntiFling = true,
    TargetFlingKey = true,

    -- New Skins & StatTrak
    SkinChanger = true,
    GunSkinModel = "AWP Sniper",
    GunSkinFinish = "Dragon Lore",
    KnifeSkinModel = "Karambit",
    KnifeSkinFinish = "Doppler Ruby",
    StatTrakCounter = true,
    StatTrakKills = 67,
    WeaponBladeTrail = true,
    WeaponSparkles = false,
    KnifeInspectSpin = true,
    CustomViewmodelOffset = false,
    ViewmodelX = 0,
    ViewmodelY = 0,
    ViewmodelZ = 0,

    -- Forum Visuals
    ESP_BoxStyle = "Corner",
    ESP_HeadDot = true,
    ESP_LookLaser = true,
    ESP_Tracers = false,
    ESP_TracerOrigin = "Bottom",
    SkeetIndicators = true,
    VelocityGraph = true,
    SpectatorList = true,
    OrbitSpheres = true,
    OrbitCount = 3,
    OrbitSpeed = 4,
    OrbitRadius = 4,
    WorldBloom = false
}

for k, v in pairs(AllNewDefaults) do
    if Config[k] == nil then Config[k] = v end
    if GS.DefaultConfigBackup and GS.DefaultConfigBackup[k] == nil then
        GS.DefaultConfigBackup[k] = v
    end
end

local BloomEffect = GS.TrackInstance(Instance.new("BloomEffect"))
BloomEffect.Name = "GS_Bloom"
BloomEffect.Enabled = false
BloomEffect.Parent = Lighting

-------------------------------------------------------------------------
-- ВСТРОЕННЫЙ ДВИЖОК ANTI-FLING И TARGET FLING [KEY H]
-------------------------------------------------------------------------
GS.TrackConnection(RunService.Stepped:Connect(function()
    if GS.Unhooked or not Config.AntiFling then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            for _, part in ipairs(plr.Character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if myRoot and (myRoot.AssemblyAngularVelocity.Magnitude > 50 or myRoot.AssemblyLinearVelocity.Magnitude > 250) then
        myRoot.AssemblyAngularVelocity = Vector3.zero
        myRoot.AssemblyLinearVelocity = Vector3.new(0, myRoot.AssemblyLinearVelocity.Y, 0)
    end
end))

local FlingRunning = false
function GS.TriggerTargetFling(customPlr)
    if FlingRunning then return end
    local targetPlr = customPlr or GS.CurrentTargetPlr or GS.FindByRole("Murderer")
    if not targetPlr or not targetPlr.Character or not targetPlr.Character:FindFirstChild("HumanoidRootPart") then
        GS.PushSkeetLog("Target Fling: Нет живой цели!", Skeet.Danger)
        return
    end

    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    FlingRunning = true
    local savedCF = myRoot.CFrame
    local wasAntiFling = Config.AntiFling
    Config.AntiFling = false

    GS.PushSkeetLog("Target Fling: Запускаем " .. targetPlr.Name .. " за карту!", Skeet.Gold)

    task.spawn(function()
        local bav = Instance.new("BodyAngularVelocity")
        bav.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bav.P = math.huge
        bav.AngularVelocity = Vector3.new(99999, 99999, 99999)
        bav.Parent = myRoot

        local startTick = tick()
        while (tick() - startTick) < 1.15 and not GS.Unhooked do
            local tChar = targetPlr.Character
            local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
            if not tRoot or tRoot.Velocity.Magnitude > 600 then break end

            myRoot.CanCollide = true
            local tVel = tRoot.AssemblyLinearVelocity
            myRoot.CFrame = tRoot.CFrame + Vector3.new(tVel.X * 0.08, 0, tVel.Z * 0.08)
            myRoot.AssemblyLinearVelocity = Vector3.new(99999, 99999, 99999)
            RunService.RenderStepped:Wait()
        end

        if bav then bav:Destroy() end
        if myRoot and myRoot.Parent then
            myRoot.AssemblyLinearVelocity = Vector3.zero
            myRoot.AssemblyAngularVelocity = Vector3.zero
            myRoot.CFrame = savedCF
        end
        Config.AntiFling = wasAntiFling
        FlingRunning = false
        GS.PushSkeetLog("Target Fling завершён: " .. targetPlr.Name, Skeet.Accent)
    end)
end

-------------------------------------------------------------------------
-- КАСТОМНЫЙ ПРИЦЕЛ СКИТА, SKEET INDICATORS ПОД ПРИЦЕЛОМ И VELOCITY GRAPH
-------------------------------------------------------------------------
local ScopeHolder = Instance.new("Frame", ScreenGui)
ScopeHolder.Name = "GS_CustomScope"
ScopeHolder.Size = UDim2.new(1, 0, 1, 0)
ScopeHolder.BackgroundTransparency = 1
ScopeHolder.Active = false
ScopeHolder.Visible = false

local ScopeTop = Instance.new("Frame", ScopeHolder)
ScopeTop.BorderSizePixel = 0; ScopeTop.BackgroundColor3 = Color3.new(1, 1, 1)
local GradTop = Instance.new("UIGradient", ScopeTop)
GradTop.Rotation = -90
GradTop.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})

local ScopeBot = Instance.new("Frame", ScopeHolder)
ScopeBot.BorderSizePixel = 0; ScopeBot.BackgroundColor3 = Color3.new(1, 1, 1)
local GradBot = Instance.new("UIGradient", ScopeBot)
GradBot.Rotation = 90
GradBot.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})

local ScopeLeft = Instance.new("Frame", ScopeHolder)
ScopeLeft.BorderSizePixel = 0; ScopeLeft.BackgroundColor3 = Color3.new(1, 1, 1)
local GradLeft = Instance.new("UIGradient", ScopeLeft)
GradLeft.Rotation = 180
GradLeft.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})

local ScopeRight = Instance.new("Frame", ScopeHolder)
ScopeRight.BorderSizePixel = 0; ScopeRight.BackgroundColor3 = Color3.new(1, 1, 1)
local GradRight = Instance.new("UIGradient", ScopeRight)
GradRight.Rotation = 0
GradRight.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})

local ScopeDot = Instance.new("Frame", ScopeHolder)
ScopeDot.BorderSizePixel = 0; ScopeDot.BackgroundColor3 = Skeet.Accent

local SkeetIndHolder = Instance.new("Frame", ScreenGui)
SkeetIndHolder.Size = UDim2.new(0, 160, 0, 120)
SkeetIndHolder.BackgroundTransparency = 1
local indLayout = Instance.new("UIListLayout", SkeetIndHolder)
indLayout.Padding = UDim.new(0, 1)
indLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left

local IndLabels = {}
for i = 1, 6 do
    local lbl = Instance.new("TextLabel", SkeetIndHolder)
    lbl.Size = UDim2.new(1, 0, 0, 14)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 12
    lbl.TextStrokeTransparency = 0
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Visible = false
    IndLabels[i] = lbl
end

local VelHolder = Instance.new("Frame", ScreenGui)
VelHolder.Size = UDim2.new(0, 180, 0, 65)
VelHolder.Position = UDim2.new(0.5, -90, 0.84, 0)
VelHolder.BackgroundTransparency = 1
VelHolder.Visible = false

local VelText = Instance.new("TextLabel", VelHolder)
VelText.Size = UDim2.new(1, 0, 0, 22)
VelText.Position = UDim2.new(0, 0, 0, 0)
VelText.BackgroundTransparency = 1
VelText.Font = Enum.Font.SourceSansBold
VelText.TextSize = 22
VelText.TextColor3 = Skeet.Accent
VelText.TextStrokeTransparency = 0
VelText.Text = "0 u/s"

local VelGraphBars = {}
local VelHistory = {}
for i = 1, 30 do
    VelHistory[i] = 0
    local bar = Instance.new("Frame", VelHolder)
    bar.Size = UDim2.new(0, 4, 0, 2)
    bar.Position = UDim2.new(0, (i - 1) * 6, 1, -2)
    bar.AnchorPoint = Vector2.new(0, 1)
    bar.BackgroundColor3 = Skeet.Accent
    bar.BorderSizePixel = 0
    VelGraphBars[i] = bar
end

local SpecBox = Instance.new("Frame", ScreenGui)
SpecBox.Size = UDim2.new(0, 185, 0, 24)
SpecBox.Position = UDim2.new(1, -197, 0, 42)
SpecBox.BackgroundColor3 = Skeet.MainBg
SpecBox.BorderColor3 = Skeet.GroupBorder
SpecBox.BorderSizePixel = 1
SpecBox.AutomaticSize = Enum.AutomaticSize.Y
local spBar = Instance.new("Frame", SpecBox)
spBar.Size = UDim2.new(1, 0, 0, 2); spBar.BackgroundColor3 = Skeet.Cyan; spBar.BorderSizePixel = 0
local spHdr = Instance.new("TextLabel", SpecBox)
spHdr.Size = UDim2.new(1, 0, 0, 18); spHdr.Position = UDim2.new(0, 0, 0, 2); spHdr.BackgroundTransparency = 1
spHdr.Font = Enum.Font.Code; spHdr.TextSize = 11; spHdr.TextColor3 = Skeet.TextActive; spHdr.Text = "Spectators / Dead"
local spBody = Instance.new("TextLabel", SpecBox)
spBody.Size = UDim2.new(1, -12, 0, 14); spBody.Position = UDim2.new(0, 6, 0, 20); spBody.BackgroundTransparency = 1
spBody.Font = Enum.Font.Code; spBody.TextSize = 11; spBody.TextColor3 = Skeet.TextDim
spBody.TextXAlignment = Enum.TextXAlignment.Left; spBody.TextYAlignment = Enum.TextYAlignment.Top
spBody.AutomaticSize = Enum.AutomaticSize.Y

local RadarFrame = Instance.new("Frame", ScreenGui)
RadarFrame.Size = UDim2.new(0, 136, 0, 136)
RadarFrame.Position = UDim2.new(0, 14, 0, 195)
RadarFrame.BackgroundColor3 = Skeet.MainBg
RadarFrame.BorderColor3 = Skeet.GroupBorder
RadarFrame.BorderSizePixel = 1
RadarFrame.ClipsDescendants = true

local RadarTopLine = Instance.new("Frame", RadarFrame)
RadarTopLine.Size = UDim2.new(1, 0, 0, 2); RadarTopLine.BackgroundColor3 = Skeet.Accent; RadarTopLine.BorderSizePixel = 0

local RadarCrossH = Instance.new("Frame", RadarFrame)
RadarCrossH.Size = UDim2.new(1, 0, 0, 1); RadarCrossH.Position = UDim2.new(0, 0, 0.5, 0)
RadarCrossH.BackgroundColor3 = Color3.fromRGB(30, 30, 30); RadarCrossH.BorderSizePixel = 0

local RadarCrossV = Instance.new("Frame", RadarFrame)
RadarCrossV.Size = UDim2.new(0, 1, 1, 0); RadarCrossV.Position = UDim2.new(0.5, 0, 0, 0)
RadarCrossV.BackgroundColor3 = Color3.fromRGB(30, 30, 30); RadarCrossV.BorderSizePixel = 0

local RadarCenterDot = Instance.new("Frame", RadarFrame)
RadarCenterDot.Size = UDim2.new(0, 4, 0, 4); RadarCenterDot.Position = UDim2.new(0.5, -2, 0.5, -2)
RadarCenterDot.BackgroundColor3 = Color3.new(1, 1, 1); RadarCenterDot.BorderSizePixel = 0

local RadarDots = {}

local TargetHudFrame = Instance.new("Frame", ScreenGui)
TargetHudFrame.Size = UDim2.new(0, 230, 0, 56)
TargetHudFrame.Position = UDim2.new(0.5, -115, 0.65, 0)
TargetHudFrame.BackgroundColor3 = Skeet.MainBg
TargetHudFrame.BorderColor3 = Skeet.GroupBorder
TargetHudFrame.BorderSizePixel = 1
TargetHudFrame.Visible = false

local thTop = Instance.new("Frame", TargetHudFrame)
thTop.Size = UDim2.new(1, 0, 0, 2); thTop.BackgroundColor3 = Skeet.Accent; thTop.BorderSizePixel = 0

local thName = Instance.new("TextLabel", TargetHudFrame)
thName.Size = UDim2.new(1, -12, 0, 18); thName.Position = UDim2.new(0, 6, 0, 4); thName.BackgroundTransparency = 1
thName.Font = Enum.Font.Code; thName.TextSize = 12; thName.TextColor3 = Skeet.TextActive
thName.TextXAlignment = Enum.TextXAlignment.Left; thName.Text = "Target: None"

local thInfo = Instance.new("TextLabel", TargetHudFrame)
thInfo.Size = UDim2.new(1, -12, 0, 14); thInfo.Position = UDim2.new(0, 6, 0, 21); thInfo.BackgroundTransparency = 1
thInfo.Font = Enum.Font.Code; thInfo.TextSize = 11; thInfo.TextColor3 = Skeet.Text
thInfo.TextXAlignment = Enum.TextXAlignment.Left; thInfo.Text = "Role: Innocent | Dist: 0m"

local thBarBg = Instance.new("Frame", TargetHudFrame)
thBarBg.Size = UDim2.new(1, -12, 0, 7); thBarBg.Position = UDim2.new(0, 6, 0, 41)
thBarBg.BackgroundColor3 = Skeet.ControlBg; thBarBg.BorderColor3 = Skeet.ControlBorder; thBarBg.BorderSizePixel = 1

local thBarFill = Instance.new("Frame", thBarBg)
thBarFill.Size = UDim2.new(1, 0, 1, 0); thBarFill.BackgroundColor3 = Skeet.Accent; thBarFill.BorderSizePixel = 0

local OrbitFolder = GS.TrackInstance(Instance.new("Folder"))
OrbitFolder.Name = "GS_OrbitSpheres"
OrbitFolder.Parent = Workspace

local OrbitBalls = {}
for i = 1, 6 do
    local ball = Instance.new("Part")
    ball.Shape = Enum.PartType.Ball
    ball.Size = Vector3.new(0.55, 0.55, 0.55)
    ball.Anchored = true; ball.CanCollide = false; ball.CanTouch = false; ball.CanQuery = false; ball.CastShadow = false
    ball.Material = Enum.Material.Neon
    ball.Color = Skeet.Accent
    ball.Transparency = 1
    ball.Parent = OrbitFolder

    local att0 = Instance.new("Attachment", ball); att0.Position = Vector3.new(0, 0.2, 0)
    local att1 = Instance.new("Attachment", ball); att1.Position = Vector3.new(0, -0.2, 0)

    local tr = Instance.new("Trail", ball)
    tr.Attachment0 = att0; tr.Attachment1 = att1; tr.Lifetime = 0.35
    tr.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
    tr.Color = ColorSequence.new(Skeet.Accent)
    tr.Enabled = false

    OrbitBalls[i] = {Part = ball, Trail = tr}
end

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
        f.Size = UDim2.new(0, w, 0, h); f.Position = UDim2.new(0, x, 0, y)
        f.BackgroundColor3 = Skeet.IconIdle; f.BorderSizePixel = 0
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
        f.Size = UDim2.new(0, size, 0, size); f.Position = UDim2.new(0, x, 0, y)
        f.BackgroundTransparency = 1
        local c = Instance.new("UICorner", f); c.CornerRadius = UDim.new(1, 0)
        local s = Instance.new("UIStroke", f); s.Color = Skeet.IconIdle; s.Thickness = thick or 2
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
GS.OuterWindow = OuterWindow

local MidBorder = Instance.new("Frame", OuterWindow)
MidBorder.Size = UDim2.new(1, -4, 1, -4); MidBorder.Position = UDim2.new(0, 2, 0, 2)
MidBorder.BackgroundColor3 = Skeet.InnerBorder; MidBorder.BorderSizePixel = 0

local InnerWindow = Instance.new("Frame", MidBorder)
InnerWindow.Size = UDim2.new(1, -2, 1, -2); InnerWindow.Position = UDim2.new(0, 1, 0, 1)
InnerWindow.BackgroundColor3 = Skeet.MainBg; InnerWindow.BorderSizePixel = 0

local RainbowBar = Instance.new("Frame", InnerWindow)
RainbowBar.Size = UDim2.new(1, 0, 0, 2); RainbowBar.BackgroundColor3 = Color3.new(1, 1, 1); RainbowBar.BorderSizePixel = 0
local RainbowGrad = Instance.new("UIGradient", RainbowBar)
RainbowGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(55, 175, 225)),
    ColorSequenceKeypoint.new(0.50, Color3.fromRGB(205, 70, 185)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(220, 225, 55))
})

local Sidebar = Instance.new("Frame", InnerWindow)
Sidebar.Size = UDim2.new(0, 64, 1, -2); Sidebar.Position = UDim2.new(0, 0, 0, 2)
Sidebar.BackgroundColor3 = Skeet.SidebarBg; Sidebar.BorderSizePixel = 0

local SidebarDivider = Instance.new("Frame", Sidebar)
SidebarDivider.Size = UDim2.new(0, 1, 1, 0); SidebarDivider.Position = UDim2.new(1, -1, 0, 0)
SidebarDivider.BackgroundColor3 = Skeet.GroupBorder; SidebarDivider.BorderSizePixel = 0

local PagesArea = Instance.new("Frame", InnerWindow)
PagesArea.Size = UDim2.new(1, -80, 1, -20); PagesArea.Position = UDim2.new(0, 72, 0, 12)
PagesArea.BackgroundTransparency = 1

local Tabs = {}
local FirstTab = true

local function CreateSkeetTab(iconName)
    local idx = #Tabs
    local Btn = Instance.new("TextButton", Sidebar)
    Btn.Size = UDim2.new(1, -1, 0, 56); Btn.Position = UDim2.new(0, 0, 0, 8 + idx * 58)
    Btn.BackgroundColor3 = FirstTab and Skeet.MainBg or Skeet.SidebarBg
    Btn.BorderSizePixel = 0; Btn.AutoButtonColor = false; Btn.Text = ""

    local TopSelLine = Instance.new("Frame", Btn)
    TopSelLine.Size = UDim2.new(1, 0, 0, 1); TopSelLine.BackgroundColor3 = Skeet.GroupBorder
    TopSelLine.BorderSizePixel = 0; TopSelLine.Visible = FirstTab

    local BotSelLine = Instance.new("Frame", Btn)
    BotSelLine.Size = UDim2.new(1, 0, 0, 1); BotSelLine.Position = UDim2.new(0, 0, 1, -1)
    BotSelLine.BackgroundColor3 = Skeet.GroupBorder; BotSelLine.BorderSizePixel = 0; BotSelLine.Visible = FirstTab

    local setIconActive = DrawVectorIcon(Btn, iconName)
    setIconActive(FirstTab)

    local Page = Instance.new("Frame", PagesArea)
    Page.Size = UDim2.new(1, 0, 1, 0); Page.BackgroundTransparency = 1; Page.Visible = FirstTab

    local LeftCol = Instance.new("ScrollingFrame", Page)
    LeftCol.Size = UDim2.new(0.485, 0, 1, 0); LeftCol.BackgroundTransparency = 1; LeftCol.BorderSizePixel = 0
    LeftCol.ScrollBarThickness = 0; LeftCol.AutomaticCanvasSize = Enum.AutomaticSize.Y; LeftCol.CanvasSize = UDim2.new(0, 0, 0, 0)
    local lList = Instance.new("UIListLayout", LeftCol); lList.Padding = UDim.new(0, 12)

    local RightCol = Instance.new("ScrollingFrame", Page)
    RightCol.Size = UDim2.new(0.485, 0, 1, 0); RightCol.Position = UDim2.new(0.515, 0, 0, 0)
    RightCol.BackgroundTransparency = 1; RightCol.BorderSizePixel = 0; RightCol.ScrollBarThickness = 0
    RightCol.AutomaticCanvasSize = Enum.AutomaticSize.Y; RightCol.CanvasSize = UDim2.new(0, 0, 0, 0)
    local rList = Instance.new("UIListLayout", RightCol); rList.Padding = UDim.new(0, 12)

    GS.TrackConnection(Btn.MouseButton1Click:Connect(function()
        for _, t in ipairs(Tabs) do
            t.Page.Visible = false; t.Btn.BackgroundColor3 = Skeet.SidebarBg
            t.Top.Visible = false; t.Bot.Visible = false; t.SetIcon(false)
        end
        Page.Visible = true; Btn.BackgroundColor3 = Skeet.MainBg
        TopSelLine.Visible = true; BotSelLine.Visible = true; setIconActive(true)
    end))

    FirstTab = false
    table.insert(Tabs, {Btn = Btn, Page = Page, Top = TopSelLine, Bot = BotSelLine, SetIcon = setIconActive})
    return LeftCol, RightCol
end

local function CreateGroupbox(column, title)
    local Wrapper = Instance.new("Frame", column)
    Wrapper.Size = UDim2.new(1, -2, 0, 40); Wrapper.BackgroundTransparency = 1; Wrapper.AutomaticSize = Enum.AutomaticSize.Y

    local Box = Instance.new("Frame", Wrapper)
    Box.Size = UDim2.new(1, 0, 1, -6); Box.Position = UDim2.new(0, 0, 0, 6)
    Box.BackgroundColor3 = Skeet.GroupBg; Box.BorderColor3 = Skeet.GroupBorder; Box.BorderSizePixel = 1
    Box.AutomaticSize = Enum.AutomaticSize.Y

    local TitleBg = Instance.new("Frame", Wrapper)
    TitleBg.Position = UDim2.new(0, 10, 0, 0); TitleBg.Size = UDim2.new(0, #title * 7 + 8, 0, 13)
    TitleBg.BackgroundColor3 = Skeet.GroupBg; TitleBg.BorderSizePixel = 0

    local TitleLbl = Instance.new("TextLabel", TitleBg)
    TitleLbl.Size = UDim2.new(1, 0, 1, 0); TitleLbl.BackgroundTransparency = 1
    TitleLbl.Font = Enum.Font.SourceSansBold; TitleLbl.TextSize = 13; TitleLbl.TextColor3 = Skeet.TextActive; TitleLbl.Text = title

    local Content = Instance.new("Frame", Box)
    Content.Size = UDim2.new(1, -24, 0, 10); Content.Position = UDim2.new(0, 12, 0, 14)
    Content.BackgroundTransparency = 1; Content.AutomaticSize = Enum.AutomaticSize.Y

    local cLayout = Instance.new("UIListLayout", Content); cLayout.Padding = UDim.new(0, 5)
    local Pad = Instance.new("UIPadding", Box); Pad.PaddingBottom = UDim.new(0, 12)
    return Content
end

local function RefreshAllUIControls()
    for _, fn in ipairs(GS.UIUpdaters) do pcall(fn) end
end

local function AddCheckbox(group, label, key, hasBindTag)
    local Row = Instance.new("TextButton", group)
    Row.Size = UDim2.new(1, 0, 0, 16); Row.BackgroundTransparency = 1; Row.Text = ""; Row.AutoButtonColor = false

    local Box = Instance.new("Frame", Row)
    Box.Size = UDim2.new(0, 8, 0, 8); Box.Position = UDim2.new(0, 0, 0.5, -4)
    Box.BackgroundColor3 = Config[key] and Skeet.Accent or Skeet.ControlBg
    Box.BorderColor3 = Skeet.ControlBorder; Box.BorderSizePixel = 1

    local Lbl = Instance.new("TextLabel", Row)
    Lbl.Size = UDim2.new(1, -40, 1, 0); Lbl.Position = UDim2.new(0, 18, 0, 0); Lbl.BackgroundTransparency = 1
    Lbl.Font = Enum.Font.SourceSans; Lbl.TextSize = 13
    Lbl.TextColor3 = Config[key] and Skeet.TextActive or Skeet.Text
    Lbl.TextXAlignment = Enum.TextXAlignment.Left; Lbl.Text = label

    if hasBindTag then
        local BindTag = Instance.new("TextLabel", Row)
        BindTag.Size = UDim2.new(0, 22, 1, 0); BindTag.Position = UDim2.new(1, -22, 0, 0); BindTag.BackgroundTransparency = 1
        BindTag.Font = Enum.Font.Code; BindTag.TextSize = 10; BindTag.TextColor3 = Skeet.TextDim
        BindTag.TextXAlignment = Enum.TextXAlignment.Right; BindTag.Text = "[-]"
    end

    local function sync()
        Box.BackgroundColor3 = Config[key] and Skeet.Accent or Skeet.ControlBg
        Lbl.TextColor3 = Config[key] and Skeet.TextActive or Skeet.Text
    end
    table.insert(GS.UIUpdaters, sync)

    GS.TrackConnection(Row.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        sync()
        if string.find(key, "Skin") or string.find(key, "StatTrak") or string.find(key, "Weapon") then
            GS.ClearCustomSkins()
        end
    end))
end

local function AddSlider(group, label, key, minVal, maxVal, suffix)
    suffix = suffix or ""
    local Wrap = Instance.new("Frame", group)
    Wrap.Size = UDim2.new(1, 0, 0, 28); Wrap.BackgroundTransparency = 1

    local Lbl = Instance.new("TextLabel", Wrap)
    Lbl.Size = UDim2.new(1, -18, 0, 14); Lbl.Position = UDim2.new(0, 18, 0, 0); Lbl.BackgroundTransparency = 1
    Lbl.Font = Enum.Font.SourceSans; Lbl.TextSize = 13; Lbl.TextColor3 = Skeet.Text
    Lbl.TextXAlignment = Enum.TextXAlignment.Left; Lbl.Text = label

    local Bar = Instance.new("TextButton", Wrap)
    Bar.Size = UDim2.new(1, -36, 0, 7); Bar.Position = UDim2.new(0, 18, 0, 16)
    Bar.BackgroundColor3 = Skeet.ControlBg; Bar.BorderColor3 = Skeet.ControlBorder
    Bar.BorderSizePixel = 1; Bar.AutoButtonColor = false; Bar.Text = ""

    local Fill = Instance.new("Frame", Bar)
    local pct = math.clamp((Config[key] - minVal) / (maxVal - minVal), 0, 1)
    Fill.Size = UDim2.new(pct, 0, 1, 0); Fill.BackgroundColor3 = Skeet.Accent; Fill.BorderSizePixel = 0

    local ValText = Instance.new("TextLabel", Bar)
    ValText.Size = UDim2.new(0, 50, 0, 14); ValText.AnchorPoint = Vector2.new(0.5, 0.5)
    ValText.Position = UDim2.new(pct, 0, 0.5, 1); ValText.BackgroundTransparency = 1
    ValText.Font = Enum.Font.SourceSansBold; ValText.TextSize = 12; ValText.TextColor3 = Skeet.TextActive
    ValText.TextStrokeTransparency = 0; ValText.Text = tostring(Config[key]) .. suffix

    local function sync()
        local r = math.clamp((Config[key] - minVal) / (maxVal - minVal), 0, 1)
        Fill.Size = UDim2.new(r, 0, 1, 0); ValText.Position = UDim2.new(r, 0, 0.5, 1)
        ValText.Text = tostring(Config[key]) .. suffix
    end
    table.insert(GS.UIUpdaters, sync)

    local dragging = false
    local function update(input)
        local rel = math.clamp((input.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
        local val = math.floor(minVal + (maxVal - minVal) * rel)
        Config[key] = val; sync()
    end

    GS.TrackConnection(Bar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; update(inp) end
    end))
    GS.TrackConnection(UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))
    GS.TrackConnection(UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then update(inp) end
    end))
end

local function AddDropdown(group, label, key, options)
    local Wrap = Instance.new("Frame", group)
    Wrap.Size = UDim2.new(1, 0, 0, 36); Wrap.BackgroundTransparency = 1

    local Lbl = Instance.new("TextLabel", Wrap)
    Lbl.Size = UDim2.new(1, -18, 0, 14); Lbl.Position = UDim2.new(0, 18, 0, 0); Lbl.BackgroundTransparency = 1
    Lbl.Font = Enum.Font.SourceSans; Lbl.TextSize = 13; Lbl.TextColor3 = Skeet.Text
    Lbl.TextXAlignment = Enum.TextXAlignment.Left; Lbl.Text = label

    local DropBtn = Instance.new("TextButton", Wrap)
    DropBtn.Size = UDim2.new(1, -36, 0, 18); DropBtn.Position = UDim2.new(0, 18, 0, 16)
    DropBtn.BackgroundColor3 = Skeet.ControlBg; DropBtn.BorderColor3 = Skeet.ControlBorder
    DropBtn.BorderSizePixel = 1; DropBtn.AutoButtonColor = false; DropBtn.Text = ""

    local ValLbl = Instance.new("TextLabel", DropBtn)
    ValLbl.Size = UDim2.new(1, -20, 1, 0); ValLbl.Position = UDim2.new(0, 6, 0, 0); ValLbl.BackgroundTransparency = 1
    ValLbl.Font = Enum.Font.SourceSans; ValLbl.TextSize = 13; ValLbl.TextColor3 = Skeet.Text
    ValLbl.TextXAlignment = Enum.TextXAlignment.Left; ValLbl.Text = tostring(Config[key])

    local Arrow = Instance.new("TextLabel", DropBtn)
    Arrow.Size = UDim2.new(0, 14, 1, 0); Arrow.Position = UDim2.new(1, -14, 0, 0); Arrow.BackgroundTransparency = 1
    Arrow.Font = Enum.Font.SourceSansBold; Arrow.TextSize = 10; Arrow.TextColor3 = Skeet.TextDim; Arrow.Text = "v"

    local function sync() ValLbl.Text = tostring(Config[key]) end
    table.insert(GS.UIUpdaters, sync)

    GS.TrackConnection(DropBtn.MouseButton1Click:Connect(function()
        local idx = table.find(options, Config[key]) or 1
        idx = idx % #options + 1
        Config[key] = options[idx]
        sync()
        if string.find(key, "Skin") then GS.ClearCustomSkins() end
    end))
end

local function AddButton(group, label, callback, customTextColor)
    local Wrap = Instance.new("Frame", group)
    Wrap.Size = UDim2.new(1, 0, 0, 22); Wrap.BackgroundTransparency = 1

    local Btn = Instance.new("TextButton", Wrap)
    Btn.Size = UDim2.new(1, -36, 0, 20); Btn.Position = UDim2.new(0, 18, 0, 1)
    Btn.BackgroundColor3 = Skeet.ControlBg; Btn.BorderColor3 = Skeet.ControlBorder; Btn.BorderSizePixel = 1
    Btn.Font = Enum.Font.SourceSansBold; Btn.TextSize = 13
    Btn.TextColor3 = customTextColor or Skeet.TextActive; Btn.Text = label
    GS.TrackConnection(Btn.MouseButton1Click:Connect(callback))
end

-------------------------------------------------------------------------
-- СБОРКА ВСЕХ 8 ВКЛАДОК SKEET.CC (СО ВСЕМИ НОВЫМИ КНОПКАМИ ВНУТРИ!)
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
local gAimbot = CreateGroupbox(R_L, "Aimbot (Universal MM2 Hook)")
AddCheckbox(gAimbot, "Enabled (Silent Aim)", "SilentAim", true)
AddCheckbox(gAimbot, "Direct CreateBeam invoke on click", "DirectClickInvoke", false)
AddCheckbox(gAimbot, "Fix Sheriff low bullet (0px Ray Fix)", "FixBulletDrop", false)
AddDropdown(gAimbot, "Target role priority", "TargetRolePriority", {"Smart (Role-Based)", "Any Closest", "Murderer Only"})
AddDropdown(gAimbot, "Target hitbox", "HitPart", {"HumanoidRootPart", "Head", "UpperTorso", "LowerTorso"})
AddCheckbox(gAimbot, "Automatic fire (Sheriff)", "AutoFire", true)
AddCheckbox(gAimbot, "Automatic penetration (Wallbang)", "Wallbang", false)
AddSlider(gAimbot, "Minimum hit chance", "HitChance", 1, 100, "%")
AddSlider(gAimbot, "Velocity prediction", "Prediction", 0, 35, "ms")
AddSlider(gAimbot, "Maximum FOV", "FOV", 20, 500, "px")
AddCheckbox(gAimbot, "Log hits & misses to screen", "LogMisses", false)

local gSheriffGun = CreateGroupbox(R_R, "Living Sheriff Gun Stealer")
AddButton(gSheriffGun, "STEAL / EQUIP SHERIFF GUN NOW", GS.StealGunFromLivingSheriff, Skeet.Accent)
AddButton(gSheriffGun, "REMOTE SHOOT MURDERER [Key G]", function()
    GS.RemoteFireLivingSheriffGun()
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

-- ВКЛАДКА 2: ANTI-AIM И АНТИ-ЧИТЕР ДЕСИНК
local gAA = CreateGroupbox(AA_L, "Anti-aimbot angles")
AddCheckbox(gAA, "Enabled", "AA_Enabled", true)
AddCheckbox(gAA, "Auto-disable on ladders (Climb Fix)", "AA_LadderBypass", false)
AddDropdown(gAA, "Pitch (Head & Spine)", "AA_Pitch", {"Down", "Up", "Zero", "Jitter", "None"})
AddDropdown(gAA, "Yaw mode", "AA_Yaw", {"Spinbot", "180", "Jitter", "Crosshair"})
AddDropdown(gAA, "Yaw jitter", "AA_YawJitter", {"Center", "Offset", "Random", "3-Way", "Off"})
AddSlider(gAA, "Yaw jitter angle", "AA_JitterRange", -180, 180, "°")
AddSlider(gAA, "Spinbot speed", "AA_SpinSpeed", 5, 120, "°")
AddDropdown(gAA, "Body yaw (Torso Twist)", "AA_BodyYaw", {"Opposite", "Static", "Jitter", "Off"})
AddSlider(gAA, "Roll lean angle (Body Tilt)", "AA_RollLean", -45, 45, "°")
AddCheckbox(gAA, "Manual AA binds [Z / X / C]", "AA_ManualKeys", true)
AddCheckbox(gAA, "Show Real / Fake AA arrows", "AA_ShowArrows", false)
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

-- ВКЛАДКА 3: ПОЛНЫЙ 1:1 CS:GO СКИНЧЕНДЖЕР (С AK-47, M4A1-S, STATTRAK И ШЛЕЙФАМИ!) + LEGITBOT
local gSkins = CreateGroupbox(LG_L, "1:1 CS:GO 3D Skinchanger (Pro)")
AddCheckbox(gSkins, "Enable 1:1 CS:GO Skinchanger", "SkinChanger", false)
AddDropdown(gSkins, "Gun model (Replaces Revolver)", "GunSkinModel", {"AWP Sniper", "AK-47 Kalash", "M4A1-S Silencer", "SSG-08 Scout", "Desert Eagle"})
AddDropdown(gSkins, "Gun skin finish", "GunSkinFinish", {"Chroma Wave (Animated)", "Dragon Lore", "Asiimov", "Fade", "Gungnir", "Printstream", "Redline"})
AddDropdown(gSkins, "Knife model (Replaces Knife)", "KnifeSkinModel", {"Karambit", "Butterfly Knife", "M9 Bayonet", "Talon Knife", "Skeleton Knife"})
AddDropdown(gSkins, "Knife skin finish", "KnifeSkinFinish", {"Chroma Wave (Animated)", "Doppler Ruby", "Sapphire", "Emerald", "Fade", "Case Hardened Blue Gem", "Lore"})
AddCheckbox(gSkins, "3D StatTrak™ LED Kill Counter", "StatTrakCounter", false)
AddCheckbox(gSkins, "Neon Blade & Barrel Trail", "WeaponBladeTrail", false)
AddCheckbox(gSkins, "Weapon Energy Sparkles", "WeaponSparkles", false)
AddCheckbox(gSkins, "Inspect Spin Animation [Key F]", "KnifeInspectSpin", true)
AddCheckbox(gSkins, "CS:GO AWP & Knife sounds", "CSGOSounds", false)
AddCheckbox(gSkins, "Custom Viewmodel Offset (Hand Pos)", "CustomViewmodelOffset", false)
AddSlider(gSkins, "Viewmodel X", "ViewmodelX", -25, 25, "")
AddSlider(gSkins, "Viewmodel Y", "ViewmodelY", -25, 25, "")
AddSlider(gSkins, "Viewmodel Z", "ViewmodelZ", -25, 25, "")
AddButton(gSkins, "Rebuild 1:1 Skins Now", GS.ClearCustomSkins, Skeet.Accent)

local gLegitAim = CreateGroupbox(LG_R, "Legit Aimbot, Trigger & Backtrack")
AddCheckbox(gLegitAim, "Enable Smooth Camera Aimbot", "LegitAim", true)
AddDropdown(gLegitAim, "Legit aim activation", "LegitAimKey", {"Always On", "MouseButton2 (RMB)", "Key E"})
AddSlider(gLegitAim, "Camera smoothness", "LegitSmooth", 2, 50, "x")
AddSlider(gLegitAim, "Legit FOV radius", "LegitFOV", 20, 300, "px")
AddCheckbox(gLegitAim, "Draw Legit FOV circle", "ShowLegitFOV", false)
AddCheckbox(gLegitAim, "Visible check", "LegitVisibleOnly", false)
AddCheckbox(gLegitAim, "Legit Triggerbot", "LegitTriggerbot", true)
AddSlider(gLegitAim, "Triggerbot delay", "TriggerbotDelay", 0, 250, "ms")
AddCheckbox(gLegitAim, "Enable Position Backtrack", "LegitBacktrack", false)
AddSlider(gLegitAim, "Backtrack window", "BacktrackMS", 50, 400, "ms")
AddCheckbox(gLegitAim, "Legit Hitbox Expander", "HitboxExpander", false)
AddSlider(gLegitAim, "Expanded hitbox size", "HitboxSize", 3, 20, "st")

-- ВКЛАДКА 4: ФОРУМНЫЕ ВИЗУАЛЫ
local gPlayerESP = CreateGroupbox(VS_L, "Player ESP (Forum Pack)")
AddCheckbox(gPlayerESP, "Enabled", "ESP_Enabled", false)
AddCheckbox(gPlayerESP, "Bounding box", "ESP_Box", false)
AddDropdown(gPlayerESP, "Box mode (2D / Corner / 3D Cube)", "ESP_BoxStyle", {"Corner", "Full 2D", "3D Box (12 Lines)"})
AddCheckbox(gPlayerESP, "Dark translucent box fill", "ESP_BoxFill", false)
AddCheckbox(gPlayerESP, "Health bar + HP value", "ESP_HealthBar", false)
AddCheckbox(gPlayerESP, "Name tag", "ESP_Name", false)
AddCheckbox(gPlayerESP, "Role & Equipped weapon flag", "ESP_Flags", false)
AddCheckbox(gPlayerESP, "Distance tag", "ESP_Distance", false)
AddCheckbox(gPlayerESP, "Skeleton (Universal Bone ESP)", "ESP_Skeleton", false)
AddCheckbox(gPlayerESP, "Head Dot ESP", "ESP_HeadDot", false)
AddCheckbox(gPlayerESP, "3D View Barrel (Look Laser)", "ESP_LookLaser", false)
AddCheckbox(gPlayerESP, "Snapline Tracers to enemies", "ESP_Tracers", false)
AddDropdown(gPlayerESP, "Tracer origin", "ESP_TracerOrigin", {"Bottom", "Center", "Mouse"})
AddCheckbox(gPlayerESP, "Out of FOV arrows", "ESP_OOFArrows", false)
AddSlider(gPlayerESP, "OOF arrow radius", "ESP_OOFRadius", 60, 320, "px")
AddCheckbox(gPlayerESP, "Colored models (Chams)", "Chams", false)
AddSlider(gPlayerESP, "Chams transparency", "ChamsAlpha", 0, 95, "%")

local gTacticalVis = CreateGroupbox(VS_L, "Skeet Indicators, Radar & Self")
AddCheckbox(gTacticalVis, "Skeet Crosshair Indicators (DT/FAKE/WALL)", "SkeetIndicators", false)
AddCheckbox(gTacticalVis, "Velocity Speedometer + Live Graph", "VelocityGraph", false)
AddCheckbox(gTacticalVis, "Spectator & Dead Players List", "SpectatorList", false)
AddCheckbox(gTacticalVis, "2D Minimap Radar", "Radar2D", false)
AddSlider(gTacticalVis, "Radar zoom scale", "RadarZoom", 6, 40, "x")
AddCheckbox(gTacticalVis, "Target HUD card", "TargetHUD", false)
AddCheckbox(gTacticalVis, "3D Orbiting Neon Spheres (Self Aura)", "OrbitSpheres", false)
AddSlider(gTacticalVis, "Orbit spheres count", "OrbitCount", 1, 6, "")
AddSlider(gTacticalVis, "Orbit speed", "OrbitSpeed", 1, 12, "x")
AddCheckbox(gTacticalVis, "Murderer 3D danger ring", "MurdererDangerRing", false)
AddCheckbox(gTacticalVis, "3D Floating damage numbers", "FloatingDamage", false)
AddCheckbox(gTacticalVis, "3D Floating Head Halo", "HaloRing", false)
AddCheckbox(gTacticalVis, "3D China Hat", "ChinaHat", false)
AddDropdown(gTacticalVis, "China Hat & Aura color", "ChinaHatColor", {"Skeet Green", "Cyan", "Purple", "Rainbow"})

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

local gWorldESP = CreateGroupbox(VS_R, "World, Camera & Hit Effects")
AddCheckbox(gWorldESP, "Dropped gun ESP", "ESP_GunDrop", false)
AddCheckbox(gWorldESP, "Coin container ESP", "ESP_Coins", false)
AddCheckbox(gWorldESP, "Hit chams (On-shot skeleton)", "HitChams", false)
AddCheckbox(gWorldESP, "3D Bullet impact boxes", "BulletImpacts", false)
AddCheckbox(gWorldESP, "Dual-layer laser bullet tracers", "BulletTracers", false)
AddCheckbox(gWorldESP, "Hit marker & Sound", "HitSound", false)
AddDropdown(gWorldESP, "Sound type", "SoundType", {"Skeet", "Neverlose", "Rust", "Bell"})
AddCheckbox(gWorldESP, "World ambience tint", "WorldAmbience", false)
AddDropdown(gWorldESP, "Ambience palette", "WorldTintMode", {"Midnight Purple", "Skeet Green", "Cyber Cyan", "Crimson"})
AddCheckbox(gWorldESP, "Neon Bloom glow effect", "WorldBloom", false)
AddSlider(gWorldESP, "Color saturation boost", "ColorSaturation", 0, 100, "%")
AddCheckbox(gWorldESP, "Force thirdperson zoom", "ThirdPerson", true)
AddSlider(gWorldESP, "Thirdperson distance", "ThirdPersonDist", 8, 45, "st")
AddCheckbox(gWorldESP, "Override FOV", "CustomFOV", false)
AddSlider(gWorldESP, "Camera FOV", "CameraFOV", 60, 120, "°")
AddCheckbox(gWorldESP, "Aspect ratio (4:3 Stretch)", "AspectRatio", false)
AddSlider(gWorldESP, "Aspect ratio width", "AspectRatioVal", 55, 100, "%")
AddCheckbox(gWorldESP, "Fullbright", "Fullbright", false)
AddCheckbox(gWorldESP, "Night mode", "NightMode", false)

-- ВКЛАДКА 5: ПОЛНЫЙ PRO МУВМЕНТ (ВСЕ НОВЫЕ ФУНКЦИИ В МЕНЮ!) + ANTI-FLING & TARGET FLING
local gMove = CreateGroupbox(MS_L, "Movement, Fly & Strafes (Pro)")
AddCheckbox(gMove, "Enable Speed", "Speed_Enabled", true)
AddDropdown(gMove, "Speed mode", "SpeedMode", {"WalkSpeed", "CFrame Bypass", "Velocity Impulse", "Pulse Boost"})
AddSlider(gMove, "Speed factor", "SpeedVal", 16, 110, "")
AddCheckbox(gMove, "Camera Fly Mode [Key V]", "Fly_Enabled", true)
AddSlider(gMove, "Camera Fly Speed", "Fly_Speed", 20, 150, "")
AddCheckbox(gMove, "Phase Dash Blink [Key Q]", "Dash_Enabled", true)
AddSlider(gMove, "Phase Dash Distance", "Dash_Power", 8, 45, "st")
AddCheckbox(gMove, "Ctrl + Click Teleport", "ClickTP", true)
AddCheckbox(gMove, "Spider Wall-Climb (Climb Walls)", "SpiderClimb", false)
AddSlider(gMove, "Spider Climb Speed", "SpiderSpeed", 15, 60, "")
AddCheckbox(gMove, "Moonwalk (Slide Backwards)", "Moonwalk", false)
AddCheckbox(gMove, "Target Orbit Strafe (Lock Orbit)", "TargetStrafe", true)
AddSlider(gMove, "Orbit Strafe Radius", "CircleRadius", 5, 25, "st")
AddCheckbox(gMove, "Low Moon Gravity", "LowGravity", false)
AddSlider(gMove, "Gravity Power", "GravityVal", 30, 196, "")
AddCheckbox(gMove, "Anti-Void (Save from falling)", "AntiVoid", false)
AddCheckbox(gMove, "Bunny hop", "BHop", false)
AddCheckbox(gMove, "Air autostrafe (WASD Directional)", "AirStrafe", false)
AddSlider(gMove, "Air strafe velocity", "StrafeSpeed", 18, 90, "")
AddCheckbox(gMove, "Infinite jump", "InfiniteJump", false)
AddCheckbox(gMove, "Modify JumpPower", "HighJump", false)
AddSlider(gMove, "Jump power", "JumpPower", 50, 160, "")
AddCheckbox(gMove, "Noclip (Phase walls)", "Noclip", true)

local gMM2Util = CreateGroupbox(MS_R, "Fling, Anti-Fling & MM2 Utils")
AddCheckbox(gMM2Util, "Anti-Fling (Immunity to body push)", "AntiFling", false)
AddCheckbox(gMM2Util, "Enable Target Fling Hotkey [Key H]", "TargetFlingKey", true)
AddButton(gMM2Util, "TARGET FLING LOCKED ENEMY [Key H]", function()
    GS.TriggerTargetFling()
end, Skeet.Danger)
AddButton(gMM2Util, "FLING MURDERER INTO VOID", function()
    local m = GS.FindByRole("Murderer")
    if m then GS.TriggerTargetFling(m) else GS.PushSkeetLog("Мардер не найден!", Skeet.Danger) end
end, Skeet.Gold)
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
    local m = GS.FindByRole("Murderer")
    local s = GS.FindByRole("Sheriff")
    local msg = string.format("[MM2] Murderer: %s | Sheriff: %s", m and m.Name or "None", s and s.Name or "None")
    GS.PushSkeetLog(msg, Skeet.Gold)
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
    if GS.GetRole(LocalPlayer) ~= "Murderer" then return end
    local sh = GS.FindByRole("Sheriff")
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if sh and sh.Character and sh.Character:FindFirstChild("HumanoidRootPart") and myRoot then
        local knife = myChar:FindFirstChild("Knife") or LocalPlayer.Backpack:FindFirstChild("Knife")
        if knife and knife.Parent == LocalPlayer.Backpack then
            myChar:FindFirstChildOfClass("Humanoid"):EquipTool(knife)
        end
        GS.LastAttackData = {Player = sh, Time = tick()}
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
RoleStatusLbl.Size = UDim2.new(1, -18, 0, 44); RoleStatusLbl.Position = UDim2.new(0, 18, 0, 0)
RoleStatusLbl.BackgroundTransparency = 1; RoleStatusLbl.Font = Enum.Font.Code; RoleStatusLbl.TextSize = 12
RoleStatusLbl.TextColor3 = Skeet.Text; RoleStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
RoleStatusLbl.TextYAlignment = Enum.TextYAlignment.Top; RoleStatusLbl.Text = "Murderer: Scanning...\nSheriff: Scanning..."

local gPlrTp = CreateGroupbox(PL_R, "Role Teleports")
AddButton(gPlrTp, "Teleport to Murderer", function()
    local m = GS.FindByRole("Murderer")
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if m and m.Character and m.Character:FindFirstChild("HumanoidRootPart") and root then
        root.CFrame = m.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 4)
    end
end)
AddButton(gPlrTp, "Teleport to Sheriff", function()
    local s = GS.FindByRole("Sheriff")
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if s and s.Character and s.Character:FindFirstChild("HumanoidRootPart") and root then
        root.CFrame = s.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 4)
    end
end)

-- ВКЛАДКА 8: СИСТЕМА КОНФИГОВ И ПОЛНЫЙ UNHOOK
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
    "Slot 1 (Rage)", "Slot 2 (HvH Desync)", "Slot 3 (Legit Sheriff)", "Slot 4 (Murderer Pro)", "Slot 5 (Custom)"
})

local ConfigStatusLbl = Instance.new("TextLabel", gCfgSys)
ConfigStatusLbl.Size = UDim2.new(1, -18, 0, 16); ConfigStatusLbl.Position = UDim2.new(0, 18, 0, 0)
ConfigStatusLbl.BackgroundTransparency = 1; ConfigStatusLbl.Font = Enum.Font.Code; ConfigStatusLbl.TextSize = 11
ConfigStatusLbl.TextColor3 = Skeet.Accent; ConfigStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
ConfigStatusLbl.Text = "Status: Ready"

AddButton(gCfgSys, "Save config", function()
    local slot = Config.SelectedConfigSlot
    local ok, encoded = pcall(function() return HttpService:JSONEncode(Config) end)
    if ok and encoded then
        if writefile then
            pcall(writefile, GetConfigPath(slot), encoded)
            ConfigStatusLbl.Text = "Saved: " .. slot
            GS.PushSkeetLog("Saved config to " .. GetConfigPath(slot), Skeet.Accent)
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
            GS.ClearCustomSkins()
            ConfigStatusLbl.Text = "Loaded: " .. slot
            GS.PushSkeetLog("Loaded config: " .. slot, Skeet.Accent)
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
    for k, v in pairs(GS.DefaultConfigBackup) do
        Config[k] = v
    end
    RefreshAllUIControls()
    GS.ClearCustomSkins()
    ConfigStatusLbl.Text = "Reset to defaults"
end)

local gUnload = CreateGroupbox(CF_R, "Overlay & Unhook")
AddCheckbox(gUnload, "Watermark", "Watermark", false)
AddCheckbox(gUnload, "Keybind list", "KeybindList", false)
AddButton(gUnload, "UNHOOK / UNLOAD [END]", GS.FullUnhook, Skeet.Danger)

local SidebarUnhookBtn = Instance.new("TextButton", Sidebar)
SidebarUnhookBtn.Size = UDim2.new(1, -9, 0, 22); SidebarUnhookBtn.Position = UDim2.new(0, 4, 1, -28)
SidebarUnhookBtn.BackgroundColor3 = Skeet.ControlBg; SidebarUnhookBtn.BorderColor3 = Skeet.Danger; SidebarUnhookBtn.BorderSizePixel = 1
SidebarUnhookBtn.Font = Enum.Font.Code; SidebarUnhookBtn.TextSize = 10; SidebarUnhookBtn.TextColor3 = Skeet.Danger; SidebarUnhookBtn.Text = "UNHOOK"
GS.TrackConnection(SidebarUnhookBtn.MouseButton1Click:Connect(GS.FullUnhook))

-------------------------------------------------------------------------
-- ВОТЕРМАРКА, КЕЙБИНДЫ, СТРЕЛКИ И 3D МОДЕЛИ (GHOST, BACKTRACK)
-------------------------------------------------------------------------
local Watermark = Instance.new("Frame", ScreenGui)
Watermark.Size = UDim2.new(0, 310, 0, 22); Watermark.Position = UDim2.new(1, -322, 0, 12)
Watermark.BackgroundColor3 = Skeet.MainBg; Watermark.BorderColor3 = Skeet.GroupBorder; Watermark.BorderSizePixel = 1
local wmBar = Instance.new("Frame", Watermark)
wmBar.Size = UDim2.new(1, 0, 0, 2); wmBar.BackgroundColor3 = Skeet.Accent; wmBar.BorderSizePixel = 0
local wmTxt = Instance.new("TextLabel", Watermark)
wmTxt.Size = UDim2.new(1, -10, 1, -2); wmTxt.Position = UDim2.new(0, 5, 0, 2); wmTxt.BackgroundTransparency = 1
wmTxt.Font = Enum.Font.Code; wmTxt.TextSize = 11; wmTxt.TextColor3 = Skeet.TextActive; wmTxt.Text = "gamesense | mm2 | 60 fps"

local KeybindBox = Instance.new("Frame", ScreenGui)
KeybindBox.Size = UDim2.new(0, 185, 0, 24); KeybindBox.Position = UDim2.new(0, 14, 0.44, 0)
KeybindBox.BackgroundColor3 = Skeet.MainBg; KeybindBox.BorderColor3 = Skeet.GroupBorder; KeybindBox.BorderSizePixel = 1
KeybindBox.AutomaticSize = Enum.AutomaticSize.Y
local kbBar = Instance.new("Frame", KeybindBox)
kbBar.Size = UDim2.new(1, 0, 0, 2); kbBar.BackgroundColor3 = Skeet.Accent; kbBar.BorderSizePixel = 0
local kbHdr = Instance.new("TextLabel", KeybindBox)
kbHdr.Size = UDim2.new(1, 0, 0, 18); kbHdr.Position = UDim2.new(0, 0, 0, 2); kbHdr.BackgroundTransparency = 1
kbHdr.Font = Enum.Font.Code; kbHdr.TextSize = 11; kbHdr.TextColor3 = Skeet.TextActive; kbHdr.Text = "Keybinds"
local kbBody = Instance.new("TextLabel", KeybindBox)
kbBody.Size = UDim2.new(1, -12, 0, 14); kbBody.Position = UDim2.new(0, 6, 0, 20); kbBody.BackgroundTransparency = 1
kbBody.Font = Enum.Font.Code; kbBody.TextSize = 11; kbBody.TextColor3 = Skeet.Text
kbBody.TextXAlignment = Enum.TextXAlignment.Left; kbBody.TextYAlignment = Enum.TextYAlignment.Top
kbBody.AutomaticSize = Enum.AutomaticSize.Y

local ArrowLeft = Instance.new("TextLabel", ScreenGui)
ArrowLeft.Size = UDim2.new(0, 30, 0, 30); ArrowLeft.Position = UDim2.new(0.5, -55, 0.5, -15); ArrowLeft.BackgroundTransparency = 1
ArrowLeft.Font = Enum.Font.SourceSansBold; ArrowLeft.TextSize = 24; ArrowLeft.TextColor3 = Skeet.TextDim; ArrowLeft.TextStrokeTransparency = 0.2; ArrowLeft.Text = "<"; ArrowLeft.Visible = false

local ArrowRight = Instance.new("TextLabel", ScreenGui)
ArrowRight.Size = UDim2.new(0, 30, 0, 30); ArrowRight.Position = UDim2.new(0.5, 25, 0.5, -15); ArrowRight.BackgroundTransparency = 1
ArrowRight.Font = Enum.Font.SourceSansBold; ArrowRight.TextSize = 24; ArrowRight.TextColor3 = Skeet.TextDim; ArrowRight.TextStrokeTransparency = 0.2; ArrowRight.Text = ">"; ArrowRight.Visible = false

local ArrowDown = Instance.new("TextLabel", ScreenGui)
ArrowDown.Size = UDim2.new(0, 30, 0, 30); ArrowDown.Position = UDim2.new(0.5, -15, 0.5, 25); ArrowDown.BackgroundTransparency = 1
ArrowDown.Font = Enum.Font.SourceSansBold; ArrowDown.TextSize = 20; ArrowDown.TextColor3 = Skeet.TextDim; ArrowDown.TextStrokeTransparency = 0.2; ArrowDown.Text = "v"; ArrowDown.Visible = false

local GhostModel = GS.TrackInstance(Instance.new("Model"))
GhostModel.Name = "GS_DesyncClone"; GhostModel.Parent = Workspace
GS.GhostModel = GhostModel

local GhostParts = {}
local function RebuildGhostModel()
    GhostModel:ClearAllChildren()
    table.clear(GhostParts)
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local clone = Instance.new("Part")
            clone.Name = part.Name; clone.Size = part.Size
            clone.Anchored = true; clone.CanCollide = false; clone.CanTouch = false; clone.CanQuery = false; clone.CastShadow = false
            clone.Material = Enum.Material.ForceField; clone.Color = Skeet.Accent; clone.Transparency = 1
            clone.Parent = GhostModel
            GhostParts[part.Name] = clone
        end
    end
end
if LocalPlayer.Character then task.spawn(RebuildGhostModel) end
GS.TrackConnection(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if not GS.Unhooked then RebuildGhostModel() end
end))

local BacktrackGhost = GS.TrackInstance(Instance.new("Part"))
BacktrackGhost.Name = "GS_BacktrackGhost"
BacktrackGhost.Anchored = true; BacktrackGhost.CanCollide = false; BacktrackGhost.CanTouch = false; BacktrackGhost.CanQuery = false; BacktrackGhost.CastShadow = false
BacktrackGhost.Size = Vector3.new(2, 4.5, 1); BacktrackGhost.Material = Enum.Material.ForceField; BacktrackGhost.Color = Skeet.Cyan; BacktrackGhost.Transparency = 1
BacktrackGhost.Parent = Workspace
GS.BacktrackGhost = BacktrackGhost

local HatLines = {}
local HaloLines = {}
local DangerLines = {}
local HatSegments = 24

if Drawing then
    for i = 1, HatSegments do
        local rim = GS.TrackDrawing(Drawing.new("Line")); rim.Thickness = 1.5; rim.Visible = false
        local rib = GS.TrackDrawing(Drawing.new("Line")); rib.Thickness = 1.1; rib.Visible = false
        table.insert(HatLines, {Rim = rim, Rib = rib})

        local hLine = GS.TrackDrawing(Drawing.new("Line")); hLine.Thickness = 1.8; hLine.Visible = false
        table.insert(HaloLines, hLine)

        local dLine = GS.TrackDrawing(Drawing.new("Line")); dLine.Thickness = 1.8; dLine.Visible = false
        table.insert(DangerLines, dLine)
    end
end

local FOVCircle = GS.TrackDrawing(Drawing and Drawing.new("Circle"))
if FOVCircle then FOVCircle.Thickness = 1; FOVCircle.Color = Skeet.Accent; FOVCircle.Filled = false end

local LegitFOVCircle = GS.TrackDrawing(Drawing and Drawing.new("Circle"))
if LegitFOVCircle then LegitFOVCircle.Thickness = 1; LegitFOVCircle.Color = Skeet.Cyan; LegitFOVCircle.Filled = false end

local SnapLine = GS.TrackDrawing(Drawing and Drawing.new("Line"))
if SnapLine then SnapLine.Thickness = 1.2; SnapLine.Color = Skeet.Accent end

local TargetDot = GS.TrackDrawing(Drawing and Drawing.new("Circle"))
if TargetDot then TargetDot.Thickness = 1; TargetDot.Radius = 3.5; TargetDot.Filled = true; TargetDot.Color = Skeet.Murderer end

local BonePairsR15 = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}
}

local BonePairsR6 = {
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"}, {"Torso", "Left Leg"}, {"Torso", "Right Leg"}
}

local CubeEdges = {
    {1, 2}, {2, 3}, {3, 4}, {4, 1},
    {5, 6}, {6, 7}, {7, 8}, {8, 5},
    {1, 5}, {2, 6}, {3, 7}, {4, 8}
}

GS.TrackConnection(Players.PlayerRemoving:Connect(function(plr)
    GS.BacktrackHistory[plr] = nil
    if RadarDots[plr] then RadarDots[plr]:Destroy(); RadarDots[plr] = nil end
    if GS.ESPObjects[plr] then
        for _, item in pairs(GS.ESPObjects[plr]) do
            if type(item) == "table" then
                for _, sub in pairs(item) do if sub and sub.Remove then sub:Remove() end end
            elseif item and item.Remove then
                item:Remove()
            end
        end
        GS.ESPObjects[plr] = nil
    end
end))

GS.TrackConnection(UserInputService.InputBegan:Connect(function(inp, gp)
    if not gp then
        if inp.KeyCode == Enum.KeyCode.Insert or inp.KeyCode == Enum.KeyCode.RightShift then
            OuterWindow.Visible = not OuterWindow.Visible
        elseif inp.KeyCode == Enum.KeyCode.End then
            GS.FullUnhook()
        elseif inp.KeyCode == Enum.KeyCode.H and Config.TargetFlingKey then
            GS.TriggerTargetFling()
        elseif inp.KeyCode == Enum.KeyCode.G and Config.RemoteShootFromSheriff then
            GS.RemoteFireLivingSheriffGun(GS.CurrentAimPos)
        elseif inp.KeyCode == Enum.KeyCode.Space then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and Config.InfiniteJump then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        elseif Config.AA_Enabled and Config.AA_ManualKeys then
            if inp.KeyCode == Enum.KeyCode.Z then GS.ManualDir = (GS.ManualDir == -90) and 0 or -90
            elseif inp.KeyCode == Enum.KeyCode.X then GS.ManualDir = (GS.ManualDir == 180) and 0 or 180
            elseif inp.KeyCode == Enum.KeyCode.C then GS.ManualDir = (GS.ManualDir == 90) and 0 or 90 end
        elseif inp.UserInputType == Enum.UserInputType.MouseButton1 and not OuterWindow.Visible then
            local myChar = LocalPlayer.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not myChar or not myRoot then return end
            local knife = myChar:FindFirstChild("Knife")
            if knife and Config.GuaranteedStabFix then
                GS.PlayCSGOWeaponSound(false)
                local handle = knife:FindFirstChild("Handle")
                local reach = Config.LegitKnifeReach and Config.KnifeReachDist or 7.5
                if handle then
                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                            local tHum = plr.Character:FindFirstChildOfClass("Humanoid")
                            local tRoot = plr.Character.HumanoidRootPart
                            if tHum and tHum.Health > 0 and (tRoot.Position - myRoot.Position).Magnitude <= reach then
                                GS.LastAttackData = {Player = plr, Time = tick()}
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
    end
end))

-------------------------------------------------------------------------
-- ГЛАВНЫЙ ЦИКЛ ОТРИСОВКИ ВИЗУАЛОВ И ESP
-------------------------------------------------------------------------
local LastXRayCheck = 0

GS.TrackConnection(RunService.RenderStepped:Connect(function(dt)
    if GS.Unhooked then return end

    local myChar = LocalPlayer.Character
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local mousePos = UserInputService:GetMouseLocation()
    local vpSize = Camera.ViewportSize
    local vpCenter = vpSize / 2
    local themeCol = GS.GetThemeColor(Config.ChinaHatColor)

    Watermark.Visible = Config.Watermark
    KeybindBox.Visible = Config.KeybindList
    RadarFrame.Visible = Config.Radar2D
    SpecBox.Visible = Config.SpectatorList
    VelHolder.Visible = Config.VelocityGraph

    if Config.Watermark then
        local fps = math.floor(1 / math.max(dt, 0.001))
        local desyncState = Config.Desync_Enabled and " | anti-silent" or ""
        wmTxt.Text = string.format("gamesense | %s [%s]%s | %d fps", LocalPlayer.Name, GS.GetRole(LocalPlayer), desyncState, fps)
    end

    local scopeCenter = (Config.ScopeAlignMode == "Crosshair / Mouse") and mousePos or vpCenter
    SkeetIndHolder.Visible = Config.SkeetIndicators
    if Config.SkeetIndicators then
        SkeetIndHolder.Position = UDim2.new(0, scopeCenter.X + 14, 0, scopeCenter.Y + 16)
        local activeInds = {}
        if Config.Desync_Enabled then
            table.insert(activeInds, {Text = "FAKE [" .. string.upper(Config.Desync_Side) .. "]", Col = Skeet.Accent})
        end
        if Config.SilentAim then
            local locked = GS.CurrentTargetPlr ~= nil
            table.insert(activeInds, {Text = locked and ("LOCKED: " .. string.sub(GS.CurrentTargetPlr.Name, 1, 8)) or "SILENT", Col = locked and Skeet.Murderer or Skeet.Cyan})
        end
        if Config.Wallbang then
            table.insert(activeInds, {Text = "WALLBANG", Col = Skeet.Gold})
        end
        if Config.Fly_Enabled then
            table.insert(activeInds, {Text = "FLY [ACTIVE]", Col = Skeet.Accent})
        end
        if Config.AA_Enabled then
            table.insert(activeInds, {Text = "AA: " .. string.upper(Config.AA_Yaw), Col = Skeet.Purple})
        end
        if Config.AntiFling then
            table.insert(activeInds, {Text = "ANTI-FLING", Col = Skeet.Cyan})
        end
        for i = 1, 6 do
            local data = activeInds[i]
            if data then
                IndLabels[i].Visible = true
                IndLabels[i].Text = data.Text
                IndLabels[i].TextColor3 = data.Col
            else
                IndLabels[i].Visible = false
            end
        end
    end

    if Config.VelocityGraph and myRoot then
        local speed = math.floor(Vector3.new(myRoot.AssemblyLinearVelocity.X, 0, myRoot.AssemblyLinearVelocity.Z).Magnitude)
        VelText.Text = tostring(speed) .. " u/s"
        VelText.TextColor3 = (speed > 24) and Skeet.Accent or Skeet.TextActive
        table.remove(VelHistory, 1)
        table.insert(VelHistory, speed)
        for i = 1, 30 do
            local h = math.clamp(math.floor((VelHistory[i] / 60) * 36), 2, 38)
            VelGraphBars[i].Size = UDim2.new(0, 4, 0, h)
            VelGraphBars[i].BackgroundColor3 = (VelHistory[i] > 24) and Skeet.Accent or Skeet.Cyan
        end
    end

    if Config.SpectatorList then
        local deadOrSpec = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
                if not h or h.Health <= 0 then
                    table.insert(deadOrSpec, p.Name .. " [spec]")
                end
            end
        end
        spBody.Text = #deadOrSpec > 0 and table.concat(deadOrSpec, "\n") or "None watching"
    end

    for i = 1, 6 do
        local item = OrbitBalls[i]
        if Config.OrbitSpheres and myRoot and i <= Config.OrbitCount then
            local angle = (tick() * Config.OrbitSpeed) + ((i / Config.OrbitCount) * math.pi * 2)
            local rad = Config.OrbitRadius
            local yWave = math.sin(tick() * 3 + i) * 1.1
            local targetP = myRoot.Position + Vector3.new(math.cos(angle) * rad, yWave, math.sin(angle) * rad)
            item.Part.Transparency = 0.15
            item.Part.Color = themeCol
            item.Part.Position = targetP
            item.Trail.Color = ColorSequence.new(themeCol)
            item.Trail.Enabled = true
        else
            item.Part.Transparency = 1
            item.Trail.Enabled = false
        end
    end

    if Config.KeybindList then
        local list = {}
        if Config.SilentAim then
            local tName = GS.CurrentTargetPlr and GS.CurrentTargetPlr.Name or "ready"
            table.insert(list, "Silent aim       [" .. string.sub(tName, 1, 7) .. "]")
        end
        if Config.Wallbang then table.insert(list, "Wallbang         [on]") end
        if Config.Fly_Enabled then table.insert(list, "Camera Fly [V]   [on]") end
        if Config.Dash_Enabled then table.insert(list, "Phase Dash [Q]   [ready]") end
        if Config.TargetFlingKey then table.insert(list, "Target Fling [H] [ready]") end
        if Config.Desync_Enabled then table.insert(list, "Anti-Silent      [" .. Config.Desync_Side .. "]") end
        if Config.Speed_Enabled then table.insert(list, "Speed (" .. Config.SpeedMode .. ")") end
        kbBody.Text = #list > 0 and table.concat(list, "\n") or "No active binds"
    end

    if Config.TargetHUD and GS.CurrentTargetPlr and GS.CurrentTargetPart and GS.CurrentTargetPlr.Character then
        local tHum = GS.CurrentTargetPlr.Character:FindFirstChildOfClass("Humanoid")
        if tHum and tHum.Health > 0 then
            TargetHudFrame.Visible = true
            local role = GS.GetRole(GS.CurrentTargetPlr)
            local dist = myRoot and math.floor((GS.CurrentTargetPart.Position - myRoot.Position).Magnitude) or 0
            thName.Text = "Target: " .. GS.CurrentTargetPlr.Name
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

    if Config.LegitBacktrack and GS.CurrentTargetPlr and GS.BacktrackHistory[GS.CurrentTargetPlr] and #GS.BacktrackHistory[GS.CurrentTargetPlr] > 0 then
        local oldest = GS.BacktrackHistory[GS.CurrentTargetPlr][1]
        BacktrackGhost.Transparency = 0.55
        BacktrackGhost.Position = oldest.Pos
    else
        BacktrackGhost.Transparency = 1
    end

    local showArrows = Config.AA_Enabled and Config.AA_ShowArrows
    ArrowLeft.Visible = showArrows; ArrowRight.Visible = showArrows; ArrowDown.Visible = showArrows
    if showArrows then
        ArrowLeft.TextColor3 = (GS.ManualDir == -90) and Skeet.Accent or Skeet.TextDim
        ArrowRight.TextColor3 = (GS.ManualDir == 90) and Skeet.Accent or Skeet.TextDim
        ArrowDown.TextColor3 = (GS.ManualDir == 180) and Skeet.Accent or Skeet.TextDim
    end

    ScopeHolder.Visible = Config.CustomScope
    if Config.CustomScope then
        local scopeCol = GS.GetThemeColor(Config.ScopeColorMode)
        local velMag = myRoot and Vector3.new(myRoot.AssemblyLinearVelocity.X, 0, myRoot.AssemblyLinearVelocity.Z).Magnitude or 0
        local dynAdd = Config.ScopeDynamicSpread and math.clamp(velMag * 0.70, 0, 42) or 0
        local gap = Config.ScopeGap + math.floor(dynAdd)
        local len = Config.ScopeLength
        local thick = Config.ScopeThickness

        local showLines = (Config.ScopeMode ~= "Dot Only")
        ScopeTop.Visible = showLines; ScopeBot.Visible = showLines; ScopeLeft.Visible = showLines; ScopeRight.Visible = showLines

        if showLines then
            local gradTrans = (Config.ScopeMode == "Gradient Cross")
                and NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
                or NumberSequence.new(0)
            GradTop.Transparency = gradTrans; GradBot.Transparency = gradTrans; GradLeft.Transparency = gradTrans; GradRight.Transparency = gradTrans

            ScopeTop.BackgroundColor3 = scopeCol; ScopeBot.BackgroundColor3 = scopeCol; ScopeLeft.BackgroundColor3 = scopeCol; ScopeRight.BackgroundColor3 = scopeCol
            ScopeTop.Size = UDim2.new(0, thick, 0, len); ScopeTop.Position = UDim2.new(0, scopeCenter.X - math.floor(thick / 2), 0, scopeCenter.Y - gap - len)
            ScopeBot.Size = UDim2.new(0, thick, 0, len); ScopeBot.Position = UDim2.new(0, scopeCenter.X - math.floor(thick / 2), 0, scopeCenter.Y + gap)
            ScopeLeft.Size = UDim2.new(0, len, 0, thick); ScopeLeft.Position = UDim2.new(0, scopeCenter.X - gap - len, 0, scopeCenter.Y - math.floor(thick / 2))
            ScopeRight.Size = UDim2.new(0, len, 0, thick); ScopeRight.Position = UDim2.new(0, scopeCenter.X + gap, 0, scopeCenter.Y - math.floor(thick / 2))
        end

        ScopeDot.Visible = Config.ScopeCenterDot or (Config.ScopeMode == "Dot Only")
        ScopeDot.BackgroundColor3 = scopeCol
        ScopeDot.Size = UDim2.new(0, thick + 1, 0, thick + 1)
        ScopeDot.Position = UDim2.new(0, scopeCenter.X - math.floor((thick + 1) / 2), 0, scopeCenter.Y - math.floor((thick + 1) / 2))
    end

    local mPlr = GS.FindByRole("Murderer")
    local sPlr = GS.FindByRole("Sheriff")
    RoleStatusLbl.Text = string.format("Murderer: %s\nSheriff: %s", mPlr and mPlr.Name or "None", sPlr and sPlr.Name or "None")

    local rmbZooming = Config.CustomScope and Config.ScopeZoomRMB and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    if rmbZooming then
        Camera.FieldOfView = Config.ScopeZoomFOV
    elseif Config.CustomFOV then
        Camera.FieldOfView = Config.CameraFOV
    else
        Camera.FieldOfView = GS.OriginalState.CameraFOV
    end

    if Config.ThirdPerson then
        LocalPlayer.CameraMaxZoomDistance = Config.ThirdPersonDist
        LocalPlayer.CameraMinZoomDistance = Config.ThirdPersonDist
    else
        LocalPlayer.CameraMaxZoomDistance = GS.OriginalState.MaxZoom
        LocalPlayer.CameraMinZoomDistance = GS.OriginalState.MinZoom
    end

    BloomEffect.Enabled = Config.WorldBloom
    BloomEffect.Intensity = 0.8; BloomEffect.Size = 24; BloomEffect.Threshold = 0.85

    GS.ColorGrade.Saturation = Config.ColorSaturation / 100
    if Config.WorldAmbience then
        local ambCol = GS.GetThemeColor(Config.WorldTintMode)
        Lighting.Ambient = ambCol; Lighting.OutdoorAmbient = ambCol
    else
        Lighting.Ambient = GS.OriginalState.Ambient; Lighting.OutdoorAmbient = GS.OriginalState.OutdoorAmbient
    end

    if Config.NightMode then
        Lighting.ClockTime = 0; Lighting.Brightness = 0.5
    elseif Config.Fullbright then
        Lighting.ClockTime = 14; Lighting.Brightness = 2.2; Lighting.FogEnd = 100000; Lighting.GlobalShadows = false
    end

    if tick() - LastXRayCheck > 0.8 then
        LastXRayCheck = tick()
        if Config.XRayWalls then
            for _, v in ipairs(Workspace:GetDescendants()) do
                if v:IsA("BasePart") and not v:IsDescendantOf(myChar or Instance.new("Folder")) then
                    local model = v:FindFirstAncestorOfClass("Model")
                    local isPlayer = model and Players:GetPlayerFromCharacter(model)
                    if not isPlayer and v.Transparency < 0.8 and v.Size.Magnitude > 5 then
                        if not GS.XRayParts[v] then GS.XRayParts[v] = v.LocalTransparencyModifier end
                        v.LocalTransparencyModifier = Config.XRayTrans / 100
                    end
                end
            end
        elseif next(GS.XRayParts) ~= nil then
            GS.RestoreXRay()
        end
    end

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
                local segCol = GS.GetThemeColor(Config.ChinaHatColor, i / HatSegments)

                local rim = HatLines[i].Rim; local rib = HatLines[i].Rib
                if v1 and v2 and tipVis then
                    rim.Visible = true; rim.From = Vector2.new(s1.X, s1.Y); rim.To = Vector2.new(s2.X, s2.Y); rim.Color = segCol
                    rib.Visible = (i % 2 == 0); rib.From = Vector2.new(tipScreen.X, tipScreen.Y); rib.To = Vector2.new(s1.X, s1.Y); rib.Color = segCol
                else
                    rim.Visible = false; rib.Visible = false
                end
            end
        else
            for i = 1, HatSegments do HatLines[i].Rim.Visible = false; HatLines[i].Rib.Visible = false end
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
                    hLine.Visible = true; hLine.From = Vector2.new(s1.X, s1.Y); hLine.To = Vector2.new(s2.X, s2.Y); hLine.Color = themeCol
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
                    dLine.Visible = true; dLine.From = Vector2.new(s1.X, s1.Y); dLine.To = Vector2.new(s2.X, s2.Y); dLine.Color = Skeet.Murderer
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
        if Config.SilentAim and Config.TargetLine and GS.CurrentAimPos then
            local sp, vis = Camera:WorldToViewportPoint(GS.CurrentAimPos)
            SnapLine.Visible = vis; SnapLine.From = mousePos; SnapLine.To = Vector2.new(sp.X, sp.Y)
            TargetDot.Visible = vis; TargetDot.Position = Vector2.new(sp.X, sp.Y)
        else
            SnapLine.Visible = false; TargetDot.Visible = false
        end
    end

    local tracerStart = (Config.ESP_TracerOrigin == "Bottom" and Vector2.new(vpCenter.X, vpSize.Y - 10))
        or (Config.ESP_TracerOrigin == "Center" and vpCenter)
        or mousePos

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local alive = hum and hum.Health > 0
            local role = GS.GetRole(plr)
            local col = (role == "Murderer" and Skeet.Murderer) or (role == "Sheriff" and Skeet.Sheriff) or Skeet.Innocent

            if Config.Radar2D and hrp and alive and myRoot then
                if not RadarDots[plr] then
                    local dot = Instance.new("Frame", RadarFrame)
                    dot.Size = UDim2.new(0, 5, 0, 5); dot.BorderSizePixel = 0
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
                    hrp.Color = col; hrp.CanCollide = false
                else
                    hrp.Size = Vector3.new(2, 2, 1); hrp.Transparency = 1
                end
            end

            if char and hrp and alive and Config.ESP_Enabled then
                local hl = char:FindFirstChild("GS_Chams")
                if Config.Chams then
                    if not hl then
                        hl = Instance.new("Highlight", char)
                        hl.Name = "GS_Chams"; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    end
                    hl.FillColor = col; hl.OutlineColor = Color3.fromRGB(15, 15, 15)
                    hl.FillTransparency = Config.ChamsAlpha / 100; hl.OutlineTransparency = 0.35
                elseif hl then
                    hl:Destroy()
                end

                if Drawing then
                    if not GS.ESPObjects[plr] then
                        local bones = {}
                        for i = 1, 10 do
                            local b = Drawing.new("Line"); b.Thickness = 1; b.Transparency = 0.85; b.Visible = false
                            bones[i] = b
                        end
                        local corners = {}
                        for i = 1, 8 do
                            local c = Drawing.new("Line"); c.Thickness = 1.5; c.Visible = false
                            corners[i] = c
                        end
                        local cubeLines = {}
                        for i = 1, 12 do
                            local cl = Drawing.new("Line"); cl.Thickness = 1.3; cl.Visible = false
                            cubeLines[i] = cl
                        end
                        GS.ESPObjects[plr] = {
                            BoxFill = Drawing.new("Square"),
                            BoxOutline = Drawing.new("Square"),
                            Box = Drawing.new("Square"),
                            Corners = corners,
                            CubeLines = cubeLines,
                            HpOutline = Drawing.new("Line"),
                            HpBar = Drawing.new("Line"),
                            Name = Drawing.new("Text"),
                            Flag = Drawing.new("Text"),
                            HeadDot = Drawing.new("Circle"),
                            LookLaser = Drawing.new("Line"),
                            Tracer = Drawing.new("Line"),
                            OOF1 = Drawing.new("Line"),
                            OOF2 = Drawing.new("Line"),
                            OOF3 = Drawing.new("Line"),
                            Bones = bones
                        }
                        GS.ESPObjects[plr].BoxFill.Filled = true; GS.ESPObjects[plr].BoxFill.Color = Color3.fromRGB(10, 10, 12); GS.ESPObjects[plr].BoxFill.Transparency = 0.35
                        GS.ESPObjects[plr].BoxOutline.Thickness = 2.5; GS.ESPObjects[plr].BoxOutline.Color = Color3.new(0, 0, 0)
                        GS.ESPObjects[plr].Box.Thickness = 1
                        GS.ESPObjects[plr].HpOutline.Thickness = 3; GS.ESPObjects[plr].HpOutline.Color = Color3.new(0, 0, 0)
                        GS.ESPObjects[plr].HpBar.Thickness = 1.5
                        GS.ESPObjects[plr].Name.Size = 12; GS.ESPObjects[plr].Name.Center = true; GS.ESPObjects[plr].Name.Outline = true
                        GS.ESPObjects[plr].Flag.Size = 11; GS.ESPObjects[plr].Flag.Center = true; GS.ESPObjects[plr].Flag.Outline = true
                        GS.ESPObjects[plr].HeadDot.Thickness = 1.5; GS.ESPObjects[plr].HeadDot.Filled = false
                        GS.ESPObjects[plr].LookLaser.Thickness = 1.4
                        GS.ESPObjects[plr].Tracer.Thickness = 1.2
                        GS.ESPObjects[plr].OOF1.Thickness = 1.8; GS.ESPObjects[plr].OOF2.Thickness = 1.8; GS.ESPObjects[plr].OOF3.Thickness = 1.8
                    end

                    local esp = GS.ESPObjects[plr]
                    local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                    if onScreen then
                        esp.OOF1.Visible = false; esp.OOF2.Visible = false; esp.OOF3.Visible = false

                        local scale = 2000 / math.max(pos.Z, 1)
                        local w, h = math.floor(scale * 1.75), math.floor(scale * 2.55)
                        local x, y = math.floor(pos.X - w / 2), math.floor(pos.Y - h / 2)

                        esp.BoxFill.Visible = Config.ESP_Box and Config.ESP_BoxFill and (Config.ESP_BoxStyle ~= "3D Box (12 Lines)")
                        esp.BoxFill.Size = Vector2.new(w, h); esp.BoxFill.Position = Vector2.new(x, y)

                        if Config.ESP_Box and Config.ESP_BoxStyle == "3D Box (12 Lines)" then
                            esp.BoxOutline.Visible = false; esp.Box.Visible = false
                            for idx = 1, 8 do esp.Corners[idx].Visible = false end
                            local cf = hrp.CFrame
                            local sx, sy, sz = 1.8, 2.8, 1.2
                            local verts3D = {
                                cf * Vector3.new(-sx, sy, -sz), cf * Vector3.new(sx, sy, -sz),
                                cf * Vector3.new(sx, sy, sz),  cf * Vector3.new(-sx, sy, sz),
                                cf * Vector3.new(-sx, -sy, -sz), cf * Vector3.new(sx, -sy, -sz),
                                cf * Vector3.new(sx, -sy, sz),  cf * Vector3.new(-sx, -sy, sz)
                            }
                            local verts2D = {}
                            local allVis = true
                            for vIdx = 1, 8 do
                                local vp, vVis = Camera:WorldToViewportPoint(verts3D[vIdx])
                                if not vVis then allVis = false; break end
                                verts2D[vIdx] = Vector2.new(vp.X, vp.Y)
                            end
                            for eIdx, edge in ipairs(CubeEdges) do
                                local ln = esp.CubeLines[eIdx]
                                if allVis then
                                    ln.Visible = true; ln.From = verts2D[edge[1]]; ln.To = verts2D[edge[2]]; ln.Color = col
                                else
                                    ln.Visible = false
                                end
                            end
                        elseif Config.ESP_Box and Config.ESP_BoxStyle == "Corner" then
                            esp.BoxOutline.Visible = false; esp.Box.Visible = false
                            for idx = 1, 12 do esp.CubeLines[idx].Visible = false end
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
                                ln.Visible = true; ln.From = pt[1]; ln.To = pt[2]; ln.Color = col
                            end
                        else
                            for idx = 1, 8 do esp.Corners[idx].Visible = false end
                            for idx = 1, 12 do esp.CubeLines[idx].Visible = false end
                            esp.BoxOutline.Visible = Config.ESP_Box; esp.BoxOutline.Size = Vector2.new(w, h); esp.BoxOutline.Position = Vector2.new(x, y)
                            esp.Box.Visible = Config.ESP_Box; esp.Box.Size = Vector2.new(w, h); esp.Box.Position = Vector2.new(x, y); esp.Box.Color = col
                        end

                        local hpPct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                        esp.HpOutline.Visible = Config.ESP_HealthBar; esp.HpOutline.From = Vector2.new(x - 5, y - 1); esp.HpOutline.To = Vector2.new(x - 5, y + h + 1)
                        esp.HpBar.Visible = Config.ESP_HealthBar; esp.HpBar.From = Vector2.new(x - 5, y + h); esp.HpBar.To = Vector2.new(x - 5, y + h - (h * hpPct))
                        esp.HpBar.Color = Color3.fromRGB(255 - math.floor(hpPct * 150), math.floor(hpPct * 225), 40)

                        esp.Name.Visible = Config.ESP_Name; esp.Name.Position = Vector2.new(pos.X, y - 14); esp.Name.Text = plr.Name; esp.Name.Color = Color3.fromRGB(240, 240, 240)

                        local d = myRoot and math.floor((hrp.Position - myRoot.Position).Magnitude) or 0
                        local heldTool = char:FindFirstChildOfClass("Tool")
                        local heldStr = (heldTool and (" [" .. string.upper(heldTool.Name) .. "]")) or ""
                        esp.Flag.Visible = Config.ESP_Flags or Config.ESP_Distance
                        esp.Flag.Position = Vector2.new(pos.X, y + h + 2)
                        esp.Flag.Text = string.upper(role) .. heldStr .. (Config.ESP_Distance and string.format(" · %dM", d) or "")
                        esp.Flag.Color = col

                        local pHead = char:FindFirstChild("Head")
                        if pHead and (Config.ESP_HeadDot or Config.ESP_LookLaser) then
                            local hp2D, hVis = Camera:WorldToViewportPoint(pHead.Position)
                            if hVis then
                                esp.HeadDot.Visible = Config.ESP_HeadDot
                                esp.HeadDot.Position = Vector2.new(hp2D.X, hp2D.Y)
                                esp.HeadDot.Radius = math.clamp(800 / math.max(hp2D.Z, 1), 2, 9)
                                esp.HeadDot.Color = col

                                if Config.ESP_LookLaser then
                                    local lookEnd, lVis = Camera:WorldToViewportPoint(pHead.Position + (pHead.CFrame.LookVector * 5.5))
                                    if lVis then
                                        esp.LookLaser.Visible = true
                                        esp.LookLaser.From = Vector2.new(hp2D.X, hp2D.Y)
                                        esp.LookLaser.To = Vector2.new(lookEnd.X, lookEnd.Y)
                                        esp.LookLaser.Color = Skeet.Cyan
                                    else
                                        esp.LookLaser.Visible = false
                                    end
                                else
                                    esp.LookLaser.Visible = false
                                end
                            else
                                esp.HeadDot.Visible = false; esp.LookLaser.Visible = false
                            end
                        else
                            esp.HeadDot.Visible = false; esp.LookLaser.Visible = false
                        end

                        if Config.ESP_Tracers then
                            esp.Tracer.Visible = true; esp.Tracer.From = tracerStart; esp.Tracer.To = Vector2.new(pos.X, y + h); esp.Tracer.Color = col
                        else
                            esp.Tracer.Visible = false
                        end

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
                                        line.Visible = true; line.From = Vector2.new(p1.X, p1.Y); line.To = Vector2.new(p2.X, p2.Y); line.Color = Color3.fromRGB(230, 230, 230)
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
                        esp.BoxFill.Visible = false; esp.BoxOutline.Visible = false; esp.Box.Visible = false
                        esp.HpOutline.Visible = false; esp.HpBar.Visible = false; esp.Name.Visible = false; esp.Flag.Visible = false
                        esp.HeadDot.Visible = false; esp.LookLaser.Visible = false; esp.Tracer.Visible = false
                        for idx = 1, 8 do esp.Corners[idx].Visible = false end
                        for idx = 1, 12 do esp.CubeLines[idx].Visible = false end
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
                if GS.ESPObjects[plr] then
                    for _, item in pairs(GS.ESPObjects[plr]) do
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

    if myChar and myRoot then
        local showGhost = Config.Desync_Enabled and Config.Desync_ShowGhost
        local deltaCF = myRoot.CFrame:Inverse() * GS.ServerGhostCFrame
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
    end
end))
