--!strict
--[[
	EnemySpawner.server.lua (Script de servidor)
	============================================
	Da vida a toda la fauna de Workspace/Enemigos, presente y futura
	(huevos, oleadas, migraciones entre planetas).

	Convención: el PREFIJO del nombre del Model decide su especie:
	  CucaronLeon*     → depredador que caza astronautas y bichos menores
	  AranaVeinteOjos* → caza astronautas Y Cucarones (veneno)
	  BichoMenor*      → presa pacífica que merodea (base del ecosistema)

	Si la carpeta está vacía, se generan placeholders para probar el
	ecosistema completo en una Baseplate.
]]

local CriaturaBase = require(script.Parent.CriaturaBase)
local CucaronLeon = require(script.Parent.CucaronLeon)
local AranaVeinteOjos = require(script.Parent.AranaVeinteOjos)

--------------------------------------------------------------------
-- Registro de especies: prefijo de nombre → clase de IA
--------------------------------------------------------------------
local ESPECIES: { [string]: any } = {
	CucaronLeon = CucaronLeon,
	AranaVeinteOjos = AranaVeinteOjos,
	BichoMenor = CriaturaBase, -- la base sin presas = herbívoro errante
}

local carpetaEnemigos = workspace:FindFirstChild("Enemigos") or Instance.new("Folder")
carpetaEnemigos.Name = "Enemigos"
carpetaEnemigos.Parent = workspace

--------------------------------------------------------------------
-- Placeholders para probar el ecosistema en una Baseplate vacía
--------------------------------------------------------------------
local APARIENCIAS = {
	CucaronLeon = { Color = Color3.fromRGB(160, 90, 30), Tamano = Vector3.new(4, 2.5, 6) },
	AranaVeinteOjos = { Color = Color3.fromRGB(40, 15, 60), Tamano = Vector3.new(5, 3, 5) },
	BichoMenor = { Color = Color3.fromRGB(90, 200, 120), Tamano = Vector3.new(2, 1.5, 3) },
}

local function construirCriaturaPlaceholder(especie: string, indice: number, posicion: Vector3): Model
	local apariencia = APARIENCIAS[especie]

	local model = Instance.new("Model")
	model.Name = especie .. indice

	local raiz = Instance.new("Part")
	raiz.Name = "HumanoidRootPart"
	raiz.Size = apariencia.Tamano
	raiz.Color = apariencia.Color
	raiz.Material = Enum.Material.Slate
	raiz.CFrame = CFrame.new(posicion + Vector3.yAxis * 5)

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100

	raiz.Parent = model
	humanoid.Parent = model
	model.PrimaryPart = raiz

	return model
end

if #carpetaEnemigos:GetChildren() == 0 then
	-- Manada reducida para la versión móvil: cada Humanoid en movimiento
	-- se replica y se anima en el teléfono de todos los jugadores
	local manada = {
		{ Especie = "CucaronLeon", Posicion = Vector3.new(80, 0, 80) },
		{ Especie = "AranaVeinteOjos", Posicion = Vector3.new(0, 0, 140) },
		{ Especie = "BichoMenor", Posicion = Vector3.new(50, 0, 100) },
		{ Especie = "BichoMenor", Posicion = Vector3.new(-40, 0, 110) },
	}
	for indice, datos in manada do
		construirCriaturaPlaceholder(datos.Especie, indice, datos.Posicion).Parent = carpetaEnemigos
	end
end

--------------------------------------------------------------------
-- Activación de la IA según la especie
--------------------------------------------------------------------
local function activarEnemigo(model: Instance)
	if not model:IsA("Model") then
		return
	end

	for prefijo, clase in ESPECIES do
		if model.Name:match("^" .. prefijo) then
			local criatura = clase.new(model)
			criatura:IniciarCaza()
			break
		end
	end
end

for _, model in carpetaEnemigos:GetChildren() do
	task.spawn(activarEnemigo, model)
end

carpetaEnemigos.ChildAdded:Connect(activarEnemigo)
