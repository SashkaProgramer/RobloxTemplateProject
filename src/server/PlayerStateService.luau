--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local LootDefs = require(Shared:WaitForChild("LootDefs"))
local Net = require(Shared:WaitForChild("Net"))

local RoundService = require(script.Parent:WaitForChild("RoundService"))

export type PlayerRoundState = {
	alive: boolean,
	extracted: boolean,
	currentZoneId: string?,
	inventory: { string },
	maxSlots: number,
	carriedValue: number,
	hasRareLoot: boolean,
	temporaryFlags: { [string]: boolean },
}

type LegacyState = {
	stamina: number,
	hunger: number,
	scrap: number,
	isSprinting: boolean,
}

type PlayerState = {
	legacy: LegacyState,
	round: PlayerRoundState,
}

type MatchSummaryPayload = {
	didExtract: boolean,
	carriedValue: number,
	securedValue: number,
	lossReason: string?,
}

type MatchScoreEntry = {
	userId: number,
	name: string,
	didExtract: boolean,
	carriedValue: number,
	securedValue: number,
	lossReason: string?,
}

local PlayerStateService = {}

local states: { [Player]: PlayerState } = {}
local stateUpdateEvent: RemoteEvent
local setSprintingEvent: RemoteEvent
local playerRoundStateChangedEvent: RemoteEvent
local inventoryUpdatedEvent: RemoteEvent
local accum = 0
local nameTagGuiName = "PlayerNameTag"

local function evaluateRoundResolution()
	if RoundService.GetCurrentPhase() ~= "Finale" then
		return
	end

	local hasActiveRoundPlayer = false
	for _, state in states do
		if state.round.alive and not state.round.extracted then
			hasActiveRoundPlayer = true
			break
		end
	end

	if not hasActiveRoundPlayer then
		RoundService.ResolveCurrentRound("NoActivePlayersRemaining")
	end
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

local function getOrCreateState(player: Player): PlayerState?
	return states[player]
end

local function createRoundState(): PlayerRoundState
	return {
		alive = true,
		extracted = false,
		currentZoneId = nil,
		inventory = {},
		maxSlots = 4,
		carriedValue = 0,
		hasRareLoot = false,
		temporaryFlags = {},
	}
end

local function createPlayerState(): PlayerState
	return {
		legacy = {
			stamina = GameConfig.Player.MaxStamina,
			hunger = GameConfig.Player.HungerMax,
			scrap = 0,
			isSprinting = false,
		},
		round = createRoundState(),
	}
end

local function rebuildDerivedRoundState(roundState: PlayerRoundState)
	local carriedValue = 0
	local hasRareLoot = false

	for _, lootId in roundState.inventory do
		local lootDef = LootDefs.getById(lootId)
		if lootDef then
			carriedValue += lootDef.value
			if lootDef.rarity == LootDefs.Rarities.Rare then
				hasRareLoot = true
			end
		end
	end

	roundState.carriedValue = carriedValue
	roundState.hasRareLoot = hasRareLoot
end

local function applyMoveSpeed(player: Player, state: PlayerState)
	local humanoid = getHumanoid(player)
	if not humanoid then
		return
	end

	if state.legacy.isSprinting and state.legacy.stamina > 0 then
		humanoid.WalkSpeed = GameConfig.Player.SprintWalkSpeed
	else
		humanoid.WalkSpeed = GameConfig.Player.NormalWalkSpeed
	end
end

local function resolveNameTagPart(character: Model): BasePart?
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	local waitedHead = character:WaitForChild("Head", 2)
	if waitedHead and waitedHead:IsA("BasePart") then
		return waitedHead
	end

	local waitedRoot = character:WaitForChild("HumanoidRootPart", 2)
	if waitedRoot and waitedRoot:IsA("BasePart") then
		return waitedRoot
	end

	return nil
end

local function applyCharacterNameTag(character: Model, displayName: string)
	local tagPart = resolveNameTagPart(character)
	if not tagPart then
		return
	end

	local existingTag = character:FindFirstChild(nameTagGuiName)
	if existingTag then
		existingTag:Destroy()
	end

	local nameTag = Instance.new("BillboardGui")
	nameTag.Name = nameTagGuiName
	nameTag.Adornee = tagPart
	nameTag.Size = UDim2.fromOffset(170, 34)
	nameTag.StudsOffsetWorldSpace = Vector3.new(0, 2.9, 0)
	nameTag.AlwaysOnTop = true
	nameTag.MaxDistance = 230
	nameTag.Parent = character

	local bg = Instance.new("Frame")
	bg.Name = "Bg"
	bg.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
	bg.BackgroundTransparency = 0.4
	bg.BorderSizePixel = 0
	bg.Size = UDim2.fromScale(1, 1)
	bg.Parent = nameTag

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 8)
	bgCorner.Parent = bg

	local nameText = Instance.new("TextLabel")
	nameText.Name = "Name"
	nameText.BackgroundTransparency = 1
	nameText.Size = UDim2.fromScale(1, 1)
	nameText.Font = Enum.Font.SourceSansBold
	nameText.TextScaled = true
	nameText.TextSize = 24
	nameText.Text = displayName
	nameText.TextColor3 = Color3.fromRGB(236, 245, 255)
	nameText.TextStrokeTransparency = 0.2
	nameText.TextStrokeColor3 = Color3.fromRGB(8, 12, 18)
	nameText.Parent = bg
end

local function applyConfiguredCharacterState(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end

	local configuredName = GameConfig.Player.DisplayName
	if typeof(configuredName) == "string" and configuredName ~= "" then
		humanoid.DisplayName = configuredName
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Subject
		humanoid.NameDisplayDistance = 220
		humanoid.NameOcclusion = Enum.NameOcclusion.NoOcclusion
		applyCharacterNameTag(character, configuredName)
	end

	local maxHealth = math.max(1, GameConfig.Player.MaxHealth)
	humanoid.MaxHealth = maxHealth
	humanoid.Health = maxHealth
end

local function pushLegacyState(player: Player)
	local state = getOrCreateState(player)
	if not state then
		return
	end

	stateUpdateEvent:FireClient(player, {
		stamina = math.floor(state.legacy.stamina + 0.5),
		hunger = math.floor(state.legacy.hunger + 0.5),
		scrap = state.legacy.scrap,
		isSprinting = state.legacy.isSprinting,
	})
end

local function pushRoundState(player: Player)
	local state = getOrCreateState(player)
	if not state then
		return
	end

	playerRoundStateChangedEvent:FireClient(player, {
		alive = state.round.alive,
		extracted = state.round.extracted,
		currentZoneId = state.round.currentZoneId,
		maxSlots = state.round.maxSlots,
		carriedValue = state.round.carriedValue,
		hasRareLoot = state.round.hasRareLoot,
		temporaryFlags = state.round.temporaryFlags,
	})
end

local function pushInventory(player: Player)
	local state = getOrCreateState(player)
	if not state then
		return
	end

	inventoryUpdatedEvent:FireClient(player, {
		items = table.clone(state.round.inventory),
		maxSlots = state.round.maxSlots,
		carriedValue = state.round.carriedValue,
		hasRareLoot = state.round.hasRareLoot,
	})
end

local function pushAllState(player: Player)
	pushLegacyState(player)
	pushRoundState(player)
	pushInventory(player)
end

local function buildMatchSummary(player: Player, roundReason: string?): MatchSummaryPayload
	local state = getOrCreateState(player)
	if not state then
		return {
			didExtract = false,
			carriedValue = 0,
			securedValue = 0,
			lossReason = "StateUnavailable",
		}
	end

	local didExtract = state.round.extracted
	local carriedValue = state.round.carriedValue
	local securedValue = if didExtract then carriedValue else 0
	local lossReason: string? = nil

	if not didExtract then
		if not state.round.alive then
			lossReason = "DiedBeforeExtraction"
		elseif roundReason == "ExtractionFull" then
			lossReason = "NoExtractionSlot"
		elseif roundReason == "NoActivePlayersRemaining" then
			lossReason = "NoSurvivorsRemaining"
		else
			lossReason = "LootNotSecured"
		end
	end

	return {
		didExtract = didExtract,
		carriedValue = carriedValue,
		securedValue = securedValue,
		lossReason = lossReason,
	}
end

local function buildMatchScoreboard(roundReason: string?): { MatchScoreEntry }
	local results = {}

	for player in states do
		local summary = buildMatchSummary(player, roundReason)
		table.insert(results, {
			userId = player.UserId,
			name = if player.DisplayName ~= "" then player.DisplayName else player.Name,
			didExtract = summary.didExtract,
			carriedValue = summary.carriedValue,
			securedValue = summary.securedValue,
			lossReason = summary.lossReason,
		})
	end

	table.sort(results, function(a: MatchScoreEntry, b: MatchScoreEntry): boolean
		if a.didExtract ~= b.didExtract then
			return a.didExtract and not b.didExtract
		end

		if a.securedValue ~= b.securedValue then
			return a.securedValue > b.securedValue
		end

		if a.carriedValue ~= b.carriedValue then
			return a.carriedValue > b.carriedValue
		end

		return a.name < b.name
	end)

	return results
end

function PlayerStateService.AddScrap(player: Player, amount: number)
	local state = getOrCreateState(player)
	if not state then
		return
	end

	state.legacy.scrap += math.max(0, math.floor(amount))
	pushLegacyState(player)
end

function PlayerStateService.IsSprinting(player: Player): boolean
	local state = getOrCreateState(player)
	if not state then
		return false
	end

	return state.legacy.isSprinting
end

function PlayerStateService.GetRoundState(player: Player): PlayerRoundState?
	local state = getOrCreateState(player)
	if not state then
		return nil
	end

	return state.round
end

function PlayerStateService.ResetRoundState(player: Player)
	local state = getOrCreateState(player)
	if not state then
		return
	end

	state.round = createRoundState()
	pushRoundState(player)
	pushInventory(player)
end

function PlayerStateService.SetAlive(player: Player, isAlive: boolean)
	local state = getOrCreateState(player)
	if not state then
		return
	end

	state.round.alive = isAlive
	if not isAlive then
		state.legacy.isSprinting = false
	end

	applyMoveSpeed(player, state)
	pushLegacyState(player)
	pushRoundState(player)
	evaluateRoundResolution()
end

function PlayerStateService.SetExtracted(player: Player, extracted: boolean)
	local state = getOrCreateState(player)
	if not state then
		return
	end

	state.round.extracted = extracted
	if extracted then
		state.legacy.isSprinting = false
	end

	applyMoveSpeed(player, state)
	pushLegacyState(player)
	pushRoundState(player)
	evaluateRoundResolution()
end

function PlayerStateService.SetCurrentZoneId(player: Player, currentZoneId: string?)
	local state = getOrCreateState(player)
	if not state then
		return
	end

	state.round.currentZoneId = currentZoneId
	pushRoundState(player)
end

function PlayerStateService.SetTemporaryFlag(player: Player, flagName: string, isEnabled: boolean)
	local state = getOrCreateState(player)
	if not state then
		return
	end

	if isEnabled then
		state.round.temporaryFlags[flagName] = true
	else
		state.round.temporaryFlags[flagName] = nil
	end

	pushRoundState(player)
end

function PlayerStateService.AddInventoryItem(player: Player, lootId: string): boolean
	local state = getOrCreateState(player)
	if not state then
		return false
	end

	if not LootDefs.getById(lootId) then
		return false
	end

	if #state.round.inventory >= state.round.maxSlots then
		return false
	end

	table.insert(state.round.inventory, lootId)
	rebuildDerivedRoundState(state.round)
	pushRoundState(player)
	pushInventory(player)
	return true
end

function PlayerStateService.RemoveInventoryItem(player: Player, lootId: string): boolean
	local state = getOrCreateState(player)
	if not state then
		return false
	end

	for index, itemId in state.round.inventory do
		if itemId == lootId then
			table.remove(state.round.inventory, index)
			rebuildDerivedRoundState(state.round)
			pushRoundState(player)
			pushInventory(player)
			return true
		end
	end

	return false
end

local function onSetSprinting(player: Player, wantsSprint: boolean)
	local state = getOrCreateState(player)
	if not state then
		return
	end

	local canSprint = wantsSprint == true
		and state.legacy.stamina > 0
		and state.round.alive
		and not state.round.extracted

	state.legacy.isSprinting = canSprint
	applyMoveSpeed(player, state)
	pushLegacyState(player)
end

local function onPlayerAdded(player: Player)
	states[player] = createPlayerState()

	player.CharacterAdded:Connect(function(character: Model)
		applyConfiguredCharacterState(character)
		task.defer(function()
			task.wait(0.65)
			if character.Parent then
				applyConfiguredCharacterState(character)
			end
			task.wait(1.15)
			if character.Parent then
				applyConfiguredCharacterState(character)
			end
		end)

		local state = getOrCreateState(player)
		if state then
			state.legacy.isSprinting = false
			state.round.alive = true
			state.round.extracted = false
			applyMoveSpeed(player, state)
			pushAllState(player)
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				PlayerStateService.SetAlive(player, false)
			end)
		end
	end)

	local existingCharacter = player.Character
	if existingCharacter then
		task.spawn(function()
			applyConfiguredCharacterState(existingCharacter)
			task.wait(0.5)
			if existingCharacter.Parent then
				applyConfiguredCharacterState(existingCharacter)
			end
		end)
	end

	pushAllState(player)
end

local function onPlayerRemoving(player: Player)
	states[player] = nil
	evaluateRoundResolution()
end

function PlayerStateService.Start(netFolder: Folder)
	stateUpdateEvent = netFolder:WaitForChild(Net.Events.StateUpdate) :: RemoteEvent
	setSprintingEvent = netFolder:WaitForChild(Net.Events.SetSprinting) :: RemoteEvent
	playerRoundStateChangedEvent = netFolder:WaitForChild(Net.Events.PlayerRoundStateChanged) :: RemoteEvent
	inventoryUpdatedEvent = netFolder:WaitForChild(Net.Events.InventoryUpdated) :: RemoteEvent

	setSprintingEvent.OnServerEvent:Connect(onSetSprinting)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	RoundService.RegisterMatchSummaryProvider(function(player: Player, roundReason: string?): MatchSummaryPayload
		return buildMatchSummary(player, roundReason)
	end)
	RoundService.RegisterMatchScoreboardProvider(function(roundReason: string?): { MatchScoreEntry }
		return buildMatchScoreboard(roundReason)
	end)

	RoundService.OnPhaseChanged(function(newPhase: string)
		if newPhase ~= "Preparation" then
			return
		end

		for player, state in states do
			state.round = createRoundState()
			state.legacy.isSprinting = false
			applyMoveSpeed(player, state)
			pushAllState(player)
		end
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		accum += dt
		if accum < 0.2 then
			return
		end

		local step = accum
		accum = 0

		for player, state in states do
			if state.legacy.isSprinting and state.legacy.stamina > 0 then
				state.legacy.stamina = math.max(0, state.legacy.stamina - GameConfig.Player.StaminaDrainPerSecond * step)
				if state.legacy.stamina <= 0 then
					state.legacy.isSprinting = false
				end
			else
				state.legacy.stamina = math.min(
					GameConfig.Player.MaxStamina,
					state.legacy.stamina + GameConfig.Player.StaminaRegenPerSecond * step
				)
			end

			state.legacy.hunger = math.max(0, state.legacy.hunger - GameConfig.Player.HungerDrainPerSecond * step)
			applyMoveSpeed(player, state)
			pushLegacyState(player)
		end
	end)
end

return PlayerStateService
