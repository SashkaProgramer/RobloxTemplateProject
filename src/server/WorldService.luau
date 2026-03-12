--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local InteractionDefs = require(Shared:WaitForChild("InteractionDefs"))
local Net = require(Shared:WaitForChild("Net"))

local ObjectiveService = require(script.Parent:WaitForChild("ObjectiveService"))
local RoundService = require(script.Parent:WaitForChild("RoundService"))
local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))

type ZoneState = {
	zoneId: string,
	model: Model,
	powerOn: boolean,
	lightParts: { BasePart },
}

type DoorState = {
	doorId: string,
	fromZoneId: string,
	toZoneId: string,
	blocker: BasePart,
	isOpen: boolean,
	isLocked: boolean,
}

type GateState = {
	gateId: string,
	blocker: BasePart,
	isOpen: boolean,
}

local WorldService = {}

local requestInteractEvent: RemoteEvent
local requestSabotageEvent: RemoteEvent
local sabotageFeedbackEvent: RemoteEvent
local zoneTrackingConnection: RBXScriptConnection?

local zonesById: { [string]: ZoneState } = {}
local doorsById: { [string]: DoorState } = {}
local extractionGateState: GateState? = nil
local openDoor: (doorState: DoorState) -> ()
local closeDoor: (doorState: DoorState) -> ()

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

local function clearRegistries()
	table.clear(zonesById)
	table.clear(doorsById)
	extractionGateState = nil
end

local function getHospitalWorldFolder(): Folder?
	local folder = Workspace:FindFirstChild("HospitalRaidWorld")
	if folder and folder:IsA("Folder") then
		return folder
	end

	return nil
end

local function collectLightParts(zoneModel: Model): { BasePart }
	local lights = {}
	for _, descendant in zoneModel:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("ZoneLight") == true then
			table.insert(lights, descendant)
		end
	end

	return lights
end

local function setDoorVisual(doorState: DoorState)
	local blocker = doorState.blocker
	blocker.CanCollide = not doorState.isOpen
	blocker.CanQuery = not doorState.isOpen
	blocker.Transparency = doorState.isOpen and 0.72 or 0.08
	blocker.Color = if doorState.isLocked
		then Color3.fromRGB(168, 73, 62)
		else Color3.fromRGB(96, 118, 136)

	local prompt = blocker:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		if doorState.isLocked then
			prompt.ActionText = if doorState.isOpen then "Close Door" else "Door Locked"
		else
			prompt.ActionText = if doorState.isOpen then "Close Door" else "Open Door"
		end
	end
end

local function setZonePower(zoneState: ZoneState, powerOn: boolean)
	zoneState.powerOn = powerOn

	for _, lightPart in zoneState.lightParts do
		lightPart.Material = if powerOn then Enum.Material.Neon else Enum.Material.Metal
		lightPart.Color = if powerOn then Color3.fromRGB(255, 228, 167) else Color3.fromRGB(54, 58, 66)

		for _, child in lightPart:GetChildren() do
			if child:IsA("PointLight") then
				child.Enabled = powerOn
			end
		end
	end
end

local function setExtractionGateVisual(gateState: GateState)
	gateState.blocker.CanCollide = not gateState.isOpen
	gateState.blocker.CanQuery = not gateState.isOpen
	gateState.blocker.Transparency = gateState.isOpen and 0.82 or 0.06
	gateState.blocker.Color = if gateState.isOpen
		then Color3.fromRGB(110, 180, 144)
		else Color3.fromRGB(188, 92, 80)
	gateState.blocker:SetAttribute("IsGateOpen", gateState.isOpen)
end

local function registerZonesAndDoors()
	clearRegistries()

	local hospitalWorld = getHospitalWorldFolder()
	if not hospitalWorld then
		return
	end

	for _, child in hospitalWorld:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("ZoneId") ~= nil then
			local zoneId = tostring(child:GetAttribute("ZoneId"))
			zonesById[zoneId] = {
				zoneId = zoneId,
				model = child,
				powerOn = true,
				lightParts = collectLightParts(child),
			}
		end

		if child:IsA("BasePart") and child:GetAttribute("DoorId") ~= nil then
			local doorId = tostring(child:GetAttribute("DoorId"))
			local fromZoneId = tostring(child:GetAttribute("FromZoneId"))
			local toZoneId = tostring(child:GetAttribute("ToZoneId"))
			local doorState: DoorState = {
				doorId = doorId,
				fromZoneId = fromZoneId,
				toZoneId = toZoneId,
				blocker = child,
				isOpen = child:GetAttribute("IsDoorOpen") == true,
				isLocked = child:GetAttribute("IsDoorLocked") == true,
			}
			doorsById[doorId] = doorState
			setDoorVisual(doorState)
		end

		if child:IsA("BasePart") and child:GetAttribute("GateId") ~= nil then
			extractionGateState = {
				gateId = tostring(child:GetAttribute("GateId")),
				blocker = child,
				isOpen = child:GetAttribute("IsGateOpen") == true,
			}
			setExtractionGateVisual(extractionGateState)
		end
	end

	for _, zoneState in zonesById do
		setZonePower(zoneState, true)
	end
end

local function resetWorldState()
	for _, doorState in doorsById do
		doorState.isLocked = false
		doorState.blocker:SetAttribute("IsDoorLocked", false)
		closeDoor(doorState)
	end

	for _, zoneState in zonesById do
		setZonePower(zoneState, true)
	end

	WorldService.SetExtractionGateOpen(false)
end

local function isPhaseAllowed(interactionId: string): boolean
	return InteractionDefs.isAllowedInPhase(interactionId, RoundService.GetCurrentPhase())
end

local function canPlayerUseWorldInteractions(player: Player): boolean
	local roundState = PlayerStateService.GetRoundState(player)
	if not roundState then
		return false
	end

	return roundState.alive and not roundState.extracted
end

local function isPlayerNearPart(player: Player, part: BasePart, maxDistance: number): boolean
	local root = getCharacterRoot(player)
	if not root then
		return false
	end

	return (root.Position - part.Position).Magnitude <= maxDistance
end

local function getNearestZoneIdForPlayer(player: Player): string?
	local root = getCharacterRoot(player)
	if not root then
		return nil
	end

	local nearestZoneId: string? = nil
	local nearestDistance = math.huge

	for zoneId, zoneState in zonesById do
		local primaryPart = zoneState.model.PrimaryPart
		if primaryPart then
			local distance = (root.Position - primaryPart.Position).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearestZoneId = zoneId
			end
		end
	end

	return nearestZoneId
end

local function startZoneTracking()
	if zoneTrackingConnection then
		zoneTrackingConnection:Disconnect()
		zoneTrackingConnection = nil
	end

	zoneTrackingConnection = RunService.Heartbeat:Connect(function()
		for _, player in Players:GetPlayers() do
			local nearestZoneId = getNearestZoneIdForPlayer(player)
			PlayerStateService.SetCurrentZoneId(player, nearestZoneId)
		end
	end)
end

openDoor = function(doorState: DoorState)
	doorState.isOpen = true
	doorState.blocker:SetAttribute("IsDoorOpen", true)
	setDoorVisual(doorState)
end

closeDoor = function(doorState: DoorState)
	doorState.isOpen = false
	doorState.blocker:SetAttribute("IsDoorOpen", false)
	setDoorVisual(doorState)
end

local function setDoorLocked(doorState: DoorState, isLocked: boolean)
	doorState.isLocked = isLocked
	doorState.blocker:SetAttribute("IsDoorLocked", isLocked)
	if isLocked then
		closeDoor(doorState)
	end
	setDoorVisual(doorState)
end

local function onRequestInteract(player: Player, payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	if not canPlayerUseWorldInteractions(player) then
		return
	end

	local interactionId = payload.interactionId
	if typeof(interactionId) ~= "string" or not isPhaseAllowed(interactionId) then
		return
	end

	local objectId = payload.objectId
	if typeof(objectId) ~= "string" then
		return
	end

	if interactionId == "open_door" or interactionId == "close_door" then
		local doorState = doorsById[objectId]
		if not doorState or not isPlayerNearPart(player, doorState.blocker, 12) then
			return
		end

		if interactionId == "open_door" then
			if doorState.isLocked then
				sabotageFeedbackEvent:FireClient(player, {
					ok = false,
					message = "Door is jammed",
				})
				return
			end

			if doorState.isOpen then
				closeDoor(doorState)
			else
				openDoor(doorState)
			end
		else
			closeDoor(doorState)
		end

		return
	end

	if interactionId == "recover_power" then
		local completed = ObjectiveService.TryCompleteZoneObjective(player, objectId)
		if completed and ObjectiveService.AreAllObjectivesComplete() then
			WorldService.SetExtractionGateOpen(true)
			sabotageFeedbackEvent:FireClient(player, {
				ok = true,
				message = "Roof gate unlocked",
			})
		end
		return
	end
end

local function onRequestSabotage(player: Player, payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	if not canPlayerUseWorldInteractions(player) then
		return
	end

	local interactionId = payload.interactionId
	if typeof(interactionId) ~= "string" or not isPhaseAllowed(interactionId) then
		return
	end

	local objectId = payload.objectId
	if typeof(objectId) ~= "string" then
		return
	end

	if interactionId == "lock_door" then
		local doorState = doorsById[objectId]
		if not doorState or not isPlayerNearPart(player, doorState.blocker, 12) then
			return
		end

		setDoorLocked(doorState, true)
		sabotageFeedbackEvent:FireClient(player, {
			ok = true,
			message = "Door jammed",
		})
		task.delay(12, function()
			if doorsById[doorState.doorId] == doorState then
				setDoorLocked(doorState, false)
			end
		end)
		return
	end

	if interactionId == "cut_power" then
		local zoneState = zonesById[objectId]
		if not zoneState then
			return
		end

		local root = getCharacterRoot(player)
		local primaryPart = zoneState.model.PrimaryPart or zoneState.model:FindFirstChild("Floor")
		if not root or not primaryPart or not primaryPart:IsA("BasePart") then
			return
		end

		if (root.Position - primaryPart.Position).Magnitude > 20 then
			return
		end

		setZonePower(zoneState, false)
		sabotageFeedbackEvent:FireClient(player, {
			ok = true,
			message = ("Power cut in %s"):format(zoneState.zoneId),
		})
		task.delay(18, function()
			local liveZoneState = zonesById[zoneState.zoneId]
			if liveZoneState then
				setZonePower(liveZoneState, true)
			end
		end)
	end
end

local function bindDoorPrompt(doorState: DoorState)
	local prompt = doorState.blocker:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end

	prompt.Triggered:Connect(function(player: Player)
		if doorState.isLocked then
			sabotageFeedbackEvent:FireClient(player, {
				ok = false,
				message = "Door is jammed",
			})
			return
		end

		onRequestInteract(player, {
			interactionId = if doorState.isOpen then "close_door" else "open_door",
			objectId = doorState.doorId,
		})
	end)
end

local function bindZonePrompts(zoneState: ZoneState)
	for _, descendant in zoneState.model:GetDescendants() do
		if not descendant:IsA("ProximityPrompt") then
			continue
		end

		local promptParent = descendant.Parent
		if not promptParent or not promptParent:IsA("BasePart") then
			continue
		end

		if promptParent:GetAttribute("InteractionId") ~= "recover_power" then
			continue
		end

		local objectiveZoneId = promptParent:GetAttribute("ObjectiveZoneId")
		if typeof(objectiveZoneId) ~= "string" then
			continue
		end

		descendant.Triggered:Connect(function(player: Player)
			onRequestInteract(player, {
				interactionId = "recover_power",
				objectId = objectiveZoneId,
			})
		end)
	end
end

function WorldService.Start(netFolder: Folder)
	requestInteractEvent = netFolder:WaitForChild(Net.Events.RequestInteract) :: RemoteEvent
	requestSabotageEvent = netFolder:WaitForChild(Net.Events.RequestSabotage) :: RemoteEvent
	sabotageFeedbackEvent = netFolder:WaitForChild(Net.Events.SabotageFeedback) :: RemoteEvent

	registerZonesAndDoors()

	requestInteractEvent.OnServerEvent:Connect(onRequestInteract)
	requestSabotageEvent.OnServerEvent:Connect(onRequestSabotage)
	startZoneTracking()
	resetWorldState()

	RoundService.OnPhaseChanged(function(newPhase: string)
		if newPhase == "Preparation" then
			resetWorldState()
		end
	end)

	for _, doorState in doorsById do
		bindDoorPrompt(doorState)
	end

	for _, zoneState in zonesById do
		bindZonePrompts(zoneState)
	end
end

function WorldService.GetZoneState(zoneId: string): ZoneState?
	return zonesById[zoneId]
end

function WorldService.GetDoorState(doorId: string): DoorState?
	return doorsById[doorId]
end

function WorldService.GetAllZones(): { [string]: ZoneState }
	return zonesById
end

function WorldService.GetAllDoors(): { [string]: DoorState }
	return doorsById
end

function WorldService.SetExtractionGateOpen(isOpen: boolean)
	local gateState = extractionGateState
	if not gateState then
		return
	end

	gateState.isOpen = isOpen
	setExtractionGateVisual(gateState)
end

function WorldService.IsExtractionGateOpen(): boolean
	local gateState = extractionGateState
	return gateState ~= nil and gateState.isOpen
end

return WorldService
