--!strict
--[[
	ConsumableSystem.server.lua (Script de servidor)
	================================================
	Consumibles de supervivencia repartidos por los restos de la estación.
	En un mundo sin agua, las cápsulas de agua reciclada son oro puro.

	Convención: dentro de Workspace/Consumibles, cualquier BasePart cuyo
	nombre coincida con una entrada de la tabla CONSUMIBLES recibe un
	ProximityPrompt y aplica su efecto al usarse.

	Ubicación: ServerScriptService/Core/ConsumableSystem
]]

local StatsService = require(script.Parent.Parent.Modules.StatsService)

--------------------------------------------------------------------
-- Catálogo de consumibles: añade nuevos sin tocar la lógica
--------------------------------------------------------------------
type Consumible = {
	Accion: string,
	Efecto: (stats: any) -> (),
}

local CONSUMIBLES: { [string]: Consumible } = {
	CapsulaAgua = {
		Accion = "Beber agua reciclada",
		Efecto = function(stats)
			stats:ModificarSed(40)
		end,
	},
	BateriaTraje = {
		Accion = "Recargar traje",
		Efecto = function(stats)
			stats:ModificarEnergia(50)
		end,
	},
	RacionMedica = {
		Accion = "Usar botiquín",
		Efecto = function(stats)
			stats:Curar(35)
		end,
	},
}

--------------------------------------------------------------------
-- Carpeta de consumibles en el mundo
--------------------------------------------------------------------
local carpeta = workspace:FindFirstChild("Consumibles") or Instance.new("Folder")
carpeta.Name = "Consumibles"
carpeta.Parent = workspace

local function prepararConsumible(instancia: Instance)
	if not instancia:IsA("BasePart") then
		return
	end

	local definicion = CONSUMIBLES[instancia.Name]
	if not definicion then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = definicion.Accion
	prompt.ObjectText = instancia.Name
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 8
	prompt.Parent = instancia

	prompt.Triggered:Connect(function(player)
		local stats = StatsService.Obtener(player)
		if not stats then
			return
		end

		-- Desactivar primero: evita el doble uso si dos jugadores
		-- lo activan en el mismo frame
		if not prompt.Enabled then
			return
		end
		prompt.Enabled = false

		definicion.Efecto(stats)
		instancia:Destroy()
	end)
end

for _, instancia in carpeta:GetChildren() do
	prepararConsumible(instancia)
end
carpeta.ChildAdded:Connect(prepararConsumible)
