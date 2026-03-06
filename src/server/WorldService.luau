--!strict

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local WorldService = {}

local decorFolderName = "WorldArt"
local destructibleAttribute = "DestructibleByGrenade"
local rng = Random.new(70421)
local birdFlockSize = 14
local birdFlightRadius = 360
local birdMinAltitude = 34
local birdMaxAltitude = 96
local treeCount = 72
local shrubCount = 220
local grassPatchCount = 170
local redMoonDistance = 240
local redMoonAltitude = 210
local redMoonSize = 96
local dragonOrbitRadius = 140
local dragonMinAltitude = 68
local dragonMaxAltitude = 88
local dragonFireMinCooldown = 4.5
local dragonFireMaxCooldown = 8.2
local dragonFireDamage = 16
local dragonFireDamageRadius = 20
local dragonFireTickSeconds = 0.22
local dragonPeacefulMode = true

type BirdAgent = {
	model: Model,
	root: Part,
	body: Part,
	head: Part,
	leftWing: Part,
	rightWing: Part,
	target: Vector3,
	speed: number,
	flapPhase: number,
	flapSpeed: number,
	bobPhase: number,
}

type DragonAgent = {
	model: Model,
	root: Part,
	body: Part,
	chest: Part,
	neck: Part,
	head: Part,
	snout: Part,
	jaw: Part,
	leftFang: Part,
	rightFang: Part,
	leftWing: Part,
	rightWing: Part,
	leftWingTip: Part,
	rightWingTip: Part,
	leftWingMembrane: Part,
	rightWingMembrane: Part,
	leftForeLeg: Part,
	rightForeLeg: Part,
	leftForeClaw: Part,
	rightForeClaw: Part,
	leftHindLeg: Part,
	rightHindLeg: Part,
	leftHindClaw: Part,
	rightHindClaw: Part,
	tailBase: Part,
	tailTip: Part,
	spineSpikes: { Part },
	tailSpikes: { Part },
	leftHorn: Part,
	rightHorn: Part,
	leftEye: Part,
	rightEye: Part,
	mouthAttachment: Attachment,
	fireEmitter: ParticleEmitter,
	smokeEmitter: ParticleEmitter,
	emberEmitter: ParticleEmitter,
	mouthLight: PointLight,
	fireBeam: Part?,
	center: Vector3,
	orbitAngle: number,
	orbitRadius: number,
	orbitSpeed: number,
	altitude: number,
	flapPhase: number,
	flapSpeed: number,
	tailPhase: number,
	pitchBobPhase: number,
	isBreathingFire: boolean,
	fireCooldown: number,
	fireDuration: number,
	fireTick: number,
	fireTarget: Vector3?,
	fireRetarget: number,
}

local birdAgents: { BirdAgent } = {}
local birdHeartbeatConnection: RBXScriptConnection?
local dragonAgent: DragonAgent?
local dragonHeartbeatConnection: RBXScriptConnection?

local function ensureGround()
	local existing = Workspace:FindFirstChild("Ground")
	local ground: Part
	if existing and existing:IsA("Part") then
		ground = existing
	else
		ground = Instance.new("Part")
		ground.Name = "Ground"
		ground.Parent = Workspace
	end

	ground.Size = Vector3.new(900, 8, 900)
	ground.Position = Vector3.new(0, -1, 0)
	ground.Anchored = true
	ground.Material = Enum.Material.Slate
	ground.Color = Color3.fromRGB(57, 60, 58)
	ground.Reflectance = 0.02
	ground.TopSurface = Enum.SurfaceType.Smooth
	ground.BottomSurface = Enum.SurfaceType.Smooth
end

local function ensureSpawn(): SpawnLocation
	local existing = Workspace:FindFirstChild("StartSpawn")
	local spawn: SpawnLocation
	if existing and existing:IsA("SpawnLocation") then
		spawn = existing
	else
		spawn = Instance.new("SpawnLocation")
		spawn.Name = "StartSpawn"
		spawn.Parent = Workspace
	end

	spawn.Size = Vector3.new(9, 1, 9)
	spawn.Position = Vector3.new(0, 6, 0)
	spawn.Anchored = true
	spawn.Material = Enum.Material.Concrete
	spawn.Color = Color3.fromRGB(131, 129, 121)
	spawn.Neutral = true
	return spawn
end

local function ensureAtmosphere()
	Lighting.Technology = Enum.Technology.Future
	Lighting.ClockTime = 14.4
	Lighting.Brightness = 1.2
	Lighting.ExposureCompensation = -0.34
	Lighting.Ambient = Color3.fromRGB(62, 68, 65)
	Lighting.OutdoorAmbient = Color3.fromRGB(84, 91, 88)
	Lighting.EnvironmentDiffuseScale = 0.32
	Lighting.EnvironmentSpecularScale = 0.16
	Lighting.ShadowSoftness = 0.56
	Lighting.GlobalShadows = true
	Lighting.FogColor = Color3.fromRGB(104, 114, 109)
	Lighting.FogStart = 36
	Lighting.FogEnd = 320

	local atmosphere = Lighting:FindFirstChild("WorldAtmosphere")
	if not atmosphere or not atmosphere:IsA("Atmosphere") then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "WorldAtmosphere"
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.58
	atmosphere.Offset = -0.24
	atmosphere.Color = Color3.fromRGB(128, 139, 132)
	atmosphere.Decay = Color3.fromRGB(72, 86, 79)
	atmosphere.Glare = 0
	atmosphere.Haze = 3.5

	local grade = Lighting:FindFirstChild("WorldColorGrade")
	if not grade or not grade:IsA("ColorCorrectionEffect") then
		grade = Instance.new("ColorCorrectionEffect")
		grade.Name = "WorldColorGrade"
		grade.Parent = Lighting
	end
	grade.Brightness = -0.06
	grade.Contrast = 0.15
	grade.Saturation = -0.34
	grade.TintColor = Color3.fromRGB(214, 224, 216)

	local bloom = Lighting:FindFirstChild("WorldBloom")
	if not bloom or not bloom:IsA("BloomEffect") then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "WorldBloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.22
	bloom.Size = 28
	bloom.Threshold = 1.45

	local sunRays = Lighting:FindFirstChild("WorldSunRays")
	if not sunRays or not sunRays:IsA("SunRaysEffect") then
		sunRays = Instance.new("SunRaysEffect")
		sunRays.Name = "WorldSunRays"
		sunRays.Parent = Lighting
	end
	sunRays.Intensity = 0.045
	sunRays.Spread = 0.9

	local dof = Lighting:FindFirstChild("WorldDepthOfField")
	if not dof or not dof:IsA("DepthOfFieldEffect") then
		dof = Instance.new("DepthOfFieldEffect")
		dof.Name = "WorldDepthOfField"
		dof.Parent = Lighting
	end
	dof.FarIntensity = 0.12
	dof.FocusDistance = 88
	dof.InFocusRadius = 38
	dof.NearIntensity = 0.22

	local clouds = Workspace.Terrain:FindFirstChild("WorldClouds")
	if not clouds or not clouds:IsA("Clouds") then
		clouds = Instance.new("Clouds")
		clouds.Name = "WorldClouds"
		clouds.Parent = Workspace.Terrain
	end
	clouds.Cover = 0.95
	clouds.Density = 0.98
	clouds.Color = Color3.fromRGB(166, 172, 168)
end

local function ensureDecorFolder(): Folder
	local existing = Workspace:FindFirstChild(decorFolderName)
	local folder: Folder
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = decorFolderName
		folder.Parent = Workspace
	end

	for _, child in folder:GetChildren() do
		child:Destroy()
	end
	return folder
end

local function createDecorPart(
	parent: Folder,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	canCollide: boolean
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = canCollide
	part.Material = material
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute(destructibleAttribute, true)
	part.Parent = parent
	return part
end

local function createMossPatch(anchor: BasePart, offset: Vector3, size: Vector3, parent: Folder)
	createDecorPart(
		parent,
		"MossPatch",
		size,
		anchor.CFrame * CFrame.new(offset) * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), rng:NextNumber(0, math.pi * 2), 0),
		Color3.fromRGB(
			rng:NextInteger(56, 72),
			rng:NextInteger(82, 104),
			rng:NextInteger(49, 64)
		),
		Enum.Material.Grass,
		false
	)
end

local function createFernClump(center: Vector3, parent: Folder, intensity: number)
	for _ = 1, intensity do
		local leaf = Instance.new("Part")
		local height = rng:NextNumber(0.8, 1.8)
		leaf.Name = "FernLeaf"
		leaf.Size = Vector3.new(0.12, height, 0.52)
		leaf.Anchored = true
		leaf.CanCollide = false
		leaf.Material = Enum.Material.Grass
		leaf.Color = Color3.fromRGB(
			rng:NextInteger(44, 66),
			rng:NextInteger(72, 104),
			rng:NextInteger(40, 58)
		)
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(0, 2.2)
		local basePos = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		leaf.CFrame = CFrame.new(basePos + Vector3.new(0, height * 0.5, 0))
			* CFrame.Angles(math.rad(rng:NextNumber(12, 46)), angle, math.rad(rng:NextNumber(-8, 8)))
		leaf:SetAttribute(destructibleAttribute, true)
		leaf.Parent = parent
	end
end

local function createIvyStrands(anchor: BasePart, parent: Folder, strandCount: number)
	for _ = 1, strandCount do
		local strand = Instance.new("Part")
		strand.Name = "IvyStrand"
		local width = rng:NextNumber(0.14, 0.34)
		local length = rng:NextNumber(1.8, 6.4)
		local side = rng:NextInteger(1, 4)
		local xOffset = 0
		local zOffset = 0

		if side == 1 then
			xOffset = -anchor.Size.X * 0.5 - 0.06
			zOffset = rng:NextNumber(-anchor.Size.Z * 0.48, anchor.Size.Z * 0.48)
		elseif side == 2 then
			xOffset = anchor.Size.X * 0.5 + 0.06
			zOffset = rng:NextNumber(-anchor.Size.Z * 0.48, anchor.Size.Z * 0.48)
		elseif side == 3 then
			xOffset = rng:NextNumber(-anchor.Size.X * 0.48, anchor.Size.X * 0.48)
			zOffset = -anchor.Size.Z * 0.5 - 0.06
		else
			xOffset = rng:NextNumber(-anchor.Size.X * 0.48, anchor.Size.X * 0.48)
			zOffset = anchor.Size.Z * 0.5 + 0.06
		end

		local topY = anchor.Position.Y + anchor.Size.Y * 0.5 - rng:NextNumber(0.2, 1.2)
		local pos = Vector3.new(anchor.Position.X + xOffset, topY - length * 0.5, anchor.Position.Z + zOffset)

		strand.Size = Vector3.new(width, length, 0.08)
		strand.Anchored = true
		strand.CanCollide = false
		strand.Material = Enum.Material.Grass
		strand.Color = Color3.fromRGB(rng:NextInteger(36, 54), rng:NextInteger(70, 96), rng:NextInteger(34, 46))
		strand.CFrame = CFrame.new(pos)
			* CFrame.Angles(
				math.rad(rng:NextNumber(-18, 18)),
				math.rad(rng:NextNumber(0, 360)),
				math.rad(rng:NextNumber(-14, 14))
			)
		strand:SetAttribute(destructibleAttribute, true)
		strand.Parent = parent

		if rng:NextNumber() > 0.58 then
			local leaf = Instance.new("Part")
			leaf.Name = "IvyLeaf"
			leaf.Size = Vector3.new(rng:NextNumber(0.16, 0.38), rng:NextNumber(0.08, 0.2), rng:NextNumber(0.16, 0.38))
			leaf.Anchored = true
			leaf.CanCollide = false
			leaf.Material = Enum.Material.Grass
			leaf.Color = Color3.fromRGB(rng:NextInteger(44, 70), rng:NextInteger(78, 108), rng:NextInteger(40, 56))
			leaf.CFrame = strand.CFrame * CFrame.new(0, -length * rng:NextNumber(0.15, 0.48), rng:NextNumber(-0.06, 0.06))
			leaf:SetAttribute(destructibleAttribute, true)
			leaf.Parent = parent
		end
	end
end

local function createRuinBlock(name: string, size: Vector3, position: Vector3, color: Color3, parent: Folder): Part
	local block = Instance.new("Part")
	block.Name = name
	block.Size = size
	block.Position = position
	block.Anchored = true
	block.Material = Enum.Material.Concrete
	block.Color = color
	block.TopSurface = Enum.SurfaceType.Smooth
	block.BottomSurface = Enum.SurfaceType.Smooth
	block:SetAttribute(destructibleAttribute, true)
	block.Parent = parent

	for _ = 1, rng:NextInteger(6, 11) do
		local patchSize = Vector3.new(rng:NextNumber(1.6, 4.2), 0.15, rng:NextNumber(1.1, 3.4))
		local patchOffset = Vector3.new(
			rng:NextNumber(-size.X * 0.42, size.X * 0.42),
			size.Y * 0.5 + 0.08,
			rng:NextNumber(-size.Z * 0.42, size.Z * 0.42)
		)
		createMossPatch(block, patchOffset, patchSize, parent)
	end

	createIvyStrands(block, parent, rng:NextInteger(10, 18))
	createFernClump(position + Vector3.new(0, -size.Y * 0.5, 0), parent, rng:NextInteger(12, 22))
	return block
end

local function createSafeFallbackBlock(name: string, size: Vector3, position: Vector3, color: Color3)
	local existing = Workspace:FindFirstChild(name)
	if existing and existing:IsA("Part") then
		existing:Destroy()
	end

	local block = Instance.new("Part")
	block.Name = name
	block.Size = size
	block.Position = position
	block.Anchored = true
	block.Material = Enum.Material.Concrete
	block.Color = color
	block:SetAttribute(destructibleAttribute, true)
	block.Parent = Workspace
end

local function isNearSpawn(position: Vector3, spawnPos: Vector3, radius: number): boolean
	return (Vector3.new(position.X, 0, position.Z) - Vector3.new(spawnPos.X, 0, spawnPos.Z)).Magnitude < radius
end

local function randomBirdPoint(spawnPos: Vector3, currentPos: Vector3?): Vector3
	for _ = 1, 24 do
		local candidate = Vector3.new(
			rng:NextNumber(-birdFlightRadius, birdFlightRadius),
			rng:NextNumber(birdMinAltitude, birdMaxAltitude),
			rng:NextNumber(-birdFlightRadius, birdFlightRadius)
		)
		if not isNearSpawn(candidate, spawnPos, 26) then
			if not currentPos or (candidate - currentPos).Magnitude > 70 then
				return candidate
			end
		end
	end

	return Vector3.new(
		rng:NextNumber(-birdFlightRadius, birdFlightRadius),
		rng:NextNumber(birdMinAltitude, birdMaxAltitude),
		rng:NextNumber(-birdFlightRadius, birdFlightRadius)
	)
end

local function createBirdPart(
	model: Model,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Material = material
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local function syncBirdVisual(agent: BirdAgent)
	local rootCFrame = agent.root.CFrame
	local flap = math.sin(agent.flapPhase)
	local bob = math.sin(agent.bobPhase) * 0.2
	local wingRoll = math.rad(64) * flap
	local wingPitch = math.rad(8 * flap)

	agent.body.CFrame = rootCFrame * CFrame.new(0, bob, 0) * CFrame.Angles(math.rad(2.2 * flap), 0, 0)
	agent.head.CFrame = rootCFrame * CFrame.new(0, bob + 0.1, -0.62) * CFrame.Angles(math.rad(-5.5 + 2 * flap), 0, 0)
	agent.leftWing.CFrame = rootCFrame
		* CFrame.new(-0.66, bob + 0.04, -0.03)
		* CFrame.Angles(wingPitch, 0, math.rad(-11) + wingRoll)
	agent.rightWing.CFrame = rootCFrame
		* CFrame.new(0.66, bob + 0.04, -0.03)
		* CFrame.Angles(wingPitch, 0, math.rad(11) - wingRoll)
end

local function createBird(parent: Folder, spawnPos: Vector3, index: number): BirdAgent
	local model = Instance.new("Model")
	model.Name = ("Bird_%d"):format(index)
	model.Parent = parent

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.4, 0.4, 0.8)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CastShadow = false
	root.Parent = model
	model.PrimaryPart = root

	local bodyColor = Color3.fromRGB(rng:NextInteger(68, 92), rng:NextInteger(68, 92), rng:NextInteger(72, 96))
	local wingColor = Color3.fromRGB(rng:NextInteger(44, 60), rng:NextInteger(44, 60), rng:NextInteger(48, 66))
	local beakColor = Color3.fromRGB(160, 125, 74)

	local body = createBirdPart(model, "Body", Vector3.new(0.56, 0.36, 1.05), bodyColor, Enum.Material.SmoothPlastic)
	local head = createBirdPart(model, "Head", Vector3.new(0.32, 0.28, 0.34), bodyColor, Enum.Material.SmoothPlastic)
	local leftWing = createBirdPart(model, "LeftWing", Vector3.new(1.35, 0.08, 0.52), wingColor, Enum.Material.SmoothPlastic)
	local rightWing = createBirdPart(model, "RightWing", Vector3.new(1.35, 0.08, 0.52), wingColor, Enum.Material.SmoothPlastic)
	local beak = createBirdPart(model, "Beak", Vector3.new(0.1, 0.08, 0.24), beakColor, Enum.Material.SmoothPlastic)

	local startPos = randomBirdPoint(spawnPos, nil)
	local startDir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.15, 0.15), rng:NextNumber(-1, 1))
	if startDir.Magnitude < 0.01 then
		startDir = Vector3.new(0, 0, -1)
	else
		startDir = startDir.Unit
	end
	root.CFrame = CFrame.lookAt(startPos, startPos + startDir, Vector3.yAxis)

	local agent: BirdAgent = {
		model = model,
		root = root,
		body = body,
		head = head,
		leftWing = leftWing,
		rightWing = rightWing,
		target = randomBirdPoint(spawnPos, startPos),
		speed = rng:NextNumber(30, 48),
		flapPhase = rng:NextNumber(0, math.pi * 2),
		flapSpeed = rng:NextNumber(8.6, 13.2),
		bobPhase = rng:NextNumber(0, math.pi * 2),
	}

	beak.CFrame = root.CFrame * CFrame.new(0, 0.08, -0.84) * CFrame.Angles(math.rad(-4), 0, 0)
	syncBirdVisual(agent)
	return agent
end

local function updateBird(agent: BirdAgent, dt: number, spawnPos: Vector3)
	local currentPos = agent.root.Position
	local toTarget = agent.target - currentPos
	local distance = toTarget.Magnitude
	if distance < 14 then
		agent.target = randomBirdPoint(spawnPos, currentPos)
		toTarget = agent.target - currentPos
		distance = toTarget.Magnitude
	end

	local direction = if distance > 0.001 then toTarget.Unit else agent.root.CFrame.LookVector
	local speedScale = math.clamp(distance / 90, 0.4, 1.2)
	local travelStep = agent.speed * speedScale * dt
	local nextPos = currentPos + direction * math.min(distance, travelStep)
	local bank = math.rad(math.clamp(direction.X * 16, -18, 18))
	agent.root.CFrame = CFrame.lookAt(nextPos, nextPos + direction, Vector3.yAxis) * CFrame.Angles(0, 0, bank)

	agent.flapPhase += dt * agent.flapSpeed * (0.75 + speedScale * 0.6)
	agent.bobPhase += dt * (2.2 + speedScale * 2.6)
	syncBirdVisual(agent)
end

local function stopBirdSystem()
	if birdHeartbeatConnection then
		birdHeartbeatConnection:Disconnect()
		birdHeartbeatConnection = nil
	end
	table.clear(birdAgents)
end

local function startBirdSystem(parent: Folder, spawnPos: Vector3)
	stopBirdSystem()

	local birdsFolder = Instance.new("Folder")
	birdsFolder.Name = "BirdFlock"
	birdsFolder.Parent = parent

	for i = 1, birdFlockSize do
		table.insert(birdAgents, createBird(birdsFolder, spawnPos, i))
	end

	birdHeartbeatConnection = RunService.Heartbeat:Connect(function(dt: number)
		local step = math.clamp(dt, 1 / 240, 1 / 20)
		for _, bird in birdAgents do
			if bird.model.Parent then
				updateBird(bird, step, spawnPos)
			end
		end
	end)
end

local function getCharacterRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function getCharacterHumanoid(player: Player): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function pickDragonFireTarget(center: Vector3): Vector3
	if dragonPeacefulMode then
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(120, 250)
		return center + Vector3.new(math.cos(angle) * radius, rng:NextNumber(2, 24), math.sin(angle) * radius)
	end

	local bestDistance = math.huge
	local bestTarget: Vector3? = nil

	for _, player in Players:GetPlayers() do
		local root = getCharacterRoot(player)
		local humanoid = getCharacterHumanoid(player)
		if root and humanoid and humanoid.Health > 0 then
			local distance = (root.Position - center).Magnitude
			if distance < 440 and distance < bestDistance then
				bestDistance = distance
				bestTarget = root.Position
			end
		end
	end

	if bestTarget then
		return bestTarget
	end

	return center + Vector3.new(
		rng:NextNumber(-190, 190),
		rng:NextNumber(-1, 18),
		rng:NextNumber(-190, 190)
	)
end

local function applyDragonFireDamage(position: Vector3, radius: number, damage: number)
	if dragonPeacefulMode then
		return
	end

	for _, player in Players:GetPlayers() do
		local root = getCharacterRoot(player)
		local humanoid = getCharacterHumanoid(player)
		if root and humanoid and humanoid.Health > 0 then
			if (root.Position - position).Magnitude <= radius then
				humanoid:TakeDamage(damage)
			end
		end
	end
end

local function spawnDragonFireImpactFx(position: Vector3)
	local impact = Instance.new("Part")
	impact.Name = "DragonFireImpact"
	impact.Shape = Enum.PartType.Ball
	impact.Size = Vector3.new(2.8, 2.8, 2.8)
	impact.Material = Enum.Material.Neon
	impact.Color = Color3.fromRGB(255, 120, 48)
	impact.Transparency = 0.14
	impact.Anchored = true
	impact.CanCollide = false
	impact.CastShadow = false
	impact.CFrame = CFrame.new(position)
	impact.Parent = Workspace
	Debris:AddItem(impact, 0.2)

	local emberAttachment = Instance.new("Attachment")
	emberAttachment.Parent = impact

	local embers = Instance.new("ParticleEmitter")
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 176, 98), Color3.fromRGB(255, 66, 28))
	embers.LightEmission = 0.85
	embers.Lifetime = NumberRange.new(0.2, 0.45)
	embers.Speed = NumberRange.new(22, 42)
	embers.SpreadAngle = Vector2.new(60, 60)
	embers.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	embers.Rate = 0
	embers.Parent = emberAttachment
	embers:Emit(16)

	local smoke = Instance.new("ParticleEmitter")
	smoke.Color = ColorSequence.new(Color3.fromRGB(58, 58, 58), Color3.fromRGB(24, 24, 24))
	smoke.LightEmission = 0
	smoke.Lifetime = NumberRange.new(0.45, 0.9)
	smoke.Speed = NumberRange.new(4, 11)
	smoke.SpreadAngle = Vector2.new(55, 55)
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.4),
		NumberSequenceKeypoint.new(1, 2.9),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.22),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Rate = 0
	smoke.Parent = emberAttachment
	smoke:Emit(9)
end

local function createDragonPart(
	model: Model,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Material = material
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local function syncDragonVisual(agent: DragonAgent)
	local rootCFrame = agent.root.CFrame
	local flap = math.sin(agent.flapPhase)
	local flapDouble = math.sin(agent.flapPhase * 2)
	local tailSwing = math.sin(agent.tailPhase)
	local tailTwist = math.sin(agent.tailPhase * 1.7)
	local bob = math.sin(agent.pitchBobPhase) * 0.9
	local wingRoll = math.rad(58) * flap
	local wingPitch = math.rad(10) * flap
	local jawBase = if agent.isBreathingFire then 21 else 8
	local legStep = math.sin(agent.flapPhase * 0.85)
	local legCounter = math.sin(agent.flapPhase * 0.85 + math.pi)

	agent.body.CFrame = rootCFrame * CFrame.new(0, bob, 0.2) * CFrame.Angles(math.rad(3 + 2 * flapDouble), 0, 0)
	agent.chest.CFrame = rootCFrame * CFrame.new(0, 1.7 + bob, -4.2) * CFrame.Angles(math.rad(7 + 3 * flapDouble), 0, 0)
	agent.neck.CFrame = rootCFrame * CFrame.new(0, 3.4 + bob, -6.8) * CFrame.Angles(math.rad(-6 + 4 * flapDouble), 0, 0)
	agent.head.CFrame = rootCFrame * CFrame.new(0, 3.9 + bob, -12.7) * CFrame.Angles(math.rad(-11 + 5 * flapDouble), 0, 0)
	agent.jaw.CFrame = rootCFrame * CFrame.new(0, 2.25 + bob, -13.4) * CFrame.Angles(math.rad(jawBase + 2.5 * flapDouble), 0, 0)
	agent.snout.CFrame = rootCFrame * CFrame.new(0, 3.1 + bob, -16.1) * CFrame.Angles(math.rad(-8 + 3 * flapDouble), 0, 0)

	agent.leftWing.CFrame = rootCFrame
		* CFrame.new(-11.4, 2.2 + bob * 0.3, -1.8)
		* CFrame.Angles(wingPitch, math.rad(-14), math.rad(-18) + wingRoll)
	agent.rightWing.CFrame = rootCFrame
		* CFrame.new(11.4, 2.2 + bob * 0.3, -1.8)
		* CFrame.Angles(wingPitch, math.rad(14), math.rad(18) - wingRoll)
	agent.leftWingTip.CFrame = rootCFrame
		* CFrame.new(-22.1, 1.8 + bob * 0.22, -1.4)
		* CFrame.Angles(math.rad(4 * flap), math.rad(-11), math.rad(-10) + wingRoll * 1.28)
	agent.rightWingTip.CFrame = rootCFrame
		* CFrame.new(22.1, 1.8 + bob * 0.22, -1.4)
		* CFrame.Angles(math.rad(4 * flap), math.rad(11), math.rad(10) - wingRoll * 1.28)
	agent.leftWingMembrane.CFrame = rootCFrame
		* CFrame.new(-16.8, 1.2 + bob * 0.24, -2.1)
		* CFrame.Angles(math.rad(wingPitch * 0.58), math.rad(-10), math.rad(-12) + wingRoll * 0.92)
	agent.rightWingMembrane.CFrame = rootCFrame
		* CFrame.new(16.8, 1.2 + bob * 0.24, -2.1)
		* CFrame.Angles(math.rad(wingPitch * 0.58), math.rad(10), math.rad(12) - wingRoll * 0.92)

	agent.tailBase.CFrame = rootCFrame
		* CFrame.new(0, 1.25 + bob * 0.22, 11.1)
		* CFrame.Angles(math.rad(11), math.rad(10 * tailSwing), math.rad(3.5 * tailSwing))
	agent.tailTip.CFrame = rootCFrame
		* CFrame.new(0, 0.88 + bob * 0.22, 17.2)
		* CFrame.Angles(math.rad(16), math.rad(18 * tailSwing), math.rad(2 * tailTwist))

	agent.leftForeLeg.CFrame = rootCFrame
		* CFrame.new(-3.9, -1.8 + bob * 0.1, -4.1)
		* CFrame.Angles(math.rad(30 + 8 * legStep), 0, math.rad(7))
	agent.rightForeLeg.CFrame = rootCFrame
		* CFrame.new(3.9, -1.8 + bob * 0.1, -4.1)
		* CFrame.Angles(math.rad(30 + 8 * legCounter), 0, math.rad(-7))
	agent.leftForeClaw.CFrame = rootCFrame
		* CFrame.new(-4.1, -5.0 + bob * 0.12, -4.7)
		* CFrame.Angles(math.rad(16 + 4 * legStep), 0, math.rad(8))
	agent.rightForeClaw.CFrame = rootCFrame
		* CFrame.new(4.1, -5.0 + bob * 0.12, -4.7)
		* CFrame.Angles(math.rad(16 + 4 * legCounter), 0, math.rad(-8))

	agent.leftHindLeg.CFrame = rootCFrame
		* CFrame.new(-4.4, -2.0 + bob * 0.08, 7.3)
		* CFrame.Angles(math.rad(24 + 7 * legCounter), 0, math.rad(8))
	agent.rightHindLeg.CFrame = rootCFrame
		* CFrame.new(4.4, -2.0 + bob * 0.08, 7.3)
		* CFrame.Angles(math.rad(24 + 7 * legStep), 0, math.rad(-8))
	agent.leftHindClaw.CFrame = rootCFrame
		* CFrame.new(-4.7, -5.2 + bob * 0.1, 8.2)
		* CFrame.Angles(math.rad(12 + 4 * legCounter), 0, math.rad(8))
	agent.rightHindClaw.CFrame = rootCFrame
		* CFrame.new(4.7, -5.2 + bob * 0.1, 8.2)
		* CFrame.Angles(math.rad(12 + 4 * legStep), 0, math.rad(-8))

	local headCFrame = agent.head.CFrame
	agent.leftHorn.CFrame = headCFrame * CFrame.new(-1.85, 1.15, -0.8) * CFrame.Angles(math.rad(-34), math.rad(-16), math.rad(8))
	agent.rightHorn.CFrame = headCFrame * CFrame.new(1.85, 1.15, -0.8) * CFrame.Angles(math.rad(-34), math.rad(16), math.rad(-8))
	agent.leftEye.CFrame = headCFrame * CFrame.new(-1.08, 0.24, -2.68)
	agent.rightEye.CFrame = headCFrame * CFrame.new(1.08, 0.24, -2.68)
	agent.leftFang.CFrame = headCFrame * CFrame.new(-1.08, -0.82, -3.35) * CFrame.Angles(math.rad(10), 0, 0)
	agent.rightFang.CFrame = headCFrame * CFrame.new(1.08, -0.82, -3.35) * CFrame.Angles(math.rad(10), 0, 0)

	local spineCount = #agent.spineSpikes
	for index, spike in agent.spineSpikes do
		local t = if spineCount > 1 then (index - 1) / (spineCount - 1) else 0
		local z = -4.6 + t * 14.4
		local y = 3.7 + math.sin(agent.tailPhase * 0.75 + t * math.pi * 2) * 0.25
		local yaw = math.rad(3 * math.sin(agent.tailPhase + t * 3.6))
		spike.CFrame = rootCFrame
			* CFrame.new(0, y + bob * 0.1, z)
			* CFrame.Angles(math.rad(-18 + 8 * t), yaw, 0)
	end

	local tailSpikeCount = #agent.tailSpikes
	for index, spike in agent.tailSpikes do
		local t = if tailSpikeCount > 1 then (index - 1) / (tailSpikeCount - 1) else 0
		local z = 12.8 + t * 6.2
		local y = 1.7 - t * 0.44
		local yaw = math.rad(12 * tailSwing + t * 7)
		local roll = math.rad(6 * tailTwist)
		spike.CFrame = rootCFrame
			* CFrame.new(0, y + bob * 0.06, z)
			* CFrame.Angles(math.rad(14 + t * 8), yaw, roll)
	end
end

local function updateDragonFireBeam(agent: DragonAgent, fromPos: Vector3, toPos: Vector3)
	local beam = agent.fireBeam
	if not beam then
		beam = Instance.new("Part")
		beam.Name = "DragonFireBreath"
		beam.Anchored = true
		beam.CanCollide = false
		beam.CastShadow = false
		beam.Material = Enum.Material.Neon
		beam.Transparency = 0.2
		beam.Color = Color3.fromRGB(255, 108, 38)
		beam.Parent = agent.model
		agent.fireBeam = beam
	end

	local distance = (toPos - fromPos).Magnitude
	local length = math.max(2, distance)
	beam.Size = Vector3.new(4.4, 4.4, length)
	beam.Color = Color3.fromRGB(255, rng:NextInteger(88, 132), rng:NextInteger(28, 42))
	beam.CFrame = CFrame.lookAt(fromPos, toPos) * CFrame.new(0, 0, -length * 0.5)
end

local function stopDragonFireBreath(agent: DragonAgent)
	agent.isBreathingFire = false
	agent.fireDuration = 0
	agent.fireTick = 0
	agent.fireRetarget = 0
	agent.fireTarget = nil
	agent.fireCooldown = rng:NextNumber(dragonFireMinCooldown, dragonFireMaxCooldown)
	agent.fireEmitter.Enabled = false
	agent.smokeEmitter.Enabled = false
	agent.emberEmitter.Enabled = false
	agent.mouthLight.Enabled = false

	local beam = agent.fireBeam
	if beam and beam.Parent then
		beam:Destroy()
	end
	agent.fireBeam = nil
end

local function startDragonFireBreath(agent: DragonAgent)
	agent.isBreathingFire = true
	agent.fireDuration = rng:NextNumber(2.2, 3.8)
	agent.fireTick = 0
	agent.fireRetarget = 0
	agent.fireTarget = pickDragonFireTarget(agent.center)
	agent.fireEmitter.Enabled = true
	agent.smokeEmitter.Enabled = true
	agent.emberEmitter.Enabled = true
	agent.mouthLight.Enabled = true
	agent.mouthLight.Brightness = 4.5
	agent.fireEmitter:Emit(28)
	agent.smokeEmitter:Emit(14)
	agent.emberEmitter:Emit(24)
end

local function updateDragonFireBreath(agent: DragonAgent, dt: number)
	if not agent.isBreathingFire then
		agent.fireCooldown = math.max(0, agent.fireCooldown - dt)
		if agent.fireCooldown <= 0 then
			startDragonFireBreath(agent)
		end
		return
	end

	agent.fireDuration -= dt
	if agent.fireDuration <= 0 then
		stopDragonFireBreath(agent)
		return
	end

	agent.fireRetarget -= dt
	if agent.fireRetarget <= 0 then
		agent.fireTarget = pickDragonFireTarget(agent.center)
		agent.fireRetarget = rng:NextNumber(0.35, 0.85)
	end

	local mouthPos = agent.mouthAttachment.WorldPosition
	local targetPos = if agent.fireTarget
		then agent.fireTarget + Vector3.new(rng:NextNumber(-2.8, 2.8), rng:NextNumber(0, 3.2), rng:NextNumber(-2.8, 2.8))
		else agent.root.Position + agent.root.CFrame.LookVector * 140
	updateDragonFireBeam(agent, mouthPos, targetPos)

	agent.fireTick += dt
	while agent.fireTick >= dragonFireTickSeconds do
		agent.fireTick -= dragonFireTickSeconds
		applyDragonFireDamage(targetPos, dragonFireDamageRadius, dragonFireDamage)
		spawnDragonFireImpactFx(targetPos)
	end
end

local function createDragon(parent: Folder, spawnPos: Vector3): DragonAgent
	local model = Instance.new("Model")
	model.Name = "DreadDragon"
	model.Parent = parent

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(8, 6, 18)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CastShadow = false
	root.Parent = model
	model.PrimaryPart = root

	local scale = 1.55
	local bodyColor = Color3.fromRGB(56, 58, 64)
	local scaleColor = Color3.fromRGB(80, 77, 69)
	local wingColor = Color3.fromRGB(34, 30, 36)
	local membraneColor = Color3.fromRGB(52, 32, 34)
	local hornColor = Color3.fromRGB(118, 108, 88)

	local body = createDragonPart(model, "Body", Vector3.new(12.6, 6.2, 20.4) * scale, bodyColor, Enum.Material.Slate)
	local chest = createDragonPart(model, "Chest", Vector3.new(9.4, 5.6, 8.0) * scale, scaleColor, Enum.Material.Slate)
	local neck = createDragonPart(model, "Neck", Vector3.new(4.4, 4.2, 8.4) * scale, bodyColor, Enum.Material.Slate)
	local head = createDragonPart(model, "Head", Vector3.new(5.6, 4.2, 7.2) * scale, bodyColor, Enum.Material.Slate)
	local snout = createDragonPart(model, "Snout", Vector3.new(3.8, 2.8, 5.4) * scale, scaleColor, Enum.Material.Slate)
	local jaw = createDragonPart(model, "Jaw", Vector3.new(4.8, 1.2, 5.2) * scale, scaleColor, Enum.Material.Slate)
	local leftWing = createDragonPart(model, "LeftWing", Vector3.new(14.5, 1.0, 9.2) * scale, wingColor, Enum.Material.SmoothPlastic)
	local rightWing = createDragonPart(model, "RightWing", Vector3.new(14.5, 1.0, 9.2) * scale, wingColor, Enum.Material.SmoothPlastic)
	local leftWingTip = createDragonPart(model, "LeftWingTip", Vector3.new(11.4, 0.7, 7.8) * scale, wingColor, Enum.Material.SmoothPlastic)
	local rightWingTip = createDragonPart(model, "RightWingTip", Vector3.new(11.4, 0.7, 7.8) * scale, wingColor, Enum.Material.SmoothPlastic)
	local leftWingMembrane = createDragonPart(model, "LeftWingMembrane", Vector3.new(16.8, 0.3, 8.8) * scale, membraneColor, Enum.Material.SmoothPlastic)
	local rightWingMembrane = createDragonPart(model, "RightWingMembrane", Vector3.new(16.8, 0.3, 8.8) * scale, membraneColor, Enum.Material.SmoothPlastic)
	leftWingMembrane.Transparency = 0.2
	rightWingMembrane.Transparency = 0.2
	local tailBase = createDragonPart(model, "TailBase", Vector3.new(4.2, 3.4, 9.6) * scale, bodyColor, Enum.Material.Slate)
	local tailTip = createDragonPart(model, "TailTip", Vector3.new(2.2, 2.0, 8.2) * scale, scaleColor, Enum.Material.Slate)
	local leftForeLeg = createDragonPart(model, "LeftForeLeg", Vector3.new(1.9, 4.1, 2.2) * scale, scaleColor, Enum.Material.Slate)
	local rightForeLeg = createDragonPart(model, "RightForeLeg", Vector3.new(1.9, 4.1, 2.2) * scale, scaleColor, Enum.Material.Slate)
	local leftForeClaw = createDragonPart(model, "LeftForeClaw", Vector3.new(2.2, 1.2, 3.0) * scale, hornColor, Enum.Material.Slate)
	local rightForeClaw = createDragonPart(model, "RightForeClaw", Vector3.new(2.2, 1.2, 3.0) * scale, hornColor, Enum.Material.Slate)
	local leftHindLeg = createDragonPart(model, "LeftHindLeg", Vector3.new(2.2, 4.6, 2.7) * scale, scaleColor, Enum.Material.Slate)
	local rightHindLeg = createDragonPart(model, "RightHindLeg", Vector3.new(2.2, 4.6, 2.7) * scale, scaleColor, Enum.Material.Slate)
	local leftHindClaw = createDragonPart(model, "LeftHindClaw", Vector3.new(2.6, 1.35, 3.2) * scale, hornColor, Enum.Material.Slate)
	local rightHindClaw = createDragonPart(model, "RightHindClaw", Vector3.new(2.6, 1.35, 3.2) * scale, hornColor, Enum.Material.Slate)
	local leftHorn = createDragonPart(model, "LeftHorn", Vector3.new(0.8, 2.4, 0.8) * scale, hornColor, Enum.Material.SmoothPlastic)
	local rightHorn = createDragonPart(model, "RightHorn", Vector3.new(0.8, 2.4, 0.8) * scale, hornColor, Enum.Material.SmoothPlastic)
	local leftEye = createDragonPart(model, "LeftEye", Vector3.new(0.34, 0.34, 0.34) * scale, Color3.fromRGB(255, 86, 56), Enum.Material.Neon)
	local rightEye = createDragonPart(model, "RightEye", Vector3.new(0.34, 0.34, 0.34) * scale, Color3.fromRGB(255, 86, 56), Enum.Material.Neon)
	local leftFang = createDragonPart(model, "LeftFang", Vector3.new(0.22, 0.22, 1.5) * scale, hornColor, Enum.Material.SmoothPlastic)
	local rightFang = createDragonPart(model, "RightFang", Vector3.new(0.22, 0.22, 1.5) * scale, hornColor, Enum.Material.SmoothPlastic)
	leftEye.Shape = Enum.PartType.Ball
	rightEye.Shape = Enum.PartType.Ball
	snout.Shape = Enum.PartType.Wedge
	leftFang.Shape = Enum.PartType.Cylinder
	rightFang.Shape = Enum.PartType.Cylinder
	leftHorn.Shape = Enum.PartType.Wedge
	rightHorn.Shape = Enum.PartType.Wedge
	leftForeClaw.Shape = Enum.PartType.Wedge
	rightForeClaw.Shape = Enum.PartType.Wedge
	leftHindClaw.Shape = Enum.PartType.Wedge
	rightHindClaw.Shape = Enum.PartType.Wedge

	local spineSpikes: { Part } = {}
	for i = 1, 8 do
		local spikeSize = Vector3.new(0.7, 2.8 - i * 0.12, 1.2 - i * 0.06) * scale
		local spike = createDragonPart(model, ("SpineSpike_%d"):format(i), spikeSize, hornColor, Enum.Material.SmoothPlastic)
		spike.Shape = Enum.PartType.Wedge
		table.insert(spineSpikes, spike)
	end

	local tailSpikes: { Part } = {}
	for i = 1, 5 do
		local spikeSize = Vector3.new(0.5, 1.8 - i * 0.1, 0.9 - i * 0.08) * scale
		local spike = createDragonPart(model, ("TailSpike_%d"):format(i), spikeSize, hornColor, Enum.Material.SmoothPlastic)
		spike.Shape = Enum.PartType.Wedge
		table.insert(tailSpikes, spike)
	end

	local mouthAttachment = Instance.new("Attachment")
	mouthAttachment.Name = "Mouth"
	mouthAttachment.Position = Vector3.new(0, -0.08 * scale, -3.8 * scale)
	mouthAttachment.Parent = head

	local fireEmitter = Instance.new("ParticleEmitter")
	fireEmitter.Name = "Fire"
	fireEmitter.Enabled = false
	fireEmitter.Rate = 230
	fireEmitter.Lifetime = NumberRange.new(0.18, 0.34)
	fireEmitter.Speed = NumberRange.new(76, 120)
	fireEmitter.SpreadAngle = Vector2.new(12, 12)
	fireEmitter.LightEmission = 0.95
	fireEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(0.5, 0.78),
		NumberSequenceKeypoint.new(1, 0),
	})
	fireEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 214, 102)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 122, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 48, 28)),
	})
	fireEmitter.Parent = mouthAttachment

	local smokeEmitter = Instance.new("ParticleEmitter")
	smokeEmitter.Name = "FireSmoke"
	smokeEmitter.Enabled = false
	smokeEmitter.Rate = 110
	smokeEmitter.Lifetime = NumberRange.new(0.45, 0.92)
	smokeEmitter.Speed = NumberRange.new(8, 18)
	smokeEmitter.SpreadAngle = Vector2.new(24, 24)
	smokeEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.8),
		NumberSequenceKeypoint.new(1, 3.7),
	})
	smokeEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	smokeEmitter.Color = ColorSequence.new(Color3.fromRGB(66, 66, 66), Color3.fromRGB(28, 28, 28))
	smokeEmitter.Parent = mouthAttachment

	local emberEmitter = Instance.new("ParticleEmitter")
	emberEmitter.Name = "Embers"
	emberEmitter.Enabled = false
	emberEmitter.Rate = 160
	emberEmitter.Lifetime = NumberRange.new(0.22, 0.55)
	emberEmitter.Speed = NumberRange.new(34, 62)
	emberEmitter.SpreadAngle = Vector2.new(26, 26)
	emberEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	emberEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 198, 95), Color3.fromRGB(255, 80, 28))
	emberEmitter.LightEmission = 0.88
	emberEmitter.Parent = mouthAttachment

	local mouthLight = Instance.new("PointLight")
	mouthLight.Enabled = false
	mouthLight.Brightness = 0
	mouthLight.Range = 42
	mouthLight.Color = Color3.fromRGB(255, 112, 44)
	mouthLight.Parent = mouthAttachment

	local presenceLight = Instance.new("PointLight")
	presenceLight.Name = "DragonPresenceLight"
	presenceLight.Brightness = 1.3
	presenceLight.Range = 72
	presenceLight.Color = Color3.fromRGB(255, 68, 52)
	presenceLight.Parent = root

	local center = Vector3.new(spawnPos.X, 0, spawnPos.Z)
	local orbitRadius = dragonOrbitRadius + rng:NextNumber(-26, 26)
	local orbitAngle = -1.2 + rng:NextNumber(-0.26, 0.26)
	local altitude = rng:NextNumber(dragonMinAltitude, dragonMaxAltitude)
	local startPos = center + Vector3.new(math.cos(orbitAngle) * orbitRadius, altitude, math.sin(orbitAngle) * orbitRadius)
	local lookAngle = orbitAngle + 0.18
	local lookPos = center + Vector3.new(math.cos(lookAngle) * orbitRadius, altitude - 8, math.sin(lookAngle) * orbitRadius)
	root.CFrame = CFrame.lookAt(startPos, lookPos, Vector3.yAxis)

	local agent: DragonAgent = {
		model = model,
		root = root,
		body = body,
		chest = chest,
		neck = neck,
		head = head,
		snout = snout,
		jaw = jaw,
		leftFang = leftFang,
		rightFang = rightFang,
		leftWing = leftWing,
		rightWing = rightWing,
		leftWingTip = leftWingTip,
		rightWingTip = rightWingTip,
		leftWingMembrane = leftWingMembrane,
		rightWingMembrane = rightWingMembrane,
		leftForeLeg = leftForeLeg,
		rightForeLeg = rightForeLeg,
		leftForeClaw = leftForeClaw,
		rightForeClaw = rightForeClaw,
		leftHindLeg = leftHindLeg,
		rightHindLeg = rightHindLeg,
		leftHindClaw = leftHindClaw,
		rightHindClaw = rightHindClaw,
		tailBase = tailBase,
		tailTip = tailTip,
		spineSpikes = spineSpikes,
		tailSpikes = tailSpikes,
		leftHorn = leftHorn,
		rightHorn = rightHorn,
		leftEye = leftEye,
		rightEye = rightEye,
		mouthAttachment = mouthAttachment,
		fireEmitter = fireEmitter,
		smokeEmitter = smokeEmitter,
		emberEmitter = emberEmitter,
		mouthLight = mouthLight,
		fireBeam = nil,
		center = center,
		orbitAngle = orbitAngle,
		orbitRadius = orbitRadius,
		orbitSpeed = rng:NextNumber(0.12, 0.18),
		altitude = altitude,
		flapPhase = rng:NextNumber(0, math.pi * 2),
		flapSpeed = rng:NextNumber(3.4, 4.8),
		tailPhase = rng:NextNumber(0, math.pi * 2),
		pitchBobPhase = rng:NextNumber(0, math.pi * 2),
		isBreathingFire = false,
		fireCooldown = rng:NextNumber(1.2, 2.8),
		fireDuration = 0,
		fireTick = 0,
		fireTarget = nil,
		fireRetarget = 0,
	}

	syncDragonVisual(agent)
	return agent
end

local function updateDragon(agent: DragonAgent, dt: number)
	agent.orbitAngle += dt * agent.orbitSpeed
	agent.flapPhase += dt * agent.flapSpeed
	agent.tailPhase += dt * 2.05
	agent.pitchBobPhase += dt * 1.35

	local bobY = math.sin(agent.pitchBobPhase * 0.82) * 4.8
	local x = math.cos(agent.orbitAngle) * agent.orbitRadius
	local z = math.sin(agent.orbitAngle) * agent.orbitRadius
	local nextPos = agent.center + Vector3.new(x, agent.altitude + bobY, z)

	local lookAngle = agent.orbitAngle + 0.16
	local lookX = math.cos(lookAngle) * agent.orbitRadius
	local lookZ = math.sin(lookAngle) * agent.orbitRadius
	local lookPos = agent.center + Vector3.new(lookX, agent.altitude + bobY * 0.85 - 2.5, lookZ)

	local desired = CFrame.lookAt(nextPos, lookPos, Vector3.yAxis)
	agent.root.CFrame = agent.root.CFrame:Lerp(desired, math.clamp(dt * 2.8, 0, 1))

	syncDragonVisual(agent)
	updateDragonFireBreath(agent, dt)
end

local function stopDragonSystem()
	if dragonHeartbeatConnection then
		dragonHeartbeatConnection:Disconnect()
		dragonHeartbeatConnection = nil
	end

	if dragonAgent then
		stopDragonFireBreath(dragonAgent)
		if dragonAgent.model.Parent then
			dragonAgent.model:Destroy()
		end
		dragonAgent = nil
	end
end

local function startDragonSystem(parent: Folder, spawnPos: Vector3)
	stopDragonSystem()

	local dragonFolder = Instance.new("Folder")
	dragonFolder.Name = "Dragon"
	dragonFolder.Parent = parent

	local agent = createDragon(dragonFolder, spawnPos)
	dragonAgent = agent
	dragonHeartbeatConnection = RunService.Heartbeat:Connect(function(dt: number)
		updateDragon(agent, math.clamp(dt, 1 / 240, 1 / 20))
	end)
end

local function createDestructibleTrees(parent: Folder, spawnPos: Vector3)
	for _ = 1, treeCount do
		local basePos = Vector3.new(rng:NextNumber(-260, 260), 3, rng:NextNumber(-260, 260))
		if not isNearSpawn(basePos, spawnPos, 34) then
			local trunkHeight = rng:NextNumber(11, 24)
			local trunkRadius = rng:NextNumber(1.1, 1.9)
			local tilt = CFrame.Angles(math.rad(rng:NextNumber(-4, 4)), math.rad(rng:NextNumber(0, 360)), math.rad(rng:NextNumber(-4, 4)))
			local trunk = createDecorPart(
				parent,
				"TreeTrunk",
				Vector3.new(trunkRadius, trunkHeight, trunkRadius),
				CFrame.new(basePos + Vector3.new(0, trunkHeight * 0.5, 0)) * tilt,
				Color3.fromRGB(rng:NextInteger(58, 79), rng:NextInteger(44, 60), rng:NextInteger(28, 43)),
				Enum.Material.Wood,
				true
			)

			local canopyCount = rng:NextInteger(5, 9)
			for _ = 1, canopyCount do
				local canopySize = rng:NextNumber(3.8, 8.4)
				local offset = Vector3.new(
					rng:NextNumber(-2.2, 2.2),
					trunkHeight * rng:NextNumber(0.66, 1.05),
					rng:NextNumber(-2.2, 2.2)
				)
				createDecorPart(
					parent,
					"TreeCanopy",
					Vector3.new(canopySize, canopySize * rng:NextNumber(0.65, 0.95), canopySize),
					trunk.CFrame * CFrame.new(offset) * CFrame.Angles(0, math.rad(rng:NextNumber(0, 360)), 0),
					Color3.fromRGB(
						rng:NextInteger(44, 74),
						rng:NextInteger(74, 114),
						rng:NextInteger(42, 68)
					),
					Enum.Material.Grass,
					false
				)
			end
		end
	end
end

local function createDestructibleShrubs(parent: Folder, spawnPos: Vector3)
	for _ = 1, shrubCount do
		local basePos = Vector3.new(rng:NextNumber(-270, 270), 3, rng:NextNumber(-270, 270))
		if not isNearSpawn(basePos, spawnPos, 16) then
			local center = createDecorPart(
				parent,
				"ShrubCore",
				Vector3.new(rng:NextNumber(1.2, 2.6), rng:NextNumber(0.7, 1.4), rng:NextNumber(1.2, 2.6)),
				CFrame.new(basePos + Vector3.new(0, rng:NextNumber(0.35, 0.7), 0)),
				Color3.fromRGB(
					rng:NextInteger(42, 72),
					rng:NextInteger(86, 126),
					rng:NextInteger(42, 68)
				),
				Enum.Material.Grass,
				false
			)

			local leafCount = rng:NextInteger(3, 6)
			for _ = 1, leafCount do
				local radius = rng:NextNumber(0.6, 1.5)
				local angle = rng:NextNumber(0, math.pi * 2)
				createDecorPart(
					parent,
					"ShrubLeaf",
					Vector3.new(rng:NextNumber(0.6, 1.6), rng:NextNumber(0.4, 1.0), rng:NextNumber(0.6, 1.6)),
					center.CFrame
						* CFrame.new(math.cos(angle) * radius, rng:NextNumber(0.2, 0.9), math.sin(angle) * radius)
						* CFrame.Angles(0, math.rad(rng:NextNumber(0, 360)), 0),
					Color3.fromRGB(
						rng:NextInteger(46, 76),
						rng:NextInteger(82, 122),
						rng:NextInteger(42, 70)
					),
					Enum.Material.Grass,
					false
				)
			end
		end
	end
end

local function createGroundVegetation(parent: Folder, spawnPos: Vector3)
	for _ = 1, grassPatchCount do
		local patchPos = Vector3.new(rng:NextNumber(-285, 285), 3, rng:NextNumber(-285, 285))
		if not isNearSpawn(patchPos, spawnPos, 18) then
			local bladeCount = rng:NextInteger(5, 9)
			local patchRadius = rng:NextNumber(1.4, 3.4)

			for _ = 1, bladeCount do
				local blade = Instance.new("Part")
				local height = rng:NextNumber(0.9, 2.2)
				local radius = rng:NextNumber(0.05, 0.13)
				local angle = rng:NextNumber(0, math.pi * 2)
				local offsetRadius = rng:NextNumber(0, patchRadius)
				local pos = patchPos + Vector3.new(math.cos(angle) * offsetRadius, height * 0.5, math.sin(angle) * offsetRadius)
				blade.Name = "GrassBlade"
				blade.Size = Vector3.new(radius, height, radius)
				blade.Anchored = true
				blade.CanCollide = false
				blade.Material = Enum.Material.Grass
				blade.Color = Color3.fromRGB(
					rng:NextInteger(46, 74),
					rng:NextInteger(82, 120),
					rng:NextInteger(42, 62)
				)
				blade.CFrame = CFrame.new(pos)
					* CFrame.Angles(
						math.rad(rng:NextNumber(-12, 12)),
						math.rad(rng:NextNumber(0, 360)),
						math.rad(rng:NextNumber(-12, 12))
					)
				blade:SetAttribute(destructibleAttribute, true)
				blade.Parent = parent
			end
		end
	end
end

local function createGroundOverlays(parent: Folder, spawnPos: Vector3)
	for _ = 1, 140 do
		local basePos = Vector3.new(rng:NextNumber(-300, 300), 3.04, rng:NextNumber(-300, 300))
		if not isNearSpawn(basePos, spawnPos, 14) then
			local patch = Instance.new("Part")
			patch.Name = "GroundOverlay"
			patch.Size = Vector3.new(rng:NextNumber(5.5, 20), 0.05, rng:NextNumber(3.8, 16))
			patch.Anchored = true
			patch.CanCollide = false
			patch.Material = if rng:NextNumber() > 0.5 then Enum.Material.Asphalt else Enum.Material.Concrete
			patch.Color = if patch.Material == Enum.Material.Asphalt
				then Color3.fromRGB(rng:NextInteger(43, 60), rng:NextInteger(45, 63), rng:NextInteger(44, 60))
				else Color3.fromRGB(rng:NextInteger(66, 84), rng:NextInteger(69, 88), rng:NextInteger(65, 82))
			patch.CFrame = CFrame.new(basePos)
				* CFrame.Angles(0, math.rad(rng:NextNumber(0, 360)), math.rad(rng:NextNumber(-2.5, 2.5)))
			patch:SetAttribute(destructibleAttribute, true)
			patch.Parent = parent
		end
	end

	for _ = 1, 65 do
		local basePos = Vector3.new(rng:NextNumber(-280, 280), 3.03, rng:NextNumber(-280, 280))
		if not isNearSpawn(basePos, spawnPos, 16) then
			local puddle = Instance.new("Part")
			puddle.Name = "WetPuddle"
			puddle.Size = Vector3.new(rng:NextNumber(2, 8.4), 0.03, rng:NextNumber(1.6, 7.2))
			puddle.Anchored = true
			puddle.CanCollide = false
			puddle.Material = Enum.Material.Glass
			puddle.Transparency = rng:NextNumber(0.72, 0.84)
			puddle.Reflectance = rng:NextNumber(0.06, 0.12)
			puddle.Color = Color3.fromRGB(rng:NextInteger(76, 92), rng:NextInteger(89, 106), rng:NextInteger(92, 112))
			puddle.CFrame = CFrame.new(basePos) * CFrame.Angles(0, math.rad(rng:NextNumber(0, 360)), 0)
			puddle:SetAttribute(destructibleAttribute, true)
			puddle.Parent = parent
		end
	end
end

local function createDestructibleMountains(parent: Folder, spawnPos: Vector3)
	for i = 1, 18 do
		local angle = (i / 18) * math.pi * 2 + rng:NextNumber(-0.16, 0.16)
		local radius = rng:NextNumber(150, 290)
		local pos = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		if not isNearSpawn(pos, spawnPos, 56) then
			local baseWidth = rng:NextNumber(20, 54)
			local height = rng:NextNumber(24, 96)
			local depth = rng:NextNumber(20, 54)
			createDecorPart(
				parent,
				"MountainBlock",
				Vector3.new(baseWidth, height, depth),
				CFrame.new(pos + Vector3.new(0, height * 0.5 + 2, 0))
					* CFrame.Angles(
						math.rad(rng:NextNumber(-7, 7)),
						math.rad(rng:NextNumber(0, 360)),
						math.rad(rng:NextNumber(-7, 7))
					),
				Color3.fromRGB(
					rng:NextInteger(72, 98),
					rng:NextInteger(76, 104),
					rng:NextInteger(70, 94)
				),
				Enum.Material.Slate,
				true
			)
		end
	end
end

local function createDebrisScatter(parent: Folder)
	for _ = 1, 70 do
		local debris = Instance.new("Part")
		debris.Name = "GroundDebris"
		debris.Size = Vector3.new(rng:NextNumber(1.2, 4.8), rng:NextNumber(0.08, 0.22), rng:NextNumber(1.1, 4.5))
		debris.Anchored = true
		debris.CanCollide = false
		debris.Material = if rng:NextNumber() > 0.4 then Enum.Material.Concrete else Enum.Material.Metal
		debris.Color = if debris.Material == Enum.Material.Metal
			then Color3.fromRGB(96, 82, 64)
			else Color3.fromRGB(86, 82, 74)
		local x = rng:NextNumber(-230, 230)
		local z = rng:NextNumber(-230, 230)
		debris.CFrame = CFrame.new(x, 3.05, z)
			* CFrame.Angles(math.rad(rng:NextNumber(-4, 4)), math.rad(rng:NextNumber(0, 360)), math.rad(rng:NextNumber(-4, 4)))
		debris:SetAttribute(destructibleAttribute, true)
		debris.Parent = parent
	end
end

local function createCitySilhouette(parent: Folder)
	for i = 1, 28 do
		local angle = (i / 28) * math.pi * 2
		local radius = rng:NextNumber(290, 360)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local h = rng:NextNumber(55, 170)
		local building = Instance.new("Part")
		building.Name = "SkylineTower"
		building.Size = Vector3.new(rng:NextNumber(16, 40), h, rng:NextNumber(16, 40))
		building.Position = Vector3.new(x, h * 0.5, z)
		building.Anchored = true
		building.CanCollide = false
		building.Material = Enum.Material.Concrete
		building.Color = Color3.fromRGB(
			rng:NextInteger(55, 72),
			rng:NextInteger(60, 78),
			rng:NextInteger(62, 86)
		)
		building.Parent = parent
	end
end

local function createRedMoon(parent: Folder, spawnPos: Vector3)
	local moonDirection = Vector3.new(0.2, 0, -0.98).Unit
	local moonCenter = spawnPos + moonDirection * redMoonDistance + Vector3.new(0, redMoonAltitude, 0)

	local moonCore = Instance.new("Part")
	moonCore.Name = "RedMoon"
	moonCore.Shape = Enum.PartType.Ball
	moonCore.Size = Vector3.new(redMoonSize, redMoonSize, redMoonSize)
	moonCore.Position = moonCenter
	moonCore.Anchored = true
	moonCore.CanCollide = false
	moonCore.CastShadow = false
	moonCore.Material = Enum.Material.Neon
	moonCore.Color = Color3.fromRGB(224, 40, 36)
	moonCore.Transparency = 0.08
	moonCore.Parent = parent

	local moonAura = Instance.new("Part")
	moonAura.Name = "RedMoonAura"
	moonAura.Shape = Enum.PartType.Ball
	moonAura.Size = Vector3.new(redMoonSize * 1.42, redMoonSize * 1.42, redMoonSize * 1.42)
	moonAura.Position = moonCenter
	moonAura.Anchored = true
	moonAura.CanCollide = false
	moonAura.CastShadow = false
	moonAura.Material = Enum.Material.Neon
	moonAura.Color = Color3.fromRGB(255, 66, 60)
	moonAura.Transparency = 0.89
	moonAura.Parent = parent

	local moonHalo = Instance.new("Part")
	moonHalo.Name = "RedMoonHalo"
	moonHalo.Shape = Enum.PartType.Cylinder
	moonHalo.Size = Vector3.new(1.5, redMoonSize * 1.86, redMoonSize * 1.86)
	moonHalo.Anchored = true
	moonHalo.CanCollide = false
	moonHalo.CastShadow = false
	moonHalo.Material = Enum.Material.Neon
	moonHalo.Color = Color3.fromRGB(220, 60, 56)
	moonHalo.Transparency = 0.9
	moonHalo.CFrame = CFrame.new(moonCenter) * CFrame.Angles(math.rad(90), 0, math.rad(14))
	moonHalo.Parent = parent

	local moonLight = Instance.new("PointLight")
	moonLight.Name = "RedMoonLight"
	moonLight.Brightness = 2.4
	moonLight.Range = 340
	moonLight.Color = Color3.fromRGB(255, 74, 60)
	moonLight.Shadows = false
	moonLight.Parent = moonCore
end

local function createSpawnVisual(spawn: SpawnLocation, parent: Folder)
	local slab = Instance.new("Part")
	slab.Name = "SpawnSlab"
	slab.Size = Vector3.new(13, 1, 13)
	slab.Position = spawn.Position - Vector3.new(0, 0.5, 0)
	slab.Anchored = true
	slab.Material = Enum.Material.Concrete
	slab.Color = Color3.fromRGB(126, 125, 116)
	slab.Parent = parent

	createFernClump(slab.Position + Vector3.new(0, 0.52, 0), parent, 22)
	for _ = 1, 5 do
		local plate = Instance.new("Part")
		plate.Name = "SpawnScrap"
		plate.Size = Vector3.new(rng:NextNumber(1.5, 3.5), 0.12, rng:NextNumber(1, 2.6))
		plate.Anchored = true
		plate.CanCollide = false
		plate.Material = Enum.Material.Metal
		plate.Color = Color3.fromRGB(97, 77, 61)
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(4.8, 8.5)
		local pos = slab.Position + Vector3.new(math.cos(angle) * distance, 0.58, math.sin(angle) * distance)
		plate.CFrame = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-8, 8)))
		plate.Parent = parent
	end
end

function WorldService.Start()
	stopBirdSystem()
	stopDragonSystem()

	-- Critical gameplay floor/spawn must exist even if style generation fails.
	ensureGround()
	local spawn = ensureSpawn()
	local decor = ensureDecorFolder()

	local atmosphereOk, atmosphereError = pcall(ensureAtmosphere)
	if not atmosphereOk then
		warn(("[WorldService] Atmosphere setup failed: %s"):format(tostring(atmosphereError)))
	end

	local artOk, artError = pcall(function()
		createSpawnVisual(spawn, decor)

		createRuinBlock("Ruins_A", Vector3.new(28, 16, 10), Vector3.new(38, 8, 24), Color3.fromRGB(102, 106, 101), decor)
		createRuinBlock("Ruins_B", Vector3.new(18, 11, 22), Vector3.new(-34, 5.5, -22), Color3.fromRGB(110, 114, 108), decor)
		createRuinBlock("Ruins_C", Vector3.new(24, 13, 12), Vector3.new(20, 6.5, -39), Color3.fromRGB(93, 98, 91), decor)
		createRuinBlock("Ruins_D", Vector3.new(14, 9, 14), Vector3.new(-62, 4.5, 34), Color3.fromRGB(100, 104, 98), decor)
		createDestructibleMountains(decor, spawn.Position)
		createDestructibleTrees(decor, spawn.Position)
		createDestructibleShrubs(decor, spawn.Position)
		createGroundVegetation(decor, spawn.Position)
		createGroundOverlays(decor, spawn.Position)

		createDebrisScatter(decor)
		createCitySilhouette(decor)
	end)

	if not artOk then
		warn(("[WorldService] Decor generation failed: %s"):format(tostring(artError)))
		-- Fallback ruins so gameplay space always exists.
		createSafeFallbackBlock("Ruins_A", Vector3.new(24, 20, 8), Vector3.new(35, 10, 20), Color3.fromRGB(82, 84, 79))
		createSafeFallbackBlock("Ruins_B", Vector3.new(12, 12, 18), Vector3.new(-28, 6, -24), Color3.fromRGB(91, 93, 87))
		createSafeFallbackBlock("Ruins_C", Vector3.new(20, 14, 10), Vector3.new(18, 7, -35), Color3.fromRGB(72, 74, 68))
	end

	local birdsOk, birdsError = pcall(function()
		startBirdSystem(decor, spawn.Position)
	end)
	if not birdsOk then
		warn(("[WorldService] Bird system failed: %s"):format(tostring(birdsError)))
	end

	local dragonOk, dragonError = pcall(function()
		startDragonSystem(decor, spawn.Position)
	end)
	if not dragonOk then
		warn(("[WorldService] Dragon system failed: %s"):format(tostring(dragonError)))
	end

	local moonOk, moonError = pcall(function()
		createRedMoon(decor, spawn.Position)
	end)
	if not moonOk then
		warn(("[WorldService] Red moon setup failed: %s"):format(tostring(moonError)))
	end
end

return WorldService
