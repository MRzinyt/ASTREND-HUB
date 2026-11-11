-- ASTREND HUB.lua | Luau | Roblox executor (Drawing, hookmetamethod, file IO) | single file

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Tween      = game:GetService("TweenService")
local HTTP       = game:GetService("HttpService")
local Stats      = game:GetService("Stats")
local Workspace  = game:GetService("Workspace")
local LP         = Players.LocalPlayer
local Camera     = Workspace.CurrentCamera

local function guiParent()
    local ok, h = pcall(function() return gethui and gethui() end)
    if ok and h then return h end
    return game:GetService("CoreGui")
end

--// ============================ config
local CONFIG_FILE = "AstrendHubConfig.json"

local Config = {
    Aimbot = {
        Enabled=false, FOV=120, Smoothness=8, Target="Head",
        TeamCheck=true, WallCheck=false, DistanceCheck=true, MaxDist=500,
        Prediction=0.15, Key=Enum.KeyCode.E,
        Color=Color3.fromRGB(155,89,255), Transparency=0.5,
    },
    SilentAim = {
        Enabled=false, FOV=150, Target="Head", HitChance=100,
        TeamCheck=true, WallCheck=false, DistanceCheck=true, MaxDist=500,
        Prediction=0.15, Color=Color3.fromRGB(89,155,255), Transparency=0.5,
        Key=Enum.KeyCode.Q,
    },
    ESP = {
        Box=true, BoxColor=Color3.fromRGB(155,89,255), BoxThickness=1,
        Skeleton=true, SkeletonColor=Color3.fromRGB(255,255,255), SkeletonThickness=1,
        Name=true, NameColor=Color3.fromRGB(255,255,255),
        Weapon=true, WeaponColor=Color3.fromRGB(200,200,200),
        Distance=true, DistanceColor=Color3.fromRGB(200,200,200), StudsPerMeter=1,
        Line=false, LineColor=Color3.fromRGB(155,89,255), LineOrigin="Top", LineThickness=1,
        HealthBar=true, HealthText=true,
        TeamCheck=true, MaxRenderDist=2000, HideDead=true,
    },
    Fly    = { Enabled=false, Speed=50, Key=Enum.KeyCode.F },
    Player = { GodMode=false, InfAmmo=false },
    Settings = { Animations=true, Scale=1, ShowFPS=true, ShowPing=true },
}

local function encodeCfg()
    local out = {}
    for sec, vals in pairs(Config) do
        out[sec] = {}
        for k, v in pairs(vals) do
            local tv = typeof(v)
            if tv == "Color3" then
                out[sec][k] = {__t="Color3", r=v.R, g=v.G, b=v.B}
            elseif tv == "EnumItem" then
                out[sec][k] = {__t="Enum", name=v.Name}
            else
                out[sec][k] = v
            end
        end
    end
    return out
end

local function decodeCfg(t)
    for sec, vals in pairs(t) do
        if Config[sec] then
            for k, v in pairs(vals) do
                if type(v)=="table" and v.__t=="Color3" then
                    Config[sec][k] = Color3.new(v.r, v.g, v.b)
                elseif type(v)=="table" and v.__t=="Enum" then
                    Config[sec][k] = Enum.KeyCode[v.name] or Config[sec][k]
                elseif Config[sec][k] ~= nil then
                    Config[sec][k] = v
                end
            end
        end
    end
end

pcall(function()
    if isfile and isfile(CONFIG_FILE) then
        local ok, d = pcall(function() return HTTP:JSONDecode(readfile(CONFIG_FILE)) end)
        if ok and type(d)=="table" then decodeCfg(d) end
    end
end)

local function saveConfig()
    pcall(function()
        if writefile then writefile(CONFIG_FILE, HTTP:JSONEncode(encodeCfg())) end
    end)
end

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

--// ============================ UI toolkit
local g = new("ScreenGui", {Name="AstrendHub", ResetOnSpawn=false, IgnoreGuiInset=true, ZIndexBehavior=Enum.ZIndexBehavior.Sibling}, guiParent())

local main = new("Frame", {
    Name="Main", Size=UDim2.fromOffset(560, 420),
    Position=UDim2.new(0.5, -280, 0.5, -210),
    BackgroundColor3=Color3.fromRGB(18, 18, 24),
    BorderSizePixel=0, Active=true,
}, g)
corner(main, 10)
new("UIStroke", {Color=Color3.fromRGB(60,50,90), Thickness=1, Transparency=0.4}, main)

local scaleUi = new("UIScale", {Scale=Config.Settings.Scale}, main)

local titleBar = new("Frame", {
    Size=UDim2.new(1,0,0,32), BackgroundColor3=Color3.fromRGB(24,20,36),
    BorderSizePixel=0, Active=true,
}, main)
corner(titleBar, 10)
new("TextLabel", {
    Text="ASTREND HUB", Size=UDim2.new(1,-60,1,0), Position=UDim2.fromOffset(14,0),
    BackgroundTransparency=1, TextColor3=Color3.fromRGB(180,150,255),
    Font=Enum.Font.GothamBold, TextSize=14, TextXAlignment=Enum.TextXAlignment.Left,
}, titleBar)
local minBtn = new("TextButton", {
    Text="—", Size=UDim2.fromOffset(24,24), Position=UDim2.new(1,-56,0,4),
    BackgroundColor3=Color3.fromRGB(40,32,60), TextColor3=Color3.fromRGB(220,200,255),
    Font=Enum.Font.GothamBold, TextSize=14, AutoButtonColor=true,
}, titleBar)
corner(minBtn, 5)
local closeBtn = new("TextButton", {
    Text="×", Size=UDim2.fromOffset(24,24), Position=UDim2.new(1,-28,0,4),
    BackgroundColor3=Color3.fromRGB(60,24,32), TextColor3=Color3.fromRGB(255,180,190),
    Font=Enum.Font.GothamBold, TextSize=16, AutoButtonColor=true,
}, titleBar)
corner(closeBtn, 5)

local body = new("Frame", {
    Size=UDim2.new(1,0,1,-32), Position=UDim2.fromOffset(0,32),
    BackgroundTransparency=1,
}, main)

local sidebar = new("Frame", {
    Size=UDim2.new(0,140,1,0), BackgroundColor3=Color3.fromRGB(22,18,32),
    BorderSizePixel=0,
}, body)
corner(sidebar, 10)

local contentArea = new("Frame", {
    Size=UDim2.new(1,-150,1,-10), Position=UDim2.fromOffset(145,5),
    BackgroundTransparency=1,
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

-- minimize
local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    local target = minimized and UDim2.fromOffset(560, 32) or UDim2.fromOffset(560, 420)
    if Config.Settings.Animations then
        Tween:Create(main, TweenInfo.new(0.18), {Size=target}):Play()
    else
        main.Size = target
    end
    body.Visible = not minimized
end)
closeBtn.MouseButton1Click:Connect(function() g:Destroy() end)

-- tabs
local tabs = {}
local tabButtons = {}
local tabNames = {"Combat","Visuals","Movement","Player","Explorer","Settings"}

local function makeTab(name)
    local btn = new("TextButton", {
        Text=name, Size=UDim2.new(1,-16,0,28), Position=UDim2.fromOffset(8, 8 + #tabButtons*34),
        BackgroundColor3=Color3.fromRGB(32,26,48), TextColor3=Color3.fromRGB(200,180,255),
        Font=Enum.Font.Gotham, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left,
        AutoButtonColor=false,
    }, sidebar)
    corner(btn, 6)
    new("UIPadding", {PaddingLeft=UDim.new(0,10)}, btn)

    local page = new("ScrollingFrame", {
        Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
        ScrollBarThickness=3, ScrollBarImageColor3=Color3.fromRGB(120,90,200),
        CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y,
        Visible=false, BorderSizePixel=0,
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

-- widget builders
local function sectionTitle(page, text, order)
    new("TextLabel", {
        Text=text, Size=UDim2.new(1,-20,0,22), Position=UDim2.fromOffset(10, order),
        BackgroundTransparency=1, TextColor3=Color3.fromRGB(150,120,230),
        Font=Enum.Font.GothamBold, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left,
    }, page)
end

local yCursor = {}
local function allocY(page, h)
    yCursor[page] = (yCursor[page] or 0) + (h or 30) + 6
    return yCursor[page]
end

local function toggleWidget(page, label, get, set)
    local y = allocY(page, 26)
    local frame = new("TextButton", {
        Text="", Size=UDim2.new(1,-20,0,26), Position=UDim2.fromOffset(10, y),
        BackgroundColor3=Color3.fromRGB(28,24,40), AutoButtonColor=false,
    }, page)
    corner(frame, 6)
    new("TextLabel", {
        Text=label, Size=UDim2.new(1,-44,1,0), Position=UDim2.fromOffset(10,0),
        BackgroundTransparency=1, TextColor3=Color3.fromRGB(225,215,255),
        Font=Enum.Font.Gotham, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left,
    }, frame)
    local pill = new("Frame", {
        Size=UDim2.fromOffset(34,18), Position=UDim2.new(1,-42,0.5,-9),
        BackgroundColor3=get() and Color3.fromRGB(140,100,255) or Color3.fromRGB(60,55,80),
    }, frame)
    corner(pill, 9)
    local knob = new("Frame", {
        Size=UDim2.fromOffset(14,14), Position=get() and UDim2.fromOffset(18,2) or UDim2.fromOffset(2,2),
        BackgroundColor3=Color3.fromRGB(255,255,255),
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
        Size=UDim2.new(1,-20,0,42), Position=UDim2.fromOffset(10, y),
        BackgroundColor3=Color3.fromRGB(28,24,40),
    }, page)
    corner(f, 6)
    new("TextLabel", {
        Text=label, Size=UDim2.new(1,-70,0,20), Position=UDim2.fromOffset(10,2),
        BackgroundTransparency=1, TextColor3=Color3.fromRGB(225,215,255),
        Font=Enum.Font.Gotham, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left,
    }, f)
    local valLbl = new("TextLabel", {
        Text=tostring(get()), Size=UDim2.fromOffset(60,20), Position=UDim2.new(1,-70,0,2),
        BackgroundTransparency=1, TextColor3=Color3.fromRGB(180,150,255),
        Font=Enum.Font.GothamBold, TextSize=12, TextXAlignment=Enum.TextXAlignment.Right,
    }, f)
    local track = new("Frame", {
        Size=UDim2.new(1,-20,0,5), Position=UDim2.fromOffset(10,26),
        BackgroundColor3=Color3.fromRGB(50,44,68),
    }, f)
    corner(track, 3)
    local fill = new("Frame", {
        Size=UDim2.new((get()-min)/(max-min),0,1,0), BackgroundColor3=Color3.fromRGB(140,100,255),
    }, track)
    corner(fill, 3)
    local knob = new("Frame", {
        Size=UDim2.fromOffset(12,12),
        Position=UDim2.new(fill.Size.X.Scale, -6, 0.5, -6),
        BackgroundColor3=Color3.fromRGB(255,255,255),
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

local function colorWidget(page, label, get, set)
    local y = allocY(page, 26)
    local btn = new("TextButton", {
        Text=label, Size=UDim2.new(1,-20,0,26), Position=UDim2.fromOffset(10, y),
        BackgroundColor3=get(), TextColor3=Color3.fromRGB(255,255,255),
        Font=Enum.Font.Gotham, TextSize=12, AutoButtonColor=false,
    }, page)
    corner(btn, 6)
    btn.MouseButton1Click:Connect(function()
        local pop = new("Frame", {
            Size=UDim2.fromOffset(180, 130), Position=UDim2.new(0,0,0,0),
            BackgroundColor3=Color3.fromRGB(24,20,34),
        }, btn)
        corner(pop, 6)
        local c = get()
        local r, gv, b = c.R, c.G, c.B
        local function makeBar(offY, cur, apply)
            local tr = new("Frame", {Size=UDim2.new(1,-20,0,5), Position=UDim2.fromOffset(10, offY),
                BackgroundColor3=Color3.fromRGB(50,44,68)}, pop)
            corner(tr, 3)
            local fl = new("Frame", {Size=UDim2.new(cur,0,1,0), BackgroundColor3=Color3.fromRGB(255,255,255)}, tr)
            corner(fl, 3)
            local drag
            tr.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true end end)
            UIS.InputChanged:Connect(function(i)
                if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
                    local rel = math.clamp((i.Position.X - tr.AbsolutePosition.X)/tr.AbsoluteSize.X, 0, 1)
                    fl.Size = UDim2.new(rel,0,1,0); apply(rel)
                    btn.BackgroundColor3 = Color3.new(r, gv, b); set(Color3.new(r, gv, b))
                end
            end)
            UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
        end
        makeBar(20, r, function(v) r = v end)
        makeBar(50, gv, function(v) gv = v end)
        makeBar(80, b, function(v) b = v end)
        local close = new("TextButton", {Text="X", Size=UDim2.fromOffset(20,20), Position=UDim2.new(1,-24,0,2),
            BackgroundColor3=Color3.fromRGB(60,24,32), TextColor3=Color3.fromRGB(255,180,190),
            Font=Enum.Font.GothamBold, TextSize=12}, pop)
        corner(close, 4)
        close.MouseButton1Click:Connect(function() pop:Destroy() end)
    end)
end

local function keybindWidget(page, label, get, set)
    local y = allocY(page, 26)
    local btn = new("TextButton", {
        Text="", Size=UDim2.new(1,-20,0,26), Position=UDim2.fromOffset(10, y),
        BackgroundColor3=Color3.fromRGB(28,24,40), AutoButtonColor=false,
    }, page)
    corner(btn, 6)
    new("TextLabel", {
        Text=label, Size=UDim2.new(1,-100,1,0), Position=UDim2.fromOffset(10,0),
        BackgroundTransparency=1, TextColor3=Color3.fromRGB(225,215,255),
        Font=Enum.Font.Gotham, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left,
    }, btn)
    local val = new("TextLabel", {
        Text=tostring(get()):gsub("Enum.KeyCode.",""), Size=UDim2.fromOffset(80,20),
        Position=UDim2.new(1,-90,0.5,-10), BackgroundColor3=Color3.fromRGB(60,44,96),
        TextColor3=Color3.fromRGB(220,200,255), Font=Enum.Font.GothamBold, TextSize=11,
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

-- // ============================ TARGETING
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
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not (hum and hrp) or hum.Health <= 0 then continue end
        if cfg.TeamCheck and p.Team and LP.Team and p.Team == LP.Team then continue end
        local part = char:FindFirstChild(cfg.Target)
        if not part then continue end
        local dist = (camPos - part.Position).Magnitude
        if cfg.DistanceCheck and dist > cfg.MaxDist then continue end
        local sp, on = Camera:WorldToViewportPoint(part.Position)
        if not on then continue end
        local d2 = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d2 > cfg.FOV then continue end
        if cfg.WallCheck then
            local ray = Ray.new(camPos, (part.Position - camPos).Unit * dist)
            local hit = Workspace:FindPartOnRayWithIgnoreList(ray, {LP.Character, char, Camera})
            if hit and hit:IsDescendantOf(char) == false then continue end
        end
        if d2 < bestDist then best, bestDist = {player=p, part=part}, d2 end
    end
    return best
end

--// ============================ AIMBOT
local aimHeld = false
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Config.Aimbot.Key then aimHeld = true end
end)
UIS.InputEnded:Connect(function(input)
    if input.KeyCode == Config.Aimbot.Key then aimHeld = false end
end)

local aimCircle = Drawing.new("Circle")
aimCircle.Thickness = 1
aimCircle.NumSides = 64
aimCircle.Filled = false
aimCircle.Visible = false

local silentCircle = Drawing.new("Circle")
silentCircle.Thickness = 1
silentCircle.NumSides = 64
silentCircle.Filled = false
silentCircle.Visible = false

--// ============================ SILENT AIM hook
local oldNamecall
local okHook, errHook = pcall(function()
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if not oldNamecall then return end
        local method = getnamecallmethod()
        if Config.SilentAim.Enabled and (method == "FireServer" or method == "InvokeServer")
            and math.random(1,100) <= Config.SilentAim.HitChance then
            local t = getTargetFor(Config.SilentAim)
            if t then
                local args = {...}
                local changed = false
                for i = 1, #args do
                    local v = args[i]
                    if typeof(v) == "Instance" and v:IsA("BasePart") then
                        args[i] = t.part; changed = true
                    elseif typeof(v) == "CFrame" then
                        local pos = t.part.Position + (t.part.AssemblyLinearVelocity * Config.SilentAim.Prediction)
                        args[i] = CFrame.new(pos); changed = true
                    elseif typeof(v) == "Vector3" then
                        args[i] = t.part.Position + (t.part.AssemblyLinearVelocity * Config.SilentAim.Prediction); changed = true
                    end
                end
                if changed then return oldNamecall(self, table.unpack(args)) end
            end
        end
        return oldNamecall(self, ...)
    end)
end)
if not okHook then warn("[Astrend] silent aim hook failed:", errHook) end

--// ============================ ESP
local espCache = {}

local function getEsp(p)
    if espCache[p] then return espCache[p] end
    local d = {
        box = Drawing.new("Square"),
        name = Drawing.new("Text"),
        dist = Drawing.new("Text"),
        weapon = Drawing.new("Text"),
        healthBg = Drawing.new("Square"),
        healthFg = Drawing.new("Square"),
        line = Drawing.new("Line"),
        skeleton = {},
    }
    d.box.Filled = false
    d.name.Center = true; d.name.Outline = true; d.name.Size = 14; d.name.Font = 2
    d.dist.Center = true; d.dist.Outline = true; d.dist.Size = 12; d.dist.Font = 2
    d.weapon.Center = true; d.weapon.Outline = true; d.weapon.Size = 12; d.weapon.Font = 2
    d.healthBg.Filled = true
    d.healthFg.Filled = true
    for i=1,20 do
        local l = Drawing.new("Line"); l.Thickness = 1; table.insert(d.skeleton, l)
    end
    espCache[p] = d
    return d
end

local function hideEsp(d)
    d.box.Visible = false
    d.name.Visible = false
    d.dist.Visible = false
    d.weapon.Visible = false
    d.healthBg.Visible = false
    d.healthFg.Visible = false
    d.line.Visible = false
    for _, l in ipairs(d.skeleton) do l.Visible = false end
end

local function clearEsp(p)
    local d = espCache[p]
    if not d then return end
    hideEsp(d)
    d.box:Remove(); d.name:Remove(); d.dist:Remove(); d.weapon:Remove()
    d.healthBg:Remove(); d.healthFg:Remove(); d.line:Remove()
    for _, l in ipairs(d.skeleton) do l:Remove() end
    espCache[p] = nil
end

Players.PlayerRemoving:Connect(clearEsp)

local function getBones(char)
    local b = {}
    local head = char:FindFirstChild("Head")
    local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    if not (head and torso) then return b end
    table.insert(b, {head, torso})
    if char:FindFirstChild("Left Arm") then -- R6
        local parts = {"Left Arm","Right Arm","Left Leg","Right Leg"}
        for _, n in ipairs(parts) do
            local pt = char:FindFirstChild(n)
            if pt then table.insert(b, {torso, pt}) end
        end
    else -- R15
        local pairs_ = {
            {"UpperTorso","LowerTorso"},
            {"UpperTorso","LeftUpperArm"}, {"LeftUpperArm","LeftLowerArm"}, {"LeftLowerArm","LeftHand"},
            {"UpperTorso","RightUpperArm"}, {"RightUpperArm","RightLowerArm"}, {"RightLowerArm","RightHand"},
            {"LowerTorso","LeftUpperLeg"}, {"LeftUpperLeg","LeftLowerLeg"}, {"LeftLowerLeg","LeftFoot"},
            {"LowerTorso","RightUpperLeg"}, {"RightUpperLeg","RightLowerLeg"}, {"RightLowerLeg","RightFoot"},
        }
        for _, pr in ipairs(pairs_) do
            local a, c = char:FindFirstChild(pr[1]), char:FindFirstChild(pr[2])
            if a and c then table.insert(b, {a, c}) end
        end
    end
    return b
end

local function updateEsp()
    local vp = Camera.ViewportSize
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LP then continue end
        local char = p.Character
        if not char then
            if espCache[p] then hideEsp(espCache[p]) end
            continue
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        if not (hum and hrp and head) then
            if espCache[p] then hideEsp(espCache[p]) end
            continue
        end
        if (Config.ESP.HideDead and hum.Health <= 0)
            or (Config.ESP.TeamCheck and p.Team and LP.Team and p.Team == LP.Team) then
            if espCache[p] then hideEsp(espCache[p]) end
            continue
        end
        local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
        if dist > Config.ESP.MaxRenderDist then
            if espCache[p] then hideEsp(espCache[p]) end
            continue
        end
        local d = getEsp(p)

        local headTop = head.Position + Vector3.new(0, head.Size.Y/2 + 0.4, 0)
        local footBot = hrp.Position - Vector3.new(0, 3.2, 0)
        local topS, topOn = Camera:WorldToViewportPoint(headTop)
        local botS, botOn = Camera:WorldToViewportPoint(footBot)
        if not (topOn and botOn) then hideEsp(d); continue end
        local x1, y1 = topS.X, topS.Y
        local x2, y2 = botS.X, botS.Y
        local h = y2 - y1
        local w = h * 0.55
        local bx = x1 - w/2
        local by = y1

        if Config.ESP.Box then
            d.box.Size = Vector2.new(w, h)
            d.box.Position = Vector2.new(bx, by)
            d.box.Color = Config.ESP.BoxColor
            d.box.Thickness = Config.ESP.BoxThickness
            d.box.Visible = true
        else
            d.box.Visible = false
        end

        if Config.ESP.Name then
            d.name.Text = p.Name
            d.name.Position = Vector2.new(x1, by - 16)
            d.name.Color = Config.ESP.NameColor
            d.name.Visible = true
        else
            d.name.Visible = false
        end

        if Config.ESP.Distance then
            local m = dist / Config.ESP.StudsPerMeter
            d.dist.Text = string.format("%.0fm", m)
            d.dist.Position = Vector2.new(x1, by + h + 2)
            d.dist.Color = Config.ESP.DistanceColor
            d.dist.Visible = true
        else
            d.dist.Visible = false
        end

        if Config.ESP.Weapon then
            local tool = char:FindFirstChildOfClass("Tool")
            d.weapon.Text = tool and tool.Name or "Empty"
            d.weapon.Position = Vector2.new(x1, by + h + 16)
            d.weapon.Color = Config.ESP.WeaponColor
            d.weapon.Visible = true
        else
            d.weapon.Visible = false
        end

        if Config.ESP.HealthBar then
            local pct = math.clamp(hum.Health / math.max(hum.MaxHealth,1), 0, 1)
            d.healthBg.Size = Vector2.new(3, h)
            d.healthBg.Position = Vector2.new(bx - 6, by)
            d.healthBg.Color = Color3.fromRGB(30,30,30)
            d.healthBg.Visible = true
            d.healthFg.Size = Vector2.new(3, h * pct)
            d.healthFg.Position = Vector2.new(bx - 6, by + h * (1 - pct))
            d.healthFg.Color = Color3.fromRGB(0,200,80):Lerp(Color3.fromRGB(255,40,40), 1 - pct)
            d.healthFg.Visible = true
        else
            d.healthBg.Visible = false
            d.healthFg.Visible = false
        end

        if Config.ESP.Line then
            local origin
            if Config.ESP.LineOrigin == "Top" then origin = Vector2.new(vp.X/2, 0)
            elseif Config.ESP.LineOrigin == "Center" then origin = Vector2.new(vp.X/2, vp.Y/2)
            else origin = Vector2.new(vp.X/2, vp.Y) end
            d.line.From = origin
            d.line.To = Vector2.new(x1, by + h/2)
            d.line.Color = Config.ESP.LineColor
            d.line.Thickness = Config.ESP.LineThickness
            d.line.Visible = true
        else
            d.line.Visible = false
        end

        if Config.ESP.Skeleton then
            local bones = getBones(char)
            for i, l in ipairs(d.skeleton) do
                local bone = bones[i]
                if bone then
                    local a, aOn = Camera:WorldToViewportPoint(bone[1].Position)
                    local b, bOn = Camera:WorldToViewportPoint(bone[2].Position)
                    if aOn and bOn then
                        l.From = Vector2.new(a.X, a.Y)
                        l.To = Vector2.new(b.X, b.Y)
                        l.Color = Config.ESP.SkeletonColor
                        l.Thickness = Config.ESP.SkeletonThickness
                        l.Visible = true
                    else
                        l.Visible = false
                    end
                else
                    l.Visible = false
                end
            end
        else
            for _, l in ipairs(d.skeleton) do l.Visible = false end
        end
    end
end

--// ============================ FLY (LinearVelocity / no BodyMover)
local flyLV, flyAttachment, flyConn

local function setFly(on)
    Config.Fly.Enabled = on

    if on then
        local char = LP.Character
        if not char then return end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end

        hum:ChangeState(Enum.HumanoidStateType.Physics)

        flyAttachment = Instance.new("Attachment")
        flyAttachment.Parent = hrp

        flyLV = Instance.new("LinearVelocity")
        flyLV.Attachment0 = flyAttachment
        flyLV.MaxForce = Vector3.new(100000, 100000, 100000)
        flyLV.VectorVelocity = Vector3.zero
        flyLV.RelativeTo = Enum.ActuatorRelativeTo.World
        flyLV.Parent = hrp

        if flyConn then flyConn:Disconnect() end
        flyConn = RunService.RenderStepped:Connect(function()
            if not Config.Fly.Enabled then return end

            local c = LP.Character
            if not c then return end
            local h = c:FindFirstChild("HumanoidRootPart")
            if not h or not flyLV then return end

            local dir = Vector3.zero
            local camCF = Camera.CFrame

            if UIS:IsKeyDown(Enum.KeyCode.W) then dir += camCF.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= camCF.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= camCF.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then dir += camCF.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0,1,0) end

            flyLV.VectorVelocity = dir * Config.Fly.Speed
        end)
    else
        if flyConn then flyConn:Disconnect(); flyConn = nil end
        if flyLV then flyLV:Destroy(); flyLV = nil end
        if flyAttachment then flyAttachment:Destroy(); flyAttachment = nil end

        local char = LP.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum:ChangeState(Enum.HumanoidStateType.Running) end
        end
    end
end

UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Config.Fly.Key then setFly(not Config.Fly.Enabled) end
end)

--// ============================ PLAYER FEATURES
RunService.Heartbeat:Connect(function()
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
end)

--// ============================ BUILD TABS
local combatTab = tabs[1].Page
sectionTitle(combatTab, "AIMBOT", 0); yCursor[combatTab] = 30
toggleWidget(combatTab, "Enable Aimbot", function() return Config.Aimbot.Enabled end, function(v) Config.Aimbot.Enabled = v end)
sliderWidget(combatTab, "FOV", 20, 600, function() return Config.Aimbot.FOV end, function(v) Config.Aimbot.FOV = v end, true)
sliderWidget(combatTab, "Smoothness (1-30)", 1, 30, function() return Config.Aimbot.Smoothness end, function(v) Config.Aimbot.Smoothness = v end, true)
sliderWidget(combatTab, "Prediction", 0, 1, function() return Config.Aimbot.Prediction end, function(v) Config.Aimbot.Prediction = v end)
sliderWidget(combatTab, "Max Distance", 50, 2000, function() return Config.Aimbot.MaxDist end, function(v) Config.Aimbot.MaxDist = v end, true)
toggleWidget(combatTab, "Team Check", function() return Config.Aimbot.TeamCheck end, function(v) Config.Aimbot.TeamCheck = v end)
toggleWidget(combatTab, "Wall Check", function() return Config.Aimbot.WallCheck end, function(v) Config.Aimbot.WallCheck = v end)
toggleWidget(combatTab, "Distance Check", function() return Config.Aimbot.DistanceCheck end, function(v) Config.Aimbot.DistanceCheck = v end)
colorWidget(combatTab, "FOV Color", function() return Config.Aimbot.Color end, function(c) Config.Aimbot.Color = c end)
keybindWidget(combatTab, "Aim Key", function() return Config.Aimbot.Key end, function(k) Config.Aimbot.Key = k end)

sectionTitle(combatTab, "SILENT AIM", (yCursor[combatTab] or 0) + 10); yCursor[combatTab] = (yCursor[combatTab] or 0) + 40
toggleWidget(combatTab, "Enable Silent Aim", function() return Config.SilentAim.Enabled end, function(v) Config.SilentAim.Enabled = v end)
sliderWidget(combatTab, "Silent FOV", 20, 600, function() return Config.SilentAim.FOV end, function(v) Config.SilentAim.FOV = v end, true)
sliderWidget(combatTab, "Hit Chance %", 1, 100, function() return Config.SilentAim.HitChance end, function(v) Config.SilentAim.HitChance = v end, true)
sliderWidget(combatTab, "Prediction", 0, 1, function() return Config.SilentAim.Prediction end, function(v) Config.SilentAim.Prediction = v end)
toggleWidget(combatTab, "Team Check", function() return Config.SilentAim.TeamCheck end, function(v) Config.SilentAim.TeamCheck = v end)
toggleWidget(combatTab, "Wall Check", function() return Config.SilentAim.WallCheck end, function(v) Config.SilentAim.WallCheck = v end)
toggleWidget(combatTab, "Distance Check", function() return Config.SilentAim.DistanceCheck end, function(v) Config.SilentAim.DistanceCheck = v end)
colorWidget(combatTab, "Silent FOV Color", function() return Config.SilentAim.Color end, function(c) Config.SilentAim.Color = c end)
keybindWidget(combatTab, "Silent Key", function() return Config.SilentAim.Key end, function(k) Config.SilentAim.Key = k end)

-- Visuals
local visTab = tabs[2].Page
toggleWidget(visTab, "Box ESP", function() return Config.ESP.Box end, function(v) Config.ESP.Box = v end)
colorWidget(visTab, "Box Color", function() return Config.ESP.BoxColor end, function(c) Config.ESP.BoxColor = c end)
sliderWidget(visTab, "Box Thickness", 1, 5, function() return Config.ESP.BoxThickness end, function(v) Config.ESP.BoxThickness = v end, true)
toggleWidget(visTab, "Skeleton ESP", function() return Config.ESP.Skeleton end, function(v) Config.ESP.Skeleton = v end)
colorWidget(visTab, "Skeleton Color", function() return Config.ESP.SkeletonColor end, function(c) Config.ESP.SkeletonColor = c end)
sliderWidget(visTab, "Skeleton Thickness", 1, 4, function() return Config.ESP.SkeletonThickness end, function(v) Config.ESP.SkeletonThickness = v end, true)
toggleWidget(visTab, "Name ESP", function() return Config.ESP.Name end, function(v) Config.ESP.Name = v end)
toggleWidget(visTab, "Weapon ESP", function() return Config.ESP.Weapon end, function(v) Config.ESP.Weapon = v end)
toggleWidget(visTab, "Distance ESP", function() return Config.ESP.Distance end, function(v) Config.ESP.Distance = v end)
sliderWidget(visTab, "Studs / Meter", 0.1, 5, function() return Config.ESP.StudsPerMeter end, function(v) Config.ESP.StudsPerMeter = v end)
toggleWidget(visTab, "Health Bar", function() return Config.ESP.HealthBar end, function(v) Config.ESP.HealthBar = v end)
toggleWidget(visTab, "Team Check", function() return Config.ESP.TeamCheck end, function(v) Config.ESP.TeamCheck = v end)
toggleWidget(visTab, "Hide Dead", function() return Config.ESP.HideDead end, function(v) Config.ESP.HideDead = v end)
sliderWidget(visTab, "Max Render Dist", 100, 5000, function() return Config.ESP.MaxRenderDist end, function(v) Config.ESP.MaxRenderDist = v end, true)
toggleWidget(visTab, "Line ESP", function() return Config.ESP.Line end, function(v) Config.ESP.Line = v end)
colorWidget(visTab, "Line Color", function() return Config.ESP.LineColor end, function(c) Config.ESP.LineColor = c end)

-- Movement
local movTab = tabs[3].Page
toggleWidget(movTab, "Fly", function() return Config.Fly.Enabled end, function(v) setFly(v) end)
sliderWidget(movTab, "Fly Speed", 5, 300, function() return Config.Fly.Speed end, function(v) Config.Fly.Speed = v end, true)
keybindWidget(movTab, "Fly Key", function() return Config.Fly.Key end, function(k) Config.Fly.Key = k end)

-- Player
local plTab = tabs[4].Page
toggleWidget(plTab, "God Mode", function() return Config.Player.GodMode end, function(v) Config.Player.GodMode = v end)
toggleWidget(plTab, "Infinite Ammo", function() return Config.Player.InfAmmo end, function(v) Config.Player.InfAmmo = v end)

-- Explorer
local explTab = tabs[5].Page
local searchBox = new("TextBox", {
    Size=UDim2.new(1,-20,0,26), Position=UDim2.fromOffset(10, 6),
    BackgroundColor3=Color3.fromRGB(28,24,40), Text="",
    PlaceholderText="Search by name or class...",
    TextColor3=Color3.fromRGB(220,200,255), PlaceholderColor3=Color3.fromRGB(120,110,140),
    Font=Enum.Font.Gotham, TextSize=12, ClearTextOnFocus=false,
}, explTab)
corner(searchBox, 6)
local explorerList = new("ScrollingFrame", {
    Size=UDim2.new(1,-20,1,-46), Position=UDim2.fromOffset(10, 40),
    BackgroundColor3=Color3.fromRGB(22,18,32), ScrollBarThickness=3,
    CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y,
    BorderSizePixel=0,
}, explTab)
corner(explorerList, 6)
new("UIPadding", {PaddingTop=UDim.new(0,4), PaddingLeft=UDim.new(0,4)}, explorerList)

local selectedService = "Workspace"

local function rebuildExplorer()
    for _, c in ipairs(explorerList:GetChildren()) do
        if c:IsA("TextButton") or c:IsA("Frame") then c:Destroy() end
    end
    local svc = game:FindFirstChild(selectedService) or Workspace
    local y = 4
    local filter = searchBox.Text:lower()
    for _, child in ipairs(svc:GetChildren()) do
        local nameMatch = filter == "" or child.Name:lower():find(filter, 1, true)
        local classMatch = filter == "" or child.ClassName:lower():find(filter, 1, true)
        if nameMatch or classMatch then
            local row = new("TextButton", {
                Text = string.format("%s  [%s]", child.Name, child.ClassName),
                Size=UDim2.new(1,-8,0,22), Position=UDim2.fromOffset(4, y),
                BackgroundColor3=Color3.fromRGB(30,26,44), TextColor3=Color3.fromRGB(220,210,255),
                Font=Enum.Font.Code, TextSize=11, AutoButtonColor=true,
                TextXAlignment=Enum.TextXAlignment.Left,
            }, explorerList)
            corner(row, 3)
            new("UIPadding", {PaddingLeft=UDim.new(0,6)}, row)
            row.MouseButton1Click:Connect(function()
                row.BackgroundColor3 = Color3.fromRGB(60,44,96)
                local info = child.Name .. "\n" .. child.ClassName
                if child:IsA("BasePart") then
                    info = info .. string.format("\nPos: %.1f, %.1f, %.1f", child.Position.X, child.Position.Y, child.Position.Z)
                end
                print("[Astrend Explorer] " .. info)
            end)
            y = y + 26
        end
    end
    explorerList.CanvasSize = UDim2.new(0,0,0, y+8)
end

local svcSelector = new("TextButton", {
    Text="Service: Workspace", Size=UDim2.new(1,-20,0,24), Position=UDim2.fromOffset(10, 6),
    BackgroundColor3=Color3.fromRGB(40,32,60), TextColor3=Color3.fromRGB(220,200,255),
    Font=Enum.Font.GothamBold, TextSize=12, AutoButtonColor=true,
}, explTab)
corner(svcSelector, 6)
searchBox.Position = UDim2.fromOffset(10, 36)
explorerList.Position = UDim2.fromOffset(10, 70)
explorerList.Size = UDim2.new(1,-20,1,-80)

local servicesList = {"Workspace","Players","ReplicatedStorage","ReplicatedFirst","Lighting","StarterGui","StarterPack","SoundService"}
local svcIndex = 1
svcSelector.MouseButton1Click:Connect(function()
    svcIndex = svcIndex % #servicesList + 1
    selectedService = servicesList[svcIndex]
    svcSelector.Text = "Service: " .. selectedService
    rebuildExplorer()
end)
searchBox:GetPropertyChangedSignal("Text"):Connect(rebuildExplorer)
rebuildExplorer()

-- Settings
local setTab = tabs[6].Page
toggleWidget(setTab, "Animations", function() return Config.Settings.Animations end, function(v) Config.Settings.Animations = v end)
sliderWidget(setTab, "UI Scale", 0.5, 1.5, function() return Config.Settings.Scale end, function(v) Config.Settings.Scale = v; scaleUi.Scale = v end)
toggleWidget(setTab, "Show FPS", function() return Config.Settings.ShowFPS end, function(v) Config.Settings.ShowFPS = v end)
toggleWidget(setTab, "Show Ping", function() return Config.Settings.ShowPing end, function(v) Config.Settings.ShowPing = v end)

local saveBtn = new("TextButton", {
    Text="Save Config", Size=UDim2.new(1,-20,0,28), Position=UDim2.fromOffset(10, allocY(setTab, 26)),
    BackgroundColor3=Color3.fromRGB(60,44,96), TextColor3=Color3.fromRGB(230,210,255),
    Font=Enum.Font.GothamBold, TextSize=12,
}, setTab)
corner(saveBtn, 6)
saveBtn.MouseButton1Click:Connect(function()
    saveConfig()
    saveBtn.Text = "Saved!"
    task.wait(1)
    saveBtn.Text = "Save Config"
end)

local resetBtn = new("TextButton", {
    Text="Restore Defaults (re-execute)", Size=UDim2.new(1,-20,0,28), Position=UDim2.fromOffset(10, allocY(setTab, 26)),
    BackgroundColor3=Color3.fromRGB(60,24,32), TextColor3=Color3.fromRGB(255,190,200),
    Font=Enum.Font.GothamBold, TextSize=12,
}, setTab)
corner(resetBtn, 6)
resetBtn.MouseButton1Click:Connect(function()
    pcall(function() if delfile and isfile and isfile(CONFIG_FILE) then delfile(CONFIG_FILE) end end)
    for _, t in ipairs(espCache) do pcall(clearEsp, t) end
end)

-- FPS/Ping label
local info = new("TextLabel", {
    Text="", Size=UDim2.fromOffset(180,20), Position=UDim2.new(0, 12, 0, 4),
    BackgroundTransparency=1, TextColor3=Color3.fromRGB(180,150,255),
    Font=Enum.Font.Gotham, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left,
}, main)

-- FPS counter
local fpsFrames, fpsTime, fpsVal = 0, 0, 0
RunService.RenderStepped:Connect(function(dt)
    fpsFrames += 1; fpsTime += dt
    if fpsTime >= 1 then fpsVal = fpsFrames; fpsFrames = 0; fpsTime = 0 end
end)

--// ============================ MAIN LOOPS
RunService.RenderStepped:Connect(function()
    local vp = Camera.ViewportSize
    local center = Vector2.new(vp.X/2, vp.Y/2)
    aimCircle.Position = center
    aimCircle.Radius = Config.Aimbot.FOV
    aimCircle.Color = Config.Aimbot.Color
    aimCircle.Transparency = Config.Aimbot.Transparency
    aimCircle.Visible = Config.Aimbot.Enabled

    silentCircle.Position = center
    silentCircle.Radius = Config.SilentAim.FOV
    silentCircle.Color = Config.SilentAim.Color
    silentCircle.Transparency = Config.SilentAim.Transparency
    silentCircle.Visible = Config.SilentAim.Enabled

    if Config.Aimbot.Enabled and aimHeld then
        local t = getTargetFor(Config.Aimbot)
        if t then
            local aimPos = t.part.Position
            if Config.Aimbot.Prediction > 0 then
                aimPos += t.part.AssemblyLinearVelocity * Config.Aimbot.Prediction
            end
            local desired = CFrame.new(Camera.CFrame.Position, aimPos)
            local alpha = 1 / math.max(Config.Aimbot.Smoothness, 1)
            Camera.CFrame = Camera.CFrame:Lerp(desired, alpha)
        end
    end

    updateEsp()
end)

-- info refresh
task.spawn(function()
    while g.Parent do
        local parts = {}
        if Config.Settings.ShowFPS then table.insert(parts, "FPS " .. fpsVal) end
        if Config.Settings.ShowPing then
            local ok, p = pcall(function()
                return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
            end)
            if ok then table.insert(parts, "Ping " .. math.floor(p) .. "ms") end
        end
        info.Text = table.concat(parts, "   ")
        task.wait(0.5)
    end
end)

scaleUi.Scale = Config.Settings.Scale

print("[Astrend] ASTREND HUB loaded. aim: " .. tostring(Config.Aimbot.Key) .. " | fly: " .. tostring(Config.Fly.Key))