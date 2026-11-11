-- AstrendHeistBypass.lua | Luau | Roblox executor | harness de bypass para remotes de dinheiro/cofre

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Workspace  = game:GetService("Workspace")
local LP         = Players.LocalPlayer
local Camera     = Workspace.CurrentCamera

-- ============================================
-- CONFIG — preencha com o que o sniffer mostrou
-- ============================================
local CONFIG = {
    -- Caminho completo do remote (ex: "ReplicatedStorage.Remotes.ClaimMoney")
    RemotePath = "ReplicatedStorage.Remotes.ClaimMoney",

    -- Posição do cofre/área onde o server espera que você esteja
    -- Pode ser o nome do BasePart do cofre em Workspace, ou um Vector3 fixo
    VaultPartName = "CashVault", -- será buscado em Workspace
    VaultPosition = nil,         -- se preencher, sobrepõe o VaultPartName

    -- Se o server checa distância usando LP.Character.HRP, use teleport temporário
    -- Se o server checa usando o argumento, use spoof de argumento (padrão)
    UseTeleport = false,

    -- Quantas vezes disparar
    LoopCount = 20,
    LoopDelay = 0.15,

    -- Auto-encontra remotes suspeitos se RemotePath estiver vazio
    AutoFind = false,
}

-- ============================================
-- LOCALIZAR REMOTE
-- ============================================
local function resolvePath(path)
    local parts = {}
    for seg in path:gmatch("[^%.]+") do table.insert(parts, seg) end
    local cur = game
    for i, p in ipairs(parts) do
        cur = cur:FindFirstChild(p)
        if not cur then return nil end
    end
    return cur
end

local function findRemote()
    if CONFIG.RemotePath and CONFIG.RemotePath ~= "" then
        return resolvePath(CONFIG.RemotePath)
    end
    if not CONFIG.AutoFind then return nil end
    -- procura qualquer RemoteEvent com nome suspeito em ReplicatedStorage
    local keys = {"money","cash","claim","reward","take","grab","collect","heist","vault","rob","dirty"}
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local low = obj.Name:lower()
            for _, k in ipairs(keys) do
                if low:find(k, 1, true) then
                    print("[bypass] suspeito:", obj:GetFullName())
                end
            end
        end
    end
    return nil
end

local remote = findRemote()
if not remote then
    warn("[bypass] remote não encontrado. Rode o sniffer e atualize CONFIG.RemotePath.")
    return
end
print("[bypass] usando remote:", remote:GetFullName())

-- ============================================
-- OBTER POSIÇÃO DO COFRE
-- ============================================
local function getVaultPos()
    if CONFIG.VaultPosition then return CONFIG.VaultPosition end
    local p = Workspace:FindFirstChild(CONFIG.VaultPartName, true)
    if p and p:IsA("BasePart") then
        return p.Position
    end
    warn("[bypass] VaultPart não encontrado; usando posição do jogador como fallback")
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position or Vector3.zero
end

-- ============================================
-- FORJA DE ARGUMENTOS
-- ============================================
-- Substitui qualquer BasePart/Vector3/CFrame nos args pela posição do cofre
local function forgeArgs(origArgs, vaultPos)
    local out = {}
    for i, a in ipairs(origArgs) do
        local t = typeof(a)
        if t == "Vector3" then
            out[i] = vaultPos
        elseif t == "CFrame" then
            out[i] = CFrame.new(vaultPos)
        elseif t == "Instance" and a:IsA("BasePart") then
            -- tenta mover a própria parte (server usa a referência)
            -- se for parte de outro jogador, apenas substitui por referência do cofre
            out[i] = a
        else
            out[i] = a
        end
    end
    return out
end

-- ============================================
-- TELEPORT TEMPORÁRIO (para validação HRP)
-- ============================================
local function tempTeleport(targetPos, duration)
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum = LP.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local savedCFrame = hrp.CFrame
    hum:ChangeState(Enum.HumanoidStateType.Physics)
    hrp.CFrame = CFrame.new(targetPos)

    task.wait(duration or 0.05)

    hrp.CFrame = savedCFrame
    hum:ChangeState(Enum.HumanoidStateType.Running)
end

-- ============================================
-- DISPARAR
-- ============================================
local function fireWithArgs(args)
    local ok, err = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(table.unpack(args))
        elseif remote:IsA("RemoteFunction") then
            return remote:InvokeServer(table.unpack(args))
        end
    end)
    if not ok then warn("[bypass] fire err:", err) end
end

-- ============================================
-- EXECUÇÃO
-- ============================================
local vaultPos = getVaultPos()
print(string.format("[bypass] vault pos: (%.1f, %.1f, %.1f)", vaultPos.X, vaultPos.Y, vaultPos.Z))

-- Args iniciais: começa com um disparo falso pra capturar a assinatura original
-- Se você já sabe os args, defina aqui:
local baseArgs = {}
-- Exemplos:
-- baseArgs = { vaultPos }
-- baseArgs = { vaultPos, "Cash" }
-- baseArgs = { 500 }

-- Se quiser capturar automaticamente a última chamada, rode o sniffer primeiro e preencha baseArgs.

local function run()
    for i = 1, CONFIG.LoopCount do
        local forged = forgeArgs(baseArgs, vaultPos)
        if CONFIG.UseTeleport then
            task.spawn(tempTeleport, vaultPos, 0.05)
            task.wait(0.06)
        end
        fireWithArgs(forged)
        task.wait(CONFIG.LoopDelay)
    end
    print(string.format("[bypass] done, %d fires", CONFIG.LoopCount))
end

-- bind: F9 no executor ou uma tecla no jogo
UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.F9 then
        print("[bypass] triggered via F9")
        run()
    end
end)

print("[bypass] ready. Press F9 in-game to fire, or call run() from console.")
_G.AstrendBypass = { run = run, fireWithArgs = fireWithArgs, forgeArgs = forgeArgs }
