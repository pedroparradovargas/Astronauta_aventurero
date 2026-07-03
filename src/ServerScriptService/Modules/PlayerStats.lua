--!strict
--[[
	PlayerStats.lua (ModuleScript)
	==============================
	Clase OOP que encapsula las estadísticas de supervivencia de un Astronauta
	en Astroluna: Sed, Salud y Energía del Traje.

	Ubicación recomendada: ServerScriptService/Modules/PlayerStats
	(las estadísticas son autoritativas del servidor; el cliente solo
	recibe copias de lectura vía RemoteEvent para dibujar la interfaz).

	Uso:
		local PlayerStats = require(script.Parent.Modules.PlayerStats)
		local stats = PlayerStats.new(player)
		stats:ModificarSed(-1.5)          -- el calor de los soles deshidrata
		stats:ModificarEnergia(-0.5)      -- el traje consume energía
		stats.StatChanged.Event:Connect(function(nombre, valor, maximo) ... end)
]]

local PlayerStats = {}
PlayerStats.__index = PlayerStats

--------------------------------------------------------------------
-- Configuración de la clase
--------------------------------------------------------------------
local CONFIG = {
	SED_MAXIMA = 100,
	SALUD_MAXIMA = 100,
	ENERGIA_MAXIMA = 100,

	-- Daño por segundo cuando la sed llega a 0 (deshidratación total)
	DANIO_DESHIDRATACION = 4,

	-- Cuando la energía del traje llega a 0, el traje deja de refrigerar
	-- y la sed baja más rápido (multiplicador aplicado por ThirstSystem)
	MULTIPLICADOR_SIN_ENERGIA = 2,
}

export type PlayerStats = typeof(setmetatable(
	{} :: {
		Player: Player,
		Sed: number,
		Salud: number,
		EnergiaTraje: number,
		StatChanged: BindableEvent,
		Murio: BindableEvent,
		_conexiones: { RBXScriptConnection },
	},
	PlayerStats
))

--------------------------------------------------------------------
-- Constructor
--------------------------------------------------------------------
function PlayerStats.new(player: Player): PlayerStats
	local self = setmetatable({}, PlayerStats) :: PlayerStats

	self.Player = player
	self.Sed = CONFIG.SED_MAXIMA
	self.Salud = CONFIG.SALUD_MAXIMA
	self.EnergiaTraje = CONFIG.ENERGIA_MAXIMA

	-- Eventos para que otros sistemas (UI, logros, IA) reaccionen
	self.StatChanged = Instance.new("BindableEvent")
	self.Murio = Instance.new("BindableEvent")
	self._conexiones = {}

	-- Sincronizar la Salud con el Humanoid cada vez que aparece el personaje
	local function engancharPersonaje(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.MaxHealth = CONFIG.SALUD_MAXIMA
		humanoid.Health = self.Salud

		table.insert(self._conexiones, humanoid.HealthChanged:Connect(function(salud)
			self.Salud = salud
			self.StatChanged:Fire("Salud", self.Salud, CONFIG.SALUD_MAXIMA)
		end))

		table.insert(self._conexiones, humanoid.Died:Connect(function()
			self.Murio:Fire()
		end))
	end

	if player.Character then
		engancharPersonaje(player.Character)
	end
	table.insert(self._conexiones, player.CharacterAdded:Connect(engancharPersonaje))

	return self
end

--------------------------------------------------------------------
-- Métodos internos
--------------------------------------------------------------------
-- Aplica límites [0, máximo] y notifica el cambio una sola vez
local function asignar(self: PlayerStats, nombre: string, valor: number, maximo: number): number
	local nuevoValor = math.clamp(valor, 0, maximo)
	if (self :: any)[nombre] ~= nuevoValor then
		(self :: any)[nombre] = nuevoValor
		self.StatChanged:Fire(nombre, nuevoValor, maximo)
	end
	return nuevoValor
end

--------------------------------------------------------------------
-- API pública
--------------------------------------------------------------------
function PlayerStats.ModificarSed(self: PlayerStats, delta: number)
	asignar(self, "Sed", self.Sed + delta, CONFIG.SED_MAXIMA)
end

function PlayerStats.ModificarEnergia(self: PlayerStats, delta: number)
	asignar(self, "EnergiaTraje", self.EnergiaTraje + delta, CONFIG.ENERGIA_MAXIMA)
end

-- El daño pasa SIEMPRE por el Humanoid: así funcionan los ForceFields,
-- las animaciones de muerte y la reaparición estándar de Roblox.
function PlayerStats.AplicarDanio(self: PlayerStats, cantidad: number)
	local character = self.Player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:TakeDamage(cantidad)
	end
end

function PlayerStats.Curar(self: PlayerStats, cantidad: number)
	local character = self.Player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = math.min(humanoid.Health + cantidad, humanoid.MaxHealth)
	end
end

function PlayerStats.EstaDeshidratado(self: PlayerStats): boolean
	return self.Sed <= 0
end

function PlayerStats.TieneEnergia(self: PlayerStats): boolean
	return self.EnergiaTraje > 0
end

-- Empaqueta los valores para enviarlos al cliente por RemoteEvent
function PlayerStats.Serializar(self: PlayerStats)
	return {
		Sed = self.Sed,
		SedMaxima = CONFIG.SED_MAXIMA,
		Salud = self.Salud,
		SaludMaxima = CONFIG.SALUD_MAXIMA,
		EnergiaTraje = self.EnergiaTraje,
		EnergiaMaxima = CONFIG.ENERGIA_MAXIMA,
	}
end

-- Limpieza obligatoria cuando el jugador abandona la partida
function PlayerStats.Destroy(self: PlayerStats)
	for _, conexion in self._conexiones do
		conexion:Disconnect()
	end
	table.clear(self._conexiones)
	self.StatChanged:Destroy()
	self.Murio:Destroy()
end

PlayerStats.CONFIG = CONFIG

return PlayerStats
