--!strict
--[[
	StatsService.lua (ModuleScript)
	===============================
	Registro central de estadísticas: crea un PlayerStats por jugador,
	lo destruye al salir y replica cada cambio al cliente.

	Antes este registro vivía dentro de ThirstSystem, pero ahora varios
	sistemas necesitan acceder a las estadísticas (sed, consumibles,
	núcleos...), así que se extrae aquí como servicio compartido.

	Uso:
		local StatsService = require(ServerScriptService.Modules.StatsService)
		local stats = StatsService.Obtener(player)
		for player, stats in StatsService.Todos() do ... end
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStats = require(script.Parent.PlayerStats)

local StatsService = {}

--------------------------------------------------------------------
-- RemoteEvent para replicar las estadísticas al cliente (solo lectura)
--------------------------------------------------------------------
local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local statsRemote = Instance.new("RemoteEvent")
statsRemote.Name = "ActualizarStats"
statsRemote.Parent = remotes

--------------------------------------------------------------------
-- Registro por jugador
--------------------------------------------------------------------
local statsPorJugador: { [Player]: PlayerStats.PlayerStats } = {}

local function registrarJugador(player: Player)
	if statsPorJugador[player] then
		return
	end

	local stats = PlayerStats.new(player)
	statsPorJugador[player] = stats

	-- Cada cambio de estadística se replica al dueño de la UI
	stats.StatChanged.Event:Connect(function()
		statsRemote:FireClient(player, stats:Serializar())
	end)

	-- Al morir, restauramos sed y energía para el respawn
	stats.Murio.Event:Connect(function()
		stats:ModificarSed(PlayerStats.CONFIG.SED_MAXIMA)
		stats:ModificarEnergia(PlayerStats.CONFIG.ENERGIA_MAXIMA)
	end)

	-- Estado inicial para la UI
	statsRemote:FireClient(player, stats:Serializar())
end

Players.PlayerAdded:Connect(registrarJugador)

Players.PlayerRemoving:Connect(function(player)
	local stats = statsPorJugador[player]
	if stats then
		stats:Destroy()
		statsPorJugador[player] = nil
	end
end)

-- Jugadores que entraron antes de que este módulo se cargara
for _, player in Players:GetPlayers() do
	registrarJugador(player)
end

--------------------------------------------------------------------
-- API pública
--------------------------------------------------------------------
function StatsService.Obtener(player: Player): PlayerStats.PlayerStats?
	return statsPorJugador[player]
end

function StatsService.Todos(): { [Player]: PlayerStats.PlayerStats }
	return statsPorJugador
end

return StatsService
