--!strict

export type LootRarity = "Common" | "Uncommon" | "Rare"

export type LootDef = {
	id: string,
	name: string,
	rarity: LootRarity,
	value: number,
	stackable: boolean,
	tags: { string }?,
}

local lootList: { LootDef } = {
	{
		id = "scrap_bundle",
		name = "Scrap Bundle",
		rarity = "Common",
		value = 12,
		stackable = true,
		tags = { "Junk" },
	},
	{
		id = "copper_wires",
		name = "Copper Wires",
		rarity = "Common",
		value = 18,
		stackable = true,
		tags = { "Junk", "Utility" },
	},
	{
		id = "service_watch",
		name = "Service Watch",
		rarity = "Uncommon",
		value = 55,
		stackable = false,
		tags = { "Valuable" },
	},
	{
		id = "sealed_med_case",
		name = "Sealed Med Case",
		rarity = "Uncommon",
		value = 70,
		stackable = false,
		tags = { "Utility", "Medical" },
	},
	{
		id = "fuse",
		name = "Fuse",
		rarity = "Uncommon",
		value = 45,
		stackable = false,
		tags = { "KeyResource" },
	},
	{
		id = "cursed_idol",
		name = "Cursed Idol",
		rarity = "Rare",
		value = 220,
		stackable = false,
		tags = { "RareLoot", "Artifact" },
	},
	{
		id = "royal_reliquary",
		name = "Royal Reliquary",
		rarity = "Rare",
		value = 300,
		stackable = false,
		tags = { "RareLoot", "Artifact" },
	},
}

local lootById: { [string]: LootDef } = {}
for _, lootDef in lootList do
	lootById[lootDef.id] = lootDef
end

local LootDefs = {
	Rarities = table.freeze({
		Common = "Common" :: LootRarity,
		Uncommon = "Uncommon" :: LootRarity,
		Rare = "Rare" :: LootRarity,
	}),
	All = table.freeze(lootList),
}

function LootDefs.getById(lootId: string): LootDef?
	return lootById[lootId]
end

function LootDefs.mustGetById(lootId: string): LootDef
	local lootDef = lootById[lootId]
	assert(lootDef, ("Unknown loot id: %s"):format(lootId))
	return lootDef
end

function LootDefs.hasTag(lootId: string, tag: string): boolean
	local lootDef = lootById[lootId]
	if not lootDef or not lootDef.tags then
		return false
	end

	for _, lootTag in lootDef.tags do
		if lootTag == tag then
			return true
		end
	end

	return false
end

return table.freeze(LootDefs)
