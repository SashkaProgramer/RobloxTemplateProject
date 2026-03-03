--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))

local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))

local LootService = {}

local rootFolderName = "ScavengeNodes"
local scavengeResultEvent: RemoteEvent

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

local function randomNodePosition(index: number): Vector3
	local xBand = (index % 4) * 20 - 30
	local zBand = math.floor(index / 4) * 20 - 20
	local x = xBand + rng:NextNumber(-5, 5)
	local z = zBand + rng:NextNumber(-5, 5)
	return Vector3.new(x, 3, z)
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

function LootService.Start(netFolder: Folder)
	scavengeResultEvent = netFolder:WaitForChild(Net.Events.ScavengeResult) :: RemoteEvent
	local root = ensureRootFolder()

	if #root:GetChildren() > 0 then
		return
	end

	for i = 1, GameConfig.Loot.NodeCount do
		createNode(i, root)
	end
end

return LootService
