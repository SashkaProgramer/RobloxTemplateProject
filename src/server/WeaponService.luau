--!strict

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPack = game:GetService("StarterPack")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local WeaponService = {}

local weaponName = "Pulse Launcher"
local swordWeaponName = "Energy Blade"
local weaponTag = "IsMeleeWeapon"
local versionAttribute = "WeaponVersion"
local weaponVersion = 9
local swordWeaponVersion = 4
local destructibleAttribute = "DestructibleByGrenade"
local legacyWeaponNames = {
	"Rusty Pipe",
	"Survivor Sword",
	"Steel Sword",
}
local rng = Random.new()
local playerLastShotTime: { [Player]: number } = {}
local playerLastSwordSwingTime: { [Player]: number } = {}
local activeGetAimPointForPlayer: ((player: Player) -> Vector3?)?
local activeOnGrenadeImpact: ((player: Player, impactPosition: Vector3) -> ())?
local activeOnSwordAttack: ((player: Player) -> ())?

local function findMotor(character: Model, names: { string }): Motor6D?
	for _, name in names do
		local instance = character:FindFirstChild(name, true)
		if instance and instance:IsA("Motor6D") then
			return instance
		end
	end
	return nil
end

local function playCharacterSwordSlashAnimation(character: Model)
	if character:GetAttribute("SwordBodySwinging") == true then
		return
	end

	local shoulder = findMotor(character, { "RightShoulder", "Right Shoulder" })
	if not shoulder then
		return
	end
	local elbow = findMotor(character, { "RightElbow", "Right Elbow" })
	local waist = findMotor(character, { "Waist" })

	character:SetAttribute("SwordBodySwinging", true)

	task.spawn(function()
		local shoulderBase = shoulder.C0
		local elbowBase = if elbow then elbow.C0 else nil
		local waistBase = if waist then waist.C0 else nil

		local shoulderWindup = shoulderBase * CFrame.Angles(math.rad(-124), math.rad(22), math.rad(38))
		local shoulderSlash = shoulderBase * CFrame.Angles(math.rad(56), math.rad(-24), math.rad(-24))
		local shoulderFollow = shoulderBase * CFrame.Angles(math.rad(22), math.rad(-10), math.rad(-7))

		local elbowWindup = if elbowBase then elbowBase * CFrame.Angles(math.rad(-52), 0, math.rad(10)) else nil
		local elbowSlash = if elbowBase then elbowBase * CFrame.Angles(math.rad(92), 0, math.rad(-8)) else nil
		local elbowFollow = if elbowBase then elbowBase * CFrame.Angles(math.rad(52), 0, math.rad(-2)) else nil

		local waistWindup = if waistBase then waistBase * CFrame.Angles(0, math.rad(22), 0) else nil
		local waistSlash = if waistBase then waistBase * CFrame.Angles(0, math.rad(-28), 0) else nil
		local waistFollow = if waistBase then waistBase * CFrame.Angles(0, math.rad(-12), 0) else nil

		local function runPhase(
			duration: number,
			fromShoulder: CFrame,
			toShoulder: CFrame,
			fromElbow: CFrame?,
			toElbow: CFrame?,
			fromWaist: CFrame?,
			toWaist: CFrame?
		)
			local startTime = os.clock()
			while true do
				if not shoulder.Parent then
					break
				end

				local alpha = math.clamp((os.clock() - startTime) / duration, 0, 1)
				local eased = 1 - (1 - alpha) * (1 - alpha) * (1 - alpha)
				shoulder.C0 = fromShoulder:Lerp(toShoulder, eased)

				if elbow and elbow.Parent and fromElbow and toElbow then
					elbow.C0 = fromElbow:Lerp(toElbow, eased)
				end

				if waist and waist.Parent and fromWaist and toWaist then
					waist.C0 = fromWaist:Lerp(toWaist, eased)
				end

				if alpha >= 1 then
					break
				end
				RunService.Heartbeat:Wait()
			end
		end

		runPhase(0.085, shoulderBase, shoulderWindup, elbowBase, elbowWindup, waistBase, waistWindup)
		runPhase(0.09, shoulderWindup, shoulderSlash, elbowWindup, elbowSlash, waistWindup, waistSlash)
		runPhase(0.07, shoulderSlash, shoulderFollow, elbowSlash, elbowFollow, waistSlash, waistFollow)
		runPhase(0.12, shoulderFollow, shoulderBase, elbowFollow, elbowBase, waistFollow, waistBase)

		if shoulder.Parent then
			shoulder.C0 = shoulderBase
		end
		if elbow and elbow.Parent and elbowBase then
			elbow.C0 = elbowBase
		end
		if waist and waist.Parent and waistBase then
			waist.C0 = waistBase
		end
		character:SetAttribute("SwordBodySwinging", false)
	end)
end

local function isLegacyName(name: string): boolean
	for _, legacyName in legacyWeaponNames do
		if name == legacyName then
			return true
		end
	end
	return false
end

local function createWeaponPart(
	parent: Instance,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	relative: CFrame,
	handle: BasePart
): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.Massless = true
	part.Parent = parent
	part.CFrame = handle.CFrame * relative

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function playRecoilAnimation(tool: Tool)
	if tool:GetAttribute("Recoiling") == true then
		return
	end

	tool:SetAttribute("Recoiling", true)
	local baseGrip = tool.Grip

	task.spawn(function()
		for i = 1, 4 do
			local alpha = i / 4
			local recoil = CFrame.new(0, 0.01 * alpha, 0.13 * alpha)
				* CFrame.Angles(math.rad(-7 * alpha), 0, math.rad(4 * alpha))
			tool.Grip = baseGrip * recoil
			task.wait(0.018)
		end

		for i = 1, 6 do
			local alpha = i / 6
			local recoil = CFrame.new(0, 0.01 * (1 - alpha), 0.13 * (1 - alpha))
				* CFrame.Angles(math.rad(-7 * (1 - alpha)), 0, math.rad(4 * (1 - alpha)))
			tool.Grip = baseGrip * recoil
			task.wait(0.018)
		end

		tool.Grip = baseGrip
		tool:SetAttribute("Recoiling", false)
	end)
end

local function playSwordSwingAnimation(tool: Tool, character: Model)
	if tool:GetAttribute("Swinging") == true then
		return
	end

	tool:SetAttribute("Swinging", true)
	local baseGrip = tool.Grip
	playCharacterSwordSlashAnimation(character)

	task.spawn(function()
		for i = 1, 5 do
			local alpha = i / 5
			local windup = CFrame.new(0.1 * alpha, 0.07 * alpha, -0.34 * alpha)
				* CFrame.Angles(math.rad(26 * alpha), math.rad(8 * alpha), math.rad(-34 * alpha))
			tool.Grip = baseGrip * windup
			task.wait(0.01)
		end

		for i = 1, 3 do
			local alpha = i / 3
			local strike = CFrame.new(-0.04 * alpha, -0.16 * alpha, 1.04 * alpha)
				* CFrame.Angles(math.rad(-66 * alpha), math.rad(-6 * alpha), math.rad(34 * alpha))
			tool.Grip = baseGrip * strike
			task.wait(0.008)
		end

		for i = 1, 6 do
			local alpha = i / 6
			local recover = CFrame.new(-0.04 * (1 - alpha), -0.16 * (1 - alpha), 1.04 * (1 - alpha))
				* CFrame.Angles(math.rad(-66 * (1 - alpha)), math.rad(-6 * (1 - alpha)), math.rad(34 * (1 - alpha)))
			tool.Grip = baseGrip * recover
			task.wait(0.013)
		end

		tool.Grip = baseGrip
		tool:SetAttribute("Swinging", false)
	end)
end

local function createExplosionCubes(position: Vector3)
	local count = math.max(6, GameConfig.Player.GrenadeExplosionCubeCount)
	for _ = 1, count do
		local cube = Instance.new("Part")
		local side = rng:NextNumber(0.18, 0.45)
		cube.Name = "GrenadeBlastCube"
		cube.Size = Vector3.new(side, side, side)
		cube.Material = Enum.Material.Metal
		cube.Color = Color3.fromRGB(
			rng:NextInteger(65, 120),
			rng:NextInteger(70, 130),
			rng:NextInteger(55, 95)
		)
		cube.TopSurface = Enum.SurfaceType.Smooth
		cube.BottomSurface = Enum.SurfaceType.Smooth
		cube.CanCollide = true
		cube.Anchored = false
		cube.CFrame = CFrame.new(position)
			* CFrame.new(
				rng:NextNumber(-0.6, 0.6),
				rng:NextNumber(-0.4, 0.6),
				rng:NextNumber(-0.6, 0.6)
			)
		cube.Parent = Workspace

		local pushDir = Vector3.new(
			rng:NextNumber(-1, 1),
			rng:NextNumber(0.25, 1.5),
			rng:NextNumber(-1, 1)
		)
		if pushDir.Magnitude < 0.001 then
			pushDir = Vector3.new(0, 1, 0)
		end

		cube.AssemblyLinearVelocity = pushDir.Unit * rng:NextNumber(12, 32)
		cube.AssemblyAngularVelocity = Vector3.new(
			rng:NextNumber(-20, 20),
			rng:NextNumber(-20, 20),
			rng:NextNumber(-20, 20)
		)
		Debris:AddItem(cube, 2.2)
	end
end

local function shatterWorldPart(part: BasePart, blastCenter: Vector3)
	local volume = part.Size.X * part.Size.Y * part.Size.Z
	local count = math.clamp(math.floor(volume / 18), 10, 36)

	for _ = 1, count do
		local cube = Instance.new("Part")
		local side = rng:NextNumber(0.35, 1.05)
		cube.Name = "WorldShardCube"
		cube.Size = Vector3.new(side, side, side)
		cube.Material = part.Material
		cube.Color = part.Color
		cube.TopSurface = Enum.SurfaceType.Smooth
		cube.BottomSurface = Enum.SurfaceType.Smooth
		cube.CanCollide = true
		cube.Anchored = false
		cube.CFrame = part.CFrame
			* CFrame.new(
				rng:NextNumber(-part.Size.X * 0.45, part.Size.X * 0.45),
				rng:NextNumber(-part.Size.Y * 0.45, part.Size.Y * 0.45),
				rng:NextNumber(-part.Size.Z * 0.45, part.Size.Z * 0.45)
			)
		cube.Parent = Workspace

		local push = cube.Position - blastCenter
		if push.Magnitude < 0.01 then
			push = Vector3.new(
				rng:NextNumber(-1, 1),
				rng:NextNumber(0.2, 1.3),
				rng:NextNumber(-1, 1)
			)
		end

		cube.AssemblyLinearVelocity = push.Unit * rng:NextNumber(14, 34)
		cube.AssemblyAngularVelocity = Vector3.new(
			rng:NextNumber(-18, 18),
			rng:NextNumber(-18, 18),
			rng:NextNumber(-18, 18)
		)
		Debris:AddItem(cube, 4.2)
	end

	if part.Parent then
		part:Destroy()
	end
end

local function destroyDestructibleBlocks(blastCenter: Vector3, radius: number)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.MaxParts = 64
	overlapParams.FilterDescendantsInstances = {}

	local parts = Workspace:GetPartBoundsInRadius(blastCenter, radius, overlapParams)
	local handled: { [BasePart]: boolean } = {}
	for _, part in parts do
		if part:IsA("BasePart") and not handled[part] and part:GetAttribute(destructibleAttribute) == true then
			handled[part] = true
			shatterWorldPart(part, blastCenter)
		end
	end
end

local function createExplosionFx(position: Vector3)
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastRadius = 0
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Parent = Workspace

	local pulse = Instance.new("Part")
	pulse.Name = "GrenadePulse"
	pulse.Shape = Enum.PartType.Ball
	pulse.Size = Vector3.new(3.2, 3.2, 3.2)
	pulse.Material = Enum.Material.Neon
	pulse.Color = Color3.fromRGB(255, 164, 72)
	pulse.Transparency = 0.14
	pulse.Anchored = true
	pulse.CanCollide = false
	pulse.CanQuery = false
	pulse.CanTouch = false
	pulse.CFrame = CFrame.new(position)
	pulse.Parent = Workspace
	Debris:AddItem(pulse, 0.16)
end

local function createMuzzleFlash(position: Vector3, direction: Vector3)
	local flash = Instance.new("Part")
	flash.Name = "MuzzleFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(0.5, 0.5, 0.5)
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 207, 120)
	flash.Transparency = 0.12
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.CFrame = CFrame.lookAt(position, position + direction) * CFrame.new(0, 0, -0.18)
	flash.Parent = Workspace
	Debris:AddItem(flash, 0.09)
end

local function launchGrenadeProjectile(
	player: Player,
	tool: Tool,
	origin: Vector3,
	direction: Vector3,
	onImpact: (position: Vector3) -> ()
)
	local grenade = Instance.new("Part")
	grenade.Name = "GrenadeProjectile"
	grenade.Shape = Enum.PartType.Ball
	grenade.Size = Vector3.new(0.62, 0.62, 0.62)
	grenade.Material = Enum.Material.Neon
	grenade.Color = Color3.fromRGB(116, 156, 82)
	grenade.Anchored = true
	grenade.CanCollide = false
	grenade.CanTouch = false
	grenade.Parent = Workspace
	Debris:AddItem(grenade, GameConfig.Player.GrenadeProjectileLifetime + 1)

	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(180, 220, 120)
	glow.Brightness = 1.8
	glow.Range = 8
	glow.Parent = grenade

	local attachment0 = Instance.new("Attachment")
	attachment0.Position = Vector3.new(0, 0, 0.22)
	attachment0.Parent = grenade

	local attachment1 = Instance.new("Attachment")
	attachment1.Position = Vector3.new(0, 0, -0.22)
	attachment1.Parent = grenade

	local trail = Instance.new("Trail")
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.Lifetime = 0.12
	trail.MinLength = 0.1
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(
		Color3.fromRGB(255, 229, 167),
		Color3.fromRGB(255, 132, 84)
	)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(1, 0.9),
	})
	trail.Parent = grenade

	local speed = GameConfig.Player.GrenadeProjectileSpeed
	local gravity = Vector3.new(0, -Workspace.Gravity, 0)
	local launchDirection = if direction.Magnitude > 0.001 then direction.Unit else Vector3.new(0, 0, -1)
	local velocity = launchDirection * speed + Vector3.new(0, 7, 0)
	local current = origin + launchDirection * 1.35
	grenade.CFrame = CFrame.lookAt(current, current + launchDirection)
	local startTime = os.clock()
	local travelDistance = 0
	local armingDistance = 4

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local filter: { Instance } = { tool, grenade }
	if player.Character then
		table.insert(filter, player.Character)
	end
	rayParams.FilterDescendantsInstances = filter

	local exploded = false
	local heartbeatConnection: RBXScriptConnection?
	local function explodeAt(position: Vector3)
		if exploded then
			return
		end
		exploded = true
		if heartbeatConnection then
			heartbeatConnection:Disconnect()
			heartbeatConnection = nil
		end
		createExplosionFx(position)
		createExplosionCubes(position)
		destroyDestructibleBlocks(position, GameConfig.Player.GrenadeExplosionRadius)
		onImpact(position)
		if grenade.Parent then
			grenade:Destroy()
		end
	end

	heartbeatConnection = RunService.Heartbeat:Connect(function(dt: number)
		if exploded then
			return
		end

		if os.clock() - startTime > GameConfig.Player.GrenadeProjectileLifetime then
			explodeAt(current)
			return
		end

		velocity += gravity * dt
		local nextPosition = current + velocity * dt
		local segment = nextPosition - current
		local segmentDistance = segment.Magnitude

		if segmentDistance > 0.001 then
			travelDistance += segmentDistance
			local hit = Workspace:Raycast(current, segment, rayParams)
			if hit and travelDistance >= armingDistance then
				explodeAt(hit.Position)
				return
			end
		end

		current = nextPosition
		if grenade.Parent then
			grenade.CFrame = CFrame.lookAt(current, current + velocity)
		end
	end)
end

local function tryFireLauncher(player: Player, tool: Tool): boolean
	local getAimPointForPlayer = activeGetAimPointForPlayer
	local onGrenadeImpact = activeOnGrenadeImpact
	if not getAimPointForPlayer or not onGrenadeImpact then
		return false
	end

	local character = player.Character
	if not character or not character:IsA("Model") then
		return false
	end

	if tool.Parent ~= character then
		return false
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	local now = time()
	local lastShot = playerLastShotTime[player]
	if lastShot and now - lastShot < GameConfig.Player.GrenadeCooldown then
		return false
	end
	playerLastShotTime[player] = now

	playRecoilAnimation(tool)

	local direction = root.CFrame.LookVector
	local provisionalOrigin = root.Position + Vector3.new(0, 1.45, 0) + direction * 1.4
	local aimPoint = getAimPointForPlayer(player)
	if aimPoint then
		local aimVector = aimPoint - provisionalOrigin
		if aimVector.Magnitude > 0.5 then
			local candidateDirection = aimVector.Unit
			if candidateDirection:Dot(root.CFrame.LookVector) > 0.15 then
				direction = candidateDirection
			end
		end
	end

	local muzzle = tool:FindFirstChild("Muzzle")
	local origin = if muzzle and muzzle:IsA("BasePart")
		then muzzle.Position + direction * 0.25
		else provisionalOrigin

	createMuzzleFlash(origin, direction)
	launchGrenadeProjectile(player, tool, origin, direction, function(impact: Vector3)
		onGrenadeImpact(player, impact)
	end)
	return true
end

local function createGrenadeLauncherTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = weaponName
	tool:SetAttribute(weaponTag, true)
	tool:SetAttribute(versionAttribute, weaponVersion)
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Pulse launcher"
	tool.Grip = CFrame.new(0.06, -0.34, -0.66)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.24, 0.8, 0.24)
	handle.Color = Color3.fromRGB(44, 37, 31)
	handle.Material = Enum.Material.SmoothPlastic
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	createWeaponPart(
		tool,
		"UpperReceiver",
		Vector3.new(0.54, 0.24, 1.78),
		Color3.fromRGB(62, 67, 74),
		Enum.Material.Metal,
		CFrame.new(0, 0.46, -1.02),
		handle
	)
	createWeaponPart(
		tool,
		"LowerReceiver",
		Vector3.new(0.52, 0.3, 1.55),
		Color3.fromRGB(56, 60, 66),
		Enum.Material.Metal,
		CFrame.new(0, 0.26, -0.98),
		handle
	)
	createWeaponPart(
		tool,
		"Rail",
		Vector3.new(0.2, 0.08, 1.5),
		Color3.fromRGB(35, 37, 42),
		Enum.Material.Metal,
		CFrame.new(0, 0.64, -1.04),
		handle
	)
	createWeaponPart(
		tool,
		"Handguard",
		Vector3.new(0.48, 0.34, 1.28),
		Color3.fromRGB(43, 47, 53),
		Enum.Material.Metal,
		CFrame.new(0, 0.24, -2.12),
		handle
	)
	createWeaponPart(
		tool,
		"Barrel",
		Vector3.new(0.2, 0.2, 2.25),
		Color3.fromRGB(78, 82, 88),
		Enum.Material.Metal,
		CFrame.new(0, 0.24, -2.9),
		handle
	)
	createWeaponPart(
		tool,
		"Muzzle",
		Vector3.new(0.3, 0.3, 0.25),
		Color3.fromRGB(30, 32, 36),
		Enum.Material.Metal,
		CFrame.new(0, 0.24, -4.16),
		handle
	)
	createWeaponPart(
		tool,
		"Buttstock",
		Vector3.new(0.42, 0.26, 1.2),
		Color3.fromRGB(58, 44, 34),
		Enum.Material.Wood,
		CFrame.new(0, 0.27, 0.7),
		handle
	)
	createWeaponPart(
		tool,
		"Buttpad",
		Vector3.new(0.44, 0.3, 0.12),
		Color3.fromRGB(22, 23, 26),
		Enum.Material.Metal,
		CFrame.new(0, 0.27, 1.36),
		handle
	)
	createWeaponPart(
		tool,
		"PistolGrip",
		Vector3.new(0.2, 0.46, 0.18),
		Color3.fromRGB(50, 40, 31),
		Enum.Material.Wood,
		CFrame.new(0, -0.04, -0.36) * CFrame.Angles(math.rad(-22), 0, 0),
		handle
	)
	createWeaponPart(
		tool,
		"FrontGrip",
		Vector3.new(0.18, 0.5, 0.18),
		Color3.fromRGB(50, 40, 32),
		Enum.Material.Wood,
		CFrame.new(0, -0.08, -1.86),
		handle
	)
	createWeaponPart(
		tool,
		"ScopeBody",
		Vector3.new(0.2, 0.2, 0.9),
		Color3.fromRGB(34, 36, 40),
		Enum.Material.Metal,
		CFrame.new(0, 0.82, -1.1),
		handle
	)
	createWeaponPart(
		tool,
		"ScopeFront",
		Vector3.new(0.24, 0.24, 0.16),
		Color3.fromRGB(30, 31, 35),
		Enum.Material.Metal,
		CFrame.new(0, 0.82, -1.63),
		handle
	)
	createWeaponPart(
		tool,
		"ScopeBack",
		Vector3.new(0.24, 0.24, 0.16),
		Color3.fromRGB(30, 31, 35),
		Enum.Material.Metal,
		CFrame.new(0, 0.82, -0.58),
		handle
	)
	createWeaponPart(
		tool,
		"ScopeMountA",
		Vector3.new(0.12, 0.22, 0.12),
		Color3.fromRGB(34, 36, 40),
		Enum.Material.Metal,
		CFrame.new(0, 0.68, -0.84),
		handle
	)
	createWeaponPart(
		tool,
		"ScopeMountB",
		Vector3.new(0.12, 0.22, 0.12),
		Color3.fromRGB(34, 36, 40),
		Enum.Material.Metal,
		CFrame.new(0, 0.68, -1.36),
		handle
	)
	createWeaponPart(
		tool,
		"SideKnob",
		Vector3.new(0.08, 0.08, 0.08),
		Color3.fromRGB(28, 30, 34),
		Enum.Material.Metal,
		CFrame.new(0.14, 0.82, -1.02),
		handle
	)
	createWeaponPart(
		tool,
		"GrenadeDrum",
		Vector3.new(0.52, 0.52, 0.52),
		Color3.fromRGB(68, 79, 52),
		Enum.Material.SmoothPlastic,
		CFrame.new(0, -0.19, -1.38),
		handle
	)

	tool.Activated:Connect(function()
		local parent = tool.Parent
		if not parent or not parent:IsA("Model") then
			return
		end
		local player = Players:GetPlayerFromCharacter(parent)
		if player then
			tryFireLauncher(player, tool)
		end
	end)

	return tool
end

local function trySwingSword(player: Player, tool: Tool): boolean
	local onSwordAttack = activeOnSwordAttack
	if not onSwordAttack then
		return false
	end

	local character = player.Character
	if not character or not character:IsA("Model") then
		return false
	end

	if tool.Parent ~= character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	local now = time()
	local lastSwing = playerLastSwordSwingTime[player]
	if lastSwing and now - lastSwing < GameConfig.Player.AttackCooldown then
		return false
	end
	playerLastSwordSwingTime[player] = now

	playSwordSwingAnimation(tool, character)
	onSwordAttack(player)
	return true
end

local function createSwordTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = swordWeaponName
	tool:SetAttribute(weaponTag, true)
	tool:SetAttribute(versionAttribute, swordWeaponVersion)
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Glowing energy blade"
	tool.Grip = CFrame.new(0.08, -1.0, -0.18) * CFrame.Angles(0, math.rad(90), 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.24, 0.9, 0.24)
	handle.Color = Color3.fromRGB(40, 42, 46)
	handle.Material = Enum.Material.Metal
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	createWeaponPart(
		tool,
		"HiltCore",
		Vector3.new(0.18, 0.96, 0.18),
		Color3.fromRGB(58, 60, 66),
		Enum.Material.Metal,
		CFrame.new(0, 0.05, 0),
		handle
	)
	createWeaponPart(
		tool,
		"HiltEmitter",
		Vector3.new(0.22, 0.12, 0.22),
		Color3.fromRGB(130, 135, 145),
		Enum.Material.Metal,
		CFrame.new(0, 0.58, 0),
		handle
	)
	createWeaponPart(
		tool,
		"GripBandA",
		Vector3.new(0.2, 0.1, 0.2),
		Color3.fromRGB(18, 18, 20),
		Enum.Material.Metal,
		CFrame.new(0, -0.18, 0),
		handle
	)
	createWeaponPart(
		tool,
		"GripBandB",
		Vector3.new(0.2, 0.1, 0.2),
		Color3.fromRGB(18, 18, 20),
		Enum.Material.Metal,
		CFrame.new(0, -0.42, 0),
		handle
	)
	createWeaponPart(
		tool,
		"Pommel",
		Vector3.new(0.22, 0.16, 0.22),
		Color3.fromRGB(115, 118, 126),
		Enum.Material.Metal,
		CFrame.new(0, -0.55, 0),
		handle
	)
	local blade = createWeaponPart(
		tool,
		"Blade",
		Vector3.new(0.18, 3.6, 0.18),
		Color3.fromRGB(88, 232, 255),
		Enum.Material.Neon,
		CFrame.new(0, 2.42, 0),
		handle
	)
	local bladeTip = createWeaponPart(
		tool,
		"BladeTip",
		Vector3.new(0.18, 0.22, 0.18),
		Color3.fromRGB(156, 244, 255),
		Enum.Material.Neon,
		CFrame.new(0, 4.33, 0),
		handle
	)
	bladeTip.Shape = Enum.PartType.Ball

	local bladeLight = Instance.new("PointLight")
	bladeLight.Color = Color3.fromRGB(115, 236, 255)
	bladeLight.Brightness = 1.9
	bladeLight.Range = 10
	bladeLight.Shadows = false
	bladeLight.Parent = blade

	tool.Activated:Connect(function()
		local parent = tool.Parent
		if not parent or not parent:IsA("Model") then
			return
		end
		local player = Players:GetPlayerFromCharacter(parent)
		if player then
			trySwingSword(player, tool)
		end
	end)

	return tool
end

local function isCurrentWeapon(tool: Tool): boolean
	if tool.Name == weaponName then
		return tool:GetAttribute(versionAttribute) == weaponVersion
	end
	if tool.Name == swordWeaponName then
		return tool:GetAttribute(versionAttribute) == swordWeaponVersion
	end
	return false
end

local function removeOutdatedWeapons(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("Tool") then
			local isManagedWeaponName = child.Name == weaponName or child.Name == swordWeaponName
			local isTaggedWeapon = child:GetAttribute(weaponTag) == true
			local shouldRemove = isLegacyName(child.Name)
				or (isManagedWeaponName and not isCurrentWeapon(child))
				or (isTaggedWeapon and not isCurrentWeapon(child))

			if shouldRemove then
				child:Destroy()
			end
		end
	end
end

local function ensureWeapon(container: Instance, toolName: string, createTool: () -> Tool): Tool
	local existing = container:FindFirstChild(toolName)
	if existing and existing:IsA("Tool") and isCurrentWeapon(existing) then
		return existing
	end
	if existing then
		existing:Destroy()
	end

	local tool = createTool()
	tool.Parent = container
	return tool
end

local function ensureLoadout(container: Instance): (Tool, Tool)
	removeOutdatedWeapons(container)
	local launcher = ensureWeapon(container, weaponName, createGrenadeLauncherTool)
	local sword = ensureWeapon(container, swordWeaponName, createSwordTool)
	return launcher, sword
end

local function equipForCharacter(player: Player, weapon: Tool)
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
	if humanoid and weapon.Parent and weapon.Parent ~= character then
		humanoid:EquipTool(weapon)
	end
end

function WeaponService.TryFire(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end

	local equipped = character:FindFirstChildOfClass("Tool")
	if not equipped then
		return false
	end

	if equipped.Name == weaponName then
		return tryFireLauncher(player, equipped)
	end
	if equipped.Name == swordWeaponName then
		return trySwingSword(player, equipped)
	end
	return false
end

function WeaponService.Start(
	getAimPointForPlayer: (player: Player) -> Vector3?,
	onGrenadeImpact: (player: Player, impactPosition: Vector3) -> (),
	onSwordAttack: (player: Player) -> ()
)
	activeGetAimPointForPlayer = getAimPointForPlayer
	activeOnGrenadeImpact = onGrenadeImpact
	activeOnSwordAttack = onSwordAttack

	local function syncStarterPack()
		removeOutdatedWeapons(StarterPack)
		for _, name in { weaponName, swordWeaponName } do
			local existing = StarterPack:FindFirstChild(name)
			if existing and existing:IsA("Tool") then
				existing:Destroy()
			end
		end
	end

	local function giveTools(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			local nextBackpack = player:WaitForChild("Backpack")
			removeOutdatedWeapons(nextBackpack)
			removeOutdatedWeapons(character)
			local launcher = ensureLoadout(nextBackpack)
			equipForCharacter(player, launcher)
		end)

		local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 10)
		if backpack then
			removeOutdatedWeapons(backpack)
			if player.Character then
				removeOutdatedWeapons(player.Character)
			end
			local launcher = ensureLoadout(backpack)
			equipForCharacter(player, launcher)
		end
	end

	syncStarterPack()

	Players.PlayerRemoving:Connect(function(player: Player)
		playerLastShotTime[player] = nil
		playerLastSwordSwingTime[player] = nil
	end)

	Players.PlayerAdded:Connect(giveTools)
	for _, player in Players:GetPlayers() do
		giveTools(player)
	end
end

return WeaponService
