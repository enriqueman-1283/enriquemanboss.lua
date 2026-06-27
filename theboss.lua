-- Unified Garou Cross-Platform Core (With Auto-Counter & Position Repositioning)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")
local PlayerGui = Player:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

-- 1. EXTENDED ANIMATION SET
local Anims = {
    Idle = "rbxassetid://18893376101",
    Spawn = "rbxassetid://18715986914",
    M1_1 = "rbxassetid://18715994424",
    Backflip = "rbxassetid://18893417968", 
    Frontflip = "rbxassetid://18893412159",
    UltStart = "rbxassetid://12463072679",
    UltBarrage = "rbxassetid://12467789963",
    UltFinisher = "rbxassetid://12460977270",
    
    -- Counter Animation mapping requested (Using Weakest Dummy Attack/Victim framework)
    CounterStance = "rbxassetid://18440389930",
    CounterExecution = "rbxassetid://18717298618"
}

local LoadedTracks = {}
local Animator = Humanoid:WaitForChild("Animator")

local function PlayAnimation(name, priority)
    if not Anims[name] then return end
    if not LoadedTracks[name] then
        local animInstance = Instance.new("Animation")
        animInstance.AnimationId = Anims[name]
        local success, track = pcall(function()
            return Animator:LoadAnimation(animInstance)
        end)
        if success then
            LoadedTracks[name] = track
            if priority then track.Priority = priority end
        else
            return nil
        end
    end
    LoadedTracks[name]:Play()
    return LoadedTracks[name]
end

-- 2. MECHANICS & CORE STATES
local CurrentTarget = nil
local LockOnActive = false
local RunningActive = false
local UltActive = false

-- Counter configuration values
local CounterCooldown = 12 -- Cooldown time in seconds
local CounterRadius = 8 -- Tight, small perimeter bubble around your character
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

-- Camera Target Tracking
RunService.RenderStepped:Connect(function()
    if LockOnActive and CurrentTarget and CurrentTarget:FindFirstChild("HumanoidRootPart") then
        local targetPos = CurrentTarget.HumanoidRootPart.Position
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
    else
        LockOnActive = false
    end
end)

-- 3. INTERACTIVE ACTIONS & COMBAT ENGINE
local function ToggleLockOn()
    if LockOnActive then
        LockOnActive = false
        CurrentTarget = nil
    else
        local target = GetClosestEnemy()
        if target then
            CurrentTarget = target
            LockOnActive = true
        end
    end
end

local function ToggleRun()
    RunningActive = not RunningActive
    Humanoid.WalkSpeed = RunningActive and 28 or 16
end

local function TriggerBackflip()
    PlayAnimation("Backflip", Enum.AnimationPriority.Action)
    RootPart.AssemblyLinearVelocity = (RootPart.CFrame.LookVector * -40) + Vector3.new(0, 30, 0)
end

local function TriggerFrontflip()
    PlayAnimation("Frontflip", Enum.AnimationPriority.Action)
    RootPart.AssemblyLinearVelocity = (RootPart.CFrame.LookVector * 40) + Vector3.new(0, 30, 0)
end

local function LocalCameraShake(duration, intensity)
    task.spawn(function()
        local startTime = os.clock()
        while os.clock() - startTime < duration do
            local x = math.random(-intensity, intensity) / 100
            local y = math.random(-intensity, intensity) / 100
            local z = math.random(-intensity, intensity) / 100
            Camera.CFrame = Camera.CFrame * CFrame.new(x, y, z)
            RunService.RenderStepped:Wait()
        end
    end)
end

-- Ultimate Hunter Chain Sequence
local function TriggerUltimate()
    if UltActive or IsCountering then return end
    UltActive = true
    
    local startTrack = PlayAnimation("UltStart", Enum.AnimationPriority.Action)
    LocalCameraShake(1.5, 15)
    if startTrack then startTrack.Ended:Wait() end
    
    local barrageTrack = PlayAnimation("UltBarrage", Enum.AnimationPriority.Action)
    LocalCameraShake(2.5, 8)
    
    for i = 1, 5 do
        RootPart.AssemblyLinearVelocity = RootPart.CFrame.LookVector * 35
        task.wait(0.4)
    end
    if barrageTrack then barrageTrack.Ended:Wait() end
    
    PlayAnimation("UltFinisher", Enum.AnimationPriority.Action)
    LocalCameraShake(1.2, 35)
    
    task.wait(1.5)
    UltActive = false
end

-- 4. SPATIAL PROXIMITY DETECTION & COUNTER ENGINE
task.spawn(function()
    while task.wait(0.1) do
        if not IsCountering and not UltActive and Character and Character:FindFirstChild("HumanoidRootPart") then
            -- Loop through nearby entities to look for incoming threats
            for _, enemy in ipairs(Players:GetPlayers()) do
                if enemy ~= Player and enemy.Character and enemy.Character:FindFirstChild("HumanoidRootPart") and enemy.Character:FindFirstChild("Humanoid") then
                    local enemyRoot = enemy.Character.HumanoidRootPart
                    local enemyHumanoid = enemy.Character.Humanoid
                    local currentDistance = (RootPart.Position - enemyRoot.Position).Magnitude
                    
                    -- Check if they are inside our micro-perimeter bubble
                    if currentDistance <= CounterRadius then
                        -- Check if they are attempting an M1 attack or tool strike
                        local isAttacking = (enemyHumanoid.FloorMaterial == Enum.Material.Air and enemyRoot.AssemblyLinearVelocity.Magnitude > 30) or (enemy.Character:FindFirstChildOfClass("Tool"))
                        
                        if isAttacking then
                            local currentTime = os.clock()
                            
                            -- CHOICE A: Counter is ready to activate
                            if (currentTime - LastCounterTime) >= CounterCooldown then
                                IsCountering = true
                                LastCounterTime = currentTime
                                
                                -- Phase 1: Enter stance & trap position
                                RootPart.Anchored = true
                                local stanceTrack = PlayAnimation("CounterStance", Enum.AnimationPriority.Action)
                                LocalCameraShake(0.4, 10)
                                task.wait(0.3)
                                
                                -- Phase 2: Unleash counter execution payload
                                RootPart.Anchored = false
                                if stanceTrack then stanceTrack:Stop() end
                                
                                PlayAnimation("CounterExecution", Enum.AnimationPriority.Action)
                                LocalCameraShake(0.8, 25)
                                
                                -- Push the aggressive entity backward via directional velocity
                                local pullVector = (enemyRoot.Position - RootPart.Position).Unit
                                enemyRoot.AssemblyLinearVelocity = (pullVector * 65) + Vector3.new(0, 20, 0)
                                
                                task.wait(1.0)
                                IsCountering = false
                                break
                                
                            -- CHOICE B: Counter on cooldown, execute an evasive reposition shift
                            else
                                -- Pick a lateral evasion vector (Left or Right out of range)
                                local escapeVector = RootPart.CFrame.RightVector * (math.random(1, 2) == 1 and 25 or -25)
                                RootPart.CFrame = RootPart.CFrame * CFrame.new(escapeVector.X, 0, escapeVector.Z)
                                LocalCameraShake(0.2, 5)
                                task.wait(0.5) -- Mini internal buffer to avoid jittering loops
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- 5. MOBILE USER INTERFACE
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GarouParryFramework"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

local Container = Instance.new("Frame")
Container.Size = UDim2.new(0, 220, 0, 260)
Container.Position = UDim2.new(1, -240, 0.4, -100)
Container.BackgroundTransparency = 1
Container.Parent = ScreenGui

local function CreateMobileButton(name, position, color, callback)
    local button = Instance.new("TextButton")
    button.Name = name .. "Btn"
    button.Size = UDim2.new(0, 95, 0, 45)
    button.Position = position
    button.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
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

local Red = Color3.fromRGB(255, 60, 60)
local Orange = Color3.fromRGB(255, 140, 0)

CreateMobileButton("LOCK ON", UDim2.new(0, 0, 0, 0), Red, ToggleLockOn)
CreateMobileButton("RUN", UDim2.new(0, 110, 0, 0), Red, ToggleRun)
CreateMobileButton("B-FLIP", UDim2.new(0, 0, 0, 55), Red, TriggerBackflip)
CreateMobileButton("F-FLIP", UDim2.new(0, 110, 0, 55), Red, TriggerFrontflip)
CreateMobileButton("THE FINAL HUNT", UDim2.new(0, 0, 0, 120), Orange, TriggerUltimate)
Container.UltimateBtn.Size = UDim2.new(0, 205, 0, 50)
Container.UltimateBtn.TextSize = 14

-- 6. DESKTOP KEYBIND INTEGRATION
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Q then
        ToggleLockOn()
    elseif input.KeyCode == Enum.KeyCode.LeftShift then
        ToggleRun()
    elseif input.KeyCode == Enum.KeyCode.G then
        TriggerUltimate()
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
        PlayAnimation("M1_1", Enum.AnimationPriority.Action)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.LeftShift and RunningActive then
        ToggleRun()
    end
end)

task.wait(0.2)
PlayAnimation("Spawn", Enum.AnimationPriority.Action)
