--!strict
--[[
	ThirstSystem.server.lua (Script de servidor)
	============================================
	Sistema central de deshidratación de Astroluna.

	Los 5 soles abrasadores deshidratan a los astronautas de forma gradual.
	Cada "tick" el sistema:
	  1. Comprueba si el jugador está expuesto al sol (raycast hacia arriba).
	  2. Resta sed según la exposición y el estado del traje.
	  3. Si la sed llega a 0, aplica daño por deshidratación.

	El registro de jugadores y la replicación al cliente viven en
	Modules/StatsService; aquí solo está el bucle de deshidratación.

	Ubicación: ServerScriptService/Core/ThirstSystem
]]

local PlayerStats = require(script.Parent.Parent.Modules.PlayerStats)
local StatsService = require(script.Parent.Parent.Modules.StatsService)

--------------------------------------------------------------------
-- Configuración del sistema
--------------------------------------------------------------------
local TICK_SEGUNDOS = 1            -- frecuencia de actualización
local SED_POR_TICK_SOL = 0.8       -- deshidratación bajo los soles
local SED_POR_TICK_SOMBRA = 0.2    -- a la sombra o bajo techo se pierde menos
local ENERGIA_POR_TICK = 0.15      -- el traje gasta energía refrigerando
local ALTURA_RAYCAST = 500         -- distancia del rayo hacia el "cielo"

--------------------------------------------------------------------
-- ¿Está el astronauta expuesto a los soles?
-- Lanzamos un rayo hacia arriba: si no golpea nada, el sol le da de lleno.
--------------------------------------------------------------------
local function estaBajoElSol(character: Model): boolean
	local raiz = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not raiz then
		return false
	end

	local parametros = RaycastParams.new()
	parametros.FilterType = Enum.RaycastFilterType.Exclude
	parametros.FilterDescendantsInstances = { character }

	local resultado = workspace:Raycast(raiz.Position, Vector3.yAxis * ALTURA_RAYCAST, parametros)
	return resultado == nil -- nada bloquea el cielo => expuesto al sol
end

--------------------------------------------------------------------
-- Bucle principal de deshidratación
--------------------------------------------------------------------
while true do
	task.wait(TICK_SEGUNDOS)

	for player, stats in StatsService.Todos() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not humanoid or humanoid.Health <= 0 then
			continue
		end

		-- 1) Calcular pérdida de sed según exposición solar
		local perdida = if estaBajoElSol(character)
			then SED_POR_TICK_SOL
			else SED_POR_TICK_SOMBRA

		-- 2) Sin energía en el traje, la refrigeración falla: doble sed
		if not stats:TieneEnergia() then
			perdida *= PlayerStats.CONFIG.MULTIPLICADOR_SIN_ENERGIA
		end

		stats:ModificarSed(-perdida)
		stats:ModificarEnergia(-ENERGIA_POR_TICK)

		-- 3) Deshidratación total: el astronauta pierde salud
		if stats:EstaDeshidratado() then
			stats:AplicarDanio(PlayerStats.CONFIG.DANIO_DESHIDRATACION * TICK_SEGUNDOS)
		end
	end
end
