--!strict

export type InteractionType =
	"OpenDoor"
	| "CloseDoor"
	| "PickupLoot"
	| "DropLoot"
	| "UseItem"
	| "LockDoor"
	| "CutPower"
	| "MakeNoise"
	| "StealKeyResource"
	| "RecoverPower"
	| "Extract"

export type InteractionDef = {
	id: string,
	interactionType: InteractionType,
	displayName: string,
	serverAuthorityOnly: boolean,
	allowedPhases: { string },
}

local interactionList: { InteractionDef } = {
	{
		id = "open_door",
		interactionType = "OpenDoor",
		displayName = "Open Door",
		serverAuthorityOnly = true,
		allowedPhases = { "Preparation", "Traversal", "Finale" },
	},
	{
		id = "close_door",
		interactionType = "CloseDoor",
		displayName = "Close Door",
		serverAuthorityOnly = true,
		allowedPhases = { "Preparation", "Traversal", "Finale" },
	},
	{
		id = "pickup_loot",
		interactionType = "PickupLoot",
		displayName = "Pick Up",
		serverAuthorityOnly = true,
		allowedPhases = { "Preparation", "Traversal", "Finale" },
	},
	{
		id = "drop_loot",
		interactionType = "DropLoot",
		displayName = "Drop Item",
		serverAuthorityOnly = true,
		allowedPhases = { "Preparation", "Traversal", "Finale" },
	},
	{
		id = "use_item",
		interactionType = "UseItem",
		displayName = "Use Item",
		serverAuthorityOnly = true,
		allowedPhases = { "Preparation", "Traversal", "Finale" },
	},
	{
		id = "lock_door",
		interactionType = "LockDoor",
		displayName = "Jam Door",
		serverAuthorityOnly = true,
		allowedPhases = { "Traversal", "Finale" },
	},
	{
		id = "cut_power",
		interactionType = "CutPower",
		displayName = "Cut Power",
		serverAuthorityOnly = true,
		allowedPhases = { "Traversal", "Finale" },
	},
	{
		id = "make_noise",
		interactionType = "MakeNoise",
		displayName = "Make Noise",
		serverAuthorityOnly = true,
		allowedPhases = { "Traversal", "Finale" },
	},
	{
		id = "steal_key_resource",
		interactionType = "StealKeyResource",
		displayName = "Steal Resource",
		serverAuthorityOnly = true,
		allowedPhases = { "Traversal", "Finale" },
	},
	{
		id = "recover_power",
		interactionType = "RecoverPower",
		displayName = "Restore Power",
		serverAuthorityOnly = true,
		allowedPhases = { "Traversal", "Finale" },
	},
	{
		id = "extract",
		interactionType = "Extract",
		displayName = "Extract",
		serverAuthorityOnly = true,
		allowedPhases = { "Finale" },
	},
}

local interactionById: { [string]: InteractionDef } = {}
for _, interactionDef in interactionList do
	interactionById[interactionDef.id] = interactionDef
end

local InteractionDefs = {
	Types = table.freeze({
		OpenDoor = "OpenDoor" :: InteractionType,
		CloseDoor = "CloseDoor" :: InteractionType,
		PickupLoot = "PickupLoot" :: InteractionType,
		DropLoot = "DropLoot" :: InteractionType,
		UseItem = "UseItem" :: InteractionType,
		LockDoor = "LockDoor" :: InteractionType,
		CutPower = "CutPower" :: InteractionType,
		MakeNoise = "MakeNoise" :: InteractionType,
		StealKeyResource = "StealKeyResource" :: InteractionType,
		RecoverPower = "RecoverPower" :: InteractionType,
		Extract = "Extract" :: InteractionType,
	}),
	All = table.freeze(interactionList),
}

function InteractionDefs.getById(interactionId: string): InteractionDef?
	return interactionById[interactionId]
end

function InteractionDefs.isAllowedInPhase(interactionId: string, phase: string): boolean
	local interactionDef = interactionById[interactionId]
	if not interactionDef then
		return false
	end

	for _, allowedPhase in interactionDef.allowedPhases do
		if allowedPhase == phase then
			return true
		end
	end

	return false
end

return table.freeze(InteractionDefs)
