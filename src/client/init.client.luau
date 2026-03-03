--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local netFolder = ReplicatedStorage:WaitForChild(Net.FolderName)
local stateUpdateEvent = netFolder:WaitForChild(Net.Events.StateUpdate) :: RemoteEvent
local setSprintingEvent = netFolder:WaitForChild(Net.Events.SetSprinting) :: RemoteEvent
local scavengeResultEvent = netFolder:WaitForChild(Net.Events.ScavengeResult) :: RemoteEvent
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

local sprinting = false
local lastToastId = 0
local lastAttackTime = 0

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

attackFeedbackEvent.OnClientEvent:Connect(function(data)
	if data.hit == true then
		setToast("Hit infected")
	else
		setToast("Miss")
	end
end)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	local isAttackInput = input.UserInputType == Enum.UserInputType.MouseButton1
		or input.KeyCode == Enum.KeyCode.F
		or input.KeyCode == Enum.KeyCode.ButtonR2

	if isAttackInput then
		local now = os.clock()
		if now - lastAttackTime >= GameConfig.Player.AttackCooldown then
			lastAttackTime = now
			playerAttackEvent:FireServer()
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
