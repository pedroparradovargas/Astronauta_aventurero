--!strict
--[[
	CucaronLeon.lua (ModuleScript)
	==============================
	Depredador de 10 patas que caza astronautas SIN PIEDAD y, si no hay
	ninguno cerca, devora a los bichos menores del ecosistema.

	Hereda todo el ciclo de caza de CriaturaBase; aquí solo vive la
	configuración de la especie.

	Uso (desde un Script de servidor):
		local CucaronLeon = require(script.Parent.CucaronLeon)
		local bicho = CucaronLeon.new(workspace.Enemigos.CucaronLeon1)
		bicho:IniciarCaza()
]]

local CriaturaBase = require(script.Parent.CriaturaBase)

local CucaronLeon = setmetatable({}, { __index = CriaturaBase })
CucaronLeon.__index = CucaronLeon

local CONFIG: CriaturaBase.Config = {
	RANGO_DETECCION = 120,   -- olfato de gran depredador
	RANGO_ATAQUE = 6,
	DANIO = 15,              -- mordisco de 10 patas
	ENFRIAMIENTO_ATAQUE = 1.5,
	VELOCIDAD = 18,
	CAZA_JUGADORES = true,
	PRESAS = { "BichoMenor" },

	-- Un Cucarón-León es ancho y puede saltar cráteres
	AGENT_PARAMS = {
		AgentRadius = 4,
		AgentHeight = 5,
		AgentCanJump = true,
		WaypointSpacing = 4,
		Costs = {
			-- Zonas pintadas con PathfindingModifier "LavaSolar":
			-- prefiere rodearlas antes que cruzarlas
			LavaSolar = 25,
		},
	},
}

function CucaronLeon.new(model: Model)
	local self = CriaturaBase.new(model, CONFIG)
	return setmetatable(self :: any, CucaronLeon)
end

return CucaronLeon
