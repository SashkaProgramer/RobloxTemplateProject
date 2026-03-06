--!strict

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
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
local playerAttackEvent = netFolder:WaitForChild(Net.Events.PlayerAttack) :: RemoteEvent
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
staminaLabel.TextColor3 = Color3.fromRGB(184, 216, 255)
staminaLabel.TextSize = 14
staminaLabel.Text = ("Stamina: %d"):format(GameConfig.Player.MaxStamina)
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
hpFrame.BackgroundColor3 = Color3.fromRGB(19, 22, 30)
hpFrame.BackgroundTransparency = 0.2
hpFrame.Size = UDim2.fromOffset(260, 112)
hpFrame.AnchorPoint = Vector2.new(1, 0)
hpFrame.Position = UDim2.new(1, -20, 0, 20)
hpFrame.Parent = screenGui

local hpFrameCorner = Instance.new("UICorner")
hpFrameCorner.CornerRadius = UDim.new(0, 8)
hpFrameCorner.Parent = hpFrame

local hpLabel = Instance.new("TextLabel")
hpLabel.Name = "HpLabel"
hpLabel.BackgroundTransparency = 1
hpLabel.Size = UDim2.fromOffset(240, 22)
hpLabel.Position = UDim2.fromOffset(10, 8)
hpLabel.Font = Enum.Font.GothamBold
hpLabel.TextSize = 20
hpLabel.TextColor3 = Color3.fromRGB(255, 174, 174)
hpLabel.TextXAlignment = Enum.TextXAlignment.Left
hpLabel.Text = "HP: 0/0"
hpLabel.Parent = hpFrame

local hpBarBackground = Instance.new("Frame")
hpBarBackground.Name = "HpBarBackground"
hpBarBackground.BackgroundColor3 = Color3.fromRGB(61, 23, 23)
hpBarBackground.BorderSizePixel = 0
hpBarBackground.Size = UDim2.fromOffset(240, 12)
hpBarBackground.Position = UDim2.fromOffset(10, 32)
hpBarBackground.Parent = hpFrame

local hpBarBackgroundCorner = Instance.new("UICorner")
hpBarBackgroundCorner.CornerRadius = UDim.new(0, 6)
hpBarBackgroundCorner.Parent = hpBarBackground

local hpBarFill = Instance.new("Frame")
hpBarFill.Name = "HpBarFill"
hpBarFill.BackgroundColor3 = Color3.fromRGB(212, 57, 57)
hpBarFill.BorderSizePixel = 0
hpBarFill.Size = UDim2.fromScale(0, 1)
hpBarFill.Parent = hpBarBackground

local hpBarFillCorner = Instance.new("UICorner")
hpBarFillCorner.CornerRadius = UDim.new(0, 6)
hpBarFillCorner.Parent = hpBarFill

local staminaValueLabel = Instance.new("TextLabel")
staminaValueLabel.Name = "StaminaLabel"
staminaValueLabel.BackgroundTransparency = 1
staminaValueLabel.Size = UDim2.fromOffset(240, 20)
staminaValueLabel.Position = UDim2.fromOffset(10, 56)
staminaValueLabel.Font = Enum.Font.GothamMedium
staminaValueLabel.TextSize = 17
staminaValueLabel.TextColor3 = Color3.fromRGB(181, 220, 255)
staminaValueLabel.TextXAlignment = Enum.TextXAlignment.Left
staminaValueLabel.Text = ("Stamina: %d/%d"):format(GameConfig.Player.MaxStamina, GameConfig.Player.MaxStamina)
staminaValueLabel.Parent = hpFrame

local staminaBarBackground = Instance.new("Frame")
staminaBarBackground.Name = "StaminaBarBackground"
staminaBarBackground.BackgroundColor3 = Color3.fromRGB(22, 40, 74)
staminaBarBackground.BorderSizePixel = 0
staminaBarBackground.Size = UDim2.fromOffset(240, 12)
staminaBarBackground.Position = UDim2.fromOffset(10, 80)
staminaBarBackground.Parent = hpFrame

local staminaBarBackgroundCorner = Instance.new("UICorner")
staminaBarBackgroundCorner.CornerRadius = UDim.new(0, 6)
staminaBarBackgroundCorner.Parent = staminaBarBackground

local staminaBarFill = Instance.new("Frame")
staminaBarFill.Name = "StaminaBarFill"
staminaBarFill.BackgroundColor3 = Color3.fromRGB(56, 132, 232)
staminaBarFill.BorderSizePixel = 0
staminaBarFill.Size = UDim2.fromScale(1, 1)
staminaBarFill.Parent = staminaBarBackground

local staminaBarFillCorner = Instance.new("UICorner")
staminaBarFillCorner.CornerRadius = UDim.new(0, 6)
staminaBarFillCorner.Parent = staminaBarFill

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
local launcherName = "Pulse Launcher"
local swordName = "Energy Blade"
local lastAimSent = 0
local keyboardShoulderCameraOffset = Vector3.new(1.45, 0.65, 0)
local gamepadShoulderCameraOffset = Vector3.new(0.95, 0.35, 0)
local keyboardCrosshairPixelOffset = Vector2.new(0, -128)
local gamepadCrosshairPixelOffset = Vector2.new(0, -44)
local attackActionName = "ConsolePrimaryAction"
local equipLauncherActionName = "ConsoleEquipLauncher"
local equipBladeActionName = "ConsoleEquipBlade"

local function isGamepadInputType(inputType: Enum.UserInputType): boolean
	return inputType == Enum.UserInputType.Gamepad1
		or inputType == Enum.UserInputType.Gamepad2
		or inputType == Enum.UserInputType.Gamepad3
		or inputType == Enum.UserInputType.Gamepad4
		or inputType == Enum.UserInputType.Gamepad5
		or inputType == Enum.UserInputType.Gamepad6
		or inputType == Enum.UserInputType.Gamepad7
		or inputType == Enum.UserInputType.Gamepad8
end

local function isUsingGamepadAim(): boolean
	local preferredInput = UserInputService.PreferredInput
	if preferredInput == Enum.PreferredInput.Gamepad then
		return true
	end

	return isGamepadInputType(UserInputService:GetLastInputType())
end

local function getShoulderCameraOffset(): Vector3
	if isUsingGamepadAim() then
		return gamepadShoulderCameraOffset
	end

	return keyboardShoulderCameraOffset
end

local function getCrosshairPixelOffset(): Vector2
	if isUsingGamepadAim() then
		return gamepadCrosshairPixelOffset
	end

	return keyboardCrosshairPixelOffset
end

local function updateCrosshairLayout()
	local crosshairPixelOffset = getCrosshairPixelOffset()
	crosshair.Position = UDim2.new(0.5, crosshairPixelOffset.X, 0.5, crosshairPixelOffset.Y)

	if isUsingGamepadAim() then
		crosshair.Size = UDim2.fromOffset(42, 42)
	else
		crosshair.Size = UDim2.fromOffset(34, 34)
	end
end

local function setBarRatio(fillBar: Frame, ratio: number)
	local clamped = math.clamp(ratio, 0, 1)
	fillBar.Size = UDim2.fromScale(clamped, 1)
end

local function updateStaminaHud(stamina: number)
	local maxStamina = math.max(1, GameConfig.Player.MaxStamina)
	local clampedStamina = math.clamp(stamina, 0, maxStamina)
	staminaValueLabel.Text = ("Stamina: %d/%d"):format(math.floor(clampedStamina + 0.5), maxStamina)
	setBarRatio(staminaBarFill, clampedStamina / maxStamina)

	if clampedStamina <= GameConfig.Player.LowStaminaThreshold then
		staminaLabel.TextColor3 = Color3.fromRGB(129, 186, 255)
		staminaValueLabel.TextColor3 = Color3.fromRGB(165, 211, 255)
		staminaBarFill.BackgroundColor3 = Color3.fromRGB(74, 160, 255)
	else
		staminaLabel.TextColor3 = Color3.fromRGB(184, 216, 255)
		staminaValueLabel.TextColor3 = Color3.fromRGB(181, 220, 255)
		staminaBarFill.BackgroundColor3 = Color3.fromRGB(56, 132, 232)
	end
end

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
		setBarRatio(hpBarFill, 0)
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		hpLabel.Text = "HP: 0/0"
		setBarRatio(hpBarFill, 0)
		return
	end

	local health = math.max(0, math.floor(humanoid.Health + 0.5))
	local maxHealth = math.max(1, math.floor(humanoid.MaxHealth + 0.5))
	hpLabel.Text = ("HP: %d/%d"):format(health, maxHealth)
	setBarRatio(hpBarFill, health / maxHealth)

	if health <= math.floor(maxHealth * 0.3) then
		hpLabel.TextColor3 = Color3.fromRGB(255, 122, 122)
		hpBarFill.BackgroundColor3 = Color3.fromRGB(231, 72, 72)
	else
		hpLabel.TextColor3 = Color3.fromRGB(255, 174, 174)
		hpBarFill.BackgroundColor3 = Color3.fromRGB(212, 57, 57)
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

local function isSupportedWeapon(tool: Tool?): boolean
	return tool ~= nil and (tool.Name == launcherName or tool.Name == swordName)
end

local function getEquippedWeapon(): Tool?
	local character = player.Character
	if not character then
		return nil
	end
	local tool = character:FindFirstChildOfClass("Tool")
	if isSupportedWeapon(tool) then
		return tool
	end
	return nil
end

local function getEquippedLauncher(): Tool?
	local tool = getEquippedWeapon()
	if tool and tool.Name == launcherName then
		return tool
	end
	return nil
end

local function equipWeaponByName(weaponName: string)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	local inBackpack = backpack:FindFirstChild(weaponName)
	if inBackpack and inBackpack:IsA("Tool") then
		humanoid:EquipTool(inBackpack)
		return
	end

	local inCharacter = character:FindFirstChild(weaponName)
	if inCharacter and inCharacter:IsA("Tool") then
		humanoid:EquipTool(inCharacter)
	end
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

	local crosshairPixelOffset = getCrosshairPixelOffset()
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
	updateCrosshairLayout()

	local humanoid = getHumanoid()
	if humanoid then
		humanoid.CameraOffset = if equippedLauncher then getShoulderCameraOffset() else Vector3.zero
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

local function triggerPrimaryAction()
	pushAimUpdate(true)
	if getEquippedWeapon() then
		playerAttackEvent:FireServer()
	end
end

ContextActionService:BindAction(attackActionName, function(_, inputState: Enum.UserInputState, _inputObject: InputObject)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	triggerPrimaryAction()
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.ButtonR2)

ContextActionService:BindAction(
	equipLauncherActionName,
	function(_, inputState: Enum.UserInputState, _inputObject: InputObject)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end

		equipWeaponByName(launcherName)
		return Enum.ContextActionResult.Sink
	end,
	false,
	Enum.KeyCode.DPadLeft
)

ContextActionService:BindAction(
	equipBladeActionName,
	function(_, inputState: Enum.UserInputState, _inputObject: InputObject)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end

		equipWeaponByName(swordName)
		return Enum.ContextActionResult.Sink
	end,
	false,
	Enum.KeyCode.DPadRight
)

UserInputService.LastInputTypeChanged:Connect(function()
	updateCrosshairLayout()
end)

RunService.RenderStepped:Connect(function()
	pushAimUpdate(false)
end)

updateCrosshairLayout()
updateStaminaHud(GameConfig.Player.MaxStamina)

stateUpdateEvent.OnClientEvent:Connect(function(data)
	local stamina = tonumber(data.stamina) or 0
	local hunger = tonumber(data.hunger) or 0
	local scrap = tonumber(data.scrap) or 0
	local isSprinting = data.isSprinting == true

	staminaLabel.Text = ("Stamina: %d"):format(stamina)
	hungerLabel.Text = ("Hunger: %d"):format(hunger)
	scrapLabel.Text = ("Scrap: %d"):format(scrap)
	updateStaminaHud(stamina)

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
		setToast("Target reached")
	else
		setToast("No target")
	end
end)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		triggerPrimaryAction()
	end

	if gameProcessedEvent then
		return
	end

	if input.KeyCode == Enum.KeyCode.One then
		equipWeaponByName(launcherName)
		return
	end

	if input.KeyCode == Enum.KeyCode.Two then
		equipWeaponByName(swordName)
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
