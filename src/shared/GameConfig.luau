--!strict

local GameConfig = {
	Player = {
		MaxStamina = 100,
		StaminaDrainPerSecond = 20,
		StaminaRegenPerSecond = 12,
		LowStaminaThreshold = 20,
		NormalWalkSpeed = 12,
		SprintWalkSpeed = 18,
		HungerMax = 100,
		HungerDrainPerSecond = 1,
		AttackDamage = 34,
		AttackRange = 9,
		AttackCooldown = 0.45,
		AttackFovDegrees = 95,
	},
	Loot = {
		NodeCount = 12,
		RespawnSeconds = 45,
		ScrapMin = 2,
		ScrapMax = 6,
	},
	Infected = {
		Count = 6,
		PatrolRadius = 110,
		VisionRange = 75,
		VisionFovDegrees = 100,
		HearingWalkRange = 20,
		HearingSprintRange = 55,
		WanderSpeed = 6,
		ChaseSpeed = 13,
		Damage = 10,
		DamageCooldown = 1.2,
		AttackRange = 3.8,
		AttackWindupSeconds = 0.35,
		LoseTargetSeconds = 3.5,
		MaxHealth = 100,
		RespawnSeconds = 18,
		TurnLerpSpeed = 7,
		DeathCubesPerPartMin = 3,
		DeathCubesPerPartMax = 7,
		DeathCubeLifetime = 5,
	},
}

return GameConfig
