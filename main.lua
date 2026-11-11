-- ASTREND HUB.lua | Luau | Roblox executor | stable build (Highlight/BillboardGui ESP, no Drawing, no Constraints)

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Tween      = game:GetService("TweenService")
local Workspace  = game:GetService("Workspace")
local LP         = Players.LocalPlayer
local Camera     = Workspace.CurrentCamera

local function guiParent()
    local ok, h = pcall(function() return gethui and gethui() end)
    if ok and h then return h end
    return game:GetService("CoreGui")
end

--// ============================ config
local Config = {
    Aimbot = {
        Enabled = false, FOV = 150, Smoothness = 8, Target = "Head",
        TeamCheck = true, WallCheck = false, MaxDist = 500,
        Prediction = 0.15, Key = Enum.KeyCode.E,
        Color = Color3.fromRGB(155,89,255),
    },
    SilentAim = {
        Enabled = false, FOV = 150, Target = "Head",
        TeamCheck = true, MaxDist = 500,
        Color = Color3.fromRGB(89,155,255),
    },
    ESP = {
        Enabled = true,
        BoxColor = Color3.fromRGB(155,89,255),
        NameColor = Color3.fromRGB(255,255,255),
        TeamCheck = true,
        MaxRenderDist = 1000,
        HideDead = true,
    },
    Fly = { Enabled = false, Speed = 50, Key = Enum.KeyCode.F },
    Player = { GodMode = false, InfAmmo = false },
    Settings = { Scale = 1 },
}

--// ============================ helpers
local function new(class, props, parent)
    local o = Instance.new(class)
    for k,v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function corner(inst, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 6); c.Parent = inst
    return c
end

--// ============================ UI
local g = new("ScreenGui", {
    Name = "AstrendHub", ResetOnSpawn = false,
    IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, guiParent())

local main = new("Frame", {
    Size = UDim2.fromOffset(500, 380),
    Position = UDim2.new(0.5, -250, 0.5, -190),
    BackgroundColor3 = Color3.fromRGB(18, 18, 24),
    BorderSizePixel = 0, Active = true,
}, g)
corner(main, 10)
new("UIStroke", {Color=Color3.fromRGB(60,50,90), Thickness=1, Transparency=0.4}, main)
new("UIScale", {Scale = Config.Settings.Scale}, main)

local titleBar = new("Frame", {
    Size = UDim2.new(1,0,0,32), BackgroundColor3 = Color3.fromRGB(24,20,36),
    BorderSizePixel = 0, Active = true,
}, main)
corner(titleBar, 10)
new("TextLabel", {
    Text = "ASTREND HUB", Size = UDim2.new(1,-60,1,0), Position = UDim2.fromOffset(14,0),
    BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(180,150,255),
    Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
}, titleBar)

local minBtn = new("TextButton", {
    Text = "—", Size = UDim2.fromOffset(24,24), Position = UDim2.new(1,-56,0,4),
    BackgroundColor3 = Color3.fromRGB(40,32,60), TextColor3 = Color3.fromRGB(220,200,255),
    Font = Enum.Font.GothamBold, TextSize = 14, AutoButtonColor = true,
}, titleBar)
corner(minBtn, 5)

local closeBtn = new("TextButton", {
    Text = "×", Size = UDim2.fromOffset(24,24), Position = UDim2.new(1,-28,0,4),
    BackgroundColor3 = Color3.fromRGB(60,24,32), TextColor3 = Color3.fromRGB(255,180,190),
    Font = Enum.Font.GothamBold, TextSize = 16, AutoButtonColor = true,
}, titleBar)
corner(closeBtn, 5)

local body = new("Frame", {
    Size = UDim2.new(1,0,1,-32), Position = UDim2.fromOffset(0,32),
    BackgroundTransparency = 1,
}, main)

local sidebar = new("Frame", {
    Size = UDim2.new(0,140,1,0), BackgroundColor3 = Color3.fromRGB(22,18,32),
    BorderSizePixel = 0,
}, body)
corner(sidebar, 10)

local contentArea = new("Frame", {
    Size = UDim2.new(1,-150,1,-10), Position = UDim2.fromOffset(145,5),
    BackgroundTransparency = 1,
}, body)

-- drag
do
    local dragging, start, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; start = input.Position; startPos = main.Position
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = input.Position - start
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
end

minBtn.MouseButton1Click:Connect(function()
    body.Visible = not body.Visible
    main.Size = body.Visible and UDim2.fromOffset(500, 380) or UDim2.fromOffset(500, 32)
end)
closeBtn.MouseButton1Click:Connect(function() g:Destroy() end)

-- tabs
local tabs = {}
local tabButtons = {}
local tabNames = {"Combat","Visuals","Movement","Player","Settings"}

local function makeTab(name)
    local btn = new("TextButton", {
        Text = name, Size = UDim2.new(1,-16,0,28), Position = UDim2.fromOffset(8, 8 + #tabButtons*34),
        BackgroundColor3 = Color3.fromRGB(32,26,48), TextColor3 = Color3.fromRGB(200,180,255),
        Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
    }, sidebar)
    corner(btn, 6)
    new("UIPadding", {PaddingLeft = UDim.new(0,10)}, btn)

    local page = new("ScrollingFrame", {
        Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1,
        ScrollBarThickness = 3, ScrollBarImageColor3 = Color3.fromRGB(120,90,200),
        CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false, BorderSizePixel = 0,
    }, contentArea)
    table.insert(tabs, {Name=name, Btn=btn, Page=page})
    table.insert(tabButtons, btn)

    btn.MouseButton1Click:Connect(function()
        for _, t in ipairs(tabs) do t.Page.Visible = false; t.Btn.BackgroundColor3 = Color3.fromRGB(32,26,48) end
        page.Visible = true
        btn.BackgroundColor3 = Color3.fromRGB(60,44,96)
    end)
    return page
end

for _, n in ipairs(tabNames) do makeTab(n) end
tabs[1].Page.Visible = true
tabs[1].Btn.BackgroundColor3 = Color3.fromRGB(60,44,96)

-- widgets
local yCursor = {}
local function allocY(page, h)
    yCursor[page] = (yCursor[page] or 0) + (h or 30) + 6
    return yCursor[page]
end

local function sectionTitle(page, text)
    local y = allocY(page, 20)
    new("TextLabel", {
        Text = text, Size = UDim2.new(1,-20,0,20), Position = UDim2.fromOffset(10, y),
        BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(150,120,230),
        Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
    }, page)
end

local function toggleWidget(page, label, get, set)
    local y = allocY(page, 26)
    local frame = new("TextButton", {
        Text = "", Size = UDim2.new(1,-20,0,26), Position = UDim2.fromOffset(10, y),
        BackgroundColor3 = Color3.fromRGB(28,24,40), AutoButtonColor = false,
    }, page)
    corner(frame, 6)
    new("TextLabel", {
        Text = label, Size = UDim2.new(1,-44,1,0), Position = UDim2.fromOffset(10,0),
        BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(225,215,255),
        Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
    }, frame)
    local pill = new("Frame", {
        Size = UDim2.fromOffset(34,18), Position = UDim2.new(1,-42,0.5,-9),
        BackgroundColor3 = get() and Color3.fromRGB(140,100,255) or Color3.fromRGB(60,55,80),
    }, frame)
    corner(pill, 9)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(14,14), Position = get() and UDim2.fromOffset(18,2) or UDim2.fromOffset(2,2),
        BackgroundColor3 = Color3.fromRGB(255,255,255),
    }, pill)
    corner(knob, 7)
    frame.MouseButton1Click:Connect(function()
        local nv = not get(); set(nv)
        local tw = TweenInfo.new(0.15)
        Tween:Create(pill, tw, {BackgroundColor3 = nv and Color3.fromRGB(140,100,255) or Color3.fromRGB(60,55,80)}):Play()
        Tween:Create(knob, tw, {Position = nv and UDim2.fromOffset(18,2) or UDim2.fromOffset(2,2)}):Play()
    end)
end

local function sliderWidget(page, label, min, max, get, set, integer)
    local y = allocY(page, 42)
    local f = new("Frame", {
        Size = UDim2.new(1,-20,0,42), Position = UDim2.fromOffset(10, y),
        BackgroundColor3 = Color3.fromRGB(28,24,40),
    }, page)
    corner(f, 6)
    new("TextLabel", {
        Text = label, Size = UDim2.new(1,-70,0,20), Position = UDim2.fromOffset(10,2),
        BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(225,215,255),
        Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
    }, f)
    local valLbl = new("TextLabel", {
        Text = tostring(get()), Size = UDim2.fromOffset(60,20), Position = UDim2.new(1,-70,0,2),
        BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(180,150,255),
        Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right,
    }, f)
    local track = new("Frame", {
        Size = UDim2.new(1,-20,0,5), Position = UDim2.fromOffset(10,26),
        BackgroundColor3 = Color3.fromRGB(50,44,68),
    }, f)
    corner(track, 3)
    local fill = new("Frame", {
        Size = UDim2.new((get()-min)/(max-min),0,1,0), BackgroundColor3 = Color3.fromRGB(140,100,255),
    }, track)
    corner(fill, 3)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(12,12),
        Position = UDim2.new(fill.Size.X.Scale, -6, 0.5, -6),
        BackgroundColor3 = Color3.fromRGB(255,255,255),
    }, track)
    corner(knob, 6)
    local dragging = false
    local function update(input)
        local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local raw = min + (max - min) * rel
        if integer then raw = math.floor(raw + 0.5) end
        set(raw)
        valLbl.Text = tostring(raw)
        fill.Size = UDim2.new(rel,0,1,0)
        knob.Position = UDim2.new(rel, -6, 0.5, -6)
    end
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; update(i) end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then update(i) end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
end

local function keybindWidget(page, label, get, set)
    local y = allocY(page, 26)
    local btn = new("TextButton", {
        Text = "", Size = UDim2.new(1,-20,0,26), Position = UDim2.fromOffset(10, y),
        BackgroundColor3 = Color3.fromRGB(28,24,40), AutoButtonColor = false,
    }, page)
    corner(btn, 6)
    new("TextLabel", {
        Text = label, Size = UDim2.new(1,-100,1,0), Position = UDim2.fromOffset(10,0),
        BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(225,215,255),
        Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
    }, btn)
    local val = new("TextLabel", {
        Text = tostring(get()):gsub("Enum.KeyCode.",""), Size = UDim2.fromOffset(80,20),
        Position = UDim2.new(1,-90,0.5,-10), BackgroundColor3 = Color3.fromRGB(60,44,96),
        TextColor3 = Color3.fromRGB(220,200,255), Font = Enum.Font.GothamBold, TextSize = 11,
    }, btn)
    corner(val, 4)
    btn.MouseButton1Click:Connect(function()
        val.Text = "..."
        local conn
        conn = UIS.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                set(input.KeyCode)
                val.Text = tostring(input.KeyCode):gsub("Enum.KeyCode.","")
                conn:Disconnect()
            end
        end)
    end)
end

--// ============================ TARGETING
local function getTargetFor(cfg)
    if not LP.Character then return nil end
    local best, bestDist = nil, math.huge
    local camPos = Camera.CFrame.Position
    local vp = Camera.ViewportSize
    local center = Vector2.new(vp.X/2, vp.Y/2)
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LP then continue end
        local char = p.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        if cfg.TeamCheck and p.Team and LP.Team and p.Team == LP.Team then continue end
        local part = char:FindFirstChild(cfg.Target)
        if not part then continue end
        local dist = (camPos - part.Position).Magnitude
        if dist > cfg.MaxDist then continue end
        local sp, on = Camera:WorldToViewportPoint(part.Position)
        if not on then continue end
        local d2 = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d2 > cfg.FOV then continue end
        if d2 < bestDist then best, bestDist = {player=p, part=part}, d2 end
    end
    return best
end

--// ============================ FOV (via Frame, não Drawing)
local fovFrame = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(Config.Aimbot.FOV * 2, Config.Aimbot.FOV * 2),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Visible = false,
}, g)
local fovCorner = Instance.new("UICorner", fovFrame)
fovCorner.CornerRadius = UDim.new(1, 0)
local fovStroke = new("UIStroke", {Color = Config.Aimbot.Color, Thickness = 1, Transparency = 0.5}, fovFrame)

--// ============================ AIMBOT
local aimHeld = false
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Config.Aimbot.Key then aimHeld = true end
end)
UIS.InputEnded:Connect(function(input)
    if input.KeyCode == Config.Aimbot.Key then aimHeld = false end
end)

--// ============================ SILENT AIM
local oldNamecall
pcall(function()
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if not oldNamecall then return end
        local method = getnamecallmethod()
        if Config.SilentAim.Enabled and checkcaller and not checkcaller() and method == "FireServer" then
            local t = getTargetFor(Config.SilentAim)
            if t then
                local args = {...}
                for i = 1, #args do
                    if typeof(args[i]) == "Instance" and args[i]:IsA("BasePart") then
                        args[i] = t.part
                    elseif typeof(args[i]) == "Vector3" then
                        args[i] = t.part.Position
                    end
                end
                return oldNamecall(self, table.unpack(args))
            end
        end
        return oldNamecall(self, ...)
    end)
end)

--// ============================ ESP (Highlight + BillboardGui — estável)
local espCache = {}

local function clearESP(player)
    local data = espCache[player]
    if not data then return end
    if data.highlight then data.highlight:Destroy() end
    if data.billboard then data.billboard:Destroy() end
    espCache[player] = nil
end

local function createESP(player)
    if player == LP then return end
    clearESP(player)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local hl = Instance.new("Highlight")
    hl.FillColor = Config.ESP.BoxColor
    hl.OutlineColor = Color3.fromRGB(255,255,255)
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0
    hl.Adornee = char
    hl.Parent = char

    local bg = Instance.new("BillboardGui")
    bg.Size = UDim2.fromOffset(160, 40)
    bg.StudsOffset = Vector3.new(0, 3.5, 0)
    bg.AlwaysOnTop = true
    bg.Parent = hrp

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, 0, 0.6, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = player.Name
    nameLbl.TextColor3 = Config.ESP.NameColor
    nameLbl.TextStrokeTransparency = 0
    nameLbl.TextScaled = true
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.Parent = bg

    local distLbl = Instance.new("TextLabel")
    distLbl.Size = UDim2.new(1, 0, 0.4, 0)
    distLbl.Position = UDim2.new(0, 0, 0.6, 0)
    distLbl.BackgroundTransparency = 1
    distLbl.Text = ""
    distLbl.TextColor3 = Color3.fromRGB(200,200,200)
    distLbl.TextStrokeTransparency = 0
    distLbl.TextScaled = true
    distLbl.Font = Enum.Font.Gotham
    distLbl.Parent = bg

    espCache[player] = {highlight = hl, billboard = bg, nameLbl = nameLbl, distLbl = distLbl}
end

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.5)
        if Config.ESP.Enabled then createESP(p) end
    end)
end)

Players.PlayerRemoving:Connect(clearESP)

--// ============================ FLY (Velocity puro, sem constraints)
local flyConn
local function setFly(on)
    Config.Fly.Enabled = on
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    if on then
        hum.PlatformStand = true
        if flyConn then flyConn:Disconnect() end
        flyConn = RunService.RenderStepped:Connect(function()
            if not Config.Fly.Enabled then return end
            local c = LP.Character
            if not c then return end
            local h = c:FindFirstChild("HumanoidRootPart")
            if not h then return end
            local dir = Vector3.zero
            local camCF = Camera.CFrame
            if UIS:IsKeyDown(Enum.KeyCode.W) then dir += camCF.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= camCF.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= camCF.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then dir += camCF.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0,1,0) end
            h.Velocity = dir * Config.Fly.Speed
        end)
    else
        if flyConn then flyConn:Disconnect(); flyConn = nil end
        hum.PlatformStand = false
    end
end

UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Config.Fly.Key then setFly(not Config.Fly.Enabled) end
end)

--// ============================ PLAYER FEATURES
task.spawn(function()
    while g.Parent do
        if Config.Player.GodMode and LP.Character then
            local hum = LP.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.Health = hum.MaxHealth end
        end
        if Config.Player.InfAmmo and LP.Character then
            local containers = {LP.Character, LP:FindFirstChild("Backpack")}
            for _, c in ipairs(containers) do
                if c then
                    for _, tool in ipairs(c:GetChildren()) do
                        pcall(function()
                            for _, v in ipairs(tool:GetDescendants()) do
                                if v:IsA("IntValue") and v.Name:lower():find("ammo") then
                                    v.Value = 999
                                end
                            end
                        end)
                    end
                end
            end
        end
        task.wait(0.2)
    end
end)

--// ============================ ESP loop (leve)
task.spawn(function()
    while g.Parent do
        if Config.ESP.Enabled then
            for _, p in ipairs(Players:GetPlayers()) do
                if p == LP then continue end
                local char = p.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not (char and hum and hrp) then
                    clearESP(p); continue
                end
                if (Config.ESP.HideDead and hum.Health <= 0)
                    or (Config.ESP.TeamCheck and p.Team and LP.Team and p.Team == LP.Team) then
                    clearESP(p); continue
                end
                local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
                if dist > Config.ESP.MaxRenderDist then
                    clearESP(p); continue
                end
                local data = espCache[p]
                if not data then
                    createESP(p)
                    data = espCache[p]
                end
                if data and data.distLbl then
                    data.distLbl.Text = string.format("%.0fm", dist)
                end
            end
        else
            for p in pairs(espCache) do clearESP(p) end
        end
        task.wait(0.1)
    end
end)

--// ============================ BUILD TABS
local combatTab = tabs[1].Page
sectionTitle(combatTab, "AIMBOT")
toggleWidget(combatTab, "Enable Aimbot", function() return Config.Aimbot.Enabled end, function(v) Config.Aimbot.Enabled = v; fovFrame.Visible = v end)
sliderWidget(combatTab, "FOV", 20, 600, function() return Config.Aimbot.FOV end, function(v)
    Config.Aimbot.FOV = v
    fovFrame.Size = UDim2.fromOffset(v*2, v*2)
end, true)
sliderWidget(combatTab, "Smoothness", 1, 30, function() return Config.Aimbot.Smoothness end, function(v) Config.Aimbot.Smoothness = v end, true)
toggleWidget(combatTab, "Team Check", function() return Config.Aimbot.TeamCheck end, function(v) Config.Aimbot.TeamCheck = v end)
keybindWidget(combatTab, "Aim Key", function() return Config.Aimbot.Key end, function(k) Config.Aimbot.Key = k end)

sectionTitle(combatTab, "SILENT AIM")
toggleWidget(combatTab, "Enable Silent Aim", function() return Config.SilentAim.Enabled end, function(v) Config.SilentAim.Enabled = v end)
toggleWidget(combatTab, "Team Check", function() return Config.SilentAim.TeamCheck end, function(v) Config.SilentAim.TeamCheck = v end)

-- Visuals
local visTab = tabs[2].Page
toggleWidget(visTab, "ESP (Highlight)", function() return Config.ESP.Enabled end, function(v) Config.ESP.Enabled = v end)
toggleWidget(visTab, "Team Check", function() return Config.ESP.TeamCheck end, function(v) Config.ESP.TeamCheck = v end)
toggleWidget(visTab, "Hide Dead", function() return Config.ESP.HideDead end, function(v) Config.ESP.HideDead = v end)
sliderWidget(visTab, "Max Render Dist", 100, 5000, function() return Config.ESP.MaxRenderDist end, function(v) Config.ESP.MaxRenderDist = v end, true)

-- Movement
local movTab = tabs[3].Page
toggleWidget(movTab, "Fly", function() return Config.Fly.Enabled end, function(v) setFly(v) end)
sliderWidget(movTab, "Fly Speed", 5, 300, function() return Config.Fly.Speed end, function(v) Config.Fly.Speed = v end, true)
keybindWidget(movTab, "Fly Key", function() return Config.Fly.Key end, function(k) Config.Fly.Key = k end)

-- Player
local plTab = tabs[4].Page
toggleWidget(plTab, "God Mode", function() return Config.Player.GodMode end, function(v) Config.Player.GodMode = v end)
toggleWidget(plTab, "Infinite Ammo", function() return Config.Player.InfAmmo end, function(v) Config.Player.InfAmmo = v end)

-- Settings
local setTab = tabs[5].Page
sliderWidget(setTab, "UI Scale", 0.5, 1.5, function() return Config.Settings.Scale end, function(v)
    Config.Settings.Scale = v
    main.UIScale.Scale = v
end)

--// ============================ MAIN RENDER LOOP
RunService.RenderStepped:Connect(function(dt)
    -- FOV circle position (frame)
    if Config.Aimbot.Enabled then
        fovFrame.Position = UDim2.fromScale(0.5, 0.5)
        fovStroke.Color = Config.Aimbot.Color
    end

    -- Aimbot
    if Config.Aimbot.Enabled and aimHeld then
        local t = getTargetFor(Config.Aimbot)
        if t then
            local aimPos = t.part.Position
            local desired = CFrame.new(Camera.CFrame.Position, aimPos)
            local alpha = 1 / math.max(Config.Aimbot.Smoothness, 1)
            Camera.CFrame = Camera.CFrame:Lerp(desired, alpha)
        end
    end
end)

print("[Astrend] ASTREND HUB loaded — stable build")
