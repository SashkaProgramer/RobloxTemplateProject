--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local netFolder = ReplicatedStorage:WaitForChild(Net.FolderName)
local stateUpdateEvent = netFolder:WaitForChild(Net.Events.StateUpdate) :: RemoteEvent
local setSprintingEvent = netFolder:WaitForChild(Net.Events.SetSprinting) :: RemoteEvent
local scavengeResultEvent = netFolder:WaitForChild(Net.Events.ScavengeResult) :: RemoteEvent
local medkitPickupEvent = netFolder:WaitForChild(Net.Events.MedkitPickup) :: RemoteEvent
local aimUpdateEvent = netFolder:WaitForChild(Net.Events.AimUpdate) :: RemoteEvent
local attackFeedbackEvent = netFolder:WaitForChild(Net.Events.AttackFeedback) :: RemoteEvent

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SurvivalHud"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.BackgroundColor3 = Color3.fromRGB(18, 20, 22)
panel.BackgroundTransparency = 0.2
panel.Size = UDim2.fromOffset(280, 130)
panel.Position = UDim2.new(0, 20, 1, -150)
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 8)
panelCorner.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.fromOffset(260, 24)
title.Position = UDim2.fromOffset(10, 8)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(226, 225, 216)
title.TextSize = 16
title.Text = "Survival Status"
title.Parent = panel

local staminaLabel = Instance.new("TextLabel")
staminaLabel.BackgroundTransparency = 1
staminaLabel.Size = UDim2.fromOffset(260, 22)
staminaLabel.Position = UDim2.fromOffset(10, 36)
staminaLabel.TextXAlignment = Enum.TextXAlignment.Left
staminaLabel.Font = Enum.Font.Gotham
staminaLabel.TextColor3 = Color3.fromRGB(219, 219, 219)
staminaLabel.TextSize = 14
staminaLabel.Text = "Stamina: 100"
staminaLabel.Parent = panel

local hungerLabel = staminaLabel:Clone()
hungerLabel.Position = UDim2.fromOffset(10, 60)
hungerLabel.Text = "Hunger: 100"
hungerLabel.Parent = panel

local scrapLabel = staminaLabel:Clone()
scrapLabel.Position = UDim2.fromOffset(10, 84)
scrapLabel.Text = "Scrap: 0"
scrapLabel.Parent = panel

local toast = Instance.new("TextLabel")
toast.BackgroundColor3 = Color3.fromRGB(38, 52, 38)
toast.BackgroundTransparency = 0.2
toast.TextColor3 = Color3.fromRGB(210, 244, 210)
toast.Font = Enum.Font.GothamMedium
toast.TextSize = 14
toast.Visible = false
toast.Size = UDim2.fromOffset(280, 30)
toast.Position = UDim2.new(0, 20, 1, -190)
toast.Parent = screenGui

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 8)
toastCorner.Parent = toast

local hpFrame = Instance.new("Frame")
hpFrame.Name = "HpFrame"
hpFrame.BackgroundColor3 = Color3.fromRGB(50, 18, 18)
hpFrame.BackgroundTransparency = 0.2
hpFrame.Size = UDim2.fromOffset(190, 44)
hpFrame.AnchorPoint = Vector2.new(1, 0)
hpFrame.Position = UDim2.new(1, -20, 0, 20)
hpFrame.Parent = screenGui

local hpFrameCorner = Instance.new("UICorner")
hpFrameCorner.CornerRadius = UDim.new(0, 8)
hpFrameCorner.Parent = hpFrame

local hpLabel = Instance.new("TextLabel")
hpLabel.Name = "HpLabel"
hpLabel.BackgroundTransparency = 1
hpLabel.Size = UDim2.fromScale(1, 1)
hpLabel.Font = Enum.Font.GothamBold
hpLabel.TextSize = 18
hpLabel.TextColor3 = Color3.fromRGB(255, 220, 220)
hpLabel.Text = "HP: 0/0"
hpLabel.Parent = hpFrame

local crosshair = Instance.new("Frame")
crosshair.Name = "Crosshair"
crosshair.BackgroundTransparency = 1
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.Position = UDim2.fromScale(0.5, 0.5)
crosshair.Size = UDim2.fromOffset(34, 34)
crosshair.Visible = false
crosshair.Parent = screenGui

local crosshairColor = Color3.fromRGB(245, 245, 245)

local crosshairRing = Instance.new("Frame")
crosshairRing.BackgroundTransparency = 1
crosshairRing.AnchorPoint = Vector2.new(0.5, 0.5)
crosshairRing.Position = UDim2.fromScale(0.5, 0.5)
crosshairRing.Size = UDim2.fromOffset(12, 12)
crosshairRing.Parent = crosshair

local crosshairRingCorner = Instance.new("UICorner")
crosshairRingCorner.CornerRadius = UDim.new(1, 0)
crosshairRingCorner.Parent = crosshairRing

local crosshairRingStroke = Instance.new("UIStroke")
crosshairRingStroke.Color = crosshairColor
crosshairRingStroke.Thickness = 1.4
crosshairRingStroke.Parent = crosshairRing

local crosshairRingOutline = Instance.new("UIStroke")
crosshairRingOutline.Color = Color3.fromRGB(10, 10, 10)
crosshairRingOutline.Thickness = 3
crosshairRingOutline.Transparency = 0.7
crosshairRingOutline.Parent = crosshairRing

local crosshairDot = Instance.new("Frame")
crosshairDot.BackgroundColor3 = crosshairColor
crosshairDot.BorderSizePixel = 0
crosshairDot.AnchorPoint = Vector2.new(0.5, 0.5)
crosshairDot.Position = UDim2.fromScale(0.5, 0.5)
crosshairDot.Size = UDim2.fromOffset(3, 3)
crosshairDot.Parent = crosshair

local crosshairDotCorner = Instance.new("UICorner")
crosshairDotCorner.CornerRadius = UDim.new(1, 0)
crosshairDotCorner.Parent = crosshairDot

local crosshairDotOutline = Instance.new("UIStroke")
crosshairDotOutline.Color = Color3.fromRGB(10, 10, 10)
crosshairDotOutline.Thickness = 2
crosshairDotOutline.Transparency = 0.7
crosshairDotOutline.Parent = crosshairDot

local crosshairTop = Instance.new("Frame")
crosshairTop.BackgroundColor3 = crosshairColor
crosshairTop.BorderSizePixel = 0
crosshairTop.AnchorPoint = Vector2.new(0.5, 1)
crosshairTop.Position = UDim2.new(0.5, 0, 0.5, -8)
crosshairTop.Size = UDim2.fromOffset(2, 6)
crosshairTop.Parent = crosshair

local crosshairTopOutline = Instance.new("UIStroke")
crosshairTopOutline.Color = Color3.fromRGB(10, 10, 10)
crosshairTopOutline.Thickness = 2
crosshairTopOutline.Transparency = 0.7
crosshairTopOutline.Parent = crosshairTop

local crosshairBottom = crosshairTop:Clone()
crosshairBottom.AnchorPoint = Vector2.new(0.5, 0)
crosshairBottom.Position = UDim2.new(0.5, 0, 0.5, 8)
crosshairBottom.Parent = crosshair

local crosshairLeft = Instance.new("Frame")
crosshairLeft.BackgroundColor3 = crosshairColor
crosshairLeft.BorderSizePixel = 0
crosshairLeft.AnchorPoint = Vector2.new(1, 0.5)
crosshairLeft.Position = UDim2.new(0.5, -8, 0.5, 0)
crosshairLeft.Size = UDim2.fromOffset(6, 2)
crosshairLeft.Parent = crosshair

local crosshairLeftOutline = Instance.new("UIStroke")
crosshairLeftOutline.Color = Color3.fromRGB(10, 10, 10)
crosshairLeftOutline.Thickness = 2
crosshairLeftOutline.Transparency = 0.7
crosshairLeftOutline.Parent = crosshairLeft

local crosshairRight = crosshairLeft:Clone()
crosshairRight.AnchorPoint = Vector2.new(0, 0.5)
crosshairRight.Position = UDim2.new(0.5, 8, 0.5, 0)
crosshairRight.Parent = crosshair

local sprinting = false
local lastToastId = 0
local launcherName = "Grenade Launcher"
local lastAimSent = 0
local shoulderCameraOffset = Vector3.new(1.45, 0.65, 0)
local crosshairPixelOffset = Vector2.new(0, -128)

local function setToast(text: string)
	lastToastId += 1
	local toastId = lastToastId
	toast.Text = text
	toast.Visible = true
	task.delay(2, function()
		if toastId == lastToastId then
			toast.Visible = false
		end
	end)
end

local function updateHpLabel()
	local character = player.Character
	if not character then
		hpLabel.Text = "HP: 0/0"
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		hpLabel.Text = "HP: 0/0"
		return
	end

	local health = math.max(0, math.floor(humanoid.Health + 0.5))
	local maxHealth = math.max(1, math.floor(humanoid.MaxHealth + 0.5))
	hpLabel.Text = ("HP: %d/%d"):format(health, maxHealth)

	if health <= math.floor(maxHealth * 0.3) then
		hpLabel.TextColor3 = Color3.fromRGB(255, 122, 122)
	else
		hpLabel.TextColor3 = Color3.fromRGB(255, 220, 220)
	end
end

local function connectCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.HealthChanged:Connect(updateHpLabel)
		humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(updateHpLabel)
	end
	updateHpLabel()
end

if player.Character then
	task.spawn(connectCharacter, player.Character)
else
	updateHpLabel()
end

player.CharacterAdded:Connect(function(character: Model)
	connectCharacter(character)
end)

local function getEquippedLauncher(): Tool?
	local character = player.Character
	if not character then
		return nil
	end
	local tool = character:FindFirstChildOfClass("Tool")
	if tool and tool.Name == launcherName then
		return tool
	end
	return nil
end

local function getHumanoid(): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid
	end
	return nil
end

local function computeAimPoint(): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(
		viewport.X * 0.5 + crosshairPixelOffset.X,
		viewport.Y * 0.5 + crosshairPixelOffset.Y
	)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local filter: { Instance } = {}
	if player.Character then
		table.insert(filter, player.Character)
	end
	rayParams.FilterDescendantsInstances = filter

	local direction = ray.Direction * GameConfig.Player.GrenadeRange
	local hit = Workspace:Raycast(ray.Origin, direction, rayParams)
	if hit then
		return hit.Position
	end
	return ray.Origin + direction
end

local function pushAimUpdate(force: boolean)
	local equippedLauncher = getEquippedLauncher()
	crosshair.Visible = equippedLauncher ~= nil
	crosshair.Position = UDim2.new(0.5, crosshairPixelOffset.X, 0.5, crosshairPixelOffset.Y)

	local humanoid = getHumanoid()
	if humanoid then
		humanoid.CameraOffset = if equippedLauncher then shoulderCameraOffset else Vector3.zero
	end

	if not equippedLauncher then
		return
	end

	local now = time()
	if not force and now - lastAimSent < 0.03 then
		return
	end

	local aimPoint = computeAimPoint()
	if not aimPoint then
		return
	end

	lastAimSent = now
	aimUpdateEvent:FireServer(aimPoint)
end

RunService.RenderStepped:Connect(function()
	pushAimUpdate(false)
end)

stateUpdateEvent.OnClientEvent:Connect(function(data)
	local stamina = tonumber(data.stamina) or 0
	local hunger = tonumber(data.hunger) or 0
	local scrap = tonumber(data.scrap) or 0
	local isSprinting = data.isSprinting == true

	staminaLabel.Text = ("Stamina: %d"):format(stamina)
	hungerLabel.Text = ("Hunger: %d"):format(hunger)
	scrapLabel.Text = ("Scrap: %d"):format(scrap)

	if stamina <= GameConfig.Player.LowStaminaThreshold then
		staminaLabel.TextColor3 = Color3.fromRGB(235, 127, 127)
	else
		staminaLabel.TextColor3 = Color3.fromRGB(219, 219, 219)
	end

	sprinting = isSprinting
end)

scavengeResultEvent.OnClientEvent:Connect(function(data)
	if data.ok == true then
		local amount = tonumber(data.amount) or 0
		setToast(("Scavenged +%d scrap"):format(amount))
	end
end)

medkitPickupEvent.OnClientEvent:Connect(function(data)
	if data.ok == true then
		local amount = tonumber(data.amount) or 0
		setToast(("Used medkit +%d HP"):format(amount))
	end
end)

attackFeedbackEvent.OnClientEvent:Connect(function(data)
	if data.hit == true then
		setToast("Hit infected")
	else
		setToast("Miss")
	end
end)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		pushAimUpdate(true)
		local equippedLauncher = getEquippedLauncher()
		if equippedLauncher then
			equippedLauncher:Activate()
		end
	end

	if gameProcessedEvent then
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3 then
		if not sprinting then
			sprinting = true
			setSprintingEvent:FireServer(true)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject, _gameProcessedEvent: boolean)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3 then
		if sprinting then
			sprinting = false
			setSprintingEvent:FireServer(false)
		end
	end
end)
