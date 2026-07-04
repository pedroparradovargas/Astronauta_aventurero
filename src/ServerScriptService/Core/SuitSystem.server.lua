--!strict
--[[
	SuitSystem.server.lua (Script de servidor)
	===========================================
	Viste a cada jugador de Astronauta de Astroluna al aparecer.

	En Roblox el personaje jugable es el AVATAR del jugador (rig R15 con
	todas sus animaciones). El look de astronauta se consigue:
	  1. Soldando el equipo (casco + mochila) al personaje.
	  2. Pintando el cuerpo de blanco traje espacial (BodyColors).
	  3. Quitando la ropa del avatar para que se lea el traje.

	El equipo sale de ServerStorage/TrajeAstronauta si existe (las mallas
	del FBX de assets/, colocadas una vez alrededor de una Part de
	referencia — ver INSTALACION.md). Si no existe, se construye un traje
	placeholder por código: funciona en una Baseplate vacía.

	Ubicación: ServerScriptService/Core/SuitSystem
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local COLOR_TRAJE = BrickColor.new("Institutional white")

--------------------------------------------------------------------
-- Soldar una pieza al personaje (sin física propia, sin colisión)
--------------------------------------------------------------------
local function soldarPieza(pieza: BasePart, objetivo: BasePart, cframe: CFrame)
	pieza.CFrame = cframe
	pieza.Anchored = false
	pieza.CanCollide = false
	pieza.Massless = true

	local soldadura = Instance.new("WeldConstraint")
	soldadura.Part0 = objetivo
	soldadura.Part1 = pieza
	soldadura.Parent = pieza

	pieza.Parent = objetivo.Parent
end

--------------------------------------------------------------------
-- Opción A: equipo importado del FBX (ServerStorage/TrajeAstronauta)
-- Convención: el Model contiene una Part invisible llamada "Referencia"
-- colocada donde estaría el PECHO. Cada malla se recoloca respecto al
-- UpperTorso real usando su posición relativa a esa referencia.
--------------------------------------------------------------------
local function equiparDesdePlantilla(plantilla: Model, torso: BasePart): boolean
	local referencia = plantilla:FindFirstChild("Referencia") :: BasePart?
	if not referencia then
		warn("SuitSystem: ServerStorage/TrajeAstronauta necesita una Part 'Referencia' en el pecho")
		return false
	end

	local copia = plantilla:Clone()
	local refCopia = copia:FindFirstChild("Referencia") :: BasePart

	for _, pieza in copia:GetChildren() do
		if pieza:IsA("BasePart") and pieza ~= refCopia then
			local relativo = refCopia.CFrame:ToObjectSpace(pieza.CFrame)
			soldarPieza(pieza, torso, torso.CFrame * relativo)
		end
	end

	copia:Destroy() -- ya vaciado: solo quedaba la Referencia
	return true
end

--------------------------------------------------------------------
-- Opción B: traje placeholder construido por código
--------------------------------------------------------------------
local function crearParte(nombre: string, forma: Enum.PartType?, tamano: Vector3, color: Color3, material: Enum.Material): BasePart
	local pieza = Instance.new("Part")
	if forma then
		pieza.Shape = forma
	end
	pieza.Name = nombre
	pieza.Size = tamano
	pieza.Color = color
	pieza.Material = material
	return pieza
end

local function equiparPlaceholder(character: Model, torso: BasePart)
	local head = character:FindFirstChild("Head") :: BasePart?
	if head then
		-- burbuja del casco
		local casco = crearParte("Casco", Enum.PartType.Ball, Vector3.new(1.9, 1.9, 1.9),
			Color3.fromRGB(235, 235, 242), Enum.Material.SmoothPlastic)
		soldarPieza(casco, head, head.CFrame * CFrame.new(0, 0.1, 0))

		-- visor dorado
		local visor = crearParte("Visor", Enum.PartType.Ball, Vector3.new(1.25, 1.1, 1.1),
			Color3.fromRGB(240, 165, 40), Enum.Material.Foil)
		visor.Reflectance = 0.4
		soldarPieza(visor, head, head.CFrame * CFrame.new(0, 0.12, -0.45))
	end

	-- mochila de soporte vital
	local mochila = crearParte("Mochila", nil, Vector3.new(1.7, 2.0, 0.7),
		Color3.fromRGB(190, 198, 208), Enum.Material.Metal)
	soldarPieza(mochila, torso, torso.CFrame * CFrame.new(0, 0.1, 0.85))

	for lado = -1, 1, 2 do
		local tanque = crearParte("Tanque", Enum.PartType.Cylinder, Vector3.new(1.7, 0.65, 0.65),
			Color3.fromRGB(242, 115, 20), Enum.Material.Metal)
		-- el eje de un cilindro es X: rotarlo para ponerlo vertical
		soldarPieza(tanque, torso,
			torso.CFrame * CFrame.new(lado * 0.45, 0.05, 1.3) * CFrame.Angles(0, 0, math.rad(90)))
	end
end

--------------------------------------------------------------------
-- Pintura del traje y limpieza de ropa
--------------------------------------------------------------------
local function pintarTraje(character: Model)
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors.HeadColor = COLOR_TRAJE
		bodyColors.TorsoColor = COLOR_TRAJE
		bodyColors.LeftArmColor = COLOR_TRAJE
		bodyColors.RightArmColor = COLOR_TRAJE
		bodyColors.LeftLegColor = COLOR_TRAJE
		bodyColors.RightLegColor = COLOR_TRAJE
	end

	-- la ropa del avatar taparía el traje espacial
	for _, prenda in character:GetChildren() do
		if prenda:IsA("Shirt") or prenda:IsA("Pants") or prenda:IsA("ShirtGraphic") then
			prenda:Destroy()
		end
	end
end

--------------------------------------------------------------------
-- Vestir al astronauta en cada respawn
--------------------------------------------------------------------
local function vestirAstronauta(character: Model)
	-- R15 usa UpperTorso; R6 usa Torso
	local torso = (character:WaitForChild("UpperTorso", 5)
		or character:WaitForChild("Torso", 5)) :: BasePart?
	if not torso then
		return
	end

	pintarTraje(character)

	local plantilla = ServerStorage:FindFirstChild("TrajeAstronauta")
	if plantilla and plantilla:IsA("Model") and equiparDesdePlantilla(plantilla, torso) then
		return
	end
	equiparPlaceholder(character, torso)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(vestirAstronauta)
	if player.Character then
		vestirAstronauta(player.Character)
	end
end)
