--!strict

export type RoundPhase = "Lobby" | "Preparation" | "Traversal" | "Finale" | "Resolved"

export type PhaseConfig = {
	duration: number,
}

export type RoundConfig = {
	minPlayers: number,
	maxPlayers: number,
	extractionSlots: number,
	extractionWindow: number,
	phases: { [RoundPhase]: PhaseConfig },
	phaseOrder: { RoundPhase },
}

local RoundDefs = {}

RoundDefs.Phases = table.freeze({
	Lobby = "Lobby" :: RoundPhase,
	Preparation = "Preparation" :: RoundPhase,
	Traversal = "Traversal" :: RoundPhase,
	Finale = "Finale" :: RoundPhase,
	Resolved = "Resolved" :: RoundPhase,
})

RoundDefs.PhaseOrder = table.freeze({
	RoundDefs.Phases.Lobby,
	RoundDefs.Phases.Preparation,
	RoundDefs.Phases.Traversal,
	RoundDefs.Phases.Finale,
	RoundDefs.Phases.Resolved,
})

RoundDefs.Config = table.freeze({
	minPlayers = 2,
	maxPlayers = 8,
	extractionSlots = 4,
	extractionWindow = 35,
	phases = {
		[RoundDefs.Phases.Lobby] = {
			duration = 15,
		},
		[RoundDefs.Phases.Preparation] = {
			duration = 30,
		},
		[RoundDefs.Phases.Traversal] = {
			duration = 240,
		},
		[RoundDefs.Phases.Finale] = {
			duration = 75,
		},
		[RoundDefs.Phases.Resolved] = {
			duration = 12,
		},
	},
	phaseOrder = RoundDefs.PhaseOrder,
}) :: RoundConfig

function RoundDefs.isPhase(value: string): boolean
	for _, phase in RoundDefs.PhaseOrder do
		if phase == value then
			return true
		end
	end

	return false
end

function RoundDefs.getNextPhase(currentPhase: RoundPhase): RoundPhase?
	for index, phase in RoundDefs.PhaseOrder do
		if phase == currentPhase then
			return RoundDefs.PhaseOrder[index + 1]
		end
	end

	return nil
end

function RoundDefs.getPhaseDuration(phase: RoundPhase): number
	local config = RoundDefs.Config.phases[phase]
	if config then
		return config.duration
	end

	return 0
end

return table.freeze(RoundDefs)
