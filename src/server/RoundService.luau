--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local RoundDefs = require(Shared:WaitForChild("RoundDefs"))

type RoundPhase = "Lobby" | "Preparation" | "Traversal" | "Finale" | "Resolved"

type RoundRuntimeState = {
	roundId: number,
	phase: RoundPhase,
	phaseEndsAt: number?,
	extractionOpen: boolean,
	extractionSlots: number,
	extractionSlotsRemaining: number,
	activePlayers: number,
}

type MatchSummaryPayload = {
	didExtract: boolean,
	carriedValue: number,
	securedValue: number,
	lossReason: string?,
}

local RoundService = {}

local roundStateChangedEvent: RemoteEvent
local roundTimerUpdatedEvent: RemoteEvent
local extractionStateChangedEvent: RemoteEvent
local matchResultEvent: RemoteEvent

local currentRoundId = 0
local currentPhase: RoundPhase = RoundDefs.Phases.Lobby
local phaseEndsAt: number? = nil
local extractionOpen = false
local extractionSlotsRemaining = RoundDefs.Config.extractionSlots
local loopStarted = false
local extractedUserIds: { number } = {}
local phaseChangedListeners: { (RoundPhase, RoundPhase?) -> () } = {}
local resolvedEarlyReason: string? = nil
local setPhase: (RoundPhase) -> ()
local matchSummaryProvider: ((Player, string?) -> MatchSummaryPayload)? = nil

local function getActivePlayerCount(): number
	return #Players:GetPlayers()
end

local function makeRuntimeState(): RoundRuntimeState
	return {
		roundId = currentRoundId,
		phase = currentPhase,
		phaseEndsAt = phaseEndsAt,
		extractionOpen = extractionOpen,
		extractionSlots = RoundDefs.Config.extractionSlots,
		extractionSlotsRemaining = extractionSlotsRemaining,
		activePlayers = getActivePlayerCount(),
	}
end

local function hasExtractedUserId(userId: number): boolean
	for _, extractedUserId in extractedUserIds do
		if extractedUserId == userId then
			return true
		end
	end

	return false
end

local function broadcastRoundState()
	roundStateChangedEvent:FireAllClients(makeRuntimeState())
end

local function makeTimerPayload(): { [string]: any }
	local endsAt = phaseEndsAt
	local timeRemaining = 0
	if endsAt then
		timeRemaining = math.max(0, math.ceil(endsAt - os.clock()))
	end

	return {
		roundId = currentRoundId,
		phase = currentPhase,
		timeRemaining = timeRemaining,
		phaseEndsAt = endsAt,
	}
end

local function broadcastTimer()
	roundTimerUpdatedEvent:FireAllClients(makeTimerPayload())
end

local function makeExtractionPayload(): { [string]: any }
	return {
		roundId = currentRoundId,
		isOpen = extractionOpen,
		slotsRemaining = extractionSlotsRemaining,
		totalSlots = RoundDefs.Config.extractionSlots,
	}
end

local function broadcastExtractionState()
	extractionStateChangedEvent:FireAllClients(makeExtractionPayload())
end

local function notifyPhaseChanged(newPhase: RoundPhase, previousPhase: RoundPhase?)
	for _, listener in phaseChangedListeners do
		task.spawn(listener, newPhase, previousPhase)
	end
end

local function resolveRound(reason: string?)
	if currentPhase == RoundDefs.Phases.Resolved or currentPhase == RoundDefs.Phases.Lobby then
		return
	end

	resolvedEarlyReason = reason
	setPhase(RoundDefs.Phases.Resolved)
end

setPhase = function(nextPhase: RoundPhase)
	local previousPhase = currentPhase
	currentPhase = nextPhase

	local duration = RoundDefs.getPhaseDuration(nextPhase)
	if duration > 0 then
		phaseEndsAt = os.clock() + duration
	else
		phaseEndsAt = nil
	end

	extractionOpen = nextPhase == RoundDefs.Phases.Finale
	if nextPhase == RoundDefs.Phases.Preparation then
		extractionSlotsRemaining = RoundDefs.Config.extractionSlots
		table.clear(extractedUserIds)
		resolvedEarlyReason = nil
	end

	broadcastRoundState()
	broadcastTimer()
	broadcastExtractionState()

	if nextPhase == RoundDefs.Phases.Resolved then
		local basePayload = {
			roundId = currentRoundId,
			phase = currentPhase,
			extractedUserIds = table.clone(extractedUserIds),
			extractionSlots = RoundDefs.Config.extractionSlots,
			reason = resolvedEarlyReason,
		}

		if matchSummaryProvider then
			for _, player in Players:GetPlayers() do
				local payload = table.clone(basePayload)
				payload.localResult = matchSummaryProvider(player, resolvedEarlyReason)
				matchResultEvent:FireClient(player, payload)
			end
		else
			matchResultEvent:FireAllClients(basePayload)
		end
	end

	notifyPhaseChanged(nextPhase, previousPhase)
end

local function beginNewRound()
	currentRoundId += 1
	setPhase(RoundDefs.Phases.Preparation)
end

local function handlePlayerAdded(player: Player)
	task.defer(function()
		if not player.Parent then
			return
		end

		roundStateChangedEvent:FireClient(player, makeRuntimeState())
		roundTimerUpdatedEvent:FireClient(player, makeTimerPayload())
		extractionStateChangedEvent:FireClient(player, makeExtractionPayload())
	end)
end

local function handleLobbyPhase()
	phaseEndsAt = nil
	extractionOpen = false
	extractionSlotsRemaining = RoundDefs.Config.extractionSlots
	broadcastRoundState()
	broadcastTimer()
	broadcastExtractionState()

	while currentPhase == RoundDefs.Phases.Lobby do
		if getActivePlayerCount() >= RoundDefs.Config.minPlayers then
			beginNewRound()
			return
		end

		task.wait(1)
	end
end

local function handleTimedPhase()
	while currentPhase ~= RoundDefs.Phases.Lobby do
		local endsAt = phaseEndsAt
		if not endsAt then
			return
		end

		broadcastTimer()
		if os.clock() >= endsAt then
			local nextPhase = RoundDefs.getNextPhase(currentPhase)
			if not nextPhase then
				setPhase(RoundDefs.Phases.Lobby)
				return
			end

			setPhase(nextPhase)

			if currentPhase == RoundDefs.Phases.Lobby then
				return
			end
		end

		task.wait(1)
	end
end

local function runLoop()
	while loopStarted do
		if currentPhase == RoundDefs.Phases.Lobby then
			handleLobbyPhase()
		else
			handleTimedPhase()
			if currentPhase == RoundDefs.Phases.Resolved and phaseEndsAt and os.clock() >= phaseEndsAt then
				setPhase(RoundDefs.Phases.Lobby)
			end
		end

		task.wait()
	end
end

function RoundService.Start(netFolder: Folder)
	if loopStarted then
		return
	end

	roundStateChangedEvent = netFolder:WaitForChild(Net.Events.RoundStateChanged) :: RemoteEvent
	roundTimerUpdatedEvent = netFolder:WaitForChild(Net.Events.RoundTimerUpdated) :: RemoteEvent
	extractionStateChangedEvent = netFolder:WaitForChild(Net.Events.ExtractionStateChanged) :: RemoteEvent
	matchResultEvent = netFolder:WaitForChild(Net.Events.MatchResult) :: RemoteEvent

	Players.PlayerAdded:Connect(handlePlayerAdded)
	for _, player in Players:GetPlayers() do
		handlePlayerAdded(player)
	end

	loopStarted = true
	currentRoundId = 0
	currentPhase = RoundDefs.Phases.Lobby
	phaseEndsAt = nil
	extractionOpen = false
	extractionSlotsRemaining = RoundDefs.Config.extractionSlots

	task.spawn(runLoop)
end

function RoundService.GetCurrentPhase(): RoundPhase
	return currentPhase
end

function RoundService.GetRuntimeState(): RoundRuntimeState
	return makeRuntimeState()
end

function RoundService.IsExtractionOpen(): boolean
	return extractionOpen
end

function RoundService.TryRegisterExtraction(player: Player): (boolean, string?)
	if not extractionOpen or currentPhase ~= RoundDefs.Phases.Finale then
		return false, "ExtractionClosed"
	end

	if extractionSlotsRemaining <= 0 then
		return false, "NoSlotsRemaining"
	end

	if hasExtractedUserId(player.UserId) then
		return false, "AlreadyExtracted"
	end

	table.insert(extractedUserIds, player.UserId)
	extractionSlotsRemaining -= 1
	broadcastRoundState()
	broadcastExtractionState()
	if extractionSlotsRemaining <= 0 then
		resolveRound("ExtractionFull")
	end
	return true, nil
end

function RoundService.ResolveCurrentRound(reason: string?)
	resolveRound(reason)
end

function RoundService.OnPhaseChanged(listener: (RoundPhase, RoundPhase?) -> ())
	table.insert(phaseChangedListeners, listener)
end

function RoundService.RegisterMatchSummaryProvider(provider: (Player, string?) -> MatchSummaryPayload)
	matchSummaryProvider = provider
end

return RoundService
