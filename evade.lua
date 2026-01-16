-- ================= CLEAN UI =================
pcall(function()
    game.CoreGui.ScriptBoxSimpleLabel:Destroy()
end)

-- ================= SERVICES =================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local joinEvent = ReplicatedStorage
    :WaitForChild("Events")
    :WaitForChild("Player")
    :WaitForChild("ChangePlayerMode")

-- ================= SETTINGS =================
local BLOCK_SIZE = Vector3.new(20, 1, 20)
local HEIGHT = 800
local RETURN_DISTANCE = 12
local JOIN_INTERVAL = 1
-- ============================================

local currentBlock
local loopRunning = false

-- ================= CHECK LOBBY (UI Version) =================
local function isInLobby()
    local gui = player:WaitForChild("PlayerGui")

    for _, v in ipairs(gui:GetDescendants()) do
        if (v:IsA("TextLabel") or v:IsA("TextButton"))
            and v.Visible
            and typeof(v.Text) == "string"
            and string.find(v.Text, "Version:")
        then
            return true
        end
    end
    return false
end

-- ================= SAFE BLOCK =================
local function setupSafeBlock(character)
    local hrp = character:WaitForChild("HumanoidRootPart")

    if currentBlock then
        currentBlock:Destroy()
        currentBlock = nil
    end

    local block = Instance.new("Part")
    block.Size = BLOCK_SIZE
    block.Anchored = true
    block.CanCollide = true
    block.Material = Enum.Material.SmoothPlastic
    block.Color = Color3.fromRGB(180, 180, 180)
    block.Name = "SafeBlock"
    block.Parent = workspace

    local pos = hrp.Position + Vector3.new(0, HEIGHT, 0)
    block.CFrame = CFrame.new(pos)
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))

    currentBlock = block

    if loopRunning then return end
    loopRunning = true

    task.spawn(function()
        while loopRunning do
            task.wait(0.8)

            if not player.Character
            or not player.Character:FindFirstChild("HumanoidRootPart")
            or not currentBlock then
                loopRunning = false
                break
            end

            local hrp = player.Character.HumanoidRootPart
            local dist = (hrp.Position - currentBlock.Position).Magnitude

            if dist > RETURN_DISTANCE then
                hrp.CFrame = CFrame.new(currentBlock.Position + Vector3.new(0, 3, 0))
            end
        end
    end)
end

-- ================= CHARACTER HANDLER =================
player.CharacterAdded:Connect(function(character)
    task.wait(0.5)
    if not isInLobby() then
        setupSafeBlock(character)
    end
end)

-- ================= AUTO RESPAWN (HUD) =================
local function setupHUDListener(hud)
    if not hud then return end

    local lastVisible = hud.Visible
    local sentOnce = false

    hud:GetPropertyChangedSignal("Visible"):Connect(function()
        if hud.Visible == false and lastVisible == true and not sentOnce then
            sentOnce = true
            pcall(function()
                joinEvent:FireServer(true)
            end)
            print("✅ Auto Respawn Triggered")
        elseif hud.Visible == true then
            sentOnce = false
        end
        lastVisible = hud.Visible
    end)
end

local function listenToShared(shared)
    if not shared then return end

    local hud = shared:FindFirstChild("HUD")
    if hud then
        setupHUDListener(hud)
    end

    shared.ChildAdded:Connect(function(child)
        if child.Name == "HUD" then
            setupHUDListener(child)
        end
    end)
end

local function listenToPlayerGui()
    local playerGui = player:WaitForChild("PlayerGui")
    local shared = playerGui:FindFirstChild("Shared")
    if shared then
        listenToShared(shared)
    end

    playerGui.ChildAdded:Connect(function(child)
        if child.Name == "Shared" then
            listenToShared(child)
        end
    end)
end

listenToPlayerGui()
print("✅ Auto Respawn Script Loaded")

-- ================= MAIN LOOP =================
while true do
    if isInLobby() then
        if currentBlock then
            currentBlock:Destroy()
            currentBlock = nil
        end
        loopRunning = false

        pcall(function()
            joinEvent:FireServer(true)
        end)

        task.wait(JOIN_INTERVAL)
    else
        if player.Character and not currentBlock then
            setupSafeBlock(player.Character)
        end
        task.wait(2)
    end
end
