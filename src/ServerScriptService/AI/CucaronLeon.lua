--!strict
--[[
	CucaronLeon.lua (ModuleScript)
	==============================
	IA de caza del "Cucarón-León": depredador de 10 patas que persigue
	astronautas sin piedad usando PathfindingService para esquivar
	rocas, cráteres y restos de la estación.

	Requisitos del modelo en Workspace:
	  - Un Model con PrimaryPart llamada "HumanoidRootPart"
	  - Un Humanoid (controla el movimiento con :MoveTo())

	Uso (desde un Script de servidor):
		local CucaronLeon = require(script.Parent.CucaronLeon)
		local bicho = CucaronLeon.new(workspace.Enemigos.CucaronLeon1)
		bicho:IniciarCaza()
]]

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")

local CucaronLeon = {}
CucaronLeon.__index = CucaronLeon

--------------------------------------------------------------------
-- Configuración del depredador
--------------------------------------------------------------------
local CONFIG = {
	RANGO_DETECCION = 120,     -- studs a los que huele a un astronauta
	RANGO_ATAQUE = 6,          -- distancia de mordisco
	DANIO_MORDISCO = 15,
	ENFRIAMIENTO_ATAQUE = 1.5, -- segundos entre mordiscos
	RECALCULO_RUTA = 0.35,     -- cada cuánto se recalcula la ruta

	-- Parámetros del agente: un Cucarón-León es ancho y puede saltar
	AGENT_PARAMS = {
		AgentRadius = 4,
		AgentHeight = 5,
		AgentCanJump = true,
		WaypointSpacing = 4,
		Costs = {
			-- Ejemplo: si pintas zonas con PathfindingModifier "LavaSolar",
			-- el bicho preferirá rodearlas antes que cruzarlas.
			LavaSolar = 25,
		},
	},
}

export type CucaronLeon = typeof(setmetatable(
	{} :: {
		Model: Model,
		Humanoid: Humanoid,
		Raiz: BasePart,
		Cazando: boolean,
		_ultimoAtaque: number,
	},
	CucaronLeon
))

--------------------------------------------------------------------
-- Constructor
--------------------------------------------------------------------
function CucaronLeon.new(model: Model): CucaronLeon
	local self = setmetatable({}, CucaronLeon) :: CucaronLeon

	self.Model = model
	self.Humanoid = model:WaitForChild("Humanoid") :: Humanoid
	self.Raiz = model:WaitForChild("HumanoidRootPart") :: BasePart
	self.Cazando = false
	self._ultimoAtaque = 0

	-- Que el cadáver no estorbe el pathfinding de sus hermanos
	self.Humanoid.Died:Connect(function()
		self.Cazando = false
		task.delay(3, function()
			model:Destroy()
		end)
	end)

	return self
end

--------------------------------------------------------------------
-- Busca al astronauta vivo más cercano dentro del rango de detección
--------------------------------------------------------------------
function CucaronLeon.BuscarPresa(self: CucaronLeon): Model?
	local presaCercana: Model? = nil
	local distanciaMinima = CONFIG.RANGO_DETECCION

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local raiz = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?

		if character and humanoid and raiz and humanoid.Health > 0 then
			local distancia = (raiz.Position - self.Raiz.Position).Magnitude
			if distancia < distanciaMinima then
				distanciaMinima = distancia
				presaCercana = character
			end
		end
	end

	return presaCercana
end

--------------------------------------------------------------------
-- Calcula y recorre una ruta hasta la presa esquivando obstáculos
--------------------------------------------------------------------
function CucaronLeon.PerseguirA(self: CucaronLeon, presa: Model)
	local raizPresa = presa:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not raizPresa then
		return
	end

	local path = PathfindingService:CreatePath(CONFIG.AGENT_PARAMS)

	-- ComputeAsync puede fallar (presa inalcanzable): siempre en pcall
	local ok = pcall(function()
		path:ComputeAsync(self.Raiz.Position, raizPresa.Position)
	end)

	if not ok or path.Status ~= Enum.PathStatus.Success then
		-- Sin ruta válida: avanzar en línea recta como plan B
		self.Humanoid:MoveTo(raizPresa.Position)
		return
	end

	-- Si un derrumbe bloquea la ruta a mitad de camino, la abandonamos
	-- y el bucle de caza calculará una nueva en el siguiente ciclo.
	local rutaBloqueada = false
	local conexionBloqueo = path.Blocked:Connect(function()
		rutaBloqueada = true
	end)

	for indice, waypoint in path:GetWaypoints() do
		if rutaBloqueada or not self.Cazando then
			break
		end

		-- La presa se movió demasiado: recalcular antes de terminar la ruta
		if (raizPresa.Position - self.Raiz.Position).Magnitude > CONFIG.RANGO_DETECCION
			or indice > 5
		then
			break
		end

		if waypoint.Action == Enum.PathWaypointAction.Jump then
			self.Humanoid.Jump = true
		end

		self.Humanoid:MoveTo(waypoint.Position)
		self.Humanoid.MoveToFinished:Wait()
	end

	conexionBloqueo:Disconnect()
end

--------------------------------------------------------------------
-- Mordisco si la presa está al alcance
--------------------------------------------------------------------
function CucaronLeon.IntentarAtacar(self: CucaronLeon, presa: Model)
	local humanoidPresa = presa:FindFirstChildOfClass("Humanoid")
	local raizPresa = presa:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoidPresa or not raizPresa then
		return
	end

	local distancia = (raizPresa.Position - self.Raiz.Position).Magnitude
	local ahora = os.clock()

	if distancia <= CONFIG.RANGO_ATAQUE
		and ahora - self._ultimoAtaque >= CONFIG.ENFRIAMIENTO_ATAQUE
	then
		self._ultimoAtaque = ahora
		humanoidPresa:TakeDamage(CONFIG.DANIO_MORDISCO)
	end
end

--------------------------------------------------------------------
-- Bucle principal de caza
--------------------------------------------------------------------
function CucaronLeon.IniciarCaza(self: CucaronLeon)
	if self.Cazando then
		return
	end
	self.Cazando = true

	task.spawn(function()
		while self.Cazando and self.Humanoid.Health > 0 do
			local presa = self:BuscarPresa()

			if presa then
				self:PerseguirA(presa)
				self:IntentarAtacar(presa)
			else
				-- Sin presas cerca: merodear un punto aleatorio cercano
				local deriva = Vector3.new(math.random(-30, 30), 0, math.random(-30, 30))
				self.Humanoid:MoveTo(self.Raiz.Position + deriva)
				task.wait(2)
			end

			task.wait(CONFIG.RECALCULO_RUTA)
		end
	end)
end

function CucaronLeon.DetenerCaza(self: CucaronLeon)
	self.Cazando = false
end

return CucaronLeon
