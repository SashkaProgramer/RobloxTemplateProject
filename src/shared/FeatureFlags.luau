--!strict

local FeatureFlags = {
	UseHospitalWorld = true,
	EnableLegacyWorld = false,
	EnableLegacyInfected = true,
	EnableLegacyCombat = false,
}

return table.freeze(FeatureFlags)
