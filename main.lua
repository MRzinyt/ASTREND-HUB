-- ASTREND HUB.lua | Luau | Roblox executor | Sintonia RP Edition (Safe ESP)

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

-- ============================ CONFIG
local Config = {
    Aimbot = { Enabled = false, FOV = 120, Smoothness = 8, Key = Enum.KeyCode.E },
    ESP = { Enabled = false, MaxDist = 1000, BoxColor = Color3.fromRGB(155,89,255), NameColor = Color3.fromRGB(255,255,255) },
    Fly = { Enabled = false, Speed = 50, Key = Enum.KeyCode.F },
    Player = { GodMode = false, AutoHeal = false, InfAmmo = false },
    Level = { Enabled = false, Desired = 10 },
    Settings = { Scale = 1 },
}

-- ============================ HELPERS
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

-- ============================ UI BASE
local g = new("ScreenGui", { Name = "AstrendHub", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, guiParent())

local main = new("Frame", { Size = UDim2.fromOffset(500, 380), Position = UDim2.new(0.5, -250, 0.5, -190), BackgroundColor3 = Color3.fromRGB(18, 18, 24), BorderSizePixel = 0, Active = true }, g)
corner(main, 10)
new("UIStroke", {Color=Color3.fromRGB(60,50,90), Thickness=1, Transparency=0.4}, main)
new("UIScale", {Scale = Config.Settings.Scale}, main)

local titleBar = new("Frame", { Size = UDim2.new(1,0,0,32), BackgroundColor3 = Color3.fromRGB(24,20,36), BorderSizePixel = 0, Active = true }, main)
corner(titleBar, 10)
new("TextLabel", { Text = "ASTREND HUB | Sintonia", Size = UDim2.new(1,-60,1,0), Position = UDim2.fromOffset(14,0), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(180,150,255), Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left }, titleBar)

local minBtn = new("TextButton", { Text = "—", Size = UDim2.fromOffset(24,24), Position = UDim2.new(1,-56,0,4), BackgroundColor3 = Color3.fromRGB(40,32,60), TextColor3 = Color3.fromRGB(220,200,255), Font = Enum.Font.GothamBold, TextSize = 14, AutoButtonColor = true }, titleBar)
corner(minBtn, 5)
local closeBtn = new("TextButton", { Text = "×", Size = UDim2.fromOffset(24,24), Position = UDim2.new(1,-28,0,4), BackgroundColor3 = Color3.fromRGB(60,24,32), TextColor3 = Color3.fromRGB(255,180,190), Font = Enum.Font.GothamBold, TextSize = 16, AutoButtonColor = true }, titleBar)
corner(closeBtn, 5)

local body = new("Frame", { Size = UDim2.new(1,0,1,-32), Position = UDim2.fromOffset(0,32), BackgroundTransparency = 1 }, main)
local sidebar = new("Frame", { Size = UDim2.new(0,140,1,0), BackgroundColor3 = Color3.fromRGB(22,18,32), BorderSizePixel = 0 }, body)
corner(sidebar, 10)
local contentArea = new("Frame", { Size = UDim2.new(1,-150,1,-10), Position = UDim2.fromOffset(145,5), BackgroundTransparency = 1 }, body)

-- Drag
local dragging, start, startPos
titleBar.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; start = input.Position; startPos = main.Position end end)
UIS.InputChanged:Connect(function(input) if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then local d = input.Position - start; main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end end)
UIS.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)

minBtn.MouseButton1Click:Connect(function() body.Visible = not body.Visible; main.Size = body.Visible and UDim2.fromOffset(500, 380) or UDim2.fromOffset(500, 32) end)
closeBtn.MouseButton1Click:Connect(function() g:Destroy() end)

-- Tabs
local tabs = {}
local tabButtons = {}
local tabNames = {"Combat","Visuals","Movement","Player","Level","Settings"}

local function makeTab(name)
    local btn = new("TextButton", { Text = name, Size = UDim2.new(1,-16,0,28), Position = UDim2.fromOffset(8, 8 + #tabButtons*34), BackgroundColor3 = Color3.fromRGB(32,26,48), TextColor3 = Color3.fromRGB(200,180,255), Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false }, sidebar)
    corner(btn, 6)
    new("UIPadding", {PaddingLeft = UDim.new(0,10)}, btn)
    local page = new("ScrollingFrame", { Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, ScrollBarThickness = 3, CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, BorderSizePixel = 0 }, contentArea)
    table.insert(tabs, {Name=name, Btn=btn, Page=page})
    table.insert(tabButtons, btn)
    btn.MouseButton1Click:Connect(function()
        for _, t in ipairs(tabs) do t.Page.Visible = false; t.Btn.BackgroundColor3 = Color3.fromRGB(32,26,48) end
        page.Visible = true; btn.BackgroundColor3 = Color3.fromRGB(60,44,96)
    end)
    return page
end
for _, n in ipairs(tabNames) do makeTab(n) end
tabs[1].Page.Visible = true; tabs[1].Btn.BackgroundColor3 = Color3.fromRGB(60,44,96)

-- Widgets
local yCursor = {}
local function allocY(page, h) yCursor[page] = (yCursor[page] or 0) + (h or 30) + 6; return yCursor[page] end

local function toggleWidget(page, label, get, set)
    local y = allocY(page, 26)
    local frame = new("TextButton", { Text = "", Size = UDim2.new(1,-20,0,26), Position = UDim2.fromOffset(10, y), BackgroundColor3 = Color3.fromRGB(28,24,40), AutoButtonColor = false }, page)
    corner(frame, 6)
    new("TextLabel", { Text = label, Size = UDim2.new(1,-44,1,0), Position = UDim2.fromOffset(10,0), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(225,215,255), Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left }, frame)
    local pill = new("Frame", { Size = UDim2.fromOffset(34,18), Position = UDim2.new(1,-42,0.5,-9), BackgroundColor3 = get() and Color3.fromRGB(140,100,255) or Color3.fromRGB(60,55,80) }, frame)
    corner(pill, 9)
    local knob = new("Frame", { Size = UDim2.fromOffset(14,14), Position = get() and UDim2.fromOffset(18,2) or UDim2.fromOffset(2,2), BackgroundColor3 = Color3.fromRGB(255,255,255) }, pill)
    corner(knob, 7)
    frame.MouseButton1Click:Connect(function()
        local nv = not get(); set(nv)
        local tw = TweenInfo.new(0.15)
        Tween:Create(pill, tw, {BackgroundColor3 = nv and Color3.fromRGB(140,100,255) or Color3.fromRGB(60,55,80)}):Play()
        Tween:Create(knob, tw, {Position = nv and UDim2.fromOffset(18,2) or UDim2.fromOffset(2,2)}):Play()
    end)
end

-- ============================ ESP BYPASS (Safe UI)
local espCache = {}

local function getESP(player)
    if espCache[player] then return espCache[player] end
    local box = new("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false }, g)
    new("UIStroke", { Color = Config.ESP.BoxColor, Thickness = 1 }, box)
    local nameTag = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1,0,0,15), Position = UDim2.new(0,0,-16,0), TextColor3 = Config.ESP.NameColor, Font = Enum.Font.GothamBold, TextSize = 12, TextStrokeTransparency = 0, Visible = false }, box)
    nameTag.Text = player.Name
    local data = { box = box, nameTag = nameTag }
    espCache[player] = data
    return data
end

local function clearESP()
    for p, d in pairs(espCache) do
        d.box:Destroy()
        espCache[p] = nil
    end
end

-- ============================ PLAYER FEATURES (Auto-Heal e Level)
task.spawn(function()
    while g.Parent do
        if LP.Character then
            local hum = LP.Character:FindFirstChildOfClass("Humanoid")
            
            -- GodMode
            if Config.Player.GodMode and hum then
                hum.Health = hum.MaxHealth
            end
            
            -- Auto Heal (Vida, Fome, Sede)
            if Config.Player.AutoHeal then
                local containers = { LP, LP:FindFirstChild("leaderstats") }
                for _, c in ipairs(containers) do
                    if c then
                        for _, v in ipairs(c:GetDescendants()) do
                            if v:IsA("IntValue") or v:IsA("NumberValue") then
                                local n = v.Name:lower()
                                if n:find("comida") or n:find("fome") or n:find("agua") or n:find("sede") then
                                    if v.Value < 100 then v.Value = 100 end
                                end
                            end
                        end
                    end
                end
                if hum and hum.Health < 50 then hum.Health = hum.MaxHealth end
            end
            
            -- Level Setter
            if Config.Level.Enabled then
                local containers = { LP, LP:FindFirstChild("leaderstats") }
                for _, c in ipairs(containers) do
                    if c then
                        for _, v in ipairs(c:GetDescendants()) do
                            if v:IsA("IntValue") or v:IsA("NumberValue") then
                                local n = v.Name:lower()
                                if n:find("level") or n:find("nivel") then v.Value = Config.Level.Desired end
                                if n:find("xp") or n:find("exp") then v.Value = 9999999 end
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.5)
    end
end)

-- ============================ RENDER LOOP (ESP)
RunService.RenderStepped:Connect(function()
    if not Config.ESP.Enabled then
        if next(espCache) then clearESP() end
        return
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if p == LP then continue end
        local char = p.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")

        if not (hrp and head) then
            if espCache[p] then espCache[p].box.Visible = false end
            continue
        end

        local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
        if dist > Config.ESP.MaxDist then
            if espCache[p] then espCache[p].box.Visible = false end
            continue
        end

        local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
        if not onScreen then
            if espCache[p] then espCache[p].box.Visible = false end
            continue
        end

        local d = getESP(p)
        -- Calcula tamanho baseado na distância
        local height = (Camera.ViewportSize.Y / screenPos.Z) * 1.5
        local width = height * 0.5

        d.box.Size = UDim2.fromOffset(width, height)
        d.box.Position = UDim2.fromOffset(screenPos.X - width/2, screenPos.Y - height/2)
        d.box.Visible = true
        d.nameTag.Visible = true
    end
end)

-- ============================ BUILD TABS
local combatTab = tabs[1].Page
toggleWidget(combatTab, "Enable Aimbot", function() return Config.Aimbot.Enabled end, function(v) Config.Aimbot.Enabled = v end)

local visTab = tabs[2].Page
toggleWidget(visTab, "ESP Box (Safe)", function() return Config.ESP.Enabled end, function(v) Config.ESP.Enabled = v end)

local movTab = tabs[3].Page
toggleWidget(movTab, "Fly", function() return Config.Fly.Enabled end, function(v) Config.Fly.Enabled = v end)

local plTab = tabs[4].Page
toggleWidget(plTab, "God Mode", function() return Config.Player.GodMode end, function(v) Config.Player.GodMode = v end)
toggleWidget(plTab, "Auto-Heal (Vida/Fome/Sede)", function() return Config.Player.AutoHeal end, function(v) Config.Player.AutoHeal = v end)

-- LEVEL TAB
local levTab = tabs[5].Page
toggleWidget(levTab, "Ativar Nível Customizado", function() return Config.Level.Enabled end, function(v) Config.Level.Enabled = v end)

local levelInput = new("TextBox", { Size = UDim2.new(1,-20,0,30), Position = UDim2.fromOffset(10, allocY(levTab, 30)), BackgroundColor3 = Color3.fromRGB(28,24,40), Text = "10", PlaceholderText = "Digite o nível...", TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.Gotham, TextSize = 14 }, levTab)
corner(levelInput, 6)

local applyLevelBtn = new("TextButton", { Size = UDim2.new(1,-20,0,30), Position = UDim2.fromOffset(10, allocY(levTab, 30)), BackgroundColor3 = Color3.fromRGB(60,44,96), Text = "Aplicar Nível", TextColor3 = Color3.fromRGB(230,210,255), Font = Enum.Font.GothamBold, TextSize = 12 }, levTab)
corner(applyLevelBtn, 6)
applyLevelBtn.MouseButton1Click:Connect(function()
    local num = tonumber(levelInput.Text)
    if num then
        Config.Level.Desired = num
        applyLevelBtn.Text = "Nível " .. num .. " Aplicado!"
        task.wait(1.5)
        applyLevelBtn.Text = "Aplicar Nível"
    end
end)

local setTab = tabs[6].Page
toggleWidget(setTab, "Resetar Level (Desligar)", function() return false end, function() Config.Level.Enabled = false end)
