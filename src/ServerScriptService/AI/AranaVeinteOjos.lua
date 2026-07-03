--!strict
--[[
	AranaVeinteOjos.lua (ModuleScript)
	==================================
	Araña alienígena de 20 ojos: la reina del ecosistema. Caza astronautas
	Y TAMBIÉN Cucarones-Leones (los bichos se comen entre sí).

	Hereda el ciclo de caza de CriaturaBase y sobrescribe IntentarAtacar:
	su mordisco hace poco daño directo pero inyecta VENENO que sigue
	drenando salud durante varios segundos. Con 20 ojos, además, detecta
	presas desde más lejos que nadie.
]]

local CriaturaBase = require(script.Parent.CriaturaBase)

local AranaVeinteOjos = setmetatable({}, { __index = CriaturaBase })
AranaVeinteOjos.__index = AranaVeinteOjos

local CONFIG: CriaturaBase.Config = {
	RANGO_DETECCION = 160,   -- 20 ojos ven mucho más lejos
	RANGO_ATAQUE = 7,        -- patas largas
	DANIO = 8,               -- mordisco débil... pero venenoso
	ENFRIAMIENTO_ATAQUE = 2,
	VELOCIDAD = 22,          -- más rápida que un Cucarón
	CAZA_JUGADORES = true,
	PRESAS = { "CucaronLeon", "BichoMenor" },

	AGENT_PARAMS = {
		AgentRadius = 5,     -- las patas ocupan mucho
		AgentHeight = 6,
		AgentCanJump = true,
		WaypointSpacing = 4,
	},
}

local VENENO = {
	TICKS = 4,               -- número de pulsos de veneno
	DANIO_POR_TICK = 3,
	INTERVALO = 1,           -- segundos entre pulsos
}

--------------------------------------------------------------------
-- Veneno: daño residual tras el mordisco.
-- El atributo "Envenenado" evita acumular varios venenos a la vez
-- y permite que la UI o efectos visuales reaccionen al estado.
--------------------------------------------------------------------
local function aplicarVeneno(presa: Model)
	local humanoid = presa:FindFirstChildOfClass("Humanoid")
	if not humanoid or presa:GetAttribute("Envenenado") then
		return
	end

	presa:SetAttribute("Envenenado", true)

	task.spawn(function()
		for _ = 1, VENENO.TICKS do
			task.wait(VENENO.INTERVALO)
			if humanoid.Health <= 0 or not humanoid.Parent then
				break
			end
			humanoid:TakeDamage(VENENO.DANIO_POR_TICK)
		end
		if presa.Parent then
			presa:SetAttribute("Envenenado", nil)
		end
	end)
end

--------------------------------------------------------------------
-- Constructor y ataque venenoso
--------------------------------------------------------------------
function AranaVeinteOjos.new(model: Model)
	local self = CriaturaBase.new(model, CONFIG)
	return setmetatable(self :: any, AranaVeinteOjos)
end

function AranaVeinteOjos.IntentarAtacar(self: any, presa: Model): boolean
	local golpeo = CriaturaBase.IntentarAtacar(self, presa)
	if golpeo then
		aplicarVeneno(presa)
	end
	return golpeo
end

return AranaVeinteOjos
