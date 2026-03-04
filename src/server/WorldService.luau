--!strict

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local WorldService = {}

local decorFolderName = "WorldArt"
local destructibleAttribute = "DestructibleByGrenade"
local rng = Random.new(70421)

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
	ground.Material = Enum.Material.Asphalt
	ground.Color = Color3.fromRGB(54, 58, 54)
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
	Lighting.ClockTime = 16.8
	Lighting.Brightness = 1.7
	Lighting.ExposureCompensation = -0.1
	Lighting.Ambient = Color3.fromRGB(74, 79, 73)
	Lighting.OutdoorAmbient = Color3.fromRGB(96, 103, 94)
	Lighting.EnvironmentDiffuseScale = 0.45
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.FogColor = Color3.fromRGB(109, 123, 116)
	Lighting.FogStart = 80
	Lighting.FogEnd = 520

	local atmosphere = Lighting:FindFirstChild("WorldAtmosphere")
	if not atmosphere or not atmosphere:IsA("Atmosphere") then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "WorldAtmosphere"
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.39
	atmosphere.Offset = -0.15
	atmosphere.Color = Color3.fromRGB(126, 138, 129)
	atmosphere.Decay = Color3.fromRGB(74, 88, 76)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.8

	local grade = Lighting:FindFirstChild("WorldColorGrade")
	if not grade or not grade:IsA("ColorCorrectionEffect") then
		grade = Instance.new("ColorCorrectionEffect")
		grade.Name = "WorldColorGrade"
		grade.Parent = Lighting
	end
	grade.Brightness = -0.02
	grade.Contrast = 0.09
	grade.Saturation = -0.24
	grade.TintColor = Color3.fromRGB(222, 233, 220)

	local bloom = Lighting:FindFirstChild("WorldBloom")
	if not bloom or not bloom:IsA("BloomEffect") then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "WorldBloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.35
	bloom.Size = 20
	bloom.Threshold = 1.1

	local clouds = Workspace.Terrain:FindFirstChild("WorldClouds")
	if not clouds or not clouds:IsA("Clouds") then
		clouds = Instance.new("Clouds")
		clouds.Name = "WorldClouds"
		clouds.Parent = Workspace.Terrain
	end
	clouds.Cover = 0.76
	clouds.Density = 0.44
	clouds.Color = Color3.fromRGB(180, 186, 182)
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

local function createMossPatch(anchor: BasePart, offset: Vector3, size: Vector3, parent: Folder)
	local patch = Instance.new("Part")
	patch.Name = "MossPatch"
	patch.Size = size
	patch.Anchored = true
	patch.CanCollide = false
	patch.Material = Enum.Material.Grass
	patch.Color = Color3.fromRGB(
		rng:NextInteger(56, 72),
		rng:NextInteger(82, 104),
		rng:NextInteger(49, 64)
	)
	patch.CFrame = anchor.CFrame
		* CFrame.new(offset)
		* CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), rng:NextNumber(0, math.pi * 2), 0)
	patch.Parent = parent
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
			rng:NextInteger(52, 76),
			rng:NextInteger(88, 122),
			rng:NextInteger(44, 62)
		)
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(0, 2.2)
		local basePos = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		leaf.CFrame = CFrame.new(basePos + Vector3.new(0, height * 0.5, 0))
			* CFrame.Angles(math.rad(rng:NextNumber(12, 46)), angle, math.rad(rng:NextNumber(-8, 8)))
		leaf.Parent = parent
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

	createFernClump(position + Vector3.new(0, -size.Y * 0.5, 0), parent, rng:NextInteger(8, 16))
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

local function createSpawnVisual(spawn: SpawnLocation, parent: Folder)
	local slab = Instance.new("Part")
	slab.Name = "SpawnSlab"
	slab.Size = Vector3.new(13, 1, 13)
	slab.Position = spawn.Position - Vector3.new(0, 0.5, 0)
	slab.Anchored = true
	slab.Material = Enum.Material.Concrete
	slab.Color = Color3.fromRGB(126, 125, 116)
	slab.Parent = parent

	createFernClump(slab.Position + Vector3.new(0, 0.52, 0), parent, 14)
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

		createRuinBlock("Ruins_A", Vector3.new(28, 16, 10), Vector3.new(38, 8, 24), Color3.fromRGB(85, 87, 82), decor)
		createRuinBlock("Ruins_B", Vector3.new(18, 11, 22), Vector3.new(-34, 5.5, -22), Color3.fromRGB(96, 98, 91), decor)
		createRuinBlock("Ruins_C", Vector3.new(24, 13, 12), Vector3.new(20, 6.5, -39), Color3.fromRGB(74, 78, 71), decor)
		createRuinBlock("Ruins_D", Vector3.new(14, 9, 14), Vector3.new(-62, 4.5, 34), Color3.fromRGB(84, 86, 80), decor)

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
end

return WorldService
