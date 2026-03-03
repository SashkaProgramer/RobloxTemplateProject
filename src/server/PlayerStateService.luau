--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))

type PlayerState = {
	stamina: number,
	hunger: number,
	scrap: number,
	isSprinting: boolean,
}

local PlayerStateService = {}

local states: { [Player]: PlayerState } = {}
local stateUpdateEvent: RemoteEvent
local setSprintingEvent: RemoteEvent
local accum = 0

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function applyMoveSpeed(player: Player, state: PlayerState)
	local humanoid = getHumanoid(player)
	if not humanoid then
		return
	end

	if state.isSprinting and state.stamina > 0 then
		humanoid.WalkSpeed = GameConfig.Player.SprintWalkSpeed
	else
		humanoid.WalkSpeed = GameConfig.Player.NormalWalkSpeed
	end
end

local function pushState(player: Player)
	local state = states[player]
	if not state then
		return
	end

	stateUpdateEvent:FireClient(player, {
		stamina = math.floor(state.stamina + 0.5),
		hunger = math.floor(state.hunger + 0.5),
		scrap = state.scrap,
		isSprinting = state.isSprinting,
	})
end

function PlayerStateService.AddScrap(player: Player, amount: number)
	local state = states[player]
	if not state then
		return
	end

	state.scrap += math.max(0, math.floor(amount))
	pushState(player)
end

function PlayerStateService.IsSprinting(player: Player): boolean
	local state = states[player]
	if not state then
		return false
	end
	return state.isSprinting
end

local function onSetSprinting(player: Player, wantsSprint: boolean)
	local state = states[player]
	if not state then
		return
	end

	state.isSprinting = wantsSprint == true and state.stamina > 0
	applyMoveSpeed(player, state)
	pushState(player)
end

local function onPlayerAdded(player: Player)
	states[player] = {
		stamina = GameConfig.Player.MaxStamina,
		hunger = GameConfig.Player.HungerMax,
		scrap = 0,
		isSprinting = false,
	}

	player.CharacterAdded:Connect(function()
		local state = states[player]
		if state then
			state.isSprinting = false
			applyMoveSpeed(player, state)
			pushState(player)
		end
	end)
end

local function onPlayerRemoving(player: Player)
	states[player] = nil
end

function PlayerStateService.Start(netFolder: Folder)
	stateUpdateEvent = netFolder:WaitForChild(Net.Events.StateUpdate) :: RemoteEvent
	setSprintingEvent = netFolder:WaitForChild(Net.Events.SetSprinting) :: RemoteEvent
	setSprintingEvent.OnServerEvent:Connect(onSetSprinting)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	RunService.Heartbeat:Connect(function(dt: number)
		accum += dt
		if accum < 0.2 then
			return
		end
		local step = accum
		accum = 0

		for player, state in states do
			if state.isSprinting and state.stamina > 0 then
				state.stamina = math.max(0, state.stamina - GameConfig.Player.StaminaDrainPerSecond * step)
				if state.stamina <= 0 then
					state.isSprinting = false
				end
			else
				state.stamina = math.min(GameConfig.Player.MaxStamina, state.stamina + GameConfig.Player.StaminaRegenPerSecond * step)
			end

			state.hunger = math.max(0, state.hunger - GameConfig.Player.HungerDrainPerSecond * step)
			applyMoveSpeed(player, state)
			pushState(player)
		end
	end)
end

return PlayerStateService
