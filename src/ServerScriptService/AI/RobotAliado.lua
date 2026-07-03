--!strict
--[[
	RobotAliado.lua (ModuleScript)
	==============================
	Compañero robótico del astronauta. No caza por instinto: SIRVE.

	Comportamiento (en orden de prioridad):
	  1. Si hay un bicho hostil cerca de su dueño → interceptarlo y
	     dispararle descargas eléctricas.
	  2. Si su dueño se aleja → seguirlo (reutiliza IrHacia de
	     CriaturaBase, con pathfinding y esquive de obstáculos).
	  3. Si está al lado de su dueño → esperar en guardia.

	Hereda de CriaturaBase para reutilizar el desplazamiento y el ataque,
	pero reemplaza el bucle de caza por un bucle de escolta.
]]

local CriaturaBase = require(script.Parent.CriaturaBase)

local RobotAliado = setmetatable({}, { __index = CriaturaBase })
RobotAliado.__index = RobotAliado

local CONFIG: CriaturaBase.Config = {
	RANGO_ATAQUE = 8,        -- alcance de la descarga eléctrica
	DANIO = 8,
	ENFRIAMIENTO_ATAQUE = 1,
	RECALCULO_RUTA = 0.4,
	VELOCIDAD = 20,          -- un poco más rápido que su dueño
	CAZA_JUGADORES = false,  -- jamás ataca astronautas
	PRESAS = {},

	AGENT_PARAMS = {
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		WaypointSpacing = 4,
	},
}

local RANGO_DEFENSA = 35       -- studs alrededor del dueño que vigila
local DISTANCIA_SEGUIMIENTO = 8 -- si el dueño se aleja más, lo sigue

--------------------------------------------------------------------
-- Constructor
--------------------------------------------------------------------
function RobotAliado.new(model: Model, dueno: Player)
	local self = CriaturaBase.new(model, CONFIG) :: any
	self.Dueno = dueno
	return setmetatable(self, RobotAliado)
end

--------------------------------------------------------------------
-- ¿Hay algún bicho amenazando a mi dueño?
--------------------------------------------------------------------
function RobotAliado.BuscarAmenaza(self: any): Model?
	local character = self.Dueno.Character
	local raizDueno = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not raizDueno then
		return nil
	end

	local carpeta = workspace:FindFirstChild("Enemigos")
	if not carpeta then
		return nil
	end

	local amenazaCercana: Model? = nil
	local distanciaMinima = RANGO_DEFENSA

	for _, model in carpeta:GetChildren() do
		if not model:IsA("Model") then
			continue
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local raiz = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and humanoid.Health > 0 and raiz then
			local distancia = (raiz.Position - raizDueno.Position).Magnitude
			if distancia < distanciaMinima then
				distanciaMinima = distancia
				amenazaCercana = model
			end
		end
	end

	return amenazaCercana
end

--------------------------------------------------------------------
-- Bucle de escolta (reemplaza al bucle de caza de la base)
--------------------------------------------------------------------
function RobotAliado.IniciarServicio(self: any)
	if self.Cazando then
		return
	end
	self.Cazando = true

	task.spawn(function()
		while self.Cazando and self.Humanoid.Health > 0 do
			local character = self.Dueno.Character
			local raizDueno = character
				and character:FindFirstChild("HumanoidRootPart") :: BasePart?

			local amenaza = self:BuscarAmenaza()

			if amenaza then
				-- 1) Defender: interceptar al bicho y zapearlo
				self:PerseguirA(amenaza)
				self:IntentarAtacar(amenaza)
			elseif raizDueno
				and (raizDueno.Position - self.Raiz.Position).Magnitude > DISTANCIA_SEGUIMIENTO
			then
				-- 2) Seguir a su dueño esquivando obstáculos
				self:IrHacia(raizDueno.Position, 3)
			else
				-- 3) En guardia junto a su dueño
				task.wait(0.5)
			end

			task.wait(self.Config.RECALCULO_RUTA)
		end
	end)
end

return RobotAliado
