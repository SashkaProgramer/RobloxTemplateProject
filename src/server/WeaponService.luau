--!strict

local Players = game:GetService("Players")
local StarterPack = game:GetService("StarterPack")

local WeaponService = {}

local function createPipeTool(onAttack: (player: Player) -> ())
	local tool = Instance.new("Tool")
	tool.Name = "Rusty Pipe"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Melee weapon"
	tool.Grip = CFrame.new(0, -0.2, 0.4) * CFrame.Angles(0, 0, math.rad(90))

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Cylinder
	handle.Size = Vector3.new(2.6, 0.35, 0.35)
	handle.Material = Enum.Material.Metal
	handle.Color = Color3.fromRGB(132, 123, 116)
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	tool.Activated:Connect(function()
		local character = tool.Parent
		if not character or not character:IsA("Model") then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if player then
			onAttack(player)
		end
	end)

	return tool
end

function WeaponService.Start(onAttack: (player: Player) -> ())
	local function giveTool(player: Player)
		local function cloneInto(container: Instance): Tool?
			local existing = container:FindFirstChild("Rusty Pipe")
			if existing and existing:IsA("Tool") then
				return existing
			end
			local tool = createPipeTool(onAttack)
			tool.Parent = container
			return tool
		end

		local backpack = player:FindFirstChildOfClass("Backpack")
		if backpack then
			local tool = cloneInto(backpack)
			local character = player.Character
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			if tool and humanoid then
				humanoid:EquipTool(tool)
			end
		end

		player.CharacterAdded:Connect(function()
			local nextBackpack = player:WaitForChild("Backpack")
			local tool = cloneInto(nextBackpack)
			local character = player.Character or player.CharacterAdded:Wait()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if tool and humanoid then
				humanoid:EquipTool(tool)
			end
		end)
	end

	if not StarterPack:FindFirstChild("Rusty Pipe") then
		local template = createPipeTool(onAttack)
		template.Parent = StarterPack
	end

	Players.PlayerAdded:Connect(giveTool)
	for _, player in Players:GetPlayers() do
		giveTool(player)
	end
end

return WeaponService
