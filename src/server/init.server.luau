--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local PlayerStateService = require(script:WaitForChild("PlayerStateService"))
local LootService = require(script:WaitForChild("LootService"))
local InfectedService = require(script:WaitForChild("InfectedService"))
local WorldService = require(script:WaitForChild("WorldService"))
local WeaponService = require(script:WaitForChild("WeaponService"))

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

local playerAttackEvent = netFolder:WaitForChild(Net.Events.PlayerAttack) :: RemoteEvent
local attackFeedbackEvent = netFolder:WaitForChild(Net.Events.AttackFeedback) :: RemoteEvent

local function processPlayerAttack(player: Player)
	local didHit = InfectedService.TryPlayerAttack(player)
	attackFeedbackEvent:FireClient(player, {
		hit = didHit,
	})
end

playerAttackEvent.OnServerEvent:Connect(function(player: Player)
	processPlayerAttack(player)
end)

WeaponService.Start(processPlayerAttack)
