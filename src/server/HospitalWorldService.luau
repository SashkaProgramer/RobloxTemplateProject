--!strict

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local HospitalWorldService = {}

local worldFolderName = "HospitalRaidWorld"
local extractionPadName = "ExtractionPad"
local extractionGateName = "ExtractionGate"
local spawnName = "StartSpawn"
local sectionCount = 5
local sectionLength = 34
local sectionWidth = 28
local sectionHeight = 12
local corridorGap = 8
local sectionThemes = {
	{
		displayName = "Triage",
		accentColor = Color3.fromRGB(132, 162, 177),
	},
	{
		displayName = "Surgery",
		accentColor = Color3.fromRGB(116, 156, 194),
	},
	{
		displayName = "Isolation",
		accentColor = Color3.fromRGB(166, 138, 88),
	},
	{
		displayName = "Pharmacy",
		accentColor = Color3.fromRGB(104, 154, 126),
	},
	{
		displayName = "Roof Access",
		accentColor = Color3.fromRGB(176, 112, 96),
	},
}

local function ensureWorldFolder(): Folder
	local existing = Workspace:FindFirstChild(worldFolderName)
	if existing and existing:IsA("Folder") then
		existing:ClearAllChildren()
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = worldFolderName
	folder.Parent = Workspace
	return folder
end

local function configureLighting()
	Lighting.Technology = Enum.Technology.Future
	Lighting.ClockTime = 1.8
	Lighting.Brightness = 1.0
	Lighting.ExposureCompensation = -0.5
	Lighting.Ambient = Color3.fromRGB(18, 22, 28)
	Lighting.OutdoorAmbient = Color3.fromRGB(24, 29, 36)
	Lighting.FogColor = Color3.fromRGB(14, 17, 22)
	Lighting.FogStart = 20
	Lighting.FogEnd = 170

	local atmosphere = Lighting:FindFirstChild("HospitalAtmosphere")
	if not atmosphere or not atmosphere:IsA("Atmosphere") then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "HospitalAtmosphere"
		atmosphere.Parent = Lighting
	end

	atmosphere.Density = 0.38
	atmosphere.Offset = -0.16
	atmosphere.Color = Color3.fromRGB(102, 118, 128)
	atmosphere.Decay = Color3.fromRGB(21, 24, 31)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.2
end

local function createPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, canCollide: boolean): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = canCollide
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = color
	part.Material = material
	part.Parent = parent
	return part
end

local function createSignLabel(parent: Instance, adornee: BasePart, text: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneSign"
	billboard.Adornee = adornee
	billboard.Size = UDim2.fromOffset(220, 40)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.1, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 180
	billboard.Parent = parent

	local bg = Instance.new("Frame")
	bg.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
	bg.BackgroundTransparency = 0.16
	bg.BorderSizePixel = 0
	bg.Size = UDim2.fromScale(1, 1)
	bg.Parent = billboard

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 8)
	bgCorner.Parent = bg

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 20
	label.TextColor3 = Color3.fromRGB(234, 239, 244)
	label.TextStrokeTransparency = 0.45
	label.Text = text
	label.Parent = bg
end

local function createSectionSetPiece(sectionModel: Model, index: number, origin: Vector3)
	if index == 1 then
		createPart(
			sectionModel,
			"ReceptionDesk",
			Vector3.new(10, 3.2, 2.6),
			CFrame.new(origin + Vector3.new(0, 3.1, -7)),
			Color3.fromRGB(101, 112, 123),
			Enum.Material.Metal,
			true
		)
	elseif index == 2 then
		createPart(
			sectionModel,
			"SurgeryTable",
			Vector3.new(4, 1.4, 8),
			CFrame.new(origin + Vector3.new(0, 2.2, 2)),
			Color3.fromRGB(148, 158, 166),
			Enum.Material.Metal,
			true
		)
		createPart(
			sectionModel,
			"OperationLightArm",
			Vector3.new(0.6, 5, 0.6),
			CFrame.new(origin + Vector3.new(-3.5, 7.5, 2)),
			Color3.fromRGB(166, 176, 184),
			Enum.Material.Metal,
			true
		)
	elseif index == 3 then
		for side = -1, 1, 2 do
			createPart(
				sectionModel,
				("IsolationBarrier_%d"):format(side),
				Vector3.new(5, 4.6, 0.4),
				CFrame.new(origin + Vector3.new(side * 5.2, 4, -4)),
				Color3.fromRGB(178, 164, 104),
				Enum.Material.Plastic,
				true
			)
		end
	elseif index == 4 then
		for shelfIndex = 1, 2 do
			createPart(
				sectionModel,
				("MedicineShelf_%d"):format(shelfIndex),
				Vector3.new(2.2, 5.4, 8),
				CFrame.new(origin + Vector3.new(if shelfIndex == 1 then -7 else 7, 3.8, 2)),
				Color3.fromRGB(94, 128, 112),
				Enum.Material.Metal,
				true
			)
		end
	elseif index == 5 then
		createPart(
			sectionModel,
			"RoofTerminal",
			Vector3.new(3.2, 3.2, 1.2),
			CFrame.new(origin + Vector3.new(0, 4.2, -8)),
			Color3.fromRGB(140, 112, 92),
			Enum.Material.Metal,
			true
		)
	end
end

local function createHospitalSection(parent: Folder, index: number, origin: Vector3)
	local sectionModel = Instance.new("Model")
	sectionModel.Name = ("Zone_%02d"):format(index)
	sectionModel:SetAttribute("ZoneId", sectionModel.Name)
	local theme = sectionThemes[index]
	if theme then
		sectionModel:SetAttribute("ZoneDisplayName", theme.displayName)
	end
	sectionModel.Parent = parent

	local floor = createPart(
		sectionModel,
		"Floor",
		Vector3.new(sectionWidth, 1, sectionLength),
		CFrame.new(origin),
		Color3.fromRGB(188, 194, 199),
		Enum.Material.SmoothPlastic,
		true
	)
	sectionModel.PrimaryPart = floor

	if theme then
		local accentStrip = createPart(
			sectionModel,
			"AccentStrip",
			Vector3.new(sectionWidth - 6, 0.18, 2.6),
			CFrame.new(origin + Vector3.new(0, 2.6, -sectionLength * 0.5 + 2.2)),
			theme.accentColor,
			Enum.Material.Neon,
			false
		)
		accentStrip.Transparency = 0.2

		local signPanel = createPart(
			sectionModel,
			"SectionSignPanel",
			Vector3.new(7.5, 2.2, 0.4),
			CFrame.new(origin + Vector3.new(0, sectionHeight - 2.2, -sectionLength * 0.5 + 0.8)),
			Color3.fromRGB(34, 40, 48),
			Enum.Material.Metal,
			true
		)
		createSignLabel(sectionModel, signPanel, theme.displayName)
	end

	createPart(
		sectionModel,
		"Ceiling",
		Vector3.new(sectionWidth, 1, sectionLength),
		CFrame.new(origin + Vector3.new(0, sectionHeight, 0)),
		Color3.fromRGB(84, 92, 102),
		Enum.Material.Metal,
		true
	)

	createPart(
		sectionModel,
		"WallLeft",
		Vector3.new(1, sectionHeight, sectionLength),
		CFrame.new(origin + Vector3.new(-sectionWidth * 0.5, sectionHeight * 0.5, 0)),
		Color3.fromRGB(156, 164, 170),
		Enum.Material.Concrete,
		true
	)

	createPart(
		sectionModel,
		"WallRight",
		Vector3.new(1, sectionHeight, sectionLength),
		CFrame.new(origin + Vector3.new(sectionWidth * 0.5, sectionHeight * 0.5, 0)),
		Color3.fromRGB(156, 164, 170),
		Enum.Material.Concrete,
		true
	)

	createPart(
		sectionModel,
		"FrontWallLeft",
		Vector3.new((sectionWidth - 8) * 0.5, sectionHeight, 1),
		CFrame.new(origin + Vector3.new(-(sectionWidth + 8) * 0.25, sectionHeight * 0.5, -sectionLength * 0.5)),
		Color3.fromRGB(162, 170, 176),
		Enum.Material.Concrete,
		true
	)
	createPart(
		sectionModel,
		"FrontWallRight",
		Vector3.new((sectionWidth - 8) * 0.5, sectionHeight, 1),
		CFrame.new(origin + Vector3.new((sectionWidth + 8) * 0.25, sectionHeight * 0.5, -sectionLength * 0.5)),
		Color3.fromRGB(162, 170, 176),
		Enum.Material.Concrete,
		true
	)
	createPart(
		sectionModel,
		"BackWallLeft",
		Vector3.new((sectionWidth - 8) * 0.5, sectionHeight, 1),
		CFrame.new(origin + Vector3.new(-(sectionWidth + 8) * 0.25, sectionHeight * 0.5, sectionLength * 0.5)),
		Color3.fromRGB(162, 170, 176),
		Enum.Material.Concrete,
		true
	)
	createPart(
		sectionModel,
		"BackWallRight",
		Vector3.new((sectionWidth - 8) * 0.5, sectionHeight, 1),
		CFrame.new(origin + Vector3.new((sectionWidth + 8) * 0.25, sectionHeight * 0.5, sectionLength * 0.5)),
		Color3.fromRGB(162, 170, 176),
		Enum.Material.Concrete,
		true
	)

	for side = -1, 1, 2 do
		local room = createPart(
			sectionModel,
			("Ward_%d"):format(side),
			Vector3.new(7, 5, 10),
			CFrame.new(origin + Vector3.new(side * 8, 2.5, 0)),
			Color3.fromRGB(202, 208, 212),
			Enum.Material.SmoothPlastic,
			true
		)

		createPart(
			sectionModel,
			("Bed_%d"):format(side),
			Vector3.new(3, 1.2, 6),
			room.CFrame * CFrame.new(0, -1.8, 0),
			Color3.fromRGB(112, 126, 138),
			Enum.Material.Metal,
			true
		)
	end

	local lamp = createPart(
		sectionModel,
		"CeilingLamp",
		Vector3.new(4, 0.4, 4),
		CFrame.new(origin + Vector3.new(0, sectionHeight - 1.0, 0)),
		Color3.fromRGB(214, 235, 255),
		Enum.Material.Neon,
		false
	)
	lamp:SetAttribute("ZoneLight", true)

	local light = Instance.new("PointLight")
	light.Brightness = 1.8
	light.Range = 22
	light.Color = Color3.fromRGB(214, 235, 255)
	light.Parent = lamp

	if index >= 2 and index <= 4 then
		local fusePanel = createPart(
			sectionModel,
			"FusePanel",
			Vector3.new(2.4, 2.8, 0.6),
			CFrame.new(origin + Vector3.new(0, 4, -sectionLength * 0.28)),
			Color3.fromRGB(124, 142, 158),
			Enum.Material.Metal,
			true
		)
		fusePanel:SetAttribute("InteractionId", "recover_power")
		fusePanel:SetAttribute("ObjectiveZoneId", sectionModel.Name)

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RecoverPowerPrompt"
		prompt.ActionText = "Restore Power"
		prompt.ObjectText = "Fuse Panel"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.HoldDuration = 0.9
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = fusePanel
	end

	createSectionSetPiece(sectionModel, index, origin)
end

local function createCorridor(parent: Folder, index: number, origin: Vector3)
	createPart(
		parent,
		("Corridor_%02d"):format(index),
		Vector3.new(10, 1, corridorGap),
		CFrame.new(origin),
		Color3.fromRGB(180, 186, 190),
		Enum.Material.SmoothPlastic,
		true
	)
end

local function createDoorBlocker(parent: Folder, index: number, origin: Vector3)
	local blocker = createPart(
		parent,
		("Door_%02d"):format(index),
		Vector3.new(8, 8, 2),
		CFrame.new(origin + Vector3.new(0, 6, 0)),
		Color3.fromRGB(89, 119, 145),
		Enum.Material.ForceField,
		true
	)
	blocker.Transparency = 0.08
	blocker:SetAttribute("DoorId", blocker.Name)
	blocker:SetAttribute("FromZoneId", ("Zone_%02d"):format(index))
	blocker:SetAttribute("ToZoneId", ("Zone_%02d"):format(index + 1))
	blocker:SetAttribute("IsDoorOpen", false)
	blocker:SetAttribute("IsDoorLocked", false)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DoorPrompt"
	prompt.ActionText = "Open Door"
	prompt.ObjectText = "Security Door"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = blocker
end

local function createSpawn(parent: Folder, origin: Vector3)
	local existing = Workspace:FindFirstChild(spawnName)
	if existing and existing:IsA("SpawnLocation") then
		existing:Destroy()
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = spawnName
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(origin + Vector3.new(0, 3.5, 0))
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = Color3.fromRGB(116, 148, 158)
	spawn.Parent = Workspace

	local marker = createPart(
		parent,
		"SpawnMarker",
		Vector3.new(8, 0.3, 8),
		CFrame.new(origin + Vector3.new(0, 2.05, 0)),
		Color3.fromRGB(109, 148, 160),
		Enum.Material.Neon,
		false
	)
	marker.Transparency = 0.25
end

local function createExtraction(parent: Folder, origin: Vector3)
	local gate = createPart(
		parent,
		extractionGateName,
		Vector3.new(10, 9, 2),
		CFrame.new(origin + Vector3.new(0, 6, -9)),
		Color3.fromRGB(188, 92, 80),
		Enum.Material.ForceField,
		true
	)
	gate.Transparency = 0.06
	gate:SetAttribute("GateId", extractionGateName)
	gate:SetAttribute("IsGateOpen", false)

	local pad = createPart(
		parent,
		extractionPadName,
		Vector3.new(10, 1, 10),
		CFrame.new(origin + Vector3.new(0, 2.2, 0)),
		Color3.fromRGB(186, 178, 106),
		Enum.Material.Neon,
		false
	)
	pad:SetAttribute("InteractionId", "extract")
	pad:SetAttribute("ExtractionPad", true)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ExtractPrompt"
	prompt.ActionText = "Extract"
	prompt.ObjectText = "Roof Evac"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 1.2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad

	local light = Instance.new("PointLight")
	light.Brightness = 2.2
	light.Range = 20
	light.Color = Color3.fromRGB(240, 221, 126)
	light.Parent = pad
end

function HospitalWorldService.Start()
	configureLighting()

	local worldFolder = ensureWorldFolder()
	local root = Vector3.new(0, 0, 0)

	createPart(
		worldFolder,
		"GroundFloor",
		Vector3.new(170, 4, 280),
		CFrame.new(root + Vector3.new(0, -2, 20)),
		Color3.fromRGB(24, 26, 30),
		Enum.Material.Concrete,
		true
	)

	for index = 1, sectionCount do
		local z = (index - 1) * (sectionLength + corridorGap)
		createHospitalSection(worldFolder, index, root + Vector3.new(0, 2, z))

		if index < sectionCount then
			createCorridor(worldFolder, index, root + Vector3.new(0, 2, z + sectionLength * 0.5 + corridorGap * 0.5))
			createDoorBlocker(worldFolder, index, root + Vector3.new(0, 0, z + sectionLength * 0.5 + corridorGap * 0.5))
		end
	end

	createSpawn(worldFolder, root + Vector3.new(0, 0, -6))
	createExtraction(worldFolder, root + Vector3.new(0, 0, (sectionCount - 1) * (sectionLength + corridorGap) + 10))
end

return HospitalWorldService
