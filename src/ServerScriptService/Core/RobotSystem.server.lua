--!strict
--[[
	RobotSystem.server.lua (Script de servidor)
	===========================================
	Asigna a cada astronauta su Robot aliado al aparecer.

	Si existe una plantilla en ServerStorage/RobotAliado se clona esa;
	si no, se construye un robot placeholder por código para poder
	probar en una Baseplate vacía.

	Ubicación: ServerScriptService/Core/RobotSystem
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local RobotAliado = require(script.Parent.Parent.AI.RobotAliado)

local carpetaRobots = workspace:FindFirstChild("Robots") or Instance.new("Folder")
carpetaRobots.Name = "Robots"
carpetaRobots.Parent = workspace

local robotPorJugador: { [Player]: Model } = {}

--------------------------------------------------------------------
-- Robot placeholder: cubo flotante con un ojo de neón
--------------------------------------------------------------------
local function construirRobotPlaceholder(): Model
	local model = Instance.new("Model")

	local raiz = Instance.new("Part")
	raiz.Name = "HumanoidRootPart"
	raiz.Size = Vector3.new(2, 2, 2)
	raiz.Material = Enum.Material.Metal
	raiz.Color = Color3.fromRGB(180, 185, 200)

	local ojo = Instance.new("Part")
	ojo.Name = "Ojo"
	ojo.Shape = Enum.PartType.Ball
	ojo.Size = Vector3.new(0.8, 0.8, 0.8)
	ojo.Material = Enum.Material.Neon
	ojo.Color = Color3.fromRGB(0, 220, 255)
	ojo.CanCollide = false
	ojo.Massless = true
	ojo.CFrame = raiz.CFrame * CFrame.new(0, 0.4, -1)

	local soldadura = Instance.new("WeldConstraint")
	soldadura.Part0 = raiz
	soldadura.Part1 = ojo
	soldadura.Parent = ojo

	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 1.5 -- flota un poco sobre el suelo
	humanoid.MaxHealth = 80
	humanoid.Health = 80

	raiz.Parent = model
	ojo.Parent = model
	humanoid.Parent = model
	model.PrimaryPart = raiz

	return model
end

local function crearModeloRobot(): Model
	local plantilla = ServerStorage:FindFirstChild("RobotAliado")
	if plantilla and plantilla:IsA("Model") then
		return plantilla:Clone()
	end
	return construirRobotPlaceholder()
end

--------------------------------------------------------------------
-- Ciclo de vida del robot: uno por astronauta, renace con él
--------------------------------------------------------------------
local function retirarRobot(player: Player)
	local robot = robotPorJugador[player]
	if robot then
		robotPorJugador[player] = nil
		robot:Destroy()
	end
end

local function desplegarRobot(player: Player, character: Model)
	retirarRobot(player) -- el robot anterior se recicla

	local raiz = character:WaitForChild("HumanoidRootPart") :: BasePart

	local robot = crearModeloRobot()
	robot.Name = "Robot_" .. player.Name
	robot:PivotTo(raiz.CFrame * CFrame.new(3, 0, 2)) -- aparece a su lado
	robot.Parent = carpetaRobots
	robotPorJugador[player] = robot

	local escolta = RobotAliado.new(robot, player)
	escolta:IniciarServicio()
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		desplegarRobot(player, character)
	end)
end)

Players.PlayerRemoving:Connect(retirarRobot)
