--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))

type InfectedArchetype = "normal" | "baium"

type InfectedAgent = {
	id: number,
	archetype: InfectedArchetype,
	model: Model,
	root: BasePart,
	groanSound: Sound,
	groanCooldown: number,
	wasPlayerNear: boolean,
	groanPlaybackSpeedMin: number,
	groanPlaybackSpeedMax: number,
	leftEye: BasePart,
	rightEye: BasePart,
	visuals: { { part: BasePart, offset: CFrame } },
	spawnPosition: Vector3,
	wanderTarget: Vector3,
	chaseTarget: Player?,
	lastSeenPosition: Vector3?,
	timeSinceSeen: number,
	damageCooldown: number,
	attackWindup: number,
	queuedAttackTarget: Player?,
	attackDamage: number,
	attackRange: number,
	attackWindupSeconds: number,
	damageCooldownSeconds: number,
	wanderSpeed: number,
	chaseSpeed: number,
	patrolRadius: number,
	loseTargetSeconds: number,
	respawnSeconds: number,
	health: number,
	alive: boolean,
}

local InfectedService = {}

local infectedFolderName = "Infected"
local playerSpawnName = "StartSpawn"
local groundPartName = "Ground"
local rootPartName = "HumanoidRootPart"
local rng = Random.new()
local eyeIdleColor = Color3.fromRGB(214, 214, 120)
local eyeAttackColor = Color3.fromRGB(255, 74, 74)

local agents: { InfectedAgent } = {}
local heartbeatConnection: RBXScriptConnection?
local activeFolder: Folder?
local nextAgentId = 1
local playerLastAttackTime: { [Player]: number } = {}

local function getCharacterRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild(rootPartName)
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function ensureFolder(): Folder
	local existing = Workspace:FindFirstChild(infectedFolderName)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = infectedFolderName
	folder.Parent = Workspace
	return folder
end

local function randomPatrolPoint(center: Vector3, radius: number): Vector3
	local dx = rng:NextNumber(-radius, radius)
	local dz = rng:NextNumber(-radius, radius)
	return center + Vector3.new(dx, 0, dz)
end

local function moveTowards(current: Vector3, target: Vector3, speed: number, dt: number): Vector3
	local delta = target - current
	local dist = delta.Magnitude
	if dist <= 0.001 then
		return current
	end
	local step = math.min(dist, speed * dt)
	return current + delta.Unit * step
end

local function canSeeTarget(fromPos: Vector3, forward: Vector3, targetRoot: BasePart, sourceModel: Model?): boolean
	local toTarget = targetRoot.Position - fromPos
	local distance = toTarget.Magnitude
	if distance > GameConfig.Infected.VisionRange or distance <= 0.001 then
		return false
	end

	local dir = toTarget.Unit
	local cosHalfFov = math.cos(math.rad(GameConfig.Infected.VisionFovDegrees * 0.5))
	if forward:Dot(dir) < cosHalfFov then
		return false
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local filter: { Instance } = { targetRoot.Parent :: Instance }
	if sourceModel then
		table.insert(filter, sourceModel)
	end
	rayParams.FilterDescendantsInstances = filter
	local hit = Workspace:Raycast(fromPos, toTarget, rayParams)
	return hit == nil
end

local function hasClearHitPath(fromPos: Vector3, targetRoot: BasePart, sourceCharacter: Model?): boolean
	local toTarget = targetRoot.Position - fromPos
	if toTarget.Magnitude <= 0.001 then
		return true
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local filter: { Instance } = { targetRoot.Parent :: Instance }
	if sourceCharacter then
		table.insert(filter, sourceCharacter)
	end
	rayParams.FilterDescendantsInstances = filter

	local hit = Workspace:Raycast(fromPos, toTarget, rayParams)
	return hit == nil
end

local function detectPlayer(agent: InfectedAgent): (Player?, Vector3?)
	local fromPos = agent.root.Position
	local forward = agent.root.CFrame.LookVector

	local bestPlayer: Player? = nil
	local bestPos: Vector3? = nil
	local bestScore = math.huge

	for _, player in Players:GetPlayers() do
		local root = getCharacterRoot(player)
		local humanoid = getHumanoid(player)
		if root and humanoid and humanoid.Health > 0 then
			local distance = (root.Position - fromPos).Magnitude
			local heardRange = if PlayerStateService.IsSprinting(player)
				then GameConfig.Infected.HearingSprintRange
				else GameConfig.Infected.HearingWalkRange

			local heard = distance <= heardRange
			local seen = canSeeTarget(fromPos, forward, root, agent.model)

			if heard or seen then
				if distance < bestScore then
					bestScore = distance
					bestPlayer = player
					bestPos = root.Position
				end
			end
		end
	end

	return bestPlayer, bestPos
end

local function updateFacing(agent: InfectedAgent, targetPos: Vector3, dt: number)
	local at = agent.root.Position
	local look = Vector3.new(targetPos.X, at.Y, targetPos.Z)
	if (look - at).Magnitude > 0.01 then
		local targetCFrame = CFrame.lookAt(at, look)
		local lerpAlpha = math.clamp(dt * GameConfig.Infected.TurnLerpSpeed, 0, 1)
		agent.root.CFrame = agent.root.CFrame:Lerp(targetCFrame, lerpAlpha)
	end
end

local function setAttackEyes(agent: InfectedAgent, active: boolean)
	local color = if active then eyeAttackColor else eyeIdleColor
	agent.leftEye.Color = color
	agent.rightEye.Color = color
end

local function createBodyPart(
	model: Model,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material
): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.Massless = true
	part.Parent = model
	return part
end

local function syncVisuals(agent: InfectedAgent)
	for _, entry in agent.visuals do
		entry.part.CFrame = agent.root.CFrame * entry.offset
	end
end

local function randomGroanInterval(chasing: boolean): number
	local minInterval = math.max(0.2, GameConfig.Infected.GroanIntervalMin)
	local maxInterval = math.max(minInterval + 0.1, GameConfig.Infected.GroanIntervalMax)
	if chasing then
		local chaseMultiplier = math.max(0.2, GameConfig.Infected.GroanChaseIntervalMultiplier)
		minInterval *= chaseMultiplier
		maxInterval *= chaseMultiplier
	end
	return rng:NextNumber(minInterval, maxInterval)
end

local function playGroan(agent: InfectedAgent)
	local sound = agent.groanSound
	if sound.SoundId == "" then
		return
	end
	local minSpeed = math.max(0.05, agent.groanPlaybackSpeedMin)
	local maxSpeed = math.max(minSpeed + 0.01, agent.groanPlaybackSpeedMax)
	sound.PlaybackSpeed = rng:NextNumber(minSpeed, maxSpeed)
	if sound.IsPlaying then
		sound:Stop()
	end
	sound:Play()
end

local function isPlayerNear(agent: InfectedAgent, maxDistance: number): boolean
	if maxDistance <= 0 then
		return false
	end
	local fromPos = agent.root.Position
	for _, player in Players:GetPlayers() do
		local root = getCharacterRoot(player)
		local humanoid = getHumanoid(player)
		if root and humanoid and humanoid.Health > 0 then
			if (root.Position - fromPos).Magnitude <= maxDistance then
				return true
			end
		end
	end
	return false
end

local function updateGroan(agent: InfectedAgent, dt: number)
	agent.groanCooldown = math.max(0, agent.groanCooldown - dt)

	local proximityRange = math.max(0, GameConfig.Infected.GroanProximityRange)
	local proximityCooldown = math.max(0.2, GameConfig.Infected.GroanProximityCooldown)
	local nearPlayer = isPlayerNear(agent, proximityRange)

	if nearPlayer and not agent.wasPlayerNear then
		agent.groanCooldown = 0
	end
	agent.wasPlayerNear = nearPlayer

	if agent.groanCooldown > 0 then
		if nearPlayer then
			agent.groanCooldown = math.min(agent.groanCooldown, proximityCooldown)
		end
		return
	end
	playGroan(agent)
	if nearPlayer then
		agent.groanCooldown = proximityCooldown
	else
		agent.groanCooldown = randomGroanInterval(agent.chaseTarget ~= nil)
	end
end

local function getPlayerSpawnPosition(): Vector3
	local spawn = Workspace:FindFirstChild(playerSpawnName)
	if spawn and spawn:IsA("BasePart") then
		return spawn.Position
	end
	return Vector3.new(0, 8, 0)
end

local function getFixedBossSpawnPosition(): Vector3?
	local bossConfig = GameConfig.Infected.Boss
	if bossConfig.ForceFixedSpawn ~= true then
		return nil
	end
	if typeof(bossConfig.FixedSpawnOffset) ~= "Vector3" then
		return nil
	end
	return getPlayerSpawnPosition() + bossConfig.FixedSpawnOffset
end

local function getGroundSpawnBounds(): (Vector3?, Vector3?, number?)
	local ground = Workspace:FindFirstChild(groundPartName)
	if not ground or not ground:IsA("BasePart") then
		return nil
	end

	local halfX = math.max(40, ground.Size.X * 0.5 - 18)
	local halfZ = math.max(40, ground.Size.Z * 0.5 - 18)
	local topY = ground.Position.Y + ground.Size.Y * 0.5 + 5
	local minBounds = Vector3.new(ground.Position.X - halfX, topY, ground.Position.Z - halfZ)
	local maxBounds = Vector3.new(ground.Position.X + halfX, topY, ground.Position.Z + halfZ)
	return minBounds, maxBounds, topY
end

local function isFarEnoughFromPlayers(position: Vector3, minDistance: number): boolean
	for _, player in Players:GetPlayers() do
		local root = getCharacterRoot(player)
		local humanoid = getHumanoid(player)
		if root and humanoid and humanoid.Health > 0 then
			if (root.Position - position).Magnitude < minDistance then
				return false
			end
		end
	end
	return true
end

local function randomSpawnPosition(minDistanceOverride: number?, heightOffset: number?): Vector3
	local minDistance = if minDistanceOverride then minDistanceOverride else GameConfig.Infected.SpawnMinDistanceFromPlayer
	local extraHeight = if heightOffset then heightOffset else 0
	local minBounds, maxBounds, topY = getGroundSpawnBounds()

	if minBounds and maxBounds and topY then
		for _ = 1, 45 do
			local candidate = Vector3.new(
				rng:NextNumber(minBounds.X, maxBounds.X),
				topY + extraHeight,
				rng:NextNumber(minBounds.Z, maxBounds.Z)
			)
			if isFarEnoughFromPlayers(candidate, minDistance) then
				return candidate
			end
		end

		return Vector3.new(
			rng:NextNumber(minBounds.X, maxBounds.X),
			topY + extraHeight,
			rng:NextNumber(minBounds.Z, maxBounds.Z)
		)
	end

	local center = getPlayerSpawnPosition()
	local maxDistance = math.max(minDistance + 1, GameConfig.Infected.SpawnMaxDistanceFromPlayer)
	for _ = 1, 20 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(minDistance, maxDistance)
		local candidate = center + Vector3.new(math.cos(angle) * distance, 8 + extraHeight, math.sin(angle) * distance)
		if isFarEnoughFromPlayers(candidate, minDistance) then
			return candidate
		end
	end

	local fallbackDistance = maxDistance
	return center
		+ Vector3.new(
			rng:NextNumber(-fallbackDistance, fallbackDistance),
			8 + extraHeight,
			rng:NextNumber(-fallbackDistance, fallbackDistance)
		)
end

local function addVisual(visuals: { { part: BasePart, offset: CFrame } }, part: BasePart, offset: CFrame)
	table.insert(visuals, {
		part = part,
		offset = offset,
	})
end

local function spawnInfected(unitId: number, parent: Folder, archetype: InfectedArchetype?): InfectedAgent
	local infectedArchetype: InfectedArchetype = if archetype then archetype else "normal"
	local isBoss = infectedArchetype == "baium"
	local bossConfig = GameConfig.Infected.Boss
	local spawnMinDistance = if isBoss
		then bossConfig.SpawnMinDistanceFromPlayer
		else GameConfig.Infected.SpawnMinDistanceFromPlayer
	local rootHeightOffset = if isBoss then 3.5 else 0
	local fixedBossSpawn = if isBoss then getFixedBossSpawnPosition() else nil
	local spawnPos = if fixedBossSpawn
		then fixedBossSpawn
		else randomSpawnPosition(spawnMinDistance, rootHeightOffset)

	local model = Instance.new("Model")
	if isBoss then
		model.Name = ("%s_%d"):format(bossConfig.Name, unitId)
	else
		model.Name = ("Infected_%d"):format(unitId)
	end
	model.Parent = parent

	local root = Instance.new("Part")
	root.Name = rootPartName
	root.Size = if isBoss then Vector3.new(4.2, 4.2, 2.2) else Vector3.new(2, 2, 1)
	root.Position = spawnPos
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.Parent = model
	model.PrimaryPart = root

	local visuals: { { part: BasePart, offset: CFrame } } = {}
	local leftEye: BasePart
	local rightEye: BasePart

	if isBoss then
		local skinColor = Color3.fromRGB(152, 150, 136)
		local armorDark = Color3.fromRGB(61, 53, 46)
		local armorGold = Color3.fromRGB(154, 120, 62)
		local armorTrim = Color3.fromRGB(203, 171, 93)
		local capeColor = Color3.fromRGB(61, 18, 18)
		local boneColor = Color3.fromRGB(178, 173, 154)

		local torso = createBodyPart(
			model,
			"BayumTorso",
			Vector3.new(6.8, 7.6, 3.8),
			armorDark,
			Enum.Material.Metal
		)
		local chestPlate = createBodyPart(
			model,
			"BayumChestPlate",
			Vector3.new(5.3, 3.8, 1.05),
			armorGold,
			Enum.Material.Metal
		)
		local abdomenPlate = createBodyPart(
			model,
			"BayumAbdomenPlate",
			Vector3.new(4.3, 2, 0.82),
			armorTrim,
			Enum.Material.Metal
		)
		local head = createBodyPart(
			model,
			"BayumHead",
			Vector3.new(3.4, 3.2, 3),
			skinColor,
			Enum.Material.SmoothPlastic
		)
		local jaw = createBodyPart(
			model,
			"BayumJaw",
			Vector3.new(2.7, 1.1, 1.7),
			boneColor,
			Enum.Material.SmoothPlastic
		)
		local leftArm = createBodyPart(
			model,
			"BayumLeftArm",
			Vector3.new(1.9, 6.1, 1.9),
			armorDark,
			Enum.Material.Metal
		)
		local leftForearm = createBodyPart(
			model,
			"BayumLeftForearm",
			Vector3.new(2.15, 4.7, 2.15),
			armorGold,
			Enum.Material.Metal
		)
		local rightArm = createBodyPart(
			model,
			"BayumRightArm",
			Vector3.new(1.9, 6.1, 1.9),
			armorDark,
			Enum.Material.Metal
		)
		local rightForearm = createBodyPart(
			model,
			"BayumRightForearm",
			Vector3.new(2.15, 4.7, 2.15),
			armorGold,
			Enum.Material.Metal
		)
		local leftLeg = createBodyPart(
			model,
			"BayumLeftLeg",
			Vector3.new(2.4, 7.3, 2.4),
			armorDark,
			Enum.Material.Metal
		)
		local rightLeg = createBodyPart(
			model,
			"BayumRightLeg",
			Vector3.new(2.4, 7.3, 2.4),
			armorDark,
			Enum.Material.Metal
		)
		local leftPauldron = createBodyPart(
			model,
			"BayumLeftPauldron",
			Vector3.new(2.9, 1.4, 3.2),
			armorTrim,
			Enum.Material.Metal
		)
		local rightPauldron = createBodyPart(
			model,
			"BayumRightPauldron",
			Vector3.new(2.9, 1.4, 3.2),
			armorTrim,
			Enum.Material.Metal
		)
		local capeUpper = createBodyPart(
			model,
			"BayumCapeUpper",
			Vector3.new(5.4, 3.6, 0.45),
			capeColor,
			Enum.Material.Fabric
		)
		local capeLower = createBodyPart(
			model,
			"BayumCapeLower",
			Vector3.new(6.0, 5.2, 0.45),
			capeColor,
			Enum.Material.Fabric
		)
		local crownBand = createBodyPart(
			model,
			"BayumCrownBand",
			Vector3.new(3.9, 0.55, 3.9),
			armorTrim,
			Enum.Material.Metal
		)
		local heartCore = createBodyPart(
			model,
			"BayumHeartCore",
			Vector3.new(0.92, 0.92, 0.92),
			Color3.fromRGB(255, 78, 56),
			Enum.Material.Neon
		)
		heartCore.Shape = Enum.PartType.Ball

		local coreLight = Instance.new("PointLight")
		coreLight.Color = Color3.fromRGB(255, 108, 86)
		coreLight.Brightness = 2.2
		coreLight.Range = 16
		coreLight.Parent = heartCore

		leftEye = createBodyPart(
			model,
			"BayumLeftEye",
			Vector3.new(0.5, 0.5, 0.5),
			eyeIdleColor,
			Enum.Material.Neon
		)
		rightEye = createBodyPart(
			model,
			"BayumRightEye",
			Vector3.new(0.5, 0.5, 0.5),
			eyeIdleColor,
			Enum.Material.Neon
		)
		leftEye.Shape = Enum.PartType.Ball
		rightEye.Shape = Enum.PartType.Ball

		addVisual(visuals, torso, CFrame.new(0, 1.9, 0) * CFrame.Angles(math.rad(9), 0, 0))
		addVisual(visuals, chestPlate, CFrame.new(0, 2.2, -2.3) * CFrame.Angles(math.rad(14), 0, 0))
		addVisual(visuals, abdomenPlate, CFrame.new(0, 0.2, -1.9) * CFrame.Angles(math.rad(16), 0, 0))
		addVisual(visuals, head, CFrame.new(0, 6.2, -0.4) * CFrame.Angles(math.rad(13), 0, 0))
		addVisual(visuals, jaw, CFrame.new(0, 4.9, -1.55) * CFrame.Angles(math.rad(10), 0, 0))
		addVisual(visuals, leftArm, CFrame.new(-4.4, 2.2, -0.15) * CFrame.Angles(math.rad(16), 0, math.rad(-15)))
		addVisual(visuals, leftForearm, CFrame.new(-4.95, -1.15, -0.25) * CFrame.Angles(math.rad(14), 0, math.rad(-11)))
		addVisual(visuals, rightArm, CFrame.new(4.4, 2.2, -0.15) * CFrame.Angles(math.rad(16), 0, math.rad(15)))
		addVisual(visuals, rightForearm, CFrame.new(4.95, -1.15, -0.25) * CFrame.Angles(math.rad(14), 0, math.rad(11)))
		addVisual(visuals, leftLeg, CFrame.new(-1.8, -4.25, 0.05))
		addVisual(visuals, rightLeg, CFrame.new(1.8, -4.25, 0.05))
		addVisual(visuals, leftPauldron, CFrame.new(-3.2, 3.9, -0.05) * CFrame.Angles(0, 0, math.rad(-24)))
		addVisual(visuals, rightPauldron, CFrame.new(3.2, 3.9, -0.05) * CFrame.Angles(0, 0, math.rad(24)))
		addVisual(visuals, capeUpper, CFrame.new(0, 2.9, 2.05) * CFrame.Angles(math.rad(-8), 0, 0))
		addVisual(visuals, capeLower, CFrame.new(0, -0.45, 2.45) * CFrame.Angles(math.rad(-5), 0, 0))
		addVisual(visuals, crownBand, CFrame.new(0, 7.28, -0.25))
		addVisual(visuals, heartCore, CFrame.new(0, 1.95, -2.34))
		addVisual(visuals, leftEye, CFrame.new(-0.62, 6.25, -1.95))
		addVisual(visuals, rightEye, CFrame.new(0.62, 6.25, -1.95))

		for i = 1, 8 do
			local angle = ((i - 1) / 8) * math.pi * 2
			local spike = createBodyPart(
				model,
				("BayumCrownSpike_%d"):format(i),
				Vector3.new(0.24, 1.7, 0.24),
				armorTrim,
				Enum.Material.Metal
			)
			addVisual(
				visuals,
				spike,
				CFrame.new(math.cos(angle) * 1.72, 8.45, -0.25 + math.sin(angle) * 1.72)
					* CFrame.Angles(math.rad(-16), angle, 0)
			)
		end

		local bossLabel = Instance.new("BillboardGui")
		bossLabel.Name = "BossLabel"
		bossLabel.Size = UDim2.fromOffset(300, 70)
		bossLabel.StudsOffset = Vector3.new(0, 12.5, 0)
		bossLabel.AlwaysOnTop = true
		bossLabel.MaxDistance = 3000
		bossLabel.Parent = root

		local bossLabelText = Instance.new("TextLabel")
		bossLabelText.BackgroundTransparency = 1
		bossLabelText.Size = UDim2.fromScale(1, 1)
		bossLabelText.Font = Enum.Font.GothamBlack
		bossLabelText.TextScaled = true
		bossLabelText.TextStrokeTransparency = 0.1
		bossLabelText.TextStrokeColor3 = Color3.fromRGB(10, 2, 2)
		bossLabelText.TextColor3 = Color3.fromRGB(255, 72, 72)
		bossLabelText.Text = bossConfig.Name
		bossLabelText.Parent = bossLabel
	else
		local skinColor = Color3.fromRGB(104, 123, 92)
		local clothColor = Color3.fromRGB(61, 56, 52)
		local darkColor = Color3.fromRGB(42, 39, 36)
		local rustColor = Color3.fromRGB(110, 84, 66)

		local torso = createBodyPart(
			model,
			"Torso",
			Vector3.new(2.4, 2.6, 1.2),
			clothColor,
			Enum.Material.Fabric
		)
		local head = createBodyPart(
			model,
			"Head",
			Vector3.new(1.5, 1.4, 1.3),
			skinColor,
			Enum.Material.SmoothPlastic
		)
		local leftArm = createBodyPart(
			model,
			"LeftArm",
			Vector3.new(0.8, 2.2, 0.8),
			darkColor,
			Enum.Material.Fabric
		)
		local rightArm = createBodyPart(
			model,
			"RightArm",
			Vector3.new(0.8, 2.1, 0.8),
			darkColor,
			Enum.Material.Fabric
		)
		local leftLeg = createBodyPart(
			model,
			"LeftLeg",
			Vector3.new(0.9, 2.4, 0.9),
			rustColor,
			Enum.Material.Fabric
		)
		local rightLeg = createBodyPart(
			model,
			"RightLeg",
			Vector3.new(0.9, 2.4, 0.9),
			rustColor,
			Enum.Material.Fabric
		)
		leftEye = createBodyPart(
			model,
			"LeftEye",
			Vector3.new(0.18, 0.18, 0.18),
			eyeIdleColor,
			Enum.Material.Neon
		)
		rightEye = createBodyPart(
			model,
			"RightEye",
			Vector3.new(0.18, 0.18, 0.18),
			eyeIdleColor,
			Enum.Material.Neon
		)
		leftEye.Shape = Enum.PartType.Ball
		rightEye.Shape = Enum.PartType.Ball

		addVisual(visuals, torso, CFrame.new(0, 0.4, 0) * CFrame.Angles(math.rad(12), 0, 0))
		addVisual(visuals, head, CFrame.new(0, 2.2, -0.15) * CFrame.Angles(math.rad(18), 0, 0))
		addVisual(visuals, leftArm, CFrame.new(-1.55, 0.4, -0.1) * CFrame.Angles(math.rad(28), 0, math.rad(-18)))
		addVisual(visuals, rightArm, CFrame.new(1.55, 0.5, 0) * CFrame.Angles(math.rad(34), 0, math.rad(12)))
		addVisual(visuals, leftLeg, CFrame.new(-0.5, -1.9, 0) * CFrame.Angles(0, 0, math.rad(4)))
		addVisual(visuals, rightLeg, CFrame.new(0.5, -1.9, -0.05) * CFrame.Angles(0, 0, math.rad(-6)))
		addVisual(visuals, leftEye, CFrame.new(-0.25, 2.35, -0.77))
		addVisual(visuals, rightEye, CFrame.new(0.25, 2.35, -0.77))
	end

	local groanSound = Instance.new("Sound")
	groanSound.Name = "Groan"
	groanSound.SoundId = GameConfig.Infected.GroanSoundId
	groanSound.Volume = if isBoss
		then GameConfig.Infected.GroanVolume * bossConfig.GroanVolumeMultiplier
		else GameConfig.Infected.GroanVolume
	groanSound.RollOffMode = Enum.RollOffMode.InverseTapered
	groanSound.RollOffMinDistance = GameConfig.Infected.GroanMinDistance
	groanSound.RollOffMaxDistance = GameConfig.Infected.GroanMaxDistance
	groanSound.Parent = root

	local reverb = Instance.new("ReverbSoundEffect")
	reverb.DecayTime = if isBoss then 2.5 else 1.8
	reverb.Density = 0.45
	reverb.Diffusion = 0.72
	reverb.DryLevel = -1
	reverb.WetLevel = -3
	reverb.Parent = groanSound

	local distortion = Instance.new("DistortionSoundEffect")
	distortion.Level = if isBoss then 0.2 else 0.12
	distortion.Parent = groanSound

	local attackDamage = if isBoss then bossConfig.Damage else GameConfig.Infected.Damage
	local attackRange = if isBoss then bossConfig.AttackRange else GameConfig.Infected.AttackRange
	local attackWindupSeconds = if isBoss then bossConfig.AttackWindupSeconds else GameConfig.Infected.AttackWindupSeconds
	local damageCooldownSeconds = if isBoss then bossConfig.DamageCooldown else GameConfig.Infected.DamageCooldown
	local wanderSpeed = if isBoss then bossConfig.WanderSpeed else GameConfig.Infected.WanderSpeed
	local chaseSpeed = if isBoss then bossConfig.ChaseSpeed else GameConfig.Infected.ChaseSpeed
	local patrolRadius = if isBoss then bossConfig.PatrolRadius else GameConfig.Infected.PatrolRadius
	local loseTargetSeconds = if isBoss then bossConfig.LoseTargetSeconds else GameConfig.Infected.LoseTargetSeconds
	local respawnSeconds = if isBoss then bossConfig.RespawnSeconds else GameConfig.Infected.RespawnSeconds
	local maxHealth = if isBoss then bossConfig.MaxHealth else GameConfig.Infected.MaxHealth
	local groanPlaybackSpeedMin = if isBoss
		then bossConfig.GroanPlaybackSpeedMin
		else GameConfig.Infected.GroanPlaybackSpeedMin
	local groanPlaybackSpeedMax = if isBoss
		then bossConfig.GroanPlaybackSpeedMax
		else GameConfig.Infected.GroanPlaybackSpeedMax

	local agent: InfectedAgent = {
		id = unitId,
		archetype = infectedArchetype,
		model = model,
		root = root,
		groanSound = groanSound,
		groanCooldown = rng:NextNumber(0.6, 2.3),
		wasPlayerNear = false,
		groanPlaybackSpeedMin = groanPlaybackSpeedMin,
		groanPlaybackSpeedMax = groanPlaybackSpeedMax,
		leftEye = leftEye,
		rightEye = rightEye,
		visuals = visuals,
		spawnPosition = spawnPos,
		wanderTarget = randomPatrolPoint(spawnPos, patrolRadius),
		chaseTarget = nil,
		lastSeenPosition = nil,
		timeSinceSeen = 0,
		damageCooldown = 0,
		attackWindup = 0,
		queuedAttackTarget = nil,
		attackDamage = attackDamage,
		attackRange = attackRange,
		attackWindupSeconds = attackWindupSeconds,
		damageCooldownSeconds = damageCooldownSeconds,
		wanderSpeed = wanderSpeed,
		chaseSpeed = chaseSpeed,
		patrolRadius = patrolRadius,
		loseTargetSeconds = loseTargetSeconds,
		respawnSeconds = respawnSeconds,
		health = maxHealth,
		alive = true,
	}
	syncVisuals(agent)
	return agent
end

local function markDead(agent: InfectedAgent)
	agent.alive = false
	agent.queuedAttackTarget = nil
	agent.attackWindup = 0
	if agent.groanSound.IsPlaying then
		agent.groanSound:Stop()
	end

	for _, entry in agent.visuals do
		local source = entry.part
		if source.Parent then
			local minCount = GameConfig.Infected.DeathCubesPerPartMin
			local maxCount = GameConfig.Infected.DeathCubesPerPartMax
			local count = rng:NextInteger(minCount, maxCount)
			if agent.archetype == "baium" then
				count = math.max(count + 2, math.floor(count * 2.1))
			end

			for _ = 1, count do
				local cube = Instance.new("Part")
				cube.Name = "InfectedDebrisCube"
				local side = if agent.archetype == "baium"
					then rng:NextNumber(0.32, 0.72)
					else rng:NextNumber(0.22, 0.45)
				cube.Size = Vector3.new(side, side, side)
				cube.Material = source.Material
				cube.Color = source.Color
				cube.TopSurface = Enum.SurfaceType.Smooth
				cube.BottomSurface = Enum.SurfaceType.Smooth
				cube.CanCollide = true
				cube.Anchored = false
				cube.CFrame = source.CFrame
					* CFrame.new(
						rng:NextNumber(-0.6, 0.6),
						rng:NextNumber(-0.6, 0.6),
						rng:NextNumber(-0.6, 0.6)
					)
				cube.Parent = Workspace

				local pushDir = Vector3.new(
					rng:NextNumber(-1, 1),
					rng:NextNumber(0.2, 1.2),
					rng:NextNumber(-1, 1)
				)
				if pushDir.Magnitude < 0.001 then
					pushDir = Vector3.new(0, 1, 0)
				end
				cube.AssemblyLinearVelocity = pushDir.Unit * rng:NextNumber(8, 22)
				cube.AssemblyAngularVelocity = Vector3.new(
					rng:NextNumber(-12, 12),
					rng:NextNumber(-12, 12),
					rng:NextNumber(-12, 12)
				)

				Debris:AddItem(cube, GameConfig.Infected.DeathCubeLifetime)
			end
		end
	end

	if agent.model.Parent then
		agent.model:Destroy()
	end
end

local function respawnAgentAtIndex(index: number, archetype: InfectedArchetype)
	local folder = activeFolder
	if not folder then
		return
	end
	nextAgentId += 1
	agents[index] = spawnInfected(nextAgentId, folder, archetype)
end

local function applyDamageToInfected(agent: InfectedAgent, amount: number): boolean
	if not agent.alive then
		return false
	end
	agent.health -= math.max(0, amount)
	if agent.health <= 0 then
		local deadId = agent.id
		local deadArchetype = agent.archetype
		local respawnDelay = agent.respawnSeconds
		markDead(agent)
		task.delay(respawnDelay, function()
			for i, otherAgent in agents do
				if otherAgent.id == deadId and not otherAgent.alive then
					respawnAgentAtIndex(i, deadArchetype)
					break
				end
			end
		end)
		return true
	end
	return true
end

local function applyExplosionDamage(center: Vector3, radius: number, maxDamage: number): number
	local hitCount = 0

	for _, agent in agents do
		if agent.alive and agent.model.Parent then
			local distance = (agent.root.Position - center).Magnitude
			if distance <= radius then
				local falloff = 1 - (distance / radius)
				local damage = math.max(8, maxDamage * falloff)
				if applyDamageToInfected(agent, damage) then
					hitCount += 1
				end
			end
		end
	end

	return hitCount
end

local function emitSwordHitSparks(position: Vector3, fromDirection: Vector3)
	local minCount = math.max(1, GameConfig.Player.AttackSparkCountMin)
	local maxCount = math.max(minCount, GameConfig.Player.AttackSparkCountMax)
	local count = rng:NextInteger(minCount, maxCount)
	local outward = if fromDirection.Magnitude > 0.001 then fromDirection.Unit else Vector3.new(0, 0, -1)

	for _ = 1, count do
		local spark = Instance.new("Part")
		spark.Name = "SwordHitSpark"
		local side = rng:NextNumber(0.06, 0.14)
		spark.Size = Vector3.new(side, side, side)
		spark.Shape = Enum.PartType.Ball
		spark.Material = Enum.Material.Neon
		spark.Color = Color3.fromRGB(
			rng:NextInteger(245, 255),
			rng:NextInteger(178, 226),
			rng:NextInteger(86, 138)
		)
		spark.TopSurface = Enum.SurfaceType.Smooth
		spark.BottomSurface = Enum.SurfaceType.Smooth
		spark.CanCollide = true
		spark.CanQuery = false
		spark.CanTouch = false
		spark.Anchored = false
		spark.CFrame = CFrame.new(position)
			* CFrame.new(
				rng:NextNumber(-0.18, 0.18),
				rng:NextNumber(-0.18, 0.18),
				rng:NextNumber(-0.18, 0.18)
			)
		spark.Parent = Workspace

		local spread = Vector3.new(
			rng:NextNumber(-0.85, 0.85),
			rng:NextNumber(0.15, 1.25),
			rng:NextNumber(-0.85, 0.85)
		)
		local velocityDir = outward * 1.7 + spread
		if velocityDir.Magnitude < 0.001 then
			velocityDir = Vector3.new(0, 1, 0)
		end

		spark.AssemblyLinearVelocity = velocityDir.Unit * rng:NextNumber(20, 36)
		spark.AssemblyAngularVelocity = Vector3.new(
			rng:NextNumber(-26, 26),
			rng:NextNumber(-26, 26),
			rng:NextNumber(-26, 26)
		)
		Debris:AddItem(spark, 0.7)
	end
end

local function findLineAttackTarget(
	origin: Vector3,
	forward: Vector3,
	sourceCharacter: Model?
): (InfectedAgent?, Vector3?)
	local range = math.max(0.5, GameConfig.Player.AttackRange)
	local radius = math.max(0.5, GameConfig.Player.AttackLineRadius)
	local unitForward = if forward.Magnitude > 0.001 then forward.Unit else Vector3.new(0, 0, -1)

	local bestAgent: InfectedAgent? = nil
	local bestHitPosition: Vector3? = nil
	local bestScore = math.huge

	for _, agent in agents do
		if agent.alive and agent.model.Parent then
			local toTarget = agent.root.Position - origin
			local forwardDistance = toTarget:Dot(unitForward)
			if forwardDistance >= 0 and forwardDistance <= range then
				local projected = origin + unitForward * forwardDistance
				local lateralDistance = (agent.root.Position - projected).Magnitude
				if lateralDistance <= radius and hasClearHitPath(origin, agent.root, sourceCharacter) then
					local score = forwardDistance + lateralDistance * 0.7
					if score < bestScore then
						bestScore = score
						bestAgent = agent
						bestHitPosition = projected
					end
				end
			end
		end
	end

	return bestAgent, bestHitPosition
end

local function processAttack(agent: InfectedAgent, dt: number)
	agent.damageCooldown = math.max(0, agent.damageCooldown - dt)
	agent.attackWindup = math.max(0, agent.attackWindup - dt)

	local queuedTarget = agent.queuedAttackTarget
	if queuedTarget and agent.attackWindup <= 0 then
		local targetRoot = getCharacterRoot(queuedTarget)
		local targetHumanoid = getHumanoid(queuedTarget)
		if targetRoot and targetHumanoid and targetHumanoid.Health > 0 then
			local offset = targetRoot.Position - agent.root.Position
			local distance = offset.Magnitude
			local facingDot = if distance > 0.001 then agent.root.CFrame.LookVector:Dot(offset.Unit) else 1
			local seen = canSeeTarget(agent.root.Position, agent.root.CFrame.LookVector, targetRoot, agent.model)
			if distance <= agent.attackRange + 0.8 and facingDot >= 0.2 and seen then
				targetHumanoid:TakeDamage(agent.attackDamage)
				agent.damageCooldown = agent.damageCooldownSeconds
			end
		end
		agent.queuedAttackTarget = nil
		setAttackEyes(agent, false)
	end

	if agent.damageCooldown > 0 or agent.attackWindup > 0 then
		return
	end

	local chaseTarget = agent.chaseTarget
	if not chaseTarget then
		return
	end
	local root = getCharacterRoot(chaseTarget)
	local humanoid = getHumanoid(chaseTarget)
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	if (root.Position - agent.root.Position).Magnitude <= agent.attackRange then
		agent.attackWindup = agent.attackWindupSeconds
		agent.queuedAttackTarget = chaseTarget
		setAttackEyes(agent, true)
	end
end

local function updateAgent(agent: InfectedAgent, dt: number)
	if not agent.alive then
		return
	end
	if not agent.model.Parent then
		agent.alive = false
		return
	end

	local detectedPlayer, detectedPos = detectPlayer(agent)
	if detectedPlayer and detectedPos then
		agent.chaseTarget = detectedPlayer
		agent.lastSeenPosition = detectedPos
		agent.timeSinceSeen = 0
	else
		agent.timeSinceSeen += dt
		if agent.timeSinceSeen > agent.loseTargetSeconds then
			agent.chaseTarget = nil
		end
	end
	updateGroan(agent, dt)

	if not agent.chaseTarget and agent.attackWindup <= 0 then
		setAttackEyes(agent, false)
	end

	local currentPos = agent.root.Position
	local destination: Vector3
	local speed: number

	if agent.chaseTarget and agent.lastSeenPosition then
		destination = agent.lastSeenPosition
		speed = agent.chaseSpeed
	else
		if (agent.wanderTarget - currentPos).Magnitude < 2 then
			agent.wanderTarget = randomPatrolPoint(agent.spawnPosition, agent.patrolRadius)
		end
		destination = agent.wanderTarget
		speed = agent.wanderSpeed
	end

	if agent.attackWindup > 0 then
		speed *= 0.2
	end

	local nextPos = moveTowards(currentPos, destination, speed, dt)
	agent.root.Position = nextPos
	updateFacing(agent, destination, dt)
	syncVisuals(agent)
	processAttack(agent, dt)
end

function InfectedService.TryPlayerAttack(player: Player): boolean
	local now = time()
	local lastAttack = playerLastAttackTime[player]
	if lastAttack and now - lastAttack < GameConfig.Player.AttackCooldown then
		return false
	end
	playerLastAttackTime[player] = now

	local root = getCharacterRoot(player)
	local humanoid = getHumanoid(player)
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end

	local origin = root.Position + Vector3.new(0, GameConfig.Player.AttackLineVerticalOffset, 0)
	local bestAgent, hitPosition = findLineAttackTarget(origin, root.CFrame.LookVector, player.Character)

	if not bestAgent then
		return false
	end

	local didHit = applyDamageToInfected(bestAgent, GameConfig.Player.AttackDamage)
	if didHit then
		local sparkFrom = bestAgent.root.Position + Vector3.new(0, 1, 0)
		local sparkPos = if hitPosition then hitPosition else sparkFrom
		emitSwordHitSparks(sparkPos, sparkFrom - origin)
	end
	return didHit
end

function InfectedService.TryPlayerGrenadeAttack(player: Player, impactPosition: Vector3?): boolean
	local root = getCharacterRoot(player)
	local humanoid = getHumanoid(player)
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end

	local center = impactPosition
	if not center then
		local origin = root.Position + Vector3.new(0, 1.4, 0) + root.CFrame.LookVector * 2
		local direction = root.CFrame.LookVector
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { player.Character :: Model }
		local ray = Workspace:Raycast(origin, direction * GameConfig.Player.GrenadeRange, rayParams)
		center = if ray then ray.Position else (origin + direction * GameConfig.Player.GrenadeRange)
	end

	local hits = applyExplosionDamage(
		center,
		GameConfig.Player.GrenadeExplosionRadius,
		GameConfig.Player.GrenadeDamage
	)
	return hits > 0
end

function InfectedService.Start()
	local folder = ensureFolder()
	activeFolder = folder
	for _, child in folder:GetChildren() do
		child:Destroy()
	end

	table.clear(agents)
	nextAgentId = 0
	for _ = 1, GameConfig.Infected.Count do
		nextAgentId += 1
		table.insert(agents, spawnInfected(nextAgentId, folder, "normal"))
	end

	local bossCount = 0
	if GameConfig.Infected.Boss.Enabled then
		nextAgentId += 1
		table.insert(agents, spawnInfected(nextAgentId, folder, "baium"))
		bossCount = 1
	end
	warn(("[InfectedService] Spawned infected: total=%d normal=%d boss=%d"):format(#agents, GameConfig.Infected.Count, bossCount))

	if heartbeatConnection then
		heartbeatConnection:Disconnect()
	end

	heartbeatConnection = RunService.Heartbeat:Connect(function(dt: number)
		local step = math.min(dt, 0.05)
		for _, agent in agents do
			updateAgent(agent, step)
		end
	end)
end

return InfectedService
