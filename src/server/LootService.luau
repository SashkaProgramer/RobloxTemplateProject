--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local LootDefs = require(Shared:WaitForChild("LootDefs"))
local Net = require(Shared:WaitForChild("Net"))

local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))
local RoundService = require(script.Parent:WaitForChild("RoundService"))

local LootService = {}

local rootFolderName = "ScavengeNodes"
local medkitFolderName = "Medkits"
local roundLootFolderName = "RoundLoot"
local playerSpawnName = "StartSpawn"
local scavengeResultEvent: RemoteEvent
local medkitPickupEvent: RemoteEvent
local requestPickupLootEvent: RemoteEvent
local requestDropLootEvent: RemoteEvent
local requestUseItemEvent: RemoteEvent

local rng = Random.new()
local nextLootInstanceId = 0

local function getRoundLootFolder(): Folder
	local existing = Workspace:FindFirstChild(roundLootFolderName)
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = roundLootFolderName
	folder.Parent = Workspace
	return folder
end

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

local function canPlayerInteractWithRoundLoot(player: Player, lootPart: BasePart): boolean
	local roundState = PlayerStateService.GetRoundState(player)
	if not roundState or not roundState.alive or roundState.extracted then
		return false
	end

	local currentPhase = RoundService.GetCurrentPhase()
	if currentPhase == "Lobby" or currentPhase == "Resolved" then
		return false
	end

	local root = getCharacterRoot(player)
	if not root then
		return false
	end

	return (root.Position - lootPart.Position).Magnitude <= 12
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

local function makeRoundLootPosition(index: number): Vector3
	local spawn = getSpawnPosition()
	local laneOffset = ((index - 1) % 6) * 8 - 20
	local rowOffset = math.floor((index - 1) / 6) * 12 + 18
	return spawn + Vector3.new(laneOffset, 2.5, -rowOffset)
end

local function createRoundLootPart(lootId: string, position: Vector3, parent: Folder)
	local lootDef = LootDefs.getById(lootId)
	if not lootDef then
		return
	end

	nextLootInstanceId += 1

	local lootPart = Instance.new("Part")
	lootPart.Name = ("Loot_%s_%d"):format(lootId, nextLootInstanceId)
	lootPart.Size = Vector3.new(1.6, 1.2, 1.6)
	lootPart.Position = position
	lootPart.Anchored = true
	lootPart.CanCollide = false
	lootPart.Material = if lootDef.rarity == LootDefs.Rarities.Rare
		then Enum.Material.Neon
		else Enum.Material.SmoothPlastic
	lootPart.Color = if lootDef.rarity == LootDefs.Rarities.Rare
		then Color3.fromRGB(235, 196, 82)
		elseif lootDef.rarity == LootDefs.Rarities.Uncommon
		then Color3.fromRGB(112, 181, 225)
		else Color3.fromRGB(166, 166, 166)
	lootPart:SetAttribute("LootId", lootId)
	lootPart:SetAttribute("LootInstanceId", nextLootInstanceId)
	lootPart.Parent = parent

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	prompt.ActionText = "Pick Up"
	prompt.ObjectText = lootDef.name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0.15
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = lootPart

	prompt.Triggered:Connect(function(player: Player)
		if not canPlayerInteractWithRoundLoot(player, lootPart) then
			return
		end

		local itemLootId = lootPart:GetAttribute("LootId")
		if typeof(itemLootId) ~= "string" then
			return
		end

		if PlayerStateService.AddInventoryItem(player, itemLootId) then
			lootPart:Destroy()
		end
	end)
end

local function ensureRoundLoot()
	local roundLootFolder = getRoundLootFolder()
	if #roundLootFolder:GetChildren() > 0 then
		return
	end

	local seededLootIds = {
		"scrap_bundle",
		"copper_wires",
		"service_watch",
		"sealed_med_case",
		"fuse",
		"cursed_idol",
	}

	for index, lootId in seededLootIds do
		createRoundLootPart(lootId, makeRoundLootPosition(index), roundLootFolder)
	end
end

local function findLootPartByInstanceId(lootInstanceId: number): BasePart?
	local roundLootFolder = getRoundLootFolder()
	for _, child in roundLootFolder:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("LootInstanceId") == lootInstanceId then
			return child
		end
	end

	return nil
end

local function dropLootAtPlayer(player: Player, lootId: string): boolean
	local root = getCharacterRoot(player)
	if not root then
		return false
	end

	local roundLootFolder = getRoundLootFolder()
	createRoundLootPart(lootId, root.Position + root.CFrame.LookVector * 3 + Vector3.new(0, 0.5, 0), roundLootFolder)
	return true
end

local function onRequestPickupLoot(player: Player, payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	local lootInstanceId = payload.lootInstanceId
	if typeof(lootInstanceId) ~= "number" then
		return
	end

	local lootPart = findLootPartByInstanceId(lootInstanceId)
	if not lootPart then
		return
	end

	if not canPlayerInteractWithRoundLoot(player, lootPart) then
		return
	end

	local lootId = lootPart:GetAttribute("LootId")
	if typeof(lootId) ~= "string" then
		return
	end

	if PlayerStateService.AddInventoryItem(player, lootId) then
		lootPart:Destroy()
	end
end

local function onRequestDropLoot(player: Player, payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	local lootId = payload.lootId
	if typeof(lootId) ~= "string" then
		return
	end

	if PlayerStateService.RemoveInventoryItem(player, lootId) then
		dropLootAtPlayer(player, lootId)
	end
end

local function onRequestUseItem(player: Player, payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	local lootId = payload.lootId
	if typeof(lootId) ~= "string" then
		return
	end

	if not PlayerStateService.RemoveInventoryItem(player, lootId) then
		return
	end

	local humanoid = getHumanoid(player)
	if lootId == "sealed_med_case" and humanoid and humanoid.Health > 0 then
		local healedTo = math.min(humanoid.MaxHealth, humanoid.Health + 45)
		humanoid.Health = healedTo
		return
	end

	if lootId == "fuse" then
		PlayerStateService.SetTemporaryFlag(player, "HasUsedFuse", true)
		return
	end

	PlayerStateService.AddInventoryItem(player, lootId)
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
	requestPickupLootEvent = netFolder:WaitForChild(Net.Events.RequestPickupLoot) :: RemoteEvent
	requestDropLootEvent = netFolder:WaitForChild(Net.Events.RequestDropLoot) :: RemoteEvent
	requestUseItemEvent = netFolder:WaitForChild(Net.Events.RequestUseItem) :: RemoteEvent

	requestPickupLootEvent.OnServerEvent:Connect(onRequestPickupLoot)
	requestDropLootEvent.OnServerEvent:Connect(onRequestDropLoot)
	requestUseItemEvent.OnServerEvent:Connect(onRequestUseItem)

	local root = ensureRootFolder()
	local medkitRoot = ensureMedkitFolder()
	ensureRoundLoot()

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
