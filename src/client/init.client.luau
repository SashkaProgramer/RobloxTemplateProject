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
local FeatureFlags = require(Shared:WaitForChild("FeatureFlags"))

local netFolder = ReplicatedStorage:WaitForChild(Net.FolderName)
local stateUpdateEvent = netFolder:WaitForChild(Net.Events.StateUpdate) :: RemoteEvent
local setSprintingEvent = netFolder:WaitForChild(Net.Events.SetSprinting) :: RemoteEvent
local scavengeResultEvent = netFolder:WaitForChild(Net.Events.ScavengeResult) :: RemoteEvent
local medkitPickupEvent = netFolder:WaitForChild(Net.Events.MedkitPickup) :: RemoteEvent
local roundStateChangedEvent = netFolder:WaitForChild(Net.Events.RoundStateChanged) :: RemoteEvent
local roundTimerUpdatedEvent = netFolder:WaitForChild(Net.Events.RoundTimerUpdated) :: RemoteEvent
local playerRoundStateChangedEvent = netFolder:WaitForChild(Net.Events.PlayerRoundStateChanged) :: RemoteEvent
local inventoryUpdatedEvent = netFolder:WaitForChild(Net.Events.InventoryUpdated) :: RemoteEvent
local objectivesUpdatedEvent = netFolder:WaitForChild(Net.Events.ObjectivesUpdated) :: RemoteEvent
local requestInteractEvent = netFolder:WaitForChild(Net.Events.RequestInteract) :: RemoteEvent
local requestDropLootEvent = netFolder:WaitForChild(Net.Events.RequestDropLoot) :: RemoteEvent
local requestUseItemEvent = netFolder:WaitForChild(Net.Events.RequestUseItem) :: RemoteEvent
local requestExtractEvent = netFolder:WaitForChild(Net.Events.RequestExtract) :: RemoteEvent
local requestSabotageEvent = netFolder:WaitForChild(Net.Events.RequestSabotage) :: RemoteEvent
local aimUpdateEvent = netFolder:WaitForChild(Net.Events.AimUpdate) :: RemoteEvent
local playerAttackEvent = netFolder:WaitForChild(Net.Events.PlayerAttack) :: RemoteEvent
local attackFeedbackEvent = netFolder:WaitForChild(Net.Events.AttackFeedback) :: RemoteEvent
local matchResultEvent = netFolder:WaitForChild(Net.Events.MatchResult) :: RemoteEvent
local sabotageFeedbackEvent = netFolder:WaitForChild(Net.Events.SabotageFeedback) :: RemoteEvent

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SurvivalHud"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.BackgroundColor3 = Color3.fromRGB(18, 20, 22)
panel.BackgroundTransparency = 0.2
panel.Size = UDim2.fromOffset(280, 266)
panel.Position = UDim2.new(0, 20, 1, -286)
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

local phaseLabel = staminaLabel:Clone()
phaseLabel.Position = UDim2.fromOffset(10, 112)
phaseLabel.Text = "Phase: Lobby"
phaseLabel.Parent = panel

local timerLabel = staminaLabel:Clone()
timerLabel.Position = UDim2.fromOffset(10, 136)
timerLabel.Text = "Timer: --"
timerLabel.Parent = panel

local carriedLabel = staminaLabel:Clone()
carriedLabel.Position = UDim2.fromOffset(10, 160)
carriedLabel.Text = "Carried Value: 0"
carriedLabel.Parent = panel

local inventoryLabel = staminaLabel:Clone()
inventoryLabel.Position = UDim2.fromOffset(10, 184)
inventoryLabel.Text = "Inventory: empty"
inventoryLabel.Parent = panel

local zoneLabel = staminaLabel:Clone()
zoneLabel.Position = UDim2.fromOffset(10, 208)
zoneLabel.Text = "Zone: --"
zoneLabel.Parent = panel

local objectiveLabel = staminaLabel:Clone()
objectiveLabel.Position = UDim2.fromOffset(10, 232)
objectiveLabel.Text = "Objectives: 0/0"
objectiveLabel.Parent = panel

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

local resultPanel = Instance.new("Frame")
resultPanel.Name = "ResultPanel"
resultPanel.Visible = false
resultPanel.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
resultPanel.BackgroundTransparency = 0.12
resultPanel.Size = UDim2.fromOffset(360, 252)
resultPanel.AnchorPoint = Vector2.new(0.5, 0.5)
resultPanel.Position = UDim2.fromScale(0.5, 0.34)
resultPanel.Parent = screenGui

local resultPanelCorner = Instance.new("UICorner")
resultPanelCorner.CornerRadius = UDim.new(0, 10)
resultPanelCorner.Parent = resultPanel

local resultPanelStroke = Instance.new("UIStroke")
resultPanelStroke.Color = Color3.fromRGB(92, 108, 124)
resultPanelStroke.Transparency = 0.35
resultPanelStroke.Thickness = 1.5
resultPanelStroke.Parent = resultPanel

local resultTitle = Instance.new("TextLabel")
resultTitle.Name = "Title"
resultTitle.BackgroundTransparency = 1
resultTitle.Size = UDim2.fromOffset(220, 28)
resultTitle.Position = UDim2.fromOffset(20, 14)
resultTitle.Font = Enum.Font.GothamBold
resultTitle.TextSize = 20
resultTitle.TextXAlignment = Enum.TextXAlignment.Left
resultTitle.TextColor3 = Color3.fromRGB(236, 240, 245)
resultTitle.Text = "Raid Result"
resultTitle.Parent = resultPanel

local resultHeroBadge = Instance.new("TextLabel")
resultHeroBadge.Name = "HeroBadge"
resultHeroBadge.BackgroundColor3 = Color3.fromRGB(62, 74, 90)
resultHeroBadge.BackgroundTransparency = 0.08
resultHeroBadge.Size = UDim2.fromOffset(96, 24)
resultHeroBadge.Position = UDim2.fromOffset(244, 16)
resultHeroBadge.Font = Enum.Font.GothamBold
resultHeroBadge.TextSize = 12
resultHeroBadge.TextXAlignment = Enum.TextXAlignment.Center
resultHeroBadge.TextColor3 = Color3.fromRGB(236, 240, 245)
resultHeroBadge.Text = "OUTCOME"
resultHeroBadge.Parent = resultPanel

local resultHeroBadgeCorner = Instance.new("UICorner")
resultHeroBadgeCorner.CornerRadius = UDim.new(0, 8)
resultHeroBadgeCorner.Parent = resultHeroBadge

local resultSummary = Instance.new("TextLabel")
resultSummary.Name = "Summary"
resultSummary.BackgroundTransparency = 1
resultSummary.Size = UDim2.fromOffset(320, 34)
resultSummary.Position = UDim2.fromOffset(20, 50)
resultSummary.Font = Enum.Font.GothamMedium
resultSummary.TextWrapped = true
resultSummary.TextXAlignment = Enum.TextXAlignment.Left
resultSummary.TextYAlignment = Enum.TextYAlignment.Top
resultSummary.TextSize = 16
resultSummary.TextColor3 = Color3.fromRGB(214, 221, 228)
resultSummary.Text = ""
resultSummary.Parent = resultPanel

local resultCallout = Instance.new("TextLabel")
resultCallout.Name = "Callout"
resultCallout.BackgroundColor3 = Color3.fromRGB(44, 52, 64)
resultCallout.BackgroundTransparency = 0.08
resultCallout.Size = UDim2.fromOffset(320, 24)
resultCallout.Position = UDim2.fromOffset(20, 84)
resultCallout.Font = Enum.Font.GothamBold
resultCallout.TextSize = 12
resultCallout.TextXAlignment = Enum.TextXAlignment.Left
resultCallout.TextColor3 = Color3.fromRGB(239, 230, 188)
resultCallout.Text = ""
resultCallout.Parent = resultPanel

local resultCalloutCorner = Instance.new("UICorner")
resultCalloutCorner.CornerRadius = UDim.new(0, 7)
resultCalloutCorner.Parent = resultCallout

local resultValueLabel = Instance.new("TextLabel")
resultValueLabel.Name = "Value"
resultValueLabel.BackgroundTransparency = 1
resultValueLabel.Size = UDim2.fromOffset(320, 24)
resultValueLabel.Position = UDim2.fromOffset(20, 114)
resultValueLabel.Font = Enum.Font.GothamBold
resultValueLabel.TextSize = 17
resultValueLabel.TextXAlignment = Enum.TextXAlignment.Left
resultValueLabel.TextColor3 = Color3.fromRGB(231, 205, 114)
resultValueLabel.Text = ""
resultValueLabel.Parent = resultPanel

local resultReasonLabel = Instance.new("TextLabel")
resultReasonLabel.Name = "Reason"
resultReasonLabel.BackgroundTransparency = 1
resultReasonLabel.Size = UDim2.fromOffset(320, 30)
resultReasonLabel.Position = UDim2.fromOffset(20, 140)
resultReasonLabel.Font = Enum.Font.Gotham
resultReasonLabel.TextWrapped = true
resultReasonLabel.TextXAlignment = Enum.TextXAlignment.Left
resultReasonLabel.TextYAlignment = Enum.TextYAlignment.Top
resultReasonLabel.TextSize = 14
resultReasonLabel.TextColor3 = Color3.fromRGB(163, 172, 184)
resultReasonLabel.Text = ""
resultReasonLabel.Parent = resultPanel

local resultScoreboardTitle = Instance.new("TextLabel")
resultScoreboardTitle.Name = "ScoreboardTitle"
resultScoreboardTitle.BackgroundTransparency = 1
resultScoreboardTitle.Size = UDim2.fromOffset(320, 20)
resultScoreboardTitle.Position = UDim2.fromOffset(20, 174)
resultScoreboardTitle.Font = Enum.Font.GothamBold
resultScoreboardTitle.TextSize = 14
resultScoreboardTitle.TextXAlignment = Enum.TextXAlignment.Left
resultScoreboardTitle.TextColor3 = Color3.fromRGB(206, 214, 224)
resultScoreboardTitle.Text = "Raid Outcomes"
resultScoreboardTitle.Parent = resultPanel

local resultScoreboardFrame = Instance.new("Frame")
resultScoreboardFrame.Name = "Scoreboard"
resultScoreboardFrame.BackgroundTransparency = 1
resultScoreboardFrame.Size = UDim2.fromOffset(320, 62)
resultScoreboardFrame.Position = UDim2.fromOffset(20, 196)
resultScoreboardFrame.Parent = resultPanel

local resultScoreboardLayout = Instance.new("UIListLayout")
resultScoreboardLayout.FillDirection = Enum.FillDirection.Vertical
resultScoreboardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
resultScoreboardLayout.Padding = UDim.new(0, 6)
resultScoreboardLayout.Parent = resultScoreboardFrame

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
local currentRoundPhase = "Lobby"
local currentRoundTimeRemaining = 0
local currentInventory: { string } = {}
local currentCarriedValue = 0
local currentExtractionOpen = false
local currentExtractionSlotsRemaining = 0
local currentHasRareLoot = false
local legacyCombatEnabled = FeatureFlags.EnableLegacyCombat == true
local localPlayerExtracted = false
local currentZoneId = "--"
local currentObjectivesCompleted = 0
local currentObjectivesRequired = 0
local currentResultReasonText = ""
local currentResultScoreEntries: { any } = {}
local currentResultCalloutText = ""

local function clearScoreboardRows()
	for _, child in resultScoreboardFrame:GetChildren() do
		if child:IsA("Frame") and child.Name == "ScoreRow" then
			child:Destroy()
		end
	end
end

local function rebuildScoreboardRows()
	clearScoreboardRows()

	for index, entry in currentResultScoreEntries do
		if index > 4 then
			break
		end

		if typeof(entry) ~= "table" then
			continue
		end

		local didExtract = entry.didExtract == true
		local securedValue = math.max(0, tonumber(entry.securedValue) or 0)
		local carriedValue = math.max(0, tonumber(entry.carriedValue) or 0)
		local playerName = tostring(entry.name or "Unknown")
		local userId = tonumber(entry.userId) or 0
		local isLocalPlayer = userId == player.UserId

		local row = Instance.new("Frame")
		row.Name = "ScoreRow"
		row.BackgroundColor3 = if isLocalPlayer
			then (if didExtract then Color3.fromRGB(42, 78, 56) else Color3.fromRGB(88, 42, 42))
			else (if didExtract then Color3.fromRGB(26, 52, 38) else Color3.fromRGB(58, 29, 29))
		row.BackgroundTransparency = if isLocalPlayer then 0.04 else 0.18
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, 22)
		row.Parent = resultScoreboardFrame

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 6)
		rowCorner.Parent = row

		local rowStroke = Instance.new("UIStroke")
		rowStroke.Thickness = if isLocalPlayer then 1.2 else 1
		rowStroke.Transparency = if isLocalPlayer then 0.08 else 0.55
		rowStroke.Color = if didExtract then Color3.fromRGB(135, 214, 154) else Color3.fromRGB(234, 138, 138)
		rowStroke.Parent = row

		local badgeLabel = Instance.new("TextLabel")
		badgeLabel.BackgroundColor3 = if didExtract then Color3.fromRGB(84, 148, 102) else Color3.fromRGB(172, 82, 82)
		badgeLabel.BackgroundTransparency = 0.04
		badgeLabel.Size = UDim2.fromOffset(28, 14)
		badgeLabel.Position = UDim2.fromOffset(6, 4)
		badgeLabel.Font = Enum.Font.GothamBold
		badgeLabel.TextSize = 8
		badgeLabel.TextColor3 = Color3.fromRGB(248, 248, 248)
		badgeLabel.Text = if didExtract then "EVAC" else "DOWN"
		badgeLabel.Parent = row

		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(0, 4)
		badgeCorner.Parent = badgeLabel

		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size = UDim2.new(0.5, 0, 1, 0)
		nameLabel.Position = UDim2.fromOffset(40, 0)
		nameLabel.Font = if isLocalPlayer then Enum.Font.GothamBold else Enum.Font.GothamMedium
		nameLabel.TextSize = 12
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextColor3 = if isLocalPlayer then Color3.fromRGB(248, 250, 252) else Color3.fromRGB(232, 236, 242)
		nameLabel.Text = if isLocalPlayer then (playerName .. " (YOU)") else playerName
		nameLabel.Parent = row

		local statusLabel = Instance.new("TextLabel")
		statusLabel.BackgroundTransparency = 1
		statusLabel.Size = UDim2.new(0.5, -8, 1, 0)
		statusLabel.Position = UDim2.new(0.5, 0, 0, 0)
		statusLabel.Font = Enum.Font.GothamBold
		statusLabel.TextSize = 12
		statusLabel.TextXAlignment = Enum.TextXAlignment.Right
		statusLabel.TextColor3 = if didExtract then Color3.fromRGB(139, 222, 157) else Color3.fromRGB(240, 144, 144)
		statusLabel.Text = if didExtract
			then ("EXTRACTED %d"):format(securedValue)
			else ("FAILED %d"):format(carriedValue)
		statusLabel.Parent = row
	end
end

local function hideResultPanel()
	resultPanel.Visible = false
	resultHeroBadge.Text = "OUTCOME"
	resultHeroBadge.BackgroundColor3 = Color3.fromRGB(62, 74, 90)
	resultSummary.Text = ""
	resultCallout.Text = ""
	resultValueLabel.Text = ""
	resultReasonLabel.Text = ""
	currentResultReasonText = ""
	currentResultCalloutText = ""
	table.clear(currentResultScoreEntries)
	clearScoreboardRows()
end

local function refreshResultPanelStatus()
	if not resultPanel.Visible then
		return
	end

	if currentRoundPhase == "Resolved" then
		local suffix = ("Next raid in %ds"):format(math.max(0, currentRoundTimeRemaining))
		if currentResultReasonText ~= "" then
			resultReasonLabel.Text = ("%s | %s"):format(currentResultReasonText, suffix)
		else
			resultReasonLabel.Text = suffix
		end
		return
	end

	resultCallout.Text = currentResultCalloutText
	resultReasonLabel.Text = currentResultReasonText
end

local function refreshRoundHud()
	phaseLabel.Text = ("Phase: %s"):format(currentRoundPhase)
	if currentExtractionOpen then
		timerLabel.Text = ("Extraction: OPEN (%d left)"):format(currentExtractionSlotsRemaining)
	else
		timerLabel.Text = ("Timer: %ds"):format(math.max(0, currentRoundTimeRemaining))
	end

	carriedLabel.Text = ("Carried Value: %d"):format(currentCarriedValue)

	if #currentInventory == 0 then
		inventoryLabel.Text = "Inventory: empty"
	else
		local summary = table.concat(currentInventory, ", ")
		if currentHasRareLoot then
			summary ..= " [RARE]"
		end
		inventoryLabel.Text = ("Inventory: %s"):format(summary)
	end

	zoneLabel.Text = ("Zone: %s"):format(currentZoneId)
	objectiveLabel.Text = ("Objectives: %d/%d"):format(currentObjectivesCompleted, currentObjectivesRequired)
	refreshResultPanelStatus()
end

local function getCharacterRoot(): BasePart?
	local character = player.Character
	if not character then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function getNearestDoorId(maxDistance: number): string?
	local root = getCharacterRoot()
	if not root then
		return nil
	end

	local nearestDistance = maxDistance
	local nearestDoorId: string? = nil

	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("BasePart") then
			local doorId = descendant:GetAttribute("DoorId")
			if typeof(doorId) == "string" then
				local distance = (root.Position - descendant.Position).Magnitude
				if distance <= nearestDistance then
					nearestDistance = distance
					nearestDoorId = doorId
				end
			end
		end
	end

	return nearestDoorId
end

local function getNearestZoneId(maxDistance: number): string?
	local root = getCharacterRoot()
	if not root then
		return nil
	end

	local nearestDistance = maxDistance
	local nearestZoneId: string? = nil

	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("Model") then
			local zoneId = descendant:GetAttribute("ZoneId")
			local primaryPart = descendant.PrimaryPart
			if typeof(zoneId) == "string" and primaryPart then
				local distance = (root.Position - primaryPart.Position).Magnitude
				if distance <= nearestDistance then
					nearestDistance = distance
					nearestZoneId = zoneId
				end
			end
		end
	end

	return nearestZoneId
end

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
	if not legacyCombatEnabled then
		crosshair.Visible = false
		return
	end

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

local function formatExtractionFailureReason(reason: string): string
	if reason == "ObjectivesIncomplete" then
		return "Restore power before extraction"
	end

	if reason == "GateClosed" then
		return "Roof gate is still closed"
	end

	if reason == "ExtractionClosed" then
		return "Extraction is not open"
	end

	if reason == "NoSlotsRemaining" then
		return "No extraction slots left"
	end

	if reason == "AlreadyExtracted" then
		return "You are already locked in"
	end

	return ("Extraction failed: %s"):format(reason)
end

local function formatRoundResolutionToast(didExtract: boolean, reason: string?): string
	if didExtract then
		if reason == "ExtractionFull" then
			return "Round resolved: you secured a slot"
		end

		return "Round resolved: extracted"
	end

	if reason == "NoActivePlayersRemaining" then
		return "Round resolved: no survivors remained"
	end

	if reason == "ExtractionFull" then
		return "Round resolved: evacuation filled before you escaped"
	end

	return "Round resolved: lost carried loot"
end

local function formatMatchLossReason(lossReason: string?): string
	if lossReason == "DiedBeforeExtraction" then
		return "died before extraction"
	end

	if lossReason == "NoExtractionSlot" then
		return "evacuation filled up"
	end

	if lossReason == "NoSurvivorsRemaining" then
		return "no survivors remained"
	end

	if lossReason == "LootNotSecured" then
		return "loot was not secured"
	end

	return "loot was lost"
end

local function setScoreboardEntries(allResults: any)
	table.clear(currentResultScoreEntries)

	if typeof(allResults) ~= "table" then
		rebuildScoreboardRows()
		return
	end

	for index, entry in allResults do
		if index > 4 then
			break
		end

		if typeof(entry) == "table" then
			table.insert(currentResultScoreEntries, entry)
		end
	end

	rebuildScoreboardRows()
end

local function buildResultCallout(allResults: any): string
	if typeof(allResults) ~= "table" then
		return ""
	end

	local extractedCount = 0
	local topExtractorName: string? = nil
	local topExtractorValue = -1
	local biggestLossName: string? = nil
	local biggestLossValue = -1

	for _, entry in allResults do
		if typeof(entry) ~= "table" then
			continue
		end

		local name = tostring(entry.name or "Unknown")
		local didExtract = entry.didExtract == true
		local securedValue = math.max(0, tonumber(entry.securedValue) or 0)
		local carriedValue = math.max(0, tonumber(entry.carriedValue) or 0)

		if didExtract then
			extractedCount += 1
			if securedValue > topExtractorValue then
				topExtractorValue = securedValue
				topExtractorName = name
			end
		elseif carriedValue > biggestLossValue then
			biggestLossValue = carriedValue
			biggestLossName = name
		end
	end

	if extractedCount == 1 and topExtractorName then
		return ("LAST SURVIVOR  %s escaped alone"):format(topExtractorName)
	end

	if topExtractorName and topExtractorValue > 0 then
		return ("MVP EXTRACT  %s secured %d value"):format(topExtractorName, topExtractorValue)
	end

	if biggestLossName and biggestLossValue > 0 then
		return ("BIGGEST LOSS  %s dropped %d value"):format(biggestLossName, biggestLossValue)
	end

	return "RAID COMPLETE  No secured loot this round"
end

local function formatLocalMatchSummaryToast(localResult: any, roundReason: string?): string?
	if typeof(localResult) ~= "table" then
		return nil
	end

	local didExtract = localResult.didExtract == true
	local carriedValue = math.max(0, tonumber(localResult.carriedValue) or 0)
	local securedValue = math.max(0, tonumber(localResult.securedValue) or 0)
	local lossReason = localResult.lossReason
	if typeof(lossReason) ~= "string" then
		lossReason = nil
	end

	if didExtract then
		if securedValue > 0 then
			return ("Round resolved: extracted with %d value"):format(securedValue)
		end

		return formatRoundResolutionToast(true, roundReason)
	end

	if carriedValue > 0 then
		return ("Round resolved: lost %d value, %s"):format(carriedValue, formatMatchLossReason(lossReason))
	end

	return formatRoundResolutionToast(false, roundReason)
end

local function showResultPanel(titleText: string, summaryText: string, valueText: string, reasonText: string?, accentColor: Color3)
	resultTitle.Text = titleText
	resultSummary.Text = summaryText
	resultValueLabel.Text = valueText
	currentResultReasonText = reasonText or ""
	resultValueLabel.TextColor3 = accentColor
	resultPanelStroke.Color = accentColor
	resultPanel.Visible = true
	refreshResultPanelStatus()
end

local function presentLocalMatchSummary(localResult: any, allResults: any, roundReason: string?): string?
	if typeof(localResult) ~= "table" then
		return nil
	end

	local didExtract = localResult.didExtract == true
	local carriedValue = math.max(0, tonumber(localResult.carriedValue) or 0)
	local securedValue = math.max(0, tonumber(localResult.securedValue) or 0)
	local lossReason = localResult.lossReason
	if typeof(lossReason) ~= "string" then
		lossReason = nil
	end

	setScoreboardEntries(allResults)
	currentResultCalloutText = buildResultCallout(allResults)

	if didExtract then
		resultHeroBadge.Text = "EXTRACTED"
		resultHeroBadge.BackgroundColor3 = Color3.fromRGB(76, 142, 96)
		showResultPanel(
			"Raid Result: Extracted",
			"You secured your carried loot and escaped the hospital.",
			("Secured Value: %d"):format(securedValue),
			if roundReason == "ExtractionFull" then "The last extraction slot was claimed with your escape." else nil,
			Color3.fromRGB(120, 198, 142)
		)
	else
		resultHeroBadge.Text = "FAILED"
		resultHeroBadge.BackgroundColor3 = Color3.fromRGB(160, 76, 76)
		local reasonText = formatMatchLossReason(lossReason)
		showResultPanel(
			"Raid Result: Failed",
			if carriedValue > 0
				then ("You lost %d carried value before it could be secured."):format(carriedValue)
				else "You did not secure any carried loot this run.",
			("Secured Value: %d"):format(securedValue),
			("Loss Reason: %s"):format(reasonText),
			Color3.fromRGB(214, 108, 108)
		)
	end

	return formatLocalMatchSummaryToast(localResult, roundReason)
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
	if not legacyCombatEnabled then
		return nil
	end

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
	if not legacyCombatEnabled then
		return nil
	end

	local tool = getEquippedWeapon()
	if tool and tool.Name == launcherName then
		return tool
	end
	return nil
end

local function equipWeaponByName(weaponName: string)
	if not legacyCombatEnabled then
		return
	end

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
	if not legacyCombatEnabled then
		return nil
	end

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
	if not legacyCombatEnabled then
		crosshair.Visible = false
		return
	end

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
	if not legacyCombatEnabled then
		return
	end

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
refreshRoundHud()

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

roundStateChangedEvent.OnClientEvent:Connect(function(data)
	currentRoundPhase = tostring(data.phase or "Lobby")
	if currentRoundPhase == "Preparation" or currentRoundPhase == "Lobby" then
		hideResultPanel()
	end
	refreshRoundHud()
end)

roundTimerUpdatedEvent.OnClientEvent:Connect(function(data)
	currentRoundTimeRemaining = math.max(0, tonumber(data.timeRemaining) or 0)
	refreshRoundHud()
end)

playerRoundStateChangedEvent.OnClientEvent:Connect(function(data)
	currentCarriedValue = math.max(0, tonumber(data.carriedValue) or 0)
	currentHasRareLoot = data.hasRareLoot == true
	localPlayerExtracted = data.extracted == true
	currentZoneId = tostring(data.currentZoneId or "--")
	refreshRoundHud()
end)

inventoryUpdatedEvent.OnClientEvent:Connect(function(data)
	currentInventory = {}
	local items = data.items
	if typeof(items) == "table" then
		for _, item in items do
			if typeof(item) == "string" then
				table.insert(currentInventory, item)
			end
		end
	end
	currentCarriedValue = math.max(0, tonumber(data.carriedValue) or currentCarriedValue)
	currentHasRareLoot = data.hasRareLoot == true
	refreshRoundHud()
end)

objectivesUpdatedEvent.OnClientEvent:Connect(function(data)
	currentObjectivesCompleted = math.max(0, tonumber(data.completed) or 0)
	currentObjectivesRequired = math.max(0, tonumber(data.required) or 0)
	refreshRoundHud()
end)

local extractionStateChangedEvent = netFolder:WaitForChild(Net.Events.ExtractionStateChanged) :: RemoteEvent
extractionStateChangedEvent.OnClientEvent:Connect(function(data)
	currentExtractionOpen = data.isOpen == true
	currentExtractionSlotsRemaining = math.max(0, tonumber(data.slotsRemaining) or 0)
	refreshRoundHud()
end)

attackFeedbackEvent.OnClientEvent:Connect(function(data)
	if not legacyCombatEnabled then
		return
	end

	if data.hit == true then
		setToast("Target reached")
	else
		setToast("No target")
	end
end)

requestExtractEvent.OnClientEvent:Connect(function(data)
	if data.ok == true then
		setToast("Extraction locked in")
	else
		local reason = tostring(data.reason or "ExtractionFailed")
		setToast(formatExtractionFailureReason(reason))
	end
end)

matchResultEvent.OnClientEvent:Connect(function(data)
	local reason = data.reason
	if typeof(reason) ~= "string" then
		reason = nil
	end

	local panelToast = presentLocalMatchSummary(data.localResult, data.allResults, reason)
	if panelToast then
		setToast(panelToast)
		return
	end

	local extractedUserIds = data.extractedUserIds
	if typeof(extractedUserIds) == "table" then
		local didExtract = false
		for _, userId in extractedUserIds do
			if tonumber(userId) == player.UserId then
				didExtract = true
				break
			end
		end

		setToast(formatRoundResolutionToast(didExtract or localPlayerExtracted, reason))
	end
end)

sabotageFeedbackEvent.OnClientEvent:Connect(function(data)
	local message = tostring(data.message or "Action failed")
	setToast(message)
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
		return
	end

	if input.KeyCode == Enum.KeyCode.G then
		local firstItem = currentInventory[1]
		if firstItem then
			requestDropLootEvent:FireServer({
				lootId = firstItem,
			})
		end
		return
	end

	if input.KeyCode == Enum.KeyCode.F then
		local firstItem = currentInventory[1]
		if firstItem then
			requestUseItemEvent:FireServer({
				lootId = firstItem,
			})
			return
		end
	end

	if input.KeyCode == Enum.KeyCode.X then
		requestExtractEvent:FireServer()
		return
	end

	if input.KeyCode == Enum.KeyCode.T then
		local doorId = getNearestDoorId(12)
		if doorId then
			requestInteractEvent:FireServer({
				interactionId = "open_door",
				objectId = doorId,
			})
		end
		return
	end

	if input.KeyCode == Enum.KeyCode.Q then
		local doorId = getNearestDoorId(12)
		if doorId then
			requestSabotageEvent:FireServer({
				interactionId = "lock_door",
				objectId = doorId,
			})
		end
		return
	end

	if input.KeyCode == Enum.KeyCode.C then
		local zoneId = getNearestZoneId(20)
		if zoneId then
			requestSabotageEvent:FireServer({
				interactionId = "cut_power",
				objectId = zoneId,
			})
		end
		return
	end

	if input.KeyCode == Enum.KeyCode.V then
		if currentZoneId ~= "--" then
			requestInteractEvent:FireServer({
				interactionId = "recover_power",
				objectId = currentZoneId,
			})
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
