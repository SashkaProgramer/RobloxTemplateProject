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
	groanBaseVolume: number,
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
	magicDamage: number,
	magicRange: number,
	magicCooldown: number,
	magicCooldownSeconds: number,
	magicWindup: number,
	magicWindupSeconds: number,
	magicBlastRadius: number,
	queuedMagicTarget: Player?,
	wanderSpeed: number,
	chaseSpeed: number,
	patrolRadius: number,
	loseTargetSeconds: number,
	respawnSeconds: number,
	maxHealth: number,
	health: number,
	hpBarFill: Frame,
	walkCycle: number,
	moveBlend: number,
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
local normalGroanDistortionLevel = 0.12
local bossGroanDistortionLevel = 0.2
local normalGroanReverbDecay = 1.8
local bossGroanReverbDecay = 2.5
local normalGroanReverbWet = -3
local bossGroanReverbWet = -2.2

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
	local walkPhase = agent.walkCycle
	local moveBlend = math.clamp(agent.moveBlend, 0, 1)
	for _, entry in agent.visuals do
		local offset = entry.offset

		if agent.archetype == "baium" then
			local stride = math.sin(walkPhase)
			local counterStride = math.sin(walkPhase + math.pi)
			local strideDouble = math.sin(walkPhase * 2)

			if entry.part.Name == "BayumLeftLeg" then
				local lift = math.max(0, counterStride) * 0.42 * moveBlend
				offset = offset
					* CFrame.new(0, lift, 0)
					* CFrame.Angles(math.rad(22 * stride * moveBlend), 0, 0)
			elseif entry.part.Name == "BayumRightLeg" then
				local lift = math.max(0, stride) * 0.42 * moveBlend
				offset = offset
					* CFrame.new(0, lift, 0)
					* CFrame.Angles(math.rad(22 * counterStride * moveBlend), 0, 0)
			elseif entry.part.Name == "BayumLeftArm" or entry.part.Name == "BayumLeftForearm" then
				offset = offset * CFrame.Angles(math.rad(-16 * counterStride * moveBlend), 0, 0)
			elseif entry.part.Name == "BayumRightArm" or entry.part.Name == "BayumRightForearm" then
				offset = offset * CFrame.Angles(math.rad(-16 * stride * moveBlend), 0, 0)
			elseif entry.part.Name == "BayumTorso" then
				local bob = math.abs(stride) * 0.19 * moveBlend
				offset = offset
					* CFrame.new(0, bob, 0)
					* CFrame.Angles(math.rad(2.8 * strideDouble * moveBlend), 0, 0)
			elseif entry.part.Name == "BayumHead" then
				offset = offset * CFrame.Angles(math.rad(-3.2 * strideDouble * moveBlend), 0, 0)
			elseif entry.part.Name == "BayumAuraRingOuter" then
				offset = offset * CFrame.Angles(0, walkPhase * 0.65, 0)
			elseif entry.part.Name == "BayumAuraRingInner" then
				offset = offset * CFrame.Angles(0, -walkPhase * 0.85, 0)
			end
		else
			local stride = math.sin(walkPhase)
			local counterStride = math.sin(walkPhase + math.pi)
			local strideDouble = math.sin(walkPhase * 2)

			if entry.part.Name == "LeftLeg" then
				local lift = math.max(0, counterStride) * 0.18 * moveBlend
				offset = offset
					* CFrame.new(0, lift, 0)
					* CFrame.Angles(math.rad(24 * stride * moveBlend), 0, 0)
			elseif entry.part.Name == "RightLeg" then
				local lift = math.max(0, stride) * 0.18 * moveBlend
				offset = offset
					* CFrame.new(0, lift, 0)
					* CFrame.Angles(math.rad(24 * counterStride * moveBlend), 0, 0)
			elseif entry.part.Name == "LeftArm" then
				offset = offset * CFrame.Angles(math.rad(-22 * counterStride * moveBlend), 0, 0)
			elseif entry.part.Name == "RightArm" then
				offset = offset * CFrame.Angles(math.rad(-22 * stride * moveBlend), 0, 0)
			elseif entry.part.Name == "Torso" then
				local bob = math.abs(stride) * 0.08 * moveBlend
				offset = offset
					* CFrame.new(0, bob, 0)
					* CFrame.Angles(math.rad(2.5 * strideDouble * moveBlend), 0, math.rad(1.8 * stride * moveBlend))
			elseif entry.part.Name == "Head" then
				offset = offset * CFrame.Angles(math.rad(-4.5 * strideDouble * moveBlend), 0, 0)
			end
		end

		entry.part.CFrame = agent.root.CFrame * offset
	end
end

local function createHealthBar(root: BasePart, isBoss: boolean, titleText: string?): Frame
	local hpGui = Instance.new("BillboardGui")
	hpGui.Name = "HpBar"
	hpGui.Size = if isBoss then UDim2.fromOffset(104, 18) else UDim2.fromOffset(74, 12)
	hpGui.StudsOffset = if isBoss then Vector3.new(0, 9.6, 0) else Vector3.new(0, 4.75, 0)
	hpGui.AlwaysOnTop = true
	hpGui.MaxDistance = if isBoss then 180 else 120
	hpGui.Parent = root

	local bg = Instance.new("Frame")
	bg.Name = "Bg"
	bg.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
	bg.BackgroundTransparency = 0.28
	bg.BorderSizePixel = 0
	bg.Size = if titleText then UDim2.fromOffset(86, 6) else UDim2.fromOffset(62, 4)
	bg.Position = if titleText then UDim2.fromOffset(8, 10) else UDim2.fromOffset(6, 4)
	bg.Parent = hpGui

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 3)
	bgCorner.Parent = bg

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(228, 62, 62)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = bg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 3)
	fillCorner.Parent = fill

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(9, 9, 9)
	stroke.Thickness = 1
	stroke.Parent = bg

	if titleText then
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Size = UDim2.fromOffset(94, 9)
		title.Position = UDim2.fromOffset(4, 0)
		title.Font = Enum.Font.GothamBold
		title.TextScaled = false
		title.TextSize = 8
		title.TextColor3 = Color3.fromRGB(255, 212, 180)
		title.TextStrokeTransparency = 0.5
		title.Text = titleText
		title.Parent = hpGui
	end

	return fill
end

local function updateHealthBar(agent: InfectedAgent)
	local maxHealth = math.max(1, agent.maxHealth)
	local ratio = math.clamp(agent.health / maxHealth, 0, 1)
	agent.hpBarFill.Size = UDim2.fromScale(ratio, 1)

	if ratio <= 0.2 then
		agent.hpBarFill.BackgroundColor3 = Color3.fromRGB(244, 44, 44)
	elseif ratio <= 0.55 then
		agent.hpBarFill.BackgroundColor3 = Color3.fromRGB(255, 154, 58)
	else
		agent.hpBarFill.BackgroundColor3 = Color3.fromRGB(84, 214, 92)
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

local function randomGroanVariant(): { [string]: any }?
	local variants = GameConfig.Infected.GroanVariants
	if typeof(variants) ~= "table" then
		return nil
	end

	local totalWeight = 0
	for _, variant in variants do
		if typeof(variant) == "table" then
			local soundId = variant.SoundId
			if typeof(soundId) == "string" and soundId ~= "" then
				local weightValue = variant.Weight
				local weight = if typeof(weightValue) == "number" and weightValue > 0 then weightValue else 1
				totalWeight += weight
			end
		end
	end

	if totalWeight <= 0 then
		return nil
	end

	local pickedWeight = rng:NextNumber(0, totalWeight)
	local accumulatedWeight = 0
	local fallbackVariant: { [string]: any }? = nil

	for _, variant in variants do
		if typeof(variant) == "table" then
			local soundId = variant.SoundId
			if typeof(soundId) == "string" and soundId ~= "" then
				local weightValue = variant.Weight
				local weight = if typeof(weightValue) == "number" and weightValue > 0 then weightValue else 1
				accumulatedWeight += weight
				fallbackVariant = variant
				if pickedWeight <= accumulatedWeight then
					return variant
				end
			end
		end
	end

	return fallbackVariant
end

local function playGroan(agent: InfectedAgent)
	local sound = agent.groanSound
	local variant = randomGroanVariant()
	local nextSoundId = GameConfig.Infected.GroanSoundId
	if variant then
		local variantSoundId = variant.SoundId
		if typeof(variantSoundId) == "string" and variantSoundId ~= "" then
			nextSoundId = variantSoundId
		end
	end
	sound.SoundId = nextSoundId
	if sound.SoundId == "" then
		return
	end

	local minSpeed = math.max(0.05, agent.groanPlaybackSpeedMin)
	local maxSpeed = math.max(minSpeed + 0.01, agent.groanPlaybackSpeedMax)
	local volumeMultiplier = 1
	local distortionLevel = if agent.archetype == "baium" then bossGroanDistortionLevel else normalGroanDistortionLevel
	local reverbDecay = if agent.archetype == "baium" then bossGroanReverbDecay else normalGroanReverbDecay
	local reverbWet = if agent.archetype == "baium" then bossGroanReverbWet else normalGroanReverbWet
	local echoDelay = 0.1
	local echoFeedback = 0.18
	local eqLowGain = 0
	local eqMidGain = 0
	local eqHighGain = 0

	if variant then
		local variantMinSpeed = variant.PlaybackSpeedMin
		if typeof(variantMinSpeed) == "number" then
			minSpeed = math.max(0.05, variantMinSpeed)
		end

		local variantMaxSpeed = variant.PlaybackSpeedMax
		if typeof(variantMaxSpeed) == "number" then
			maxSpeed = math.max(minSpeed + 0.01, variantMaxSpeed)
		end

		local variantVolumeMultiplier = variant.VolumeMultiplier
		if typeof(variantVolumeMultiplier) == "number" then
			volumeMultiplier = math.max(0, variantVolumeMultiplier)
		end

		local variantDistortion = variant.DistortionLevel
		if typeof(variantDistortion) == "number" then
			distortionLevel = math.clamp(variantDistortion, 0, 1)
		end

		local variantReverbDecay = variant.ReverbDecay
		if typeof(variantReverbDecay) == "number" then
			reverbDecay = math.clamp(variantReverbDecay, 0.1, 20)
		end

		local variantReverbWet = variant.ReverbWet
		if typeof(variantReverbWet) == "number" then
			reverbWet = math.clamp(variantReverbWet, -80, 10)
		end

		local variantEchoDelay = variant.EchoDelay
		if typeof(variantEchoDelay) == "number" then
			echoDelay = math.clamp(variantEchoDelay, 0, 5)
		end

		local variantEchoFeedback = variant.EchoFeedback
		if typeof(variantEchoFeedback) == "number" then
			echoFeedback = math.clamp(variantEchoFeedback, 0, 1)
		end

		local variantEqLowGain = variant.EqLowGain
		if typeof(variantEqLowGain) == "number" then
			eqLowGain = math.clamp(variantEqLowGain, -80, 10)
		end

		local variantEqMidGain = variant.EqMidGain
		if typeof(variantEqMidGain) == "number" then
			eqMidGain = math.clamp(variantEqMidGain, -80, 10)
		end

		local variantEqHighGain = variant.EqHighGain
		if typeof(variantEqHighGain) == "number" then
			eqHighGain = math.clamp(variantEqHighGain, -80, 10)
		end
	end

	maxSpeed = math.max(minSpeed + 0.01, maxSpeed)
	sound.Volume = agent.groanBaseVolume * volumeMultiplier
	sound.PlaybackSpeed = rng:NextNumber(minSpeed, maxSpeed)

	local distortion = sound:FindFirstChildWhichIsA("DistortionSoundEffect")
	if distortion then
		distortion.Level = distortionLevel
	end

	local reverb = sound:FindFirstChildWhichIsA("ReverbSoundEffect")
	if reverb then
		reverb.DecayTime = reverbDecay
		reverb.WetLevel = reverbWet
	end

	local echo = sound:FindFirstChildWhichIsA("EchoSoundEffect")
	if echo then
		echo.Delay = echoDelay
		echo.Feedback = echoFeedback
	end

	local equalizer = sound:FindFirstChildWhichIsA("EqualizerSoundEffect")
	if equalizer then
		equalizer.LowGain = eqLowGain
		equalizer.MidGain = eqMidGain
		equalizer.HighGain = eqHighGain
	end

	if sound.IsPlaying then
		sound:Stop()
	end
	sound:Play()

	if variant and variant.Name == "PigSqueal" then
		local burstCountMinValue = variant.BurstCountMin
		local burstCountMin = if typeof(burstCountMinValue) == "number" then math.max(1, math.floor(burstCountMinValue)) else 1
		local burstCountMaxValue = variant.BurstCountMax
		local burstCountMax = if typeof(burstCountMaxValue) == "number"
			then math.max(burstCountMin, math.floor(burstCountMaxValue))
			else burstCountMin
		local burstCount = rng:NextInteger(burstCountMin, burstCountMax)
		if burstCount > 1 then
			local burstGapMinValue = variant.BurstGapMin
			local burstGapMin = if typeof(burstGapMinValue) == "number" then math.max(0.02, burstGapMinValue) else 0.05
			local burstGapMaxValue = variant.BurstGapMax
			local burstGapMax = if typeof(burstGapMaxValue) == "number"
				then math.max(burstGapMin + 0.005, burstGapMaxValue)
				else burstGapMin + 0.06
			local burstSpeedJitterValue = variant.BurstSpeedJitter
			local burstSpeedJitter = if typeof(burstSpeedJitterValue) == "number"
				then math.clamp(burstSpeedJitterValue, 0, 0.45)
				else 0.18
			local burstVolumeDecayValue = variant.BurstVolumeDecay
			local burstVolumeDecay = if typeof(burstVolumeDecayValue) == "number"
				then math.clamp(burstVolumeDecayValue, 0.45, 1)
				else 0.9
			local baseVolume = agent.groanBaseVolume * volumeMultiplier
			local delayAccum = 0

			for burstIndex = 2, burstCount do
				delayAccum += rng:NextNumber(burstGapMin, burstGapMax)
				task.delay(delayAccum, function()
					if not agent.alive or not sound.Parent then
						return
					end
					local jitterScale = rng:NextNumber(1 - burstSpeedJitter, 1 + burstSpeedJitter)
					local burstMinSpeed = math.max(0.05, minSpeed * jitterScale)
					local burstMaxSpeed = math.max(burstMinSpeed + 0.01, maxSpeed * jitterScale)
					sound.PlaybackSpeed = rng:NextNumber(burstMinSpeed, burstMaxSpeed)
					sound.Volume = baseVolume * (burstVolumeDecay ^ (burstIndex - 1))
					if sound.IsPlaying then
						sound:Stop()
					end
					sound:Play()
				end)
			end
		end
	end
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
	local rootHeightOffset = if isBoss then 3.5 else -1.9
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

		local auraRingOuter = createBodyPart(
			model,
			"BayumAuraRingOuter",
			Vector3.new(16, 0.22, 16),
			Color3.fromRGB(255, 72, 72),
			Enum.Material.Neon
		)
		auraRingOuter.Shape = Enum.PartType.Cylinder
		auraRingOuter.Transparency = 0.42

		local auraRingInner = createBodyPart(
			model,
			"BayumAuraRingInner",
			Vector3.new(10, 0.2, 10),
			Color3.fromRGB(255, 168, 78),
			Enum.Material.Neon
		)
		auraRingInner.Shape = Enum.PartType.Cylinder
		auraRingInner.Transparency = 0.5

		local bossAuraLight = Instance.new("PointLight")
		bossAuraLight.Name = "BossAuraLight"
		bossAuraLight.Color = Color3.fromRGB(255, 102, 92)
		bossAuraLight.Brightness = 3.1
		bossAuraLight.Range = 28
		bossAuraLight.Parent = root

		local auraAttachment = Instance.new("Attachment")
		auraAttachment.Name = "BossAuraAttachment"
		auraAttachment.Position = Vector3.new(0, 2.2, 0)
		auraAttachment.Parent = root

		local auraEmitter = Instance.new("ParticleEmitter")
		auraEmitter.Name = "BossAuraEmitter"
		auraEmitter.Rate = 42
		auraEmitter.Lifetime = NumberRange.new(0.45, 0.85)
		auraEmitter.Speed = NumberRange.new(1.6, 5.5)
		auraEmitter.SpreadAngle = Vector2.new(360, 38)
		auraEmitter.Rotation = NumberRange.new(0, 360)
		auraEmitter.RotSpeed = NumberRange.new(-140, 140)
		auraEmitter.Acceleration = Vector3.new(0, 2.8, 0)
		auraEmitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.42),
			NumberSequenceKeypoint.new(1, 0.08),
		})
		auraEmitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.18),
			NumberSequenceKeypoint.new(1, 1),
		})
		auraEmitter.Color = ColorSequence.new(
			Color3.fromRGB(255, 86, 86),
			Color3.fromRGB(255, 190, 120)
		)
		auraEmitter.LightEmission = 0.75
		auraEmitter.Parent = auraAttachment

		local bossHighlight = Instance.new("Highlight")
		bossHighlight.Name = "BossHighlight"
		bossHighlight.FillTransparency = 0.84
		bossHighlight.FillColor = Color3.fromRGB(255, 74, 74)
		bossHighlight.OutlineColor = Color3.fromRGB(255, 158, 124)
		bossHighlight.OutlineTransparency = 0.12
		bossHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		bossHighlight.Parent = model

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
		addVisual(visuals, auraRingOuter, CFrame.new(0, -5.95, 0))
		addVisual(visuals, auraRingInner, CFrame.new(0, -5.87, 0))
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
		bossLabel.Size = UDim2.fromOffset(118, 24)
		bossLabel.StudsOffset = Vector3.new(0, 11.05, 0)
		bossLabel.AlwaysOnTop = true
		bossLabel.MaxDistance = 180
		bossLabel.Parent = root

		local bossLabelText = Instance.new("TextLabel")
		bossLabelText.BackgroundTransparency = 1
		bossLabelText.Size = UDim2.fromScale(1, 1)
		bossLabelText.Font = Enum.Font.GothamBlack
		bossLabelText.TextScaled = false
		bossLabelText.TextSize = 19
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
	local groanBaseVolume = if isBoss
		then GameConfig.Infected.GroanVolume * bossConfig.GroanVolumeMultiplier
		else GameConfig.Infected.GroanVolume
	groanSound.Volume = groanBaseVolume
	groanSound.RollOffMode = Enum.RollOffMode.InverseTapered
	groanSound.RollOffMinDistance = GameConfig.Infected.GroanMinDistance
	groanSound.RollOffMaxDistance = GameConfig.Infected.GroanMaxDistance
	groanSound.Parent = root

	local reverb = Instance.new("ReverbSoundEffect")
	reverb.DecayTime = if isBoss then bossGroanReverbDecay else normalGroanReverbDecay
	reverb.Density = 0.45
	reverb.Diffusion = 0.72
	reverb.DryLevel = -1
	reverb.WetLevel = if isBoss then bossGroanReverbWet else normalGroanReverbWet
	reverb.Parent = groanSound

	local distortion = Instance.new("DistortionSoundEffect")
	distortion.Level = if isBoss then bossGroanDistortionLevel else normalGroanDistortionLevel
	distortion.Parent = groanSound

	local equalizer = Instance.new("EqualizerSoundEffect")
	equalizer.LowGain = 0
	equalizer.MidGain = 0
	equalizer.HighGain = 0
	equalizer.Parent = groanSound

	local echo = Instance.new("EchoSoundEffect")
	echo.Delay = 0.1
	echo.Feedback = 0.18
	echo.WetLevel = -4
	echo.DryLevel = 0
	echo.Parent = groanSound

	local attackDamage = if isBoss then bossConfig.Damage else GameConfig.Infected.Damage
	local attackRange = if isBoss then bossConfig.AttackRange else GameConfig.Infected.AttackRange
	local attackWindupSeconds = if isBoss then bossConfig.AttackWindupSeconds else GameConfig.Infected.AttackWindupSeconds
	local damageCooldownSeconds = if isBoss then bossConfig.DamageCooldown else GameConfig.Infected.DamageCooldown
	local magicDamage = if isBoss then bossConfig.MagicDamage else 0
	local magicRange = if isBoss then bossConfig.MagicRange else 0
	local magicCooldownSeconds = if isBoss then bossConfig.MagicCooldown else 0
	local magicWindupSeconds = if isBoss then bossConfig.MagicWindupSeconds else 0
	local magicBlastRadius = if isBoss then bossConfig.MagicBlastRadius else 0
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
	local hpBarFill = createHealthBar(root, isBoss, nil)

	local agent: InfectedAgent = {
		id = unitId,
		archetype = infectedArchetype,
		model = model,
		root = root,
		groanSound = groanSound,
		groanBaseVolume = groanBaseVolume,
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
		magicDamage = magicDamage,
		magicRange = magicRange,
		magicCooldown = 0,
		magicCooldownSeconds = magicCooldownSeconds,
		magicWindup = 0,
		magicWindupSeconds = magicWindupSeconds,
		magicBlastRadius = magicBlastRadius,
		queuedMagicTarget = nil,
		wanderSpeed = wanderSpeed,
		chaseSpeed = chaseSpeed,
		patrolRadius = patrolRadius,
		loseTargetSeconds = loseTargetSeconds,
		respawnSeconds = respawnSeconds,
		maxHealth = maxHealth,
		health = maxHealth,
		hpBarFill = hpBarFill,
		walkCycle = rng:NextNumber(0, math.pi * 2),
		moveBlend = 0,
		alive = true,
	}
	syncVisuals(agent)
	updateHealthBar(agent)
	return agent
end

local function markDead(agent: InfectedAgent)
	agent.alive = false
	agent.queuedAttackTarget = nil
	agent.queuedMagicTarget = nil
	agent.attackWindup = 0
	agent.magicWindup = 0
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
	agent.health = math.max(0, agent.health - math.max(0, amount))
	updateHealthBar(agent)
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
	local shockwaveBonus = math.max(0, GameConfig.Player.GrenadeShockwaveRadiusBonus)
	local effectiveRadius = math.max(radius + 0.1, radius + shockwaveBonus)
	local minShockDamage = math.max(1, GameConfig.Player.GrenadeShockwaveMinDamage)

	for _, agent in agents do
		if agent.alive and agent.model.Parent then
			local distance = (agent.root.Position - center).Magnitude
			if distance <= effectiveRadius then
				local falloff = 1 - (distance / effectiveRadius)
				local innerScale = if distance <= radius then 1 else 0.65
				local damage = math.max(minShockDamage, maxDamage * falloff * innerScale)
				if applyDamageToInfected(agent, damage) then
					hitCount += 1
				end
			end
		end
	end

	return hitCount
end

local function emitBossMagicCastFx(fromPos: Vector3, impactPos: Vector3)
	local direction = impactPos - fromPos
	local distance = math.max(0.8, direction.Magnitude)
	local mid = fromPos + direction * 0.5

	local beam = Instance.new("Part")
	beam.Name = "BayumMagicBeam"
	beam.Size = Vector3.new(0.5, 0.5, distance)
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 106, 120)
	beam.Transparency = 0.14
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CFrame = CFrame.lookAt(mid, impactPos)
	beam.Parent = Workspace
	Debris:AddItem(beam, 0.16)

	local flash = Instance.new("Part")
	flash.Name = "BayumMagicFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(1.8, 1.8, 1.8)
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 140, 144)
	flash.Transparency = 0.15
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.CFrame = CFrame.new(fromPos)
	flash.Parent = Workspace
	Debris:AddItem(flash, 0.18)

	local impact = Instance.new("Part")
	impact.Name = "BayumMagicImpact"
	impact.Shape = Enum.PartType.Ball
	impact.Size = Vector3.new(4.8, 4.8, 4.8)
	impact.Material = Enum.Material.Neon
	impact.Color = Color3.fromRGB(255, 86, 92)
	impact.Transparency = 0.2
	impact.Anchored = true
	impact.CanCollide = false
	impact.CanQuery = false
	impact.CanTouch = false
	impact.CFrame = CFrame.new(impactPos)
	impact.Parent = Workspace
	Debris:AddItem(impact, 0.2)
end

local function applyBossMagicDamage(center: Vector3, radius: number, maxDamage: number)
	local safeRadius = math.max(1, radius)
	local minDamage = math.max(4, maxDamage * 0.4)

	for _, player in Players:GetPlayers() do
		local root = getCharacterRoot(player)
		local humanoid = getHumanoid(player)
		if root and humanoid and humanoid.Health > 0 then
			local distance = (root.Position - center).Magnitude
			if distance <= safeRadius then
				local falloff = 1 - (distance / safeRadius)
				local damage = math.max(minDamage, maxDamage * falloff)
				humanoid:TakeDamage(damage)
			end
		end
	end
end

local function emitSwordHitBlood(position: Vector3, fromDirection: Vector3)
	local count = rng:NextInteger(24, 42)
	local outward = if fromDirection.Magnitude > 0.001 then fromDirection.Unit else Vector3.new(0, 0, -1)

	for _ = 1, count do
		local blood = Instance.new("Part")
		blood.Name = "SwordHitBlood"
		local side = rng:NextNumber(0.08, 0.22)
		blood.Size = Vector3.new(side, side, side)
		blood.Shape = Enum.PartType.Ball
		blood.Material = Enum.Material.SmoothPlastic
		blood.Color = Color3.fromRGB(
			rng:NextInteger(118, 176),
			rng:NextInteger(12, 36),
			rng:NextInteger(12, 28)
		)
		blood.TopSurface = Enum.SurfaceType.Smooth
		blood.BottomSurface = Enum.SurfaceType.Smooth
		blood.CanCollide = false
		blood.CanQuery = false
		blood.CanTouch = false
		blood.Anchored = false
		blood.CFrame = CFrame.new(position)
			* CFrame.new(
				rng:NextNumber(-0.28, 0.28),
				rng:NextNumber(-0.14, 0.28),
				rng:NextNumber(-0.28, 0.28)
			)
		blood.Parent = Workspace

		local spread = Vector3.new(
			rng:NextNumber(-1.25, 1.25),
			rng:NextNumber(0.08, 1.35),
			rng:NextNumber(-1.25, 1.25)
		)
		local velocityDir = outward * 1.6 + spread
		if velocityDir.Magnitude < 0.001 then
			velocityDir = Vector3.new(0, 1, 0)
		end

		blood.AssemblyLinearVelocity = velocityDir.Unit * rng:NextNumber(20, 40)
		blood.AssemblyAngularVelocity = Vector3.new(
			rng:NextNumber(-28, 28),
			rng:NextNumber(-28, 28),
			rng:NextNumber(-28, 28)
		)
		Debris:AddItem(blood, 0.95)
	end
end

local function emitSwordHitBossSparks(position: Vector3, fromDirection: Vector3)
	local minCount = math.max(1, GameConfig.Player.AttackSparkCountMin)
	local maxCount = math.max(minCount, GameConfig.Player.AttackSparkCountMax)
	local count = rng:NextInteger(minCount + 16, maxCount + 28)
	local outward = if fromDirection.Magnitude > 0.001 then fromDirection.Unit else Vector3.new(0, 0, -1)

	for _ = 1, count do
		local spark = Instance.new("Part")
		spark.Name = "SwordHitBossSpark"
		local side = rng:NextNumber(0.15, 0.36)
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
				rng:NextNumber(-0.24, 0.24),
				rng:NextNumber(-0.24, 0.24),
				rng:NextNumber(-0.24, 0.24)
			)
		spark.Parent = Workspace

		local spread = Vector3.new(
			rng:NextNumber(-1.35, 1.35),
			rng:NextNumber(0.22, 1.7),
			rng:NextNumber(-1.35, 1.35)
		)
		local velocityDir = outward * 2.8 + spread
		if velocityDir.Magnitude < 0.001 then
			velocityDir = Vector3.new(0, 1, 0)
		end

		spark.AssemblyLinearVelocity = velocityDir.Unit * rng:NextNumber(36, 64)
		spark.AssemblyAngularVelocity = Vector3.new(
			rng:NextNumber(-42, 42),
			rng:NextNumber(-42, 42),
			rng:NextNumber(-42, 42)
		)
		Debris:AddItem(spark, 1.2)
	end
end

local function emitSwordHitImpactFx(agent: InfectedAgent, position: Vector3, fromDirection: Vector3)
	if agent.archetype == "baium" then
		emitSwordHitBossSparks(position, fromDirection)
	else
		emitSwordHitBlood(position, fromDirection)
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
	agent.magicCooldown = math.max(0, agent.magicCooldown - dt)
	agent.magicWindup = math.max(0, agent.magicWindup - dt)

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
		if not agent.queuedMagicTarget and agent.magicWindup <= 0 then
			setAttackEyes(agent, false)
		end
	end

	local queuedMagicTarget = agent.queuedMagicTarget
	if queuedMagicTarget and agent.magicWindup <= 0 then
		local targetRoot = getCharacterRoot(queuedMagicTarget)
		local targetHumanoid = getHumanoid(queuedMagicTarget)
		if targetRoot and targetHumanoid and targetHumanoid.Health > 0 then
			local fromPos = agent.root.Position + Vector3.new(0, 4.8, 0)
			local impactPos = targetRoot.Position + Vector3.new(0, 1.4, 0)
			local distance = (targetRoot.Position - agent.root.Position).Magnitude
			local seen = canSeeTarget(fromPos, agent.root.CFrame.LookVector, targetRoot, agent.model)
			if distance <= agent.magicRange + 2 and seen then
				emitBossMagicCastFx(fromPos, impactPos)
				applyBossMagicDamage(impactPos, agent.magicBlastRadius, agent.magicDamage)
				agent.magicCooldown = agent.magicCooldownSeconds
			end
		end
		agent.queuedMagicTarget = nil
		if not agent.queuedAttackTarget and agent.attackWindup <= 0 then
			setAttackEyes(agent, false)
		end
	end

	if agent.damageCooldown > 0 or agent.attackWindup > 0 or agent.magicWindup > 0 then
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

	local distance = (root.Position - agent.root.Position).Magnitude
	if agent.archetype == "baium"
		and agent.magicRange > 0
		and agent.magicCooldown <= 0
		and distance > agent.attackRange * 0.95
		and distance <= agent.magicRange
	then
		local fromPos = agent.root.Position + Vector3.new(0, 4.8, 0)
		local seen = canSeeTarget(fromPos, agent.root.CFrame.LookVector, root, agent.model)
		if seen then
			agent.magicWindup = agent.magicWindupSeconds
			agent.queuedMagicTarget = chaseTarget
			setAttackEyes(agent, true)
			return
		end
	end

	if distance <= agent.attackRange then
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

	if not agent.chaseTarget and agent.attackWindup <= 0 and agent.magicWindup <= 0 then
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
	if agent.magicWindup > 0 then
		speed *= 0.35
	end

	local nextPos = moveTowards(currentPos, destination, speed, dt)
	local travelDistance = (nextPos - currentPos).Magnitude
	local targetBlend = if dt > 0 and speed > 0
		then math.clamp(travelDistance / math.max(0.001, speed * dt), 0, 1)
		else 0
	agent.moveBlend += (targetBlend - agent.moveBlend) * math.clamp(dt * 7.5, 0, 1)
	local cycleDistanceScale = if agent.archetype == "baium" then 1.75 else 4.25
	local idleCycleScale = if agent.archetype == "baium" then 0.6 else 0.22
	if travelDistance > 0.001 then
		agent.walkCycle += travelDistance * cycleDistanceScale
	else
		agent.walkCycle += dt * idleCycleScale
	end
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
		emitSwordHitImpactFx(bestAgent, sparkPos, sparkFrom - origin)
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
