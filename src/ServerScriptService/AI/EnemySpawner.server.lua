--!strict
--[[
	EnemySpawner.server.lua (Script de servidor)
	============================================
	Activa la IA de todos los Cucarones-Leones colocados en
	Workspace/Enemigos y de los que aparezcan después (huevos, oleadas).

	Convención: cualquier Model dentro de Workspace/Enemigos cuyo nombre
	empiece por "CucaronLeon" recibe la IA de caza.
]]

local CucaronLeon = require(script.Parent.CucaronLeon)

local carpetaEnemigos = workspace:FindFirstChild("Enemigos") or Instance.new("Folder")
carpetaEnemigos.Name = "Enemigos"
carpetaEnemigos.Parent = workspace

local function activarEnemigo(model: Instance)
	if model:IsA("Model") and model.Name:match("^CucaronLeon") then
		local bicho = CucaronLeon.new(model)
		bicho:IniciarCaza()
	end
end

for _, model in carpetaEnemigos:GetChildren() do
	task.spawn(activarEnemigo, model)
end

carpetaEnemigos.ChildAdded:Connect(activarEnemigo)
