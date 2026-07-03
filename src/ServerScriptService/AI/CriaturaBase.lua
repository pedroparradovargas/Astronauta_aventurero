--!strict
--[[
	CriaturaBase.lua (ModuleScript)
	===============================
	Clase base de toda la fauna alienígena de Astroluna.

	Implementa el ciclo depredador completo (buscar presa → ruta con
	PathfindingService → perseguir → atacar → merodear) de forma
	configurable, para que cada especie solo declare SU configuración
	y sobrescriba lo que la hace única:

		CucaronLeon     → hereda tal cual (caza jugadores y bichos menores)
		AranaVeinteOjos → sobrescribe IntentarAtacar para inyectar veneno
		RobotAliado     → reutiliza IrHacia para seguir a su dueño
		BichoMenor      → la base sin presas = herbívoro que merodea

	El ecosistema sale de la tabla PRESAS: cada especie declara los
	prefijos de nombre de los modelos que caza dentro de
	Workspace/Enemigos, además de si caza jugadores.
]]

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")

local CriaturaBase = {}
CriaturaBase.__index = CriaturaBase

--------------------------------------------------------------------
-- Configuración por defecto: un bicho menor inofensivo que merodea
--------------------------------------------------------------------
export type Config = {
	RANGO_DETECCION: number?,   -- studs a los que huele una presa
	RANGO_ATAQUE: number?,      -- distancia de mordisco
	DANIO: number?,
	ENFRIAMIENTO_ATAQUE: number?,
	RECALCULO_RUTA: number?,    -- cada cuánto se recalcula la ruta
	VELOCIDAD: number?,         -- WalkSpeed del Humanoid
	CAZA_JUGADORES: boolean?,
	PRESAS: { string }?,        -- prefijos de nombre en Workspace/Enemigos
	AGENT_PARAMS: { [string]: any }?,
}

local CONFIG_BASE: Config = {
	RANGO_DETECCION = 100,
	RANGO_ATAQUE = 6,
	DANIO = 10,
	ENFRIAMIENTO_ATAQUE = 1.5,
	RECALCULO_RUTA = 0.35,
	VELOCIDAD = 14,
	CAZA_JUGADORES = false,
	PRESAS = {},
	AGENT_PARAMS = {
		AgentRadius = 3,
		AgentHeight = 4,
		AgentCanJump = true,
		WaypointSpacing = 4,
	},
}

-- Mezcla la configuración de la especie sobre los valores por defecto
local function fusionarConfig(config: Config?): Config
	local resultado = table.clone(CONFIG_BASE)
	if config then
		for clave, valor in config :: { [string]: any } do
			(resultado :: { [string]: any })[clave] = valor
		end
	end
	return resultado
end

export type Criatura = typeof(setmetatable(
	{} :: {
		Model: Model,
		Humanoid: Humanoid,
		Raiz: BasePart,
		Config: Config,
		Cazando: boolean,
		_ultimoAtaque: number,
	},
	CriaturaBase
))

--------------------------------------------------------------------
-- Constructor (las subclases lo llaman y luego re-asignan su metatabla)
--------------------------------------------------------------------
function CriaturaBase.new(model: Model, config: Config?): Criatura
	local self = setmetatable({}, CriaturaBase) :: Criatura

	self.Model = model
	self.Humanoid = model:WaitForChild("Humanoid") :: Humanoid
	self.Raiz = model:WaitForChild("HumanoidRootPart") :: BasePart
	self.Config = fusionarConfig(config)
	self.Cazando = false
	self._ultimoAtaque = 0

	self.Humanoid.WalkSpeed = self.Config.VELOCIDAD :: number

	-- Que el cadáver no estorbe el pathfinding de los demás bichos
	self.Humanoid.Died:Connect(function()
		self.Cazando = false
		task.delay(3, function()
			model:Destroy()
		end)
	end)

	return self
end

--------------------------------------------------------------------
-- Búsqueda de presas: jugadores y/u otras criaturas del ecosistema
--------------------------------------------------------------------
local function estaViva(model: Model): (Humanoid?, BasePart?)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local raiz = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and humanoid.Health > 0 and raiz then
		return humanoid, raiz
	end
	return nil, nil
end

function CriaturaBase.BuscarPresa(self: Criatura): Model?
	local presaCercana: Model? = nil
	local distanciaMinima = self.Config.RANGO_DETECCION :: number

	local function considerar(model: Model)
		local _, raiz = estaViva(model)
		if raiz then
			local distancia = (raiz.Position - self.Raiz.Position).Magnitude
			if distancia < distanciaMinima then
				distanciaMinima = distancia
				presaCercana = model
			end
		end
	end

	-- 1) Astronautas (si la especie los caza)
	if self.Config.CAZA_JUGADORES then
		for _, player in Players:GetPlayers() do
			if player.Character then
				considerar(player.Character)
			end
		end
	end

	-- 2) Otras criaturas: los bichos se comen entre sí
	local carpeta = workspace:FindFirstChild("Enemigos")
	if carpeta then
		for _, prefijo in self.Config.PRESAS :: { string } do
			for _, model in carpeta:GetChildren() do
				if model ~= self.Model and model:IsA("Model")
					and model.Name:match("^" .. prefijo)
				then
					considerar(model)
				end
			end
		end
	end

	return presaCercana
end

--------------------------------------------------------------------
-- Desplazamiento con PathfindingService (esquivando obstáculos)
-- Recorre solo los primeros waypoints antes de devolver el control:
-- los objetivos se mueven y una ruta completa quedaría obsoleta.
--------------------------------------------------------------------
function CriaturaBase.IrHacia(self: Criatura, destino: Vector3, maxWaypoints: number?)
	local path = PathfindingService:CreatePath(self.Config.AGENT_PARAMS)

	-- ComputeAsync puede fallar (destino inalcanzable): siempre en pcall
	local ok = pcall(function()
		path:ComputeAsync(self.Raiz.Position, destino)
	end)

	if not ok or path.Status ~= Enum.PathStatus.Success then
		-- Sin ruta válida: avanzar en línea recta como plan B
		self.Humanoid:MoveTo(destino)
		return
	end

	-- Si un derrumbe bloquea la ruta a mitad de camino, la abandonamos
	local rutaBloqueada = false
	local conexionBloqueo = path.Blocked:Connect(function()
		rutaBloqueada = true
	end)

	local limite = maxWaypoints or 5
	for indice, waypoint in path:GetWaypoints() do
		if rutaBloqueada or self.Humanoid.Health <= 0 or indice > limite then
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

function CriaturaBase.PerseguirA(self: Criatura, presa: Model)
	local raizPresa = presa:FindFirstChild("HumanoidRootPart") :: BasePart?
	if raizPresa then
		self:IrHacia(raizPresa.Position)
	end
end

--------------------------------------------------------------------
-- Ataque cuerpo a cuerpo. Devuelve true si golpeó, para que las
-- subclases añadan efectos (veneno, aturdimiento...) solo al acertar.
--------------------------------------------------------------------
function CriaturaBase.IntentarAtacar(self: Criatura, presa: Model): boolean
	local humanoidPresa, raizPresa = estaViva(presa)
	if not humanoidPresa or not raizPresa then
		return false
	end

	local distancia = (raizPresa.Position - self.Raiz.Position).Magnitude
	local ahora = os.clock()

	if distancia <= (self.Config.RANGO_ATAQUE :: number)
		and ahora - self._ultimoAtaque >= (self.Config.ENFRIAMIENTO_ATAQUE :: number)
	then
		self._ultimoAtaque = ahora
		humanoidPresa:TakeDamage(self.Config.DANIO :: number)
		return true
	end

	return false
end

--------------------------------------------------------------------
-- Merodeo cuando no hay presas cerca
--------------------------------------------------------------------
function CriaturaBase.Merodear(self: Criatura)
	local deriva = Vector3.new(math.random(-30, 30), 0, math.random(-30, 30))
	self.Humanoid:MoveTo(self.Raiz.Position + deriva)
	task.wait(2)
end

--------------------------------------------------------------------
-- Bucle principal de caza
--------------------------------------------------------------------
function CriaturaBase.IniciarCaza(self: Criatura)
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
				self:Merodear()
			end

			task.wait(self.Config.RECALCULO_RUTA :: number)
		end
	end)
end

function CriaturaBase.DetenerCaza(self: Criatura)
	self.Cazando = false
end

return CriaturaBase
