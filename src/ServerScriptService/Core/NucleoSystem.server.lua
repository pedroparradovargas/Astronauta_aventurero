--!strict
--[[
	NucleoSystem.server.lua (Script de servidor)
	============================================
	Objetivo de escape de Astroluna: encontrar los 5 Núcleos de energía
	repartidos por los planetas e instalarlos en la Nave de Escape.

	Flujo:
	  1. Cada BasePart llamada "Nucleo*" dentro de Workspace/Nucleos recibe
	     un ProximityPrompt "Recoger Núcleo".
	  2. Al recogerlo, el núcleo se suelda a la espalda del astronauta
	     (todos ven quién lo lleva: ¡es un objetivo andante para los bichos!).
	  3. Si el portador muere, el núcleo cae donde murió y puede recogerse.
	  4. En la nave (Workspace/NaveEscape/PanelNucleos) se instala con otro
	     ProximityPrompt. Con los 5 instalados, ¡victoria y escape!

	Si el mapa aún no tiene núcleos o nave, el script crea placeholders
	para poder probar en una Baseplate.

	Ubicación: ServerScriptService/Core/NucleoSystem
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TOTAL_NUCLEOS = 5

--------------------------------------------------------------------
-- RemoteEvent para el contador de núcleos y el mensaje de victoria
--------------------------------------------------------------------
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local nucleosRemote = Instance.new("RemoteEvent")
nucleosRemote.Name = "ActualizarNucleos"
nucleosRemote.Parent = remotes

--------------------------------------------------------------------
-- Placeholders para probar en una Baseplate vacía
--------------------------------------------------------------------
local function crearNucleoPlaceholder(indice: number): BasePart
	local nucleo = Instance.new("Part")
	nucleo.Name = "Nucleo" .. indice
	nucleo.Shape = Enum.PartType.Ball
	nucleo.Size = Vector3.new(2.5, 2.5, 2.5)
	nucleo.Material = Enum.Material.Neon
	nucleo.Color = Color3.fromRGB(0, 200, 255)
	nucleo.Anchored = true
	nucleo.CFrame = CFrame.new(indice * 40 - 120, 3, 60)
	return nucleo
end

local carpetaNucleos = workspace:FindFirstChild("Nucleos") :: Folder?
if not carpetaNucleos then
	carpetaNucleos = Instance.new("Folder")
	assert(carpetaNucleos)
	carpetaNucleos.Name = "Nucleos"
	for indice = 1, TOTAL_NUCLEOS do
		crearNucleoPlaceholder(indice).Parent = carpetaNucleos
	end
	carpetaNucleos.Parent = workspace
end

local nave = workspace:FindFirstChild("NaveEscape") :: Model?
local panel: BasePart
if nave and nave:FindFirstChild("PanelNucleos") then
	panel = nave:FindFirstChild("PanelNucleos") :: BasePart
else
	panel = Instance.new("Part")
	panel.Name = "PanelNucleos"
	panel.Size = Vector3.new(6, 8, 2)
	panel.Material = Enum.Material.Metal
	panel.Color = Color3.fromRGB(120, 120, 130)
	panel.Anchored = true
	panel.CFrame = CFrame.new(0, 4, -80)

	local naveNueva = Instance.new("Model")
	naveNueva.Name = "NaveEscape"
	panel.Parent = naveNueva
	naveNueva.Parent = workspace
end

--------------------------------------------------------------------
-- Estado de la partida
--------------------------------------------------------------------
local nucleosInstalados = 0
local nucleoPorPortador: { [Player]: BasePart } = {}

local function anunciarEstado()
	nucleosRemote:FireAllClients({
		Instalados = nucleosInstalados,
		Total = TOTAL_NUCLEOS,
		Victoria = nucleosInstalados >= TOTAL_NUCLEOS,
	})
end

--------------------------------------------------------------------
-- Soltar el núcleo (muerte o desconexión del portador)
--------------------------------------------------------------------
local function soltarNucleo(player: Player, posicion: Vector3?)
	local nucleo = nucleoPorPortador[player]
	if not nucleo then
		return
	end
	nucleoPorPortador[player] = nil

	local soldadura = nucleo:FindFirstChildOfClass("WeldConstraint")
	if soldadura then
		soldadura:Destroy()
	end

	nucleo.Anchored = true
	nucleo.CanCollide = true
	if posicion then
		nucleo.CFrame = CFrame.new(posicion + Vector3.yAxis * 3)
	end

	local prompt = nucleo:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = true
	end
end

--------------------------------------------------------------------
-- Recoger un núcleo: se suelda a la espalda del astronauta
--------------------------------------------------------------------
local function recogerNucleo(player: Player, nucleo: BasePart, prompt: ProximityPrompt)
	if nucleoPorPortador[player] then
		return -- solo un núcleo a la vez: hay que hacer viajes
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local torso = character and (character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")) :: BasePart?
	if not character or not humanoid or humanoid.Health <= 0 or not torso then
		return
	end

	prompt.Enabled = false
	nucleo.Anchored = false
	nucleo.CanCollide = false
	nucleo.Massless = true
	nucleo.CFrame = torso.CFrame * CFrame.new(0, 0.5, 1.8)

	local soldadura = Instance.new("WeldConstraint")
	soldadura.Part0 = torso
	soldadura.Part1 = nucleo
	soldadura.Parent = nucleo

	nucleoPorPortador[player] = nucleo

	-- Si el portador muere, el núcleo cae donde estaba él
	humanoid.Died:Once(function()
		local raiz = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		soltarNucleo(player, raiz and raiz.Position or nucleo.Position)
	end)
end

--------------------------------------------------------------------
-- Prompts de recogida en cada núcleo
--------------------------------------------------------------------
local function prepararNucleo(instancia: Instance)
	if not (instancia:IsA("BasePart") and instancia.Name:match("^Nucleo")) then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Recoger Núcleo"
	prompt.ObjectText = "Núcleo de energía"
	-- Ajuste táctil: mantener pulsado en pantalla cansa; pulsación corta
	-- y más alcance para compensar la puntería con joystick virtual
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.Parent = instancia

	prompt.Triggered:Connect(function(player)
		recogerNucleo(player, instancia, prompt)
	end)
end

assert(carpetaNucleos)
for _, instancia in carpetaNucleos:GetChildren() do
	prepararNucleo(instancia)
end
carpetaNucleos.ChildAdded:Connect(prepararNucleo)

--------------------------------------------------------------------
-- Prompt de instalación en la Nave de Escape
--------------------------------------------------------------------
local promptInstalar = Instance.new("ProximityPrompt")
promptInstalar.ActionText = "Instalar Núcleo"
promptInstalar.ObjectText = "Nave de Escape"
promptInstalar.HoldDuration = 1 -- ajuste táctil
promptInstalar.MaxActivationDistance = 14
promptInstalar.Parent = panel

promptInstalar.Triggered:Connect(function(player)
	local nucleo = nucleoPorPortador[player]
	if not nucleo then
		return -- no lleva nada que instalar
	end

	nucleoPorPortador[player] = nil
	nucleo:Destroy()

	nucleosInstalados += 1
	anunciarEstado()

	if nucleosInstalados >= TOTAL_NUCLEOS then
		-- ¡Escape conseguido! La nave se enciende.
		panel.Material = Enum.Material.Neon
		panel.Color = Color3.fromRGB(0, 255, 130)
	end
end)

--------------------------------------------------------------------
-- Limpieza y estado inicial
--------------------------------------------------------------------
Players.PlayerRemoving:Connect(function(player)
	local character = player.Character
	local raiz = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	soltarNucleo(player, raiz and raiz.Position or nil)
end)

Players.PlayerAdded:Connect(function()
	task.wait(1) -- dar tiempo a que el cliente monte su HUD
	anunciarEstado()
end)
