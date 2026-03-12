--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))
local RoundService = require(script.Parent:WaitForChild("RoundService"))

local ExtractionService = {}

local extractionPadName = "ExtractionPad"
local requestExtractEvent: RemoteEvent

local function getExtractionPad(): BasePart?
	local direct = Workspace:FindFirstChild(extractionPadName)
	if direct and direct:IsA("BasePart") then
		return direct
	end

	for _, descendant in Workspace:GetDescendants() do
		if descendant.Name == extractionPadName and descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
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

local function tryExtract(player: Player)
	local root = getCharacterRoot(player)
	if not root then
		return
	end

	local pad = getExtractionPad()
	if not pad then
		return
	end

	if (root.Position - pad.Position).Magnitude > 14 then
		return
	end

	local extracted, reason = RoundService.TryRegisterExtraction(player)
	if not extracted then
		requestExtractEvent:FireClient(player, {
			ok = false,
			reason = reason,
		})
		return
	end

	PlayerStateService.SetExtracted(player, true)
	requestExtractEvent:FireClient(player, {
		ok = true,
	})
end

function ExtractionService.Start(netFolder: Folder)
	requestExtractEvent = netFolder:WaitForChild(Net.Events.RequestExtract) :: RemoteEvent
	requestExtractEvent.OnServerEvent:Connect(function(player: Player)
		tryExtract(player)
	end)

	local pad = getExtractionPad()
	if not pad then
		return
	end

	local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function(player: Player)
			tryExtract(player)
		end)
	end
end

return ExtractionService
