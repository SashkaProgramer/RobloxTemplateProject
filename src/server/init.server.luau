--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))

local PlayerStateService = require(script:WaitForChild("PlayerStateService"))
local LootService = require(script:WaitForChild("LootService"))
local InfectedService = require(script:WaitForChild("InfectedService"))
local WorldService = require(script:WaitForChild("WorldService"))
local WeaponService = require(script:WaitForChild("WeaponService"))

local playerAimPoints: { [Player]: Vector3 } = {}

local netFolder = ReplicatedStorage:FindFirstChild(Net.FolderName)
if not netFolder then
	netFolder = Instance.new("Folder")
	netFolder.Name = Net.FolderName
	netFolder.Parent = ReplicatedStorage
end

for _, eventName in Net.Events do
	local existing = netFolder:FindFirstChild(eventName)
	if not existing then
		local event = Instance.new("RemoteEvent")
		event.Name = eventName
		event.Parent = netFolder
	end
end

WorldService.Start()
PlayerStateService.Start(netFolder :: Folder)
LootService.Start(netFolder :: Folder)
InfectedService.Start()

local aimUpdateEvent = netFolder:WaitForChild(Net.Events.AimUpdate) :: RemoteEvent
local attackFeedbackEvent = netFolder:WaitForChild(Net.Events.AttackFeedback) :: RemoteEvent

local function processPlayerAttack(player: Player, impactPosition: Vector3?)
	local didHit = InfectedService.TryPlayerGrenadeAttack(player, impactPosition)
	attackFeedbackEvent:FireClient(player, {
		hit = didHit,
	})
end

aimUpdateEvent.OnServerEvent:Connect(function(player: Player, aimPoint: Vector3)
	if typeof(aimPoint) ~= "Vector3" then
		return
	end

	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return
	end

	local offset = aimPoint - root.Position
	local maxDistance = GameConfig.Player.GrenadeRange * 1.35
	if offset.Magnitude > maxDistance and offset.Magnitude > 0.01 then
		aimPoint = root.Position + offset.Unit * maxDistance
	end

	playerAimPoints[player] = aimPoint
end)

Players.PlayerRemoving:Connect(function(player: Player)
	playerAimPoints[player] = nil
end)

WeaponService.Start(function(player: Player): Vector3?
	return playerAimPoints[player]
end, function(player: Player, impactPosition: Vector3)
	processPlayerAttack(player, impactPosition)
end)
