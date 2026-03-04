--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))

local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))

local LootService = {}

local rootFolderName = "ScavengeNodes"
local medkitFolderName = "Medkits"
local playerSpawnName = "StartSpawn"
local scavengeResultEvent: RemoteEvent
local medkitPickupEvent: RemoteEvent

local rng = Random.new()

local function ensureRootFolder(): Folder
	local existing = Workspace:FindFirstChild(rootFolderName)
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = rootFolderName
	folder.Parent = Workspace
	return folder
end

local function ensureMedkitFolder(): Folder
	local existing = Workspace:FindFirstChild(medkitFolderName)
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = medkitFolderName
	folder.Parent = Workspace
	return folder
end

local function randomNodePosition(index: number): Vector3
	local xBand = (index % 4) * 20 - 30
	local zBand = math.floor(index / 4) * 20 - 20
	local x = xBand + rng:NextNumber(-5, 5)
	local z = zBand + rng:NextNumber(-5, 5)
	return Vector3.new(x, 3, z)
end

local function getSpawnPosition(): Vector3
	local spawn = Workspace:FindFirstChild(playerSpawnName)
	if spawn and spawn:IsA("BasePart") then
		return spawn.Position
	end
	return Vector3.new(0, 6, 0)
end

local function randomMedkitPosition(): Vector3
	local center = getSpawnPosition()
	local minDistance = 60
	local maxDistance = 250
	local angle = rng:NextNumber(0, math.pi * 2)
	local distance = rng:NextNumber(minDistance, maxDistance)
	return center + Vector3.new(math.cos(angle) * distance, 3, math.sin(angle) * distance)
end

local function setNodeActive(node: Part, active: boolean)
	node:SetAttribute("Active", active)
	node.Transparency = if active then 0 else 0.9
	node.CanCollide = active
	local prompt = node:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = active
	end
end

local function setMedkitActive(medkit: Part, active: boolean)
	medkit:SetAttribute("Active", active)
	medkit.CanTouch = active
	medkit.Transparency = if active then 0 else 1
end

local function onPromptTriggered(player: Player, node: Part)
	local active = node:GetAttribute("Active")
	if active ~= true then
		return
	end

	setNodeActive(node, false)
	local amount = rng:NextInteger(GameConfig.Loot.ScrapMin, GameConfig.Loot.ScrapMax)
	PlayerStateService.AddScrap(player, amount)
	scavengeResultEvent:FireClient(player, {
		ok = true,
		amount = amount,
	})

	task.delay(GameConfig.Loot.RespawnSeconds, function()
		if node.Parent then
			setNodeActive(node, true)
		end
	end)
end

local function getTouchedPlayer(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	return Players:GetPlayerFromCharacter(model)
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function onMedkitTouched(medkit: Part, hit: BasePart)
	local active = medkit:GetAttribute("Active")
	if active ~= true then
		return
	end

	local player = getTouchedPlayer(hit)
	if not player then
		return
	end

	local humanoid = getHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	if humanoid.Health >= humanoid.MaxHealth then
		return
	end

	setMedkitActive(medkit, false)
	local healAmount = GameConfig.Loot.MedkitHealAmount
	local healedTo = math.min(humanoid.MaxHealth, humanoid.Health + healAmount)
	local restored = math.floor((healedTo - humanoid.Health) + 0.5)
	humanoid.Health = healedTo

	medkitPickupEvent:FireClient(player, {
		ok = true,
		amount = restored,
	})

	task.delay(GameConfig.Loot.MedkitRespawnSeconds, function()
		if medkit.Parent then
			medkit.Position = randomMedkitPosition()
			setMedkitActive(medkit, true)
		end
	end)
end

local function createNode(index: number, parent: Folder)
	local node = Instance.new("Part")
	node.Name = ("SupplyCrate_%d"):format(index)
	node.Size = Vector3.new(3, 2, 3)
	node.Position = randomNodePosition(index)
	node.Anchored = true
	node.Material = Enum.Material.WoodPlanks
	node.Color = Color3.fromRGB(82, 67, 54)
	node.Parent = parent

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ScavengePrompt"
	prompt.ActionText = "Scavenge"
	prompt.ObjectText = "Supply Crate"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0.7
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = node

	prompt.Triggered:Connect(function(player: Player)
		onPromptTriggered(player, node)
	end)

	setNodeActive(node, true)
end

local function createMedkit(index: number, parent: Folder)
	local medkit = Instance.new("Part")
	medkit.Name = ("Medkit_%d"):format(index)
	medkit.Size = Vector3.new(1.8, 0.8, 1.8)
	medkit.Position = randomMedkitPosition()
	medkit.Anchored = true
	medkit.CanCollide = false
	medkit.Material = Enum.Material.SmoothPlastic
	medkit.Color = Color3.fromRGB(235, 235, 235)
	medkit.Parent = parent

	local crossV = Instance.new("Part")
	crossV.Name = "CrossV"
	crossV.Size = Vector3.new(0.3, 0.85, 0.05)
	crossV.Anchored = true
	crossV.CanCollide = false
	crossV.Material = Enum.Material.Neon
	crossV.Color = Color3.fromRGB(208, 38, 38)
	crossV.CFrame = medkit.CFrame * CFrame.new(0, 0.41, 0)
	crossV.Parent = medkit

	local crossH = Instance.new("Part")
	crossH.Name = "CrossH"
	crossH.Size = Vector3.new(0.85, 0.3, 0.05)
	crossH.Anchored = true
	crossH.CanCollide = false
	crossH.Material = Enum.Material.Neon
	crossH.Color = Color3.fromRGB(208, 38, 38)
	crossH.CFrame = medkit.CFrame * CFrame.new(0, 0.41, 0)
	crossH.Parent = medkit

	medkit:GetPropertyChangedSignal("CFrame"):Connect(function()
		crossV.CFrame = medkit.CFrame * CFrame.new(0, 0.41, 0)
		crossH.CFrame = medkit.CFrame * CFrame.new(0, 0.41, 0)
	end)

	medkit.Touched:Connect(function(hit: BasePart)
		onMedkitTouched(medkit, hit)
	end)

	setMedkitActive(medkit, true)
end

function LootService.Start(netFolder: Folder)
	scavengeResultEvent = netFolder:WaitForChild(Net.Events.ScavengeResult) :: RemoteEvent
	medkitPickupEvent = netFolder:WaitForChild(Net.Events.MedkitPickup) :: RemoteEvent
	local root = ensureRootFolder()
	local medkitRoot = ensureMedkitFolder()

	if #root:GetChildren() == 0 then
		for i = 1, GameConfig.Loot.NodeCount do
			createNode(i, root)
		end
	end

	if #medkitRoot:GetChildren() == 0 then
		for i = 1, GameConfig.Loot.MedkitCount do
			createMedkit(i, medkitRoot)
		end
	end
end

return LootService
