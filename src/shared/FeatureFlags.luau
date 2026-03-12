--!strict

local FeatureFlags = {
	UseHospitalWorld = true,
	EnableLegacyWorld = false,
	EnableLegacyInfected = false,
	EnableLegacyCombat = false,
}

return table.freeze(FeatureFlags)
