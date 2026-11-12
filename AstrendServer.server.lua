-- AstrendServer.server.lua | Luau | Roblox ServerScriptService | ASTREND HUB v2.0
-- Instale somente numa experiencia Roblox que voce controla.
-- Em experiencias pessoais, o proprio CreatorId e autorizado automaticamente.
-- Em experiencias de grupo, adicione os UserIds dos administradores em EXTRA_ADMINS.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EXTRA_ADMINS = {
    -- [123456789] = true, -- Use somente em experiencia administrada por voce.
}
local REMOTE_NAME = "AstrendHubAction"
local CHECK_PERIOD = 0.2

local remote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
if not remote then
    remote = Instance.new("RemoteEvent")
    remote.Name = REMOTE_NAME
    remote.Parent = ReplicatedStorage
end
assert(remote:IsA("RemoteEvent"), "[ASTREND] AstrendHubAction deve ser RemoteEvent")

local state = {}
local rateLimit = {}

local function authorized(player)
    if EXTRA_ADMINS[player.UserId] == true then return true end
    return game.CreatorType == Enum.CreatorType.User and game.CreatorId == player.UserId
end

local function ensureState(player)
    if not state[player] then
        state[player] = {
            GodMode = false,
            AutoHeal = false,
            HealThreshold = 35,
            InfiniteAmmo = false,
            Healing = false,
        }
    end
    return state[player]
end

local function getHumanoid(player)
    local character = player.Character
    if not character then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return nil end
    return humanoid
end

local function heal(player)
    local humanoid = getHumanoid(player)
    if not humanoid then return false end
    humanoid.Health = humanoid.MaxHealth
    return true
end

local function applyAmmo(player)
    -- Compatibilidade com armas que armazenam quantidade em ValueObjects da Tool.
    -- Sistemas customizados podem usar armazenamento e validacao proprios.
    local character = player.Character
    local backpack = player:FindFirstChildOfClass("Backpack")
    for _, container in ipairs({character, backpack}) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") then
                    for _, obj in ipairs(tool:GetDescendants()) do
                        if (obj:IsA("IntValue") or obj:IsA("NumberValue")) then
                            local lower = obj.Name:lower()
                            if lower == "ammo" or lower == "currentammo" or
                                lower == "magazine" or lower == "bullets" or
                                lower == "municao" then
                                obj.Value = 999
                            end
                        end
                    end
                end
            end
        end
    end
end

local function applyLevel(player, level)
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then return false end
    for _, item in ipairs(leaderstats:GetChildren()) do
        local lower = item.Name:lower()
        if (lower == "level" or lower == "nivel" or lower == "nível") and
            (item:IsA("IntValue") or item:IsA("NumberValue")) then
            item.Value = level
            return true
        end
    end
    return false
end

remote.OnServerEvent:Connect(function(player, action, value)
    if not authorized(player) then return end
    if type(action) ~= "string" or #action > 32 then return end

    local now = os.clock()
    if now - (rateLimit[player] or 0) < 0.1 then return end
    rateLimit[player] = now

    local config = ensureState(player)
    if action == "HealNow" then
        heal(player)
    elseif action == "GodMode" and type(value) == "boolean" then
        config.GodMode = value
        if value then heal(player) end
    elseif action == "AutoHeal" and type(value) == "table" then
        if type(value.Enabled) == "boolean" then
            config.AutoHeal = value.Enabled
        end
        if type(value.Threshold) == "number" and value.Threshold == value.Threshold then
            config.HealThreshold = math.clamp(math.floor(value.Threshold), 10, 90)
        end
    elseif action == "HealThreshold" and type(value) == "number" then
        if value == value then
            config.HealThreshold = math.clamp(math.floor(value), 10, 90)
        end
    elseif action == "InfiniteAmmo" and type(value) == "boolean" then
        config.InfiniteAmmo = value
        if value then applyAmmo(player) end
    elseif action == "SetLevel" and type(value) == "number" then
        if value == value and value >= 1 and value <= 999 then
            applyLevel(player, math.floor(value))
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    state[player] = nil
    rateLimit[player] = nil
end)

-- Tratamento no servidor: cliente nao concede vida permanente por conta propria.
task.spawn(function()
    while true do
        for player, config in pairs(state) do
            if player.Parent == Players and authorized(player) then
                local humanoid = getHumanoid(player)
                if humanoid then
                    if config.GodMode then
                        if humanoid.Health < humanoid.MaxHealth then
                            humanoid.Health = humanoid.MaxHealth
                        end
                    elseif config.AutoHeal and humanoid.MaxHealth > 0 then
                        local percentage = humanoid.Health / humanoid.MaxHealth * 100
                        if percentage <= config.HealThreshold then
                            humanoid.Health = humanoid.MaxHealth
                        end
                    end
                end
                if config.InfiniteAmmo then applyAmmo(player) end
            end
        end
        task.wait(CHECK_PERIOD)
    end
end)

print("[ASTREND] Canal de administracao iniciado; validacao por UserId ativa.")