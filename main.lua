                    DepthMode = Enum.HighlightDepthMode.Occluded,
                }, dummy)
                highlights[dummy] = hl
            end
        elseif highlights[dummy] then
            highlights[dummy]:Destroy()
            highlights[dummy] = nil
        end
        if Config.Training.Names then
            if not highlightLabels[dummy] then
                local bb = make("BillboardGui", {
                    Name = "AstrendTrainingName",
                    Adornee = part,
                    Size = UDim2.fromOffset(190, 32),
                    StudsOffset = Vector3.new(0, 3, 0),
                    AlwaysOnTop = false,
                }, gui)
                local lbl = textLabel(bb, dummy.Name, 12, Palette.Text, Enum.Font.GothamBold, {
                    Size = UDim2.fromScale(1, 1),
                    TextXAlignment = Enum.TextXAlignment.Center,
                    TextStrokeTransparency = 0.3,
                })
                highlightLabels[dummy] = bb
            end
            local lbl = highlightLabels[dummy]:FindFirstChildWhichIsA("TextLabel")
            if lbl then lbl.Text = string.format("%s  |  %.0f studs", dummy.Name, dist) end
        elseif highlightLabels[dummy] then
            highlightLabels[dummy]:Destroy()
            highlightLabels[dummy] = nil
        end
    end
    for model, hl in pairs(highlights) do
        if not seen[model] then hl:Destroy(); highlights[model] = nil end
    end
    for model, bb in pairs(highlightLabels) do
        if not seen[model] then bb:Destroy(); highlightLabels[model] = nil end
    end
end

local frameCounter = 0
local tickCounter = 0
local visualTimer = 0
local themeTimer = 0
local framesPerSecond = 60
connect(RunService.RenderStepped, function(dt)
    if closed then return end
    frameCounter += 1
    tickCounter += dt
    visualTimer += dt
    themeTimer += dt

    if tickCounter >= 0.40 then
        framesPerSecond = math.floor(frameCounter / tickCounter + 0.5)
        frameCounter = 0
        tickCounter = 0
        if Config.Performance.FPS and Config.Performance.Coordinates then
            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local p = root.Position
                footerStatus.Text = string.format("%d FPS  |  X %.0f  Y %.0f  Z %.0f", framesPerSecond, p.X, p.Y, p.Z)
            else
                footerStatus.Text = string.format("%d FPS  |  Personagem não carregado", framesPerSecond)
            end
        elseif Config.Performance.FPS then
            footerStatus.Text = string.format("%d FPS", framesPerSecond)
        elseif Config.Performance.Coordinates then
            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            footerStatus.Text = root and string.format("X %.0f  Y %.0f  Z %.0f", root.Position.X, root.Position.Y, root.Position.Z) or "Sem personagem"
        else
            footerStatus.Text = "RightShift: mostrar / ocultar"
        end
        if playerInfoDescription then
            playerInfoDescription.Text = string.format("Usuário: %s  |  FPS: %d  |  Studio: %s", LocalPlayer.Name, framesPerSecond, RunService:IsStudio() and "Sim" or "Não")
        end
    end

    if Config.RGB and themeTimer >= 0.04 then
        themeTimer = 0
        currentAccent = Color3.fromHSV((os.clock() * Config.RGBSpeed) % 1, 1, 1)
        refreshAccent()
    end

    if visualTimer >= 0.35 then
        visualTimer = 0
        updateTrainingVisuals()
    end

    if isTrainingAvailable() and Config.Training.Enabled and aimHeld then
        local camera = Workspace.CurrentCamera
        if camera then
            local part = getTrainingTarget(camera)
            if part then
                local cameraPos = camera.CFrame.Position
                local goal = CFrame.lookAt(cameraPos, part.Position)
                local alpha = math.clamp(dt * (35 / Config.Training.Smoothness), 0, 1)
                camera.CFrame = camera.CFrame:Lerp(goal, alpha)
            end
        end
    end
end)

refreshAccent()
print("[ASTREND HUB] Studio Edition carregada com segurança.")
