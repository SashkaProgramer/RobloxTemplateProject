--!strict

local Workspace = game:GetService("Workspace")

local WorldService = {}
local destructibleAttribute = "DestructibleByGrenade"

local function ensureGround()
	local existing = Workspace:FindFirstChild("Ground")
	if existing and existing:IsA("Part") then
		return
	end

	local ground = Instance.new("Part")
	ground.Name = "Ground"
	ground.Size = Vector3.new(600, 8, 600)
	ground.Position = Vector3.new(0, 0, 0)
	ground.Anchored = true
	ground.Material = Enum.Material.Slate
	ground.Color = Color3.fromRGB(53, 58, 52)
	ground.Parent = Workspace
end

local function ensureSpawn()
	local existing = Workspace:FindFirstChild("StartSpawn")
	if existing and existing:IsA("SpawnLocation") then
		return
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "StartSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 6, 0)
	spawn.Anchored = true
	spawn.Material = Enum.Material.Concrete
	spawn.Color = Color3.fromRGB(126, 126, 126)
	spawn.Neutral = true
	spawn.Parent = Workspace
end

local function createBlock(name: string, size: Vector3, position: Vector3, color: Color3)
	local existing = Workspace:FindFirstChild(name)
	if existing and existing:IsA("Part") then
		existing:SetAttribute(destructibleAttribute, true)
		return
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

function WorldService.Start()
	ensureGround()
	ensureSpawn()

	createBlock("Ruins_A", Vector3.new(24, 20, 8), Vector3.new(35, 10, 20), Color3.fromRGB(82, 84, 79))
	createBlock("Ruins_B", Vector3.new(12, 12, 18), Vector3.new(-28, 6, -24), Color3.fromRGB(91, 93, 87))
	createBlock("Ruins_C", Vector3.new(20, 14, 10), Vector3.new(18, 7, -35), Color3.fromRGB(72, 74, 68))
end

return WorldService
