-- Garou Complete Boss Engine (With Advanced VFX Injection)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")
local PlayerGui = Player:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

-- ============================================================================
-- 1. HOTBAR TEXT CONFIGURATION MAP
-- ============================================================================
local moveNames = {
    ["1"] = "Phantom Fangs",
    ["2"] = "Shadow Maul",
    ["3"] = "Grudge Break",
    ["4"] = "Shadow Reflex"
}

-- ============================================================================
-- 2. VERIFIED ANIMATION CACHE MAPPING
-- ============================================================================
local Anims = {
    Spawn = "rbxassetid://18715986914",
    M1_1 = "rbxassetid://18715994424",
    TwinFangs = "rbxassetid://18896229321",
    RisingFist = "rbxassetid://18896127525",
    CosmicStrike = "rbxassetid://16737255386",
    JetDriveLand = "rbxassetid://12684390285",
    TwinFangsMiss = "rbxassetid://18896124320",
    DummyAttack = "rbxassetid://18440389930",
    DummyVictim = "rbxassetid://18717298618"
}

local LoadedTracks = {}
local Animator = Humanoid:WaitForChild("Animator")

local function PlayAnimation(name, priority, speed)
    if not Anims[name] then return end
    if not LoadedTracks[name] then
        local animInstance = Instance.new("Animation")
        animInstance.AnimationId = Anims[name]
        local success, track = pcall(function()
            return Animator:LoadAnimation(animInstance)
        end)
        if success then LoadedTracks[name] = track else return nil end
    end
    if priority then LoadedTracks[name].Priority = priority end
    LoadedTracks[name]:Play()
    if speed then LoadedTracks[name]:AdjustSpeed(speed) end
    return LoadedTracks[name]
end

-- ============================================================================
-- 3. ADVANCED GAME REPLICATED VFX DEPLOYER
-- ============================================================================
local function DeployVFX(vfxType, burstCount)
    local targetSource = nil
    
    pcall(function()
        if vfxType == "HunterMode" then
            targetSource = workspace.Live:FindFirstChild(Player.Name).HumanoidRootPart:FindFirstChild("HunterMode")
        elseif vfxType == "BigAura" then
            targetSource = game.ReplicatedStorage.Emotes.VFX.VfxMods.FS.vfx.BigAuraFx.Attachment
        elseif vfxType == "LastImpact" then
            targetSource = game.ReplicatedStorage.Emotes.VFX.VfxMods.Flasher.vfx.LastImpactFx.Attachment
        elseif vfxType == "BlackFlash" then
            targetSource = game.ReplicatedStorage.Emotes.VFX.VfxMods.Flasher.vfx.BlackFlashFx.Main
        elseif vfxType == "HugeSlash" then
            targetSource = game.ReplicatedStorage.Emotes.VFX.RealAssets.HugeSlash.SLASH.M
        end
    end)
    
    if targetSource then
        local clonedVFX = targetSource:Clone()
        clonedVFX.Parent = RootPart
        
        -- Emit particles dynamically
        for _, child in ipairs(clonedVFX:GetChildren()) do
            if child:IsA("ParticleEmitter") then
                child:Emit(burstCount or 15)
                child.Enabled = true
            end
        end
        
        -- Auto clean up to maintain performance stability
        game:GetService("Debris"):AddItem(clonedVFX, 2.5)
        return clonedVFX
    end
end

-- ============================================================================
-- 4. STATE CONTROLS, TARGETING & UTILITIES
-- ============================================================================
local CurrentTarget = nil
local LockOnActive = false
local IsExecutingCombo = false
local CounterCooldown = 12
local CounterRadius = 8
local LastCounterTime = 0
local IsCountering = false

local function GetClosestEnemy()
    local closestEnemy = nil
    local maxDistance = 100
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (RootPart.Position - p.Character.HumanoidRootPart.Position).Magnitude
            if distance < maxDistance then
                maxDistance = distance
                closestEnemy = p.Character
            end
        end
    end
    return closestEnemy
end

RunService.RenderStepped:Connect(function()
    if LockOnActive and CurrentTarget and CurrentTarget:FindFirstChild("HumanoidRootPart") then
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, CurrentTarget.HumanoidRootPart.Position)
    else
        LockOnActive = false
    end
end)

local function LocalCameraShake(duration, intensity)
    task.spawn(function()
        local startTime = os.clock()
        while os.clock() - startTime < duration do
            Camera.CFrame = Camera.CFrame * CFrame.new(math.random(-intensity, intensity) / 100, math.random(-intensity, intensity) / 100, 0)
            RunService.RenderStepped:Wait()
        end
    end)
end

-- ============================================================================
-- 5. INTEGRATED RUN TOOL INITIALIZATION
-- ============================================================================
local runTool = Instance.new("Tool")
runTool.Name = "Run Tool"
runTool.Parent = Player:WaitForChild("Backpack")
runTool.RequiresHandle = false

local isRunningWithTool = false
local toolMovementSpeed = 125
local runToolAnim = Instance.new("Animation")
runToolAnim.AnimationId = "rbxassetid://18897115785"
local runToolTrack

local function moveForwardLoop()
    while isRunningWithTool do
        if RootPart then
            RootPart.Velocity = RootPart.CFrame.LookVector * toolMovementSpeed
            -- Continuous trailing aura burst when sprinting at high speeds
            DeployVFX("HunterMode", 2)
        end
        RunService.Stepped:Wait()
    end
end

runTool.Equipped:Connect(function()
    isRunningWithTool = true
    runToolTrack = Animator:LoadAnimation(runToolAnim)
    runToolTrack:Play()
    task.spawn(moveForwardLoop)
end)

runTool.Unequipped:Connect(function()
    isRunningWithTool = false
    if runToolTrack then runToolTrack:Stop() end
end)

-- ============================================================================
-- 6. COMBAT SEQUENCES WITH EMBEDDED VFX INCORPORATED
-- ============================================================================
local function TriggerMove1()
    if IsExecutingCombo or IsCountering then return end
    IsExecutingCombo = true
    local fangs = PlayAnimation("TwinFangs", Enum.AnimationPriority.Action)
    task.wait(1.25)
    if fangs then fangs:Stop() end
    
    -- Hit impact point sparks HugeSlash
    DeployVFX("HugeSlash", 20)
    local fist = PlayAnimation("RisingFist", Enum.AnimationPriority.Action, 1.5)
    LocalCameraShake(0.5, 12)
    if fist then fist.Ended:Wait() end
    IsExecutingCombo = false
end

local function TriggerMove2()
    if IsExecutingCombo or IsCountering then return end
    IsExecutingCombo = true
    
    -- Upward blast effect
    DeployVFX("LastImpact", 15)
    RootPart.AssemblyLinearVelocity = Vector3.new(0, 55, 0)
    task.wait(0.1)
    local strike = PlayAnimation("CosmicStrike", Enum.AnimationPriority.Action)
    LocalCameraShake(1.0, 18)
    if strike then strike.Ended:Wait() end
    IsExecutingCombo = false
end

local function TriggerMove3()
    if IsExecutingCombo or IsCountering then return end
    IsExecutingCombo = true
    local jet = PlayAnimation("JetDriveLand", Enum.AnimationPriority.Action)
    if jet then jet.Ended:Wait() end
    
    -- Ground crush point fires BlackFlash particles
    DeployVFX("BlackFlash", 25)
    local miss = PlayAnimation("TwinFangsMiss", Enum.AnimationPriority.Action)
    LocalCameraShake(0.6, 10)
    if miss then miss.Ended:Wait() end
    IsExecutingCombo = false
end

local function TriggerCounter()
    if IsCountering or IsExecutingCombo then return end
    local currentTime = os.clock()
    if (currentTime - LastCounterTime) < CounterCooldown then
        local escapeVector = RootPart.CFrame.RightVector * (math.random(1, 2) == 1 and 25 or -25)
        RootPart.CFrame = RootPart.CFrame * CFrame.new(escapeVector.X, 0, escapeVector.Z)
        LocalCameraShake(0.2, 5)
        return
    end
    IsCountering = true
    LastCounterTime = currentTime
    RootPart.Anchored = true
    
    -- Stance activation fires BigAura explosion
    DeployVFX("BigAura", 30)
    local activeStance = PlayAnimation("DummyAttack", Enum.AnimationPriority.Action)
    task.wait(0.4)
    RootPart.Anchored = false
    if activeStance then activeStance:Stop() end
    
    PlayAnimation("DummyVictim", Enum.AnimationPriority.Action)
    LocalCameraShake(0.8, 22)
    local enemy = GetClosestEnemy()
    if enemy and enemy:FindFirstChild("HumanoidRootPart") then
        enemy.HumanoidRootPart.AssemblyLinearVelocity = (enemy.HumanoidRootPart.Position - RootPart.Position).Unit * 60 + Vector3.new(0, 20, 0)
    end
    task.wait(0.8)
    IsCountering = false
end

local function TriggerBackflip()
    DeployVFX("HunterMode", 5)
    RootPart.AssemblyLinearVelocity = (RootPart.CFrame.LookVector * -45) + Vector3.new(0, 32, 0)
end

local function TriggerFrontflip()
    DeployVFX("HunterMode", 5)
    RootPart.AssemblyLinearVelocity = (RootPart.CFrame.LookVector * 45) + Vector3.new(0, 32, 0)
end

-- ============================================================================
-- 7. NATIVE HOTBAR HOOK INJECTION ENGINE (From Template Layout)
-- ============================================================================
task.spawn(function()
    while Humanoid.Health > 0 do
        local hotbar = PlayerGui:FindFirstChild("Hotbar")
        if hotbar then
            local backpack = hotbar:FindFirstChild("Backpack")
            if backpack then
                local hotbarFrame = backpack:FindFirstChild("Hotbar")
                if hotbarFrame then
                    for buttonName, newName in pairs(moveNames) do
                        local buttonSlot = hotbarFrame:FindFirstChild(buttonName)
                        local baseButton = buttonSlot and buttonSlot:FindFirstChild("Base")
                        if baseButton then
                            local toolName = baseButton:FindFirstChild("ToolName")
                            if toolName and toolName.Text ~= newName then
                                toolName.Text = newName
                            end
                            
                            local buttonGui = baseButton:FindFirstChild("Button") or baseButton:FindFirstChildOfClass("GuiButton")
                            if buttonGui and not buttonGui:GetAttribute("Hooked") then
                                buttonGui:SetAttribute("Hooked", true)
                                buttonGui.MouseButton1Click:Connect(function()
                                    if buttonName == "1" then task.spawn(TriggerMove1)
                                    elseif buttonName == "2" then task.spawn(TriggerMove2)
                                    elseif buttonName == "3" then task.spawn(TriggerMove3)
                                    elseif buttonName == "4" then task.spawn(TriggerCounter)
                                    end
                                end)
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.2)
    end
end)

-- ============================================================================
-- 8. INTERCEPTS & CONTROL OVERLAYS
-- ============================================================================
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.One then task.spawn(TriggerMove1)
    elseif input.KeyCode == Enum.KeyCode.Two then task.spawn(TriggerMove2)
    elseif input.KeyCode == Enum.KeyCode.Three then task.spawn(TriggerMove3)
    elseif input.KeyCode == Enum.KeyCode.Four then task.spawn(TriggerCounter)
    elseif input.KeyCode == Enum.KeyCode.Q then
        LockOnActive = not LockOnActive
        if LockOnActive then CurrentTarget = GetClosestEnemy() else CurrentTarget = nil end
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
        PlayAnimation("M1_1", Enum.AnimationPriority.Action)
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GarouUtilityHUD"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

local Container = Instance.new("Frame")
Container.Size = UDim2.new(0, 230, 0, 120)
Container.Position = UDim2.new(1, -250, 0.15, 0)
Container.BackgroundTransparency = 1
Container.Parent = ScreenGui

local function CreateMobileButton(name, position, color, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 100, 0, 45)
    button.Position = position
    button.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    button.TextColor3 = color
    button.Text = name
    button.Font = Enum.Font.GothamBold
    button.TextSize = 11
    button.Parent = Container
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = 1.5
    stroke.Parent = button
    button.Activated:Connect(callback)
end

local Crimson = Color3.fromRGB(255, 50, 50)
CreateMobileButton("LOCK ON", UDim2.new(0, 0, 0, 0), Crimson, function()
    LockOnActive = not LockOnActive
    if LockOnActive then CurrentTarget = GetClosestEnemy() else CurrentTarget = nil end
end)
CreateMobileButton("B-FLIP", UDim2.new(0, 115, 0, 0), Crimson, TriggerBackflip)
CreateMobileButton("F-FLIP", UDim2.new(0, 0, 0, 55), Crimson, TriggerFrontflip)

-- ============================================================================
-- 9. AUTOMATED PROXIMITY DEFENSE LOOP
-- ============================================================================
task.spawn(function()
    while task.wait(0.1) do
        if not IsCountering and not IsExecutingCombo and Character and Character:FindFirstChild("HumanoidRootPart") then
            for _, enemy in ipairs(Players:GetPlayers()) do
                if enemy ~= Player and enemy.Character and enemy.Character:FindFirstChild("HumanoidRootPart") and enemy.Character:FindFirstChild("Humanoid") then
                    if (RootPart.Position - enemy.Character.HumanoidRootPart.Position).Magnitude <= CounterRadius then
                        if (enemy.Character.Humanoid.FloorMaterial == Enum.Material.Air and enemy.Character.HumanoidRootPart.AssemblyLinearVelocity.Magnitude > 30) or enemy.Character:FindFirstChildOfClass("Tool") then
                            TriggerCounter()
                            break
                        end
                    end
                end
            end
        end
    end
end)

task.wait(0.2)
DeployVFX("HunterMode", 10)
PlayAnimation("Spawn", Enum.AnimationPriority.Action)
