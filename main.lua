-- main.lua | Luau | Roblox client/executor | ASTREND HUB v2.5 (otimizado, sem evasao de anti-cheat)
-- Logo: publique ASTREND-LOGO-UPLOAD.png no Roblox Creator Dashboard e informe o ImageId.
-- Funcoes que alteram dados persistentes exigem o servidor ASTREND autorizado.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    warn("[ASTREND] LocalPlayer indisponivel; execute no cliente.")
    return
end
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Config = {
    Brand = {
        LogoImageId = 0, -- Substitua pelo ID da imagem publicada no Roblox.
        Title = "ASTREND HUB",
        Subtitle = "CONTROL CENTER  /  v2.5",
    },
    Theme = {
        RGB = false,
        RGBSpeed = 0.16,
        Accent = Color3.fromRGB(124, 255, 0),
        Scale = 1,
    },
    Aim = {
        Enabled = false,
        Key = Enum.KeyCode.E,
        FOV = 140,
        Smoothness = 10,
        MaxDistance = 500,
        TeamCheck = true,
        WallCheck = true,
        Prediction = 0.0,
        ShowFOV = true,
    },
    Silent = {
        Enabled = false,
        FOV = 90,
        ShowFOV = true,
        MaxDistance = 500,
        TeamCheck = true,
        -- Preview independente; acertos reais exigem integracao com a arma do jogo.
    },
    ESP = {
        Enabled = false,
        ShowChams = true,
        ShowName = true,
        ShowDistance = true,
        ThroughWalls = true,
        FillTransparency = 65, -- 0 = opaco; 100 = invisivel
        TeamCheck = true,
        HideDead = true,
        MaxDistance = 600, -- studs
        UpdateRate = 2, -- fora de RenderStepped
        MaxHighlights = 10, -- teto para nao sobrecarregar GPU/CPU
        NewPerCycle = 2, -- distribuir criacao de objetos em ciclos
    },
    Fly = {
        Enabled = false,
        Key = Enum.KeyCode.F,
        Speed = 40,
    },
    Player = {
        GodMode = false,
        AutoHeal = false,
        AutoHealThreshold = 35,
        InfiniteAmmo = false,
        DesiredLevel = 10,
    },
    LocalTest = {
        GodMode = false,
        AutoHeal = false,
        Needs = false,
        Level = false,
        DesiredLevel = 10,
    },
}

local active = true
local connections = {}
local espCache = {}
local accentBindings = setmetatable({}, {__mode = "k"})
local refreshers = {}
local statusText
local serverRemote
local responseConnection
local pendingServer = {}
local flyingHumanoid
local aimHeld = false
local lastTheme = 0

local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end

local function new(class, properties, parent)
    local item = Instance.new(class)
    for key, value in pairs(properties or {}) do
        item[key] = value
    end
    if parent then item.Parent = parent end
    return item
end

local function round(item, radius)
    new("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, item)
    return item
end

local function stroke(item, color, thickness, transparency)
    return new("UIStroke", {
        Color = color or Color3.fromRGB(55, 59, 66),
        Thickness = thickness or 1,
        Transparency = transparency or 0,
    }, item)
end

local function accent(item, property, multiplier)
    accentBindings[item] = {Property = property, Multiplier = multiplier or 1}
    return item
end

local function mix(color, multiplier)
    return Color3.new(
        math.clamp(color.R * multiplier, 0, 1),
        math.clamp(color.G * multiplier, 0, 1),
        math.clamp(color.B * multiplier, 0, 1)
    )
end

local function currentAccent()
    if not Config.Theme.RGB then return Config.Theme.Accent end
    return Color3.fromHSV((os.clock() * Config.Theme.RGBSpeed) % 1, 0.94, 1)
end

local function applyAccent()
    local color = currentAccent()
    for item, binding in pairs(accentBindings) do
        if item.Parent then
            item[binding.Property] = mix(color, binding.Multiplier)
        end
    end
end

local function setStatus(message, color)
    if statusText and statusText.Parent then
        statusText.Text = message
        statusText.TextColor3 = color or Color3.fromRGB(158, 165, 172)
    end
end

local function refreshControls()
    for _, refresh in ipairs(refreshers) do
        local ok, err = pcall(refresh)
        if not ok then warn("[ASTREND] Controle: " .. tostring(err)) end
    end
end

-- Servidor controla alteracoes de estado. Um envio nao comprova sucesso.
local function onServerResponse(action, success, message)
    if not active then return end
    local pending = pendingServer[action]
    pendingServer[action] = nil
    if success and pending then
        if action == "GodMode" then
            Config.Player.GodMode = pending.Value
        elseif action == "AutoHeal" then
            Config.Player.AutoHeal = pending.Value.Enabled
        elseif action == "InfiniteAmmo" then
            Config.Player.InfiniteAmmo = pending.Value
        end
        refreshControls()
    end
    if type(message) == "string" and #message > 0 then
        setStatus(message, success and currentAccent() or Color3.fromRGB(255, 181, 91))
    else
        setStatus(success and "Operacao confirmada pelo servidor." or "Operacao recusada pelo servidor.",
            success and currentAccent() or Color3.fromRGB(255, 181, 91))
    end
end

local function resolveRemote()
    local candidate = ReplicatedStorage:FindFirstChild("AstrendHubAction")
    if not candidate or not candidate:IsA("RemoteEvent") then
        serverRemote = nil
        if responseConnection then
            responseConnection:Disconnect()
            responseConnection = nil
        end
        return nil
    end
    if serverRemote ~= candidate or not responseConnection then
        if responseConnection then responseConnection:Disconnect() end
        serverRemote = candidate
        responseConnection = connect(candidate.OnClientEvent, onServerResponse)
    end
    return serverRemote
end

local function serverAction(action, value)
    local remote = resolveRemote()
    if not remote then
        setStatus("Indisponivel neste jogo: o servidor nao possui ASTREND.", Color3.fromRGB(255, 181, 91))
        return false
    end
    if pendingServer[action] then
        setStatus("Aguardando resposta do servidor para " .. action .. ".", Color3.fromRGB(255, 181, 91))
        return false
    end
    local request = {Value = value}
    pendingServer[action] = request
    local ok, err = pcall(function()
        remote:FireServer(action, value)
    end)
    if not ok then
        pendingServer[action] = nil
        warn("[ASTREND] Falha ao enviar comando: " .. tostring(err))
        setStatus("Falha ao enviar comando ao servidor.", Color3.fromRGB(255, 181, 91))
        return false
    end
    setStatus("Pedido enviado; aguardando confirmacao...")
    task.delay(3, function()
        if active and pendingServer[action] == request then
            pendingServer[action] = nil
            setStatus("Servidor nao confirmou " .. action .. ". Nenhuma alteracao validada.",
                Color3.fromRGB(255, 181, 91))
        end
    end)
    return true
end

-- Evita duas interfaces sobrepostas na reexecucao.
local sharedSession = (type(getgenv) == "function" and getgenv()) or _G
if type(sharedSession.AstrendHubCleanup) == "function" then
    pcall(sharedSession.AstrendHubCleanup)
end
local old = PlayerGui:FindFirstChild("AstrendHubV2")
if old then old:Destroy() end

-- Remover objetos isolados por execucoes antigas interrompidas.
for _, item in ipairs(Workspace:GetChildren()) do
    if item:IsA("Highlight") and item.Name:match("^AstrendChams_%d+$") then
        item:Destroy()
    end
end
for _, item in ipairs(PlayerGui:GetChildren()) do
    if item:IsA("BillboardGui") and item.Name:match("^AstrendTag_%d+$") then
        item:Destroy()
    end
end

local gui
-- Limpeza de emergencia registrada antes de criar o restante da interface.
sharedSession.AstrendHubCleanup = function()
    active = false
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    for _, data in pairs(espCache) do
        if data.Highlight then pcall(function() data.Highlight:Destroy() end) end
        if data.Billboard then pcall(function() data.Billboard:Destroy() end) end
    end
    if gui then pcall(function() gui:Destroy() end) end
end

gui = new("ScreenGui", {
    Name = "AstrendHubV2",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 100,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, PlayerGui)

local overlay = new("Frame", {
    Name = "ESPOverlay",
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    ZIndex = 2,
}, gui)

local fovCircle = round(new("Frame", {
    Name = "AimFOV",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(Config.Aim.FOV * 2, Config.Aim.FOV * 2),
    BackgroundTransparency = 1,
    Visible = false,
    ZIndex = 3,
}, overlay), 9999)
local fovCorner = fovCircle:FindFirstChildOfClass("UICorner")
fovCorner.CornerRadius = UDim.new(1, 0)
accent(stroke(fovCircle, Config.Theme.Accent, 1.5, 0.12), "Color")

local silentCircle = round(new("Frame", {
    Name = "SilentFOV",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(Config.Silent.FOV * 2, Config.Silent.FOV * 2),
    BackgroundTransparency = 1,
    Visible = false,
    ZIndex = 3,
}, overlay), 9999)
silentCircle:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
stroke(silentCircle, Color3.fromRGB(75, 193, 255), 1.4, 0.15)

local main = round(new("Frame", {
    Name = "Main",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(650, 440),
    BackgroundColor3 = Color3.fromRGB(14, 16, 20),
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 10,
}, gui), 14)
accent(stroke(main, Config.Theme.Accent, 1.5, 0.15), "Color", 0.65)
local scale = new("UIScale", {Scale = Config.Theme.Scale}, main)

local header = new("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, 64),
    BackgroundColor3 = Color3.fromRGB(18, 21, 25),
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 11,
}, main)
round(header, 14)
new("Frame", {
    Position = UDim2.new(0, 0, 1, -1),
    Size = UDim2.new(1, 0, 0, 1),
    BorderSizePixel = 0,
    BackgroundColor3 = Color3.fromRGB(38, 43, 46),
    ZIndex = 12,
}, header)

local logoWrap = round(new("Frame", {
    Size = UDim2.fromOffset(46, 46),
    Position = UDim2.fromOffset(14, 9),
    BackgroundColor3 = Color3.fromRGB(4, 6, 6),
    ZIndex = 12,
}, header), 12)
accent(stroke(logoWrap, Config.Theme.Accent, 1.6, 0), "Color")
local logoImage = new("ImageLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Image = Config.Brand.LogoImageId > 0 and ("rbxassetid://" .. tostring(Config.Brand.LogoImageId)) or "",
    ScaleType = Enum.ScaleType.Fit,
    ZIndex = 13,
}, logoWrap)
round(logoImage, 11)
local fallbackLogo = new("TextLabel", {
    Text = "A",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBlack,
    TextSize = 30,
    TextColor3 = Config.Theme.Accent,
    Visible = Config.Brand.LogoImageId <= 0,
    ZIndex = 13,
}, logoWrap)
accent(fallbackLogo, "TextColor3")

new("TextLabel", {
    Text = Config.Brand.Title,
    Position = UDim2.fromOffset(72, 11),
    Size = UDim2.fromOffset(340, 24),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 20,
    TextColor3 = Color3.fromRGB(242, 246, 248),
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 12,
}, header)
local subtitle = new("TextLabel", {
    Text = Config.Brand.Subtitle,
    Position = UDim2.fromOffset(73, 37),
    Size = UDim2.fromOffset(350, 17),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamMedium,
    TextSize = 10,
    TextColor3 = Config.Theme.Accent,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 12,
}, header)
accent(subtitle, "TextColor3")

local function headerButton(symbol, rightOffset)
    return round(new("TextButton", {
        Text = symbol,
        Position = UDim2.new(1, rightOffset, 0, 17),
        Size = UDim2.fromOffset(28, 28),
        BackgroundColor3 = Color3.fromRGB(38, 42, 48),
        TextColor3 = Color3.fromRGB(220, 225, 230),
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        AutoButtonColor = true,
        ZIndex = 12,
    }, header), 7)
end
local minimizeBtn = headerButton("MIN", -101)
minimizeBtn.Size = UDim2.fromOffset(59, 28)
minimizeBtn.TextSize = 11
local closeBtn = headerButton("X", -39)

local body = new("Frame", {
    Position = UDim2.fromOffset(0, 64),
    Size = UDim2.new(1, 0, 1, -64),
    BackgroundTransparency = 1,
    ZIndex = 11,
}, main)
local sidebar = new("Frame", {
    BackgroundColor3 = Color3.fromRGB(18, 21, 26),
    BorderSizePixel = 0,
    Size = UDim2.new(0, 151, 1, 0),
    ZIndex = 11,
}, body)
new("Frame", {
    Position = UDim2.new(1, -1, 0, 0),
    Size = UDim2.new(0, 1, 1, 0),
    BorderSizePixel = 0,
    BackgroundColor3 = Color3.fromRGB(35, 39, 44),
    ZIndex = 12,
}, sidebar)

local nav = new("Frame", {
    Position = UDim2.fromOffset(10, 16),
    Size = UDim2.new(1, -20, 0, 265),
    BackgroundTransparency = 1,
    ZIndex = 12,
}, sidebar)
new("UIListLayout", {Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder}, nav)
local content = new("Frame", {
    Position = UDim2.fromOffset(151, 0),
    Size = UDim2.new(1, -151, 1, 0),
    BackgroundTransparency = 1,
    ZIndex = 11,
}, body)
local tabPages = {}
local tabButtons = {}
local tabNames = {"Combat", "Visuals", "Movement", "Player", "Settings"}
local activeTab = nil

local function selectTab(name)
    activeTab = name
    for key, page in pairs(tabPages) do
        page.Visible = key == name
    end
    for key, item in pairs(tabButtons) do
        local chosen = key == name
        item.Button.BackgroundColor3 = chosen and Color3.fromRGB(38, 46, 35) or Color3.fromRGB(25, 29, 34)
        item.Marker.Visible = chosen
        item.Button.TextColor3 = chosen and Color3.fromRGB(250, 250, 250) or Color3.fromRGB(160, 169, 176)
    end
end

for index, name in ipairs(tabNames) do
    local button = round(new("TextButton", {
        Name = name .. "Tab",
        Text = "   " .. name,
        Size = UDim2.new(1, 0, 0, 39),
        LayoutOrder = index,
        BackgroundColor3 = Color3.fromRGB(25, 29, 34),
        BorderSizePixel = 0,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = Color3.fromRGB(170, 180, 185),
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
        ZIndex = 12,
    }, nav), 8)
    local marker = round(new("Frame", {
        Position = UDim2.fromOffset(0, 9),
        Size = UDim2.fromOffset(3, 21),
        BackgroundColor3 = Config.Theme.Accent,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 13,
    }, button), 2)
    accent(marker, "BackgroundColor3")
    tabButtons[name] = {Button = button, Marker = marker}
    local page = new("ScrollingFrame", {
        Name = name .. "Page",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.fromOffset(0, 0),
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Config.Theme.Accent,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Visible = false,
        ZIndex = 11,
    }, content)
    accent(page, "ScrollBarImageColor3")
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 18),
        PaddingRight = UDim.new(0, 18),
        PaddingTop = UDim.new(0, 18),
        PaddingBottom = UDim.new(0, 22),
    }, page)
    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 9),
    }, page)
    tabPages[name] = page
    connect(button.MouseButton1Click, function() selectTab(name) end)
end
selectTab("Combat")

statusText = new("TextLabel", {
    Text = "ASTREND v2.5  |  Modo leve",
    Position = UDim2.new(0, 10, 1, -58),
    Size = UDim2.new(1, -20, 0, 55),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Bottom,
    TextColor3 = Color3.fromRGB(157, 165, 171),
    ZIndex = 12,
}, sidebar)

local function section(page, title, description)
    local block = new("Frame", {
        Size = UDim2.new(1, 0, 0, description and 48 or 26),
        BackgroundTransparency = 1,
        ZIndex = 12,
    }, page)
    local label = new("TextLabel", {
        Text = title:upper(),
        Size = UDim2.new(1, 0, 0, 23),
        BackgroundTransparency = 1,
        TextColor3 = Config.Theme.Accent,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 12,
    }, block)
    accent(label, "TextColor3")
    if description then
        new("TextLabel", {
            Text = description,
            Position = UDim2.fromOffset(0, 24),
            Size = UDim2.new(1, 0, 0, 23),
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(139, 147, 156),
            Font = Enum.Font.Gotham,
            TextSize = 10,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 12,
        }, block)
    end
end

local function controlFrame(page, height)
    local frame = round(new("Frame", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = Color3.fromRGB(25, 29, 35),
        BorderSizePixel = 0,
        ZIndex = 12,
    }, page), 9)
    stroke(frame, Color3.fromRGB(45, 49, 55), 1, 0.3)
    return frame
end

local function toggle(page, title, getter, setter)
    local frame = controlFrame(page, 42)
    local button = new("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 14,
    }, frame)
    new("TextLabel", {
        Text = title,
        Size = UDim2.new(1, -80, 1, 0),
        Position = UDim2.fromOffset(13, 0),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(222, 230, 231),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 13,
    }, frame)
    local pill = round(new("Frame", {
        Position = UDim2.new(1, -58, 0.5, -10),
        Size = UDim2.fromOffset(43, 20),
        BackgroundColor3 = Color3.fromRGB(65, 70, 77),
        ZIndex = 13,
    }, frame), 10)
    local knob = round(new("Frame", {
        Size = UDim2.fromOffset(16, 16),
        BackgroundColor3 = Color3.fromRGB(245, 245, 245),
        Position = UDim2.fromOffset(2, 2),
        ZIndex = 14,
    }, pill), 8)
    local function refresh()
        local enabled = getter()
        pill.BackgroundColor3 = enabled and currentAccent() or Color3.fromRGB(66, 70, 77)
        knob.Position = enabled and UDim2.fromOffset(25, 2) or UDim2.fromOffset(2, 2)
    end
    table.insert(refreshers, refresh)
    connect(button.MouseButton1Click, function()
        setter(not getter())
        refresh()
    end)
    refresh()
    return refresh
end

local function slider(page, title, minimum, maximum, getter, setter, integer, suffix)
    local frame = controlFrame(page, 62)
    new("TextLabel", {
        Text = title,
        Position = UDim2.fromOffset(13, 7),
        Size = UDim2.new(1, -100, 0, 21),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(222, 230, 231),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 13,
    }, frame)
    local readout = new("TextLabel", {
        Text = "",
        Position = UDim2.new(1, -87, 0, 8),
        Size = UDim2.fromOffset(73, 20),
        BackgroundTransparency = 1,
        TextColor3 = Config.Theme.Accent,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 13,
    }, frame)
    accent(readout, "TextColor3")
    local track = round(new("Frame", {
        Position = UDim2.new(0, 14, 0, 43),
        Size = UDim2.new(1, -28, 0, 5),
        BackgroundColor3 = Color3.fromRGB(58, 65, 69),
        ZIndex = 13,
    }, frame), 4)
    local fill = round(new("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = Config.Theme.Accent,
        ZIndex = 14,
    }, track), 4)
    accent(fill, "BackgroundColor3")
    local handle = round(new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(12, 12),
        Position = UDim2.fromScale(0, 0.5),
        BackgroundColor3 = Color3.fromRGB(243, 248, 241),
        ZIndex = 15,
    }, track), 6)
    local dragging = false
    local function refresh()
        local value = math.clamp(getter(), minimum, maximum)
        local fraction = (value - minimum) / (maximum - minimum)
        readout.Text = (integer and tostring(math.floor(value)) or string.format("%.2f", value)) .. (suffix or "")
        fill.Size = UDim2.fromScale(fraction, 1)
        handle.Position = UDim2.fromScale(fraction, 0.5)
    end
    local function update(screenX)
        if track.AbsoluteSize.X <= 0 then return end
        local fraction = math.clamp((screenX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local value = minimum + fraction * (maximum - minimum)
        if integer then value = math.floor(value + 0.5) end
        setter(value)
        refresh()
    end
    connect(frame.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input.Position.X)
        end
    end)
    connect(UIS.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input.Position.X)
        end
    end)
    connect(UIS.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    table.insert(refreshers, refresh)
    refresh()
end

local function keybind(page, title, getter, setter)
    local frame = controlFrame(page, 42)
    new("TextLabel", {
        Text = title,
        Size = UDim2.new(1, -105, 1, 0),
        Position = UDim2.fromOffset(13, 0),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(222, 230, 231),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 13,
    }, frame)
    local button = round(new("TextButton", {
        Position = UDim2.new(1, -88, 0.5, -13),
        Size = UDim2.fromOffset(73, 26),
        BackgroundColor3 = Color3.fromRGB(45, 51, 55),
        TextColor3 = Color3.fromRGB(240, 245, 245),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        ZIndex = 14,
    }, frame), 6)
    local listening = false
    local function refresh()
        if not listening then button.Text = getter().Name end
    end
    connect(button.MouseButton1Click, function()
        listening = true
        button.Text = "TECLA..."
    end)
    connect(UIS.InputBegan, function(input, processed)
        if not listening or processed then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        listening = false
        if input.KeyCode ~= Enum.KeyCode.Escape then setter(input.KeyCode) end
        refresh()
    end)
    table.insert(refreshers, refresh)
    refresh()
end

local function buttonControl(page, title, callback)
    local frame = controlFrame(page, 42)
    local button = new("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = title,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = Config.Theme.Accent,
        ZIndex = 14,
    }, frame)
    accent(button, "TextColor3")
    connect(button.MouseButton1Click, callback)
end

local function textInput(page, title, initial, callback)
    local frame = controlFrame(page, 70)
    new("TextLabel", {
        Text = title,
        Size = UDim2.new(1, -20, 0, 20),
        Position = UDim2.fromOffset(13, 5),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(222, 230, 231),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 13,
    }, frame)
    local field = round(new("TextBox", {
        Text = tostring(initial),
        PlaceholderText = "Digite um valor",
        Size = UDim2.new(1, -27, 0, 30),
        Position = UDim2.fromOffset(13, 29),
        BackgroundColor3 = Color3.fromRGB(37, 42, 48),
        TextColor3 = Color3.fromRGB(235, 240, 240),
        Font = Enum.Font.Gotham,
        TextSize = 13,
        ClearTextOnFocus = false,
        ZIndex = 13,
    }, frame), 6)
    connect(field.FocusLost, function(enterPressed)
        if enterPressed then callback(field.Text) end
    end)
    return field
end

-- Combat: mira assistida por camera; nao altera remotes de armas nem faz hook.
local combat = tabPages.Combat
section(combat, "Mira", "Ativacao manual. Sem interceptacao do protocolo do jogo.")
toggle(combat, "Ativar Aimbot", function() return Config.Aim.Enabled end, function(v) Config.Aim.Enabled = v end)
toggle(combat, "Mostrar circulo FOV", function() return Config.Aim.ShowFOV end, function(v) Config.Aim.ShowFOV = v end)
slider(combat, "FOV", 30, 400, function() return Config.Aim.FOV end, function(v) Config.Aim.FOV = v end, true, "px")
slider(combat, "Suavizacao", 1, 35, function() return Config.Aim.Smoothness end, function(v) Config.Aim.Smoothness = v end, true)
slider(combat, "Alcance maximo", 50, 1500, function() return Config.Aim.MaxDistance end, function(v) Config.Aim.MaxDistance = v end, true, " studs")
toggle(combat, "Ignorar mesma equipe", function() return Config.Aim.TeamCheck end, function(v) Config.Aim.TeamCheck = v end)
toggle(combat, "Checar obstrucao", function() return Config.Aim.WallCheck end, function(v) Config.Aim.WallCheck = v end)
keybind(combat, "Tecla de mira", function() return Config.Aim.Key end, function(v) Config.Aim.Key = v end)

section(combat, "Silent (FOV separado)", "Previa visual independente. A alteracao de acertos requer integracao com seu jogo.")
toggle(combat, "Habilitar preview Silent", function() return Config.Silent.Enabled end,
    function(v) Config.Silent.Enabled = v end)
toggle(combat, "Mostrar FOV Silent", function() return Config.Silent.ShowFOV end,
    function(v) Config.Silent.ShowFOV = v end)
slider(combat, "FOV Silent", 20, 400, function() return Config.Silent.FOV end,
    function(v) Config.Silent.FOV = v end, true, "px")
slider(combat, "Alcance Silent", 50, 1500, function() return Config.Silent.MaxDistance end,
    function(v) Config.Silent.MaxDistance = v end, true, " studs")
toggle(combat, "Silent: ignorar equipe", function() return Config.Silent.TeamCheck end,
    function(v) Config.Silent.TeamCheck = v end)

task.wait() -- Distribui a criacao da interface em mais de um frame.
-- Visuals: modelo 3D em vez de caixas 2D calculadas pela CPU.
local visuals = tabPages.Visuals
section(visuals, "CHAMS ESP 3D", "O Sintonia RP detectou ESP (erro 267). Pode expulsar novamente.")
toggle(visuals, "Ativar ESP", function() return Config.ESP.Enabled end, function(v) Config.ESP.Enabled = v end)
toggle(visuals, "Mostrar Chams 3D", function() return Config.ESP.ShowChams end, function(v) Config.ESP.ShowChams = v end)
toggle(visuals, "Ver atraves de paredes", function() return Config.ESP.ThroughWalls end, function(v) Config.ESP.ThroughWalls = v end)
slider(visuals, "Transparencia do Chams", 0, 100, function() return Config.ESP.FillTransparency end, function(v) Config.ESP.FillTransparency = v end, true, " %")
toggle(visuals, "Mostrar nomes", function() return Config.ESP.ShowName end, function(v) Config.ESP.ShowName = v end)
toggle(visuals, "Mostrar distancia", function() return Config.ESP.ShowDistance end, function(v) Config.ESP.ShowDistance = v end)
toggle(visuals, "Ignorar mesma equipe", function() return Config.ESP.TeamCheck end, function(v) Config.ESP.TeamCheck = v end)
toggle(visuals, "Ocultar jogadores mortos", function() return Config.ESP.HideDead end, function(v) Config.ESP.HideDead = v end)
slider(visuals, "Distancia do ESP", 100, 2000, function() return Config.ESP.MaxDistance end, function(v) Config.ESP.MaxDistance = v end, true, " studs")
slider(visuals, "Atualizacoes por segundo", 1, 12, function() return Config.ESP.UpdateRate end, function(v) Config.ESP.UpdateRate = v end, true, " Hz")

task.wait()
-- Movement.
local movement = tabPages.Movement
section(movement, "Movimentacao", "Movimento local sujeito a validacao do servidor.")
local function setFly(enabled)
    Config.Fly.Enabled = enabled
    if not enabled and flyingHumanoid and flyingHumanoid.Parent then
        flyingHumanoid.PlatformStand = false
        flyingHumanoid.AutoRotate = true
    end
    if not enabled then
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root then root.AssemblyLinearVelocity = Vector3.zero end
        flyingHumanoid = nil
    end
end
toggle(movement, "Ativar Fly", function() return Config.Fly.Enabled end, setFly)
slider(movement, "Velocidade do Fly", 5, 100, function() return Config.Fly.Speed end, function(v) Config.Fly.Speed = v end, true)
keybind(movement, "Tecla de Fly", function() return Config.Fly.Key end, function(v) Config.Fly.Key = v end)

task.wait()
-- Funcoes do jogador: alteracoes reais sao executadas apenas por servidor proprio.
local playerPage = tabPages.Player
local healThresholdToken = 0
section(playerPage, "Personagem", "Controles reais exigem servidor ASTREND instalado e autorizacao. Nao funcionam no Sintonia RP.")
toggle(playerPage, "God Mode", function() return Config.Player.GodMode end, function(v)
    serverAction("GodMode", v)
end)
toggle(playerPage, "Auto-Heal (vida baixa)", function() return Config.Player.AutoHeal end, function(v)
    serverAction("AutoHeal", {Enabled = v, Threshold = Config.Player.AutoHealThreshold})
end)
slider(playerPage, "Ativar cura abaixo de", 10, 90,
    function() return Config.Player.AutoHealThreshold end,
    function(v)
        Config.Player.AutoHealThreshold = v
        if Config.Player.AutoHeal then
            healThresholdToken += 1
            local token = healThresholdToken
            task.delay(0.2, function()
                if active and token == healThresholdToken then
                    serverAction("HealThreshold", v)
                end
            end)
        end
    end, true, "%")
buttonControl(playerPage, "RECUPERAR VIDA AGORA", function() serverAction("HealNow") end)
section(playerPage, "Necessidades", "Fome e sede precisam existir no servidor do jogo. Nao ha alteracao apenas pelo cliente.")
buttonControl(playerPage, "ENCHER FOME", function() serverAction("FillHunger") end)
buttonControl(playerPage, "ENCHER SEDE", function() serverAction("FillThirst") end)
buttonControl(playerPage, "ENCHER FOME E SEDE", function() serverAction("FillNeeds") end)
toggle(playerPage, "Municao infinita", function() return Config.Player.InfiniteAmmo end, function(v)
    serverAction("InfiniteAmmo", v)
end)
local levelField = textInput(playerPage, "Nivel desejado", Config.Player.DesiredLevel, function(value)
    local amount = tonumber(value)
    if amount then Config.Player.DesiredLevel = math.clamp(math.floor(amount), 1, 999) end
end)
buttonControl(playerPage, "APLICAR NIVEL NO SERVIDOR", function()
    local amount = tonumber(levelField.Text)
    if not amount then
        setStatus("Nivel invalido.", Color3.fromRGB(255, 181, 91))
        return
    end
    Config.Player.DesiredLevel = math.clamp(math.floor(amount), 1, 999)
    serverAction("SetLevel", Config.Player.DesiredLevel)
end)

-- Compatibilidade com a PRIMEIRA rotina enviada: alteracao somente dos valores locais.
-- Em servidor de terceiros, nenhuma mudanca e garantida ou persistente.
-- Cache de valores locais: evita GetDescendants em todo o PlayerGui.
-- Apenas containers de dados conhecidos; varredura no maximo a cada 8 segundos.
local STAT_KIND = {
    fome = "Hunger", comida = "Hunger", hunger = "Hunger", food = "Hunger",
    sede = "Thirst", agua = "Thirst", ["água"] = "Thirst", thirst = "Thirst", water = "Thirst",
    nivel = "Level", ["nível"] = "Level", level = "Level", lvl = "Level",
    xp = "XP", exp = "XP", experience = "XP", experiencia = "XP", ["experiência"] = "XP",
}
local localStatCache = {Hunger = {}, Thirst = {}, Level = {}, XP = {}}
local lastStatScan = -math.huge
local lastStatCharacter

local function statKind(name)
    local normalized = string.lower(tostring(name)):gsub("[%s_%-]", "")
    return STAT_KIND[normalized]
end

local function refreshLocalStatCache(force)
    local character = LocalPlayer.Character
    if not force and character == lastStatCharacter and os.clock() - lastStatScan < 8 then return end
    lastStatScan = os.clock()
    lastStatCharacter = character
    for _, entries in pairs(localStatCache) do table.clear(entries) end
    -- Vetor sem lacunas: ipairs para no primeiro nil.
    local roots = {LocalPlayer}
    if character then table.insert(roots, character) end
    for _, name in ipairs({"leaderstats", "Data", "PlayerData", "Stats", "Status"}) do
        local container = LocalPlayer:FindFirstChild(name)
        if container then table.insert(roots, container) end
    end
    local scanned = {}
    local function track(item)
        if (item:IsA("IntValue") or item:IsA("NumberValue")) then
            local kind = statKind(item.Name)
            if kind then table.insert(localStatCache[kind], {ValueObject = item}) end
        end
    end
    for _, root in ipairs(roots) do
        if root and not scanned[root] then
            scanned[root] = true
            for _, item in ipairs(root:GetChildren()) do
                track(item)
                -- Nao escanear PlayerGui, PlayerScripts, Backpack nem todo o avatar.
                if root ~= LocalPlayer and root ~= character and
                    (item:IsA("Folder") or item:IsA("Configuration")) then
                    for _, child in ipairs(item:GetDescendants()) do track(child) end
                end
            end
            for name, value in pairs(root:GetAttributes()) do
                if type(value) == "number" then
                    local kind = statKind(name)
                    if kind then table.insert(localStatCache[kind], {Container = root, Attribute = name}) end
                end
            end
        end
    end
end

local function writeLocalStats(kind, value)
    refreshLocalStatCache(false)
    local found = 0
    for _, entry in ipairs(localStatCache[kind] or {}) do
        local item = entry.ValueObject
        local container = entry.Container
        if item and item.Parent then
            found += 1
            if item.Value ~= value then pcall(function() item.Value = value end) end
        elseif container and container.Parent then
            found += 1
            if container:GetAttribute(entry.Attribute) ~= value then
                pcall(function() container:SetAttribute(entry.Attribute, value) end)
            end
        end
    end
    if found == 0 then lastStatScan = -math.huge end
    return found, found
end

local function healLocal()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    local ok = pcall(function() humanoid.Health = humanoid.MaxHealth end)
    return ok
end

local function localFeedback(label, count)
    if count == 0 then
        setStatus(label .. ": nenhum valor local compativel foi encontrado.", Color3.fromRGB(255, 181, 91))
    else
        setStatus(label .. ": " .. count .. " valor(es) ajustado(s) apenas neste cliente. O servidor pode reverter.",
            Color3.fromRGB(255, 181, 91))
    end
end

section(playerPage, "Teste local (primeira rotina)", "Altera Humanoid, NumberValue ou Attribute apenas no cliente. Sem efeito garantido no servidor.")
toggle(playerPage, "God Mode local (teste)", function() return Config.LocalTest.GodMode end, function(value)
    Config.LocalTest.GodMode = value
    setStatus(value and "Tentativa de God Mode local ativada; o servidor continua autoritativo."
        or "God Mode local desativado.", Color3.fromRGB(255, 181, 91))
end)
toggle(playerPage, "Auto-Heal local", function() return Config.LocalTest.AutoHeal end, function(value)
    Config.LocalTest.AutoHeal = value
    setStatus(value and "Auto-Heal local ativado, sem confirmacao do servidor."
        or "Auto-Heal local desativado.", Color3.fromRGB(255, 181, 91))
end)
buttonControl(playerPage, "RECUPERAR VIDA (LOCAL)", function()
    setStatus(healLocal() and "Vida ajustada localmente; nao confirmada pelo servidor."
        or "Personagem nao encontrado ou impossivel curar localmente.", Color3.fromRGB(255, 181, 91))
end)
toggle(playerPage, "Fome e sede automaticas (local)", function() return Config.LocalTest.Needs end, function(value)
    Config.LocalTest.Needs = value
    setStatus(value and "Fome e sede locais ativadas; sem efeito garantido no servidor."
        or "Fome e sede locais desativadas.", Color3.fromRGB(255, 181, 91))
end)
buttonControl(playerPage, "ENCHER FOME (LOCAL)", function()
    localFeedback("Fome", select(1, writeLocalStats("Hunger", 100)))
end)
buttonControl(playerPage, "ENCHER SEDE (LOCAL)", function()
    localFeedback("Sede", select(1, writeLocalStats("Thirst", 100)))
end)
local localLevelField = textInput(playerPage, "Nivel local desejado", Config.LocalTest.DesiredLevel, function(value)
    local n = tonumber(value)
    if n then Config.LocalTest.DesiredLevel = math.clamp(math.floor(n), 1, 999) end
end)
toggle(playerPage, "Nivel local automatico", function() return Config.LocalTest.Level end, function(value)
    Config.LocalTest.Level = value
    setStatus(value and "Nivel local automatico ativado; progresso real exige servidor."
        or "Nivel local automatico desativado.", Color3.fromRGB(255, 181, 91))
end)
buttonControl(playerPage, "APLICAR NIVEL LOCAL", function()
    local n = tonumber(localLevelField.Text)
    if not n then
        setStatus("Nivel local invalido.", Color3.fromRGB(255, 181, 91))
        return
    end
    Config.LocalTest.DesiredLevel = math.clamp(math.floor(n), 1, 999)
    local matches = select(1, writeLocalStats("Level", Config.LocalTest.DesiredLevel))
    localFeedback("Nivel", matches)
end)

-- Mantem a compatibilidade local fora de RenderStepped, com carga reduzida.
task.spawn(function()
    while active and gui.Parent do
        local options = Config.LocalTest
        if options.GodMode or options.AutoHeal then
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 and humanoid.MaxHealth > 0 then
                local belowThreshold = humanoid.Health / humanoid.MaxHealth * 100 < Config.Player.AutoHealThreshold
                if options.GodMode or (options.AutoHeal and belowThreshold) then
                    healLocal()
                end
            end
        end
        if options.Needs then
            writeLocalStats("Hunger", 100)
            writeLocalStats("Thirst", 100)
        end
        if options.Level then
            writeLocalStats("Level", options.DesiredLevel)
            -- A primeira rotina tambem ajustava XP, localmente.
            writeLocalStats("XP", 9999999)
        end
        task.wait(2.5) -- controle local de baixa frequencia
    end
end)

task.wait()
-- Settings.
local settings = tabPages.Settings
section(settings, "Identidade Visual", "Verde ASTREND ou RGB automatico em todos os detalhes.")
toggle(settings, "RGB automatico", function() return Config.Theme.RGB end, function(v)
    Config.Theme.RGB = v
    applyAccent()
    refreshControls()
end)
slider(settings, "Velocidade RGB", 0.03, 0.65, function() return Config.Theme.RGBSpeed end,
    function(v) Config.Theme.RGBSpeed = v end, false)
slider(settings, "Escala da interface", 0.7, 1.2, function() return Config.Theme.Scale end,
    function(v) Config.Theme.Scale = v; scale.Scale = v end, false)
buttonControl(settings, "RESTAURAR VERDE ASTREND", function()
    Config.Theme.RGB = false
    applyAccent()
    refreshControls()
end)
section(settings, "Logo", "No Roblox, publique sua PNG como Imagem e informe o Asset ID abaixo.")
local logoField = textInput(settings, "ID da logo ASTREND (Asset ID)", Config.Brand.LogoImageId, function(value)
    local id = tonumber(value)
    if id and id > 0 then
        Config.Brand.LogoImageId = math.floor(id)
        logoImage.Image = "rbxassetid://" .. tostring(Config.Brand.LogoImageId)
        fallbackLogo.Visible = false
        setStatus("Logo configurada. Confira se o asset e publico/aprovado.", currentAccent())
    else
        setStatus("Asset ID invalido. Envie um numero positivo.", Color3.fromRGB(255, 181, 91))
    end
end)
buttonControl(settings, "APLICAR LOGO", function()
    local id = tonumber(logoField.Text)
    if not id or id <= 0 then
        setStatus("Asset ID invalido.", Color3.fromRGB(255, 181, 91))
        return
    end
    Config.Brand.LogoImageId = math.floor(id)
    logoImage.Image = "rbxassetid://" .. tostring(Config.Brand.LogoImageId)
    fallbackLogo.Visible = false
    setStatus("Logo solicitada ao Roblox. Se nao aparecer, verifique a permissao do asset.")
end)
section(settings, "Conexao", "Somente jogos que instalaram o servidor ASTREND aceitam acoes de administracao.")
buttonControl(settings, "VERIFICAR SERVIDOR", function()
    -- Confirma permissao real, nao apenas a existencia do RemoteEvent.
    serverAction("Ping")
end)

-- Interacao da janela.
local dragging = false
local dragStart, windowStart
connect(header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        windowStart = main.Position
    end
end)
connect(UIS.InputChanged, function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local delta = input.Position - dragStart
    main.Position = UDim2.new(
        windowStart.X.Scale, windowStart.X.Offset + delta.X / scale.Scale,
        windowStart.Y.Scale, windowStart.Y.Offset + delta.Y / scale.Scale
    )
end)
connect(UIS.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
local minimized = false
connect(minimizeBtn.MouseButton1Click, function()
    minimized = not minimized
    body.Visible = not minimized
    main.Size = minimized and UDim2.fromOffset(650, 64) or UDim2.fromOffset(650, 440)
    minimizeBtn.Text = minimized and "ABRIR" or "MIN"
end)

-- Chams ESP: um Highlight por avatar, com BillboardGui opcional.
-- Nenhuma projecao de vertices, Drawing API ou calculo 2D por frame.
local function hideESP(player)
    local data = espCache[player]
    if not data then return end
    if data.Highlight and data.Highlight.Parent then data.Highlight.Enabled = false end
    if data.Billboard and data.Billboard.Parent then data.Billboard.Enabled = false end
end

local function removeESP(player)
    local data = espCache[player]
    if not data then return end
    if data.Highlight then
        accentBindings[data.Highlight] = nil
        data.Highlight:Destroy()
    end
    if data.DistanceLabel then accentBindings[data.DistanceLabel] = nil end
    if data.Billboard then data.Billboard:Destroy() end
    espCache[player] = nil
end

local function getESP(player, character, headOrRoot)
    local data = espCache[player]
    if data and data.Character == character and
        data.Highlight and data.Highlight.Parent and
        data.Billboard and data.Billboard.Parent then
        if data.Billboard.Adornee ~= headOrRoot then
            data.Billboard.Adornee = headOrRoot
        end
        return data
    end
    if data then removeESP(player) end

    local hl = new("Highlight", {
        Name = "AstrendChams_" .. tostring(player.UserId),
        Adornee = character,
        Enabled = false,
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        FillColor = Config.Theme.Accent,
        OutlineColor = Config.Theme.Accent,
        FillTransparency = Config.ESP.FillTransparency / 100,
        OutlineTransparency = 0,
    })
    accent(hl, "FillColor")
    -- Outline segue o mesmo destaque (RGB/verde)
    local billboard = new("BillboardGui", {
        Name = "AstrendTag_" .. tostring(player.UserId),
        Adornee = headOrRoot,
        Size = UDim2.fromOffset(210, 40),
        StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0),
        AlwaysOnTop = true,
        MaxDistance = Config.ESP.MaxDistance,
        Enabled = false,
        ResetOnSpawn = false,
    })
    local nameLabel = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextStrokeTransparency = 0.35,
        Text = player.DisplayName,
    }, billboard)
    local distanceLabel = new("TextLabel", {
        Position = UDim2.fromOffset(0, 22),
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextColor3 = Config.Theme.Accent,
        TextStrokeTransparency = 0.3,
        Text = "",
    }, billboard)
    accent(distanceLabel, "TextColor3")
    data = {
        Character = character,
        Highlight = hl,
        Billboard = billboard,
        NameLabel = nameLabel,
        DistanceLabel = distanceLabel,
    }
    -- Tornar os elementos visiveis somente depois que tudo estiver pronto.
    billboard.Parent = PlayerGui
    hl.Parent = Workspace
    espCache[player] = data
    return data
end

local function isTeammate(player)
    return player.Team ~= nil and LocalPlayer.Team ~= nil and player.Team == LocalPlayer.Team
end

local function renderESP(camera)
    if not Config.ESP.Enabled then
        for player in pairs(espCache) do removeESP(player) end
        return
    end
    local cameraPosition = camera.CFrame.Position
    local color = currentAccent()
    local maxDistance = Config.ESP.MaxDistance
    local activeHighlights = 0
    local createdThisCycle = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not humanoid or not root or
            (Config.ESP.HideDead and humanoid.Health <= 0) or
            (Config.ESP.TeamCheck and isTeammate(player)) then
            removeESP(player)
            continue
        end
        local distance = (cameraPosition - root.Position).Magnitude
        if distance > maxDistance or activeHighlights >= Config.ESP.MaxHighlights then
            removeESP(player)
            continue
        end
        local cached = espCache[player]
        if (not cached or cached.Character ~= character) then
            if createdThisCycle >= Config.ESP.NewPerCycle then
                removeESP(player)
                continue
            end
            createdThisCycle += 1
        end
        local head = character:FindFirstChild("Head")
        local data = getESP(player, character, head or root)
        activeHighlights += 1
        local highlight = data.Highlight
        highlight.Enabled = Config.ESP.ShowChams
        highlight.DepthMode = Config.ESP.ThroughWalls
            and Enum.HighlightDepthMode.AlwaysOnTop
            or Enum.HighlightDepthMode.Occluded
        highlight.FillColor = color
        highlight.OutlineColor = color
        highlight.FillTransparency = Config.ESP.FillTransparency / 100

        data.Billboard.Enabled = Config.ESP.ShowName or Config.ESP.ShowDistance
        data.Billboard.MaxDistance = maxDistance
        data.NameLabel.Visible = Config.ESP.ShowName
        data.DistanceLabel.Visible = Config.ESP.ShowDistance
        if data.NameLabel.Text ~= player.DisplayName then
            data.NameLabel.Text = player.DisplayName
        end
        local label = string.format("~%.0f m", distance * 0.28)
        if data.DistanceLabel.Text ~= label then data.DistanceLabel.Text = label end
    end
end

local function selectTarget(camera)
    local viewport = camera.ViewportSize
    local middle = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
    local best, bestDistance = nil, math.huge
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = LocalPlayer.Character and {LocalPlayer.Character} or {}
    rayParams.IgnoreWater = true
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Config.Aim.TeamCheck and isTeammate(player) then continue end
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local head = character and character:FindFirstChild("Head")
        if not humanoid or humanoid.Health <= 0 or not head then continue end
        local distance = (head.Position - camera.CFrame.Position).Magnitude
        if distance > Config.Aim.MaxDistance then continue end
        local screen, visible = camera:WorldToViewportPoint(head.Position)
        if not visible or screen.Z <= 0 then continue end
        local radius = (Vector2.new(screen.X, screen.Y) - middle).Magnitude
        if radius > Config.Aim.FOV or radius >= bestDistance then continue end
        if Config.Aim.WallCheck then
            local ray = Workspace:Raycast(camera.CFrame.Position, head.Position - camera.CFrame.Position, rayParams)
            if ray and not ray.Instance:IsDescendantOf(character) then continue end
        end
        best = head
        bestDistance = radius
    end
    return best
end

local function renderFly(camera)
    if not Config.Fly.Enabled then return end
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or humanoid.Health <= 0 then return end
    if flyingHumanoid ~= humanoid then
        if flyingHumanoid and flyingHumanoid.Parent then
            flyingHumanoid.PlatformStand = false
            flyingHumanoid.AutoRotate = true
        end
        flyingHumanoid = humanoid
    end
    humanoid.PlatformStand = true
    humanoid.AutoRotate = false
    local vec = Vector3.zero
    local cf = camera.CFrame
    if UIS:IsKeyDown(Enum.KeyCode.W) then vec += cf.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.S) then vec -= cf.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.A) then vec -= cf.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.D) then vec += cf.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.Space) then vec += Vector3.yAxis end
    if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.LeftShift) then vec -= Vector3.yAxis end
    root.AssemblyLinearVelocity = vec.Magnitude > 0 and vec.Unit * Config.Fly.Speed or Vector3.zero
end

local function destroy()
    if not active then return end
    active = false
    setFly(false)
    for _, connection in ipairs(connections) do connection:Disconnect() end
    for player in pairs(espCache) do removeESP(player) end
    if sharedSession.AstrendHubCleanup == destroy then
        sharedSession.AstrendHubCleanup = nil
    end
    gui:Destroy()
end
sharedSession.AstrendHubCleanup = destroy
connect(closeBtn.MouseButton1Click, destroy)
connect(Players.PlayerRemoving, removeESP)
-- Respostas vinculadas ao canal encontrado, inclusive se for criado posteriormente.
connect(ReplicatedStorage.ChildAdded, function(item)
    if item.Name == "AstrendHubAction" then resolveRemote() end
end)
connect(LocalPlayer.CharacterRemoving, function()
    if flyingHumanoid then
        flyingHumanoid.PlatformStand = false
        flyingHumanoid.AutoRotate = true
    end
    flyingHumanoid = nil
end)
connect(UIS.InputBegan, function(input, processed)
    if processed then return end
    if UIS:GetFocusedTextBox() then return end
    if input.KeyCode == Config.Aim.Key then aimHeld = true end
    if input.KeyCode == Config.Fly.Key then
        setFly(not Config.Fly.Enabled)
        refreshControls()
    end
end)
connect(UIS.InputEnded, function(input)
    if input.KeyCode == Config.Aim.Key then aimHeld = false end
end)
local lastAimFOV, lastSilentFOV
connect(RunService.RenderStepped, function(deltaTime)
    if not active or not gui.Parent then return end
    if not (Config.Aim.Enabled or Config.Silent.Enabled or Config.Fly.Enabled or Config.Theme.RGB) then
        if fovCircle.Visible then fovCircle.Visible = false end
        if silentCircle.Visible then silentCircle.Visible = false end
        return
    end
    local camera = Workspace.CurrentCamera
    if not camera then return end

    local showAim = Config.Aim.Enabled and Config.Aim.ShowFOV
    if fovCircle.Visible ~= showAim then fovCircle.Visible = showAim end
    if showAim and lastAimFOV ~= Config.Aim.FOV then
        lastAimFOV = Config.Aim.FOV
        fovCircle.Size = UDim2.fromOffset(lastAimFOV * 2, lastAimFOV * 2)
    end
    local showSilent = Config.Silent.Enabled and Config.Silent.ShowFOV
    if silentCircle.Visible ~= showSilent then silentCircle.Visible = showSilent end
    if showSilent and lastSilentFOV ~= Config.Silent.FOV then
        lastSilentFOV = Config.Silent.FOV
        silentCircle.Size = UDim2.fromOffset(lastSilentFOV * 2, lastSilentFOV * 2)
    end

    if Config.Aim.Enabled and aimHeld then
        local target = selectTarget(camera)
        if target then
            local desired = CFrame.lookAt(camera.CFrame.Position, target.Position)
            local alpha = 1 - math.exp(-deltaTime * (40 / math.max(Config.Aim.Smoothness, 1)))
            camera.CFrame = camera.CFrame:Lerp(desired, math.clamp(alpha, 0, 1))
        end
    end
    if Config.Fly.Enabled then renderFly(camera) end

    if Config.Theme.RGB and os.clock() - lastTheme >= 0.25 then
        lastTheme = os.clock()
        applyAccent()
        refreshControls()
    end
end)

-- ESP fora do RenderStepped. Falhas desativam o recurso e removem objetos.
task.spawn(function()
    while active and gui.Parent do
        if Config.ESP.Enabled or next(espCache) then
            local camera = Workspace.CurrentCamera
            if camera then
                local ok, err = pcall(renderESP, camera)
                if not ok then
                    Config.ESP.Enabled = false
                    for player in pairs(espCache) do removeESP(player) end
                    refreshControls()
                    warn("[ASTREND] ESP desativado: " .. tostring(err))
                    setStatus("ESP interrompido por erro. Veja o console.", Color3.fromRGB(255, 181, 91))
                end
            end
        end
        task.wait(math.max(0.5, 1 / math.max(Config.ESP.UpdateRate, 1)))
    end
end)


applyAccent()
if resolveRemote() then
    setStatus("Canal ASTREND encontrado. Verifique o acesso em Settings.", Config.Theme.Accent)
else
    setStatus("HUD ativo. Vida, fome, sede e God Mode indisponiveis neste servidor.")
end
print("[ASTREND] Hub v2.5 iniciado. ESP limitado e varreduras otimizadas.")