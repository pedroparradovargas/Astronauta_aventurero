--!strict
--[[
	StatsHUD.client.lua (LocalScript)
	=================================
	Interfaz de supervivencia del astronauta:
	  - Barras de Salud, Sed y Energía del traje (esquina inferior izquierda).
	  - Contador de Núcleos instalados (parte superior).
	  - Pantalla de victoria cuando se instalan los 5 Núcleos.

	El cliente NUNCA calcula estadísticas: solo dibuja lo que el servidor
	envía por los RemoteEvents de ReplicatedStorage/Remotes.

	Ubicación: StarterPlayer/StarterPlayerScripts/StatsHUD
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local statsRemote = remotes:WaitForChild("ActualizarStats") :: RemoteEvent
local nucleosRemote = remotes:WaitForChild("ActualizarNucleos") :: RemoteEvent

--------------------------------------------------------------------
-- Construcción de la interfaz
--------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AstrolunaHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Panel de barras (inferior izquierda)
local panel = Instance.new("Frame")
panel.Name = "PanelStats"
panel.AnchorPoint = Vector2.new(0, 1)
panel.Position = UDim2.new(0, 20, 1, -20)
panel.Size = UDim2.fromOffset(260, 110)
panel.BackgroundColor3 = Color3.fromRGB(15, 20, 35)
panel.BackgroundTransparency = 0.25
panel.Parent = screenGui

local esquinas = Instance.new("UICorner")
esquinas.CornerRadius = UDim.new(0, 10)
esquinas.Parent = panel

local lista = Instance.new("UIListLayout")
lista.Padding = UDim.new(0, 8)
lista.HorizontalAlignment = Enum.HorizontalAlignment.Center
lista.VerticalAlignment = Enum.VerticalAlignment.Center
lista.Parent = panel

-- Crea una barra con etiqueta y devuelve su relleno para actualizarla
local function crearBarra(nombre: string, color: Color3): Frame
	local fondo = Instance.new("Frame")
	fondo.Name = "Barra" .. nombre
	fondo.Size = UDim2.new(1, -20, 0, 24)
	fondo.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
	fondo.Parent = panel

	local esquinasFondo = Instance.new("UICorner")
	esquinasFondo.CornerRadius = UDim.new(0, 6)
	esquinasFondo.Parent = fondo

	local relleno = Instance.new("Frame")
	relleno.Name = "Relleno"
	relleno.Size = UDim2.fromScale(1, 1)
	relleno.BackgroundColor3 = color
	relleno.BorderSizePixel = 0
	relleno.Parent = fondo

	local esquinasRelleno = Instance.new("UICorner")
	esquinasRelleno.CornerRadius = UDim.new(0, 6)
	esquinasRelleno.Parent = relleno

	local etiqueta = Instance.new("TextLabel")
	etiqueta.BackgroundTransparency = 1
	etiqueta.Size = UDim2.fromScale(1, 1)
	etiqueta.Font = Enum.Font.GothamBold
	etiqueta.TextSize = 13
	etiqueta.TextColor3 = Color3.new(1, 1, 1)
	etiqueta.TextStrokeTransparency = 0.4
	etiqueta.Text = nombre
	etiqueta.ZIndex = 2
	etiqueta.Parent = fondo

	return relleno
end

local rellenoSalud = crearBarra("Salud", Color3.fromRGB(235, 70, 70))
local rellenoSed = crearBarra("Sed", Color3.fromRGB(60, 170, 255))
local rellenoEnergia = crearBarra("Energía", Color3.fromRGB(255, 200, 60))

-- Contador de Núcleos (superior centro)
local contadorNucleos = Instance.new("TextLabel")
contadorNucleos.Name = "ContadorNucleos"
contadorNucleos.AnchorPoint = Vector2.new(0.5, 0)
contadorNucleos.Position = UDim2.new(0.5, 0, 0, 12)
contadorNucleos.Size = UDim2.fromOffset(240, 32)
contadorNucleos.BackgroundColor3 = Color3.fromRGB(15, 20, 35)
contadorNucleos.BackgroundTransparency = 0.25
contadorNucleos.Font = Enum.Font.GothamBold
contadorNucleos.TextSize = 18
contadorNucleos.TextColor3 = Color3.fromRGB(0, 220, 255)
contadorNucleos.Text = "⚡ Núcleos: 0/5"
contadorNucleos.Parent = screenGui

local esquinasContador = Instance.new("UICorner")
esquinasContador.CornerRadius = UDim.new(0, 8)
esquinasContador.Parent = contadorNucleos

--------------------------------------------------------------------
-- Actualización de las barras (con tween para que se vea suave)
--------------------------------------------------------------------
local TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function actualizarBarra(relleno: Frame, valor: number, maximo: number)
	local proporcion = math.clamp(valor / maximo, 0, 1)
	TweenService:Create(relleno, TWEEN_INFO, {
		Size = UDim2.fromScale(proporcion, 1),
	}):Play()

	-- Parpadeo de alerta cuando la estadística está crítica (< 20 %)
	relleno.BackgroundTransparency = if proporcion < 0.2 then 0.3 else 0
end

statsRemote.OnClientEvent:Connect(function(datos)
	actualizarBarra(rellenoSalud, datos.Salud, datos.SaludMaxima)
	actualizarBarra(rellenoSed, datos.Sed, datos.SedMaxima)
	actualizarBarra(rellenoEnergia, datos.EnergiaTraje, datos.EnergiaMaxima)
end)

--------------------------------------------------------------------
-- Contador de Núcleos y pantalla de victoria
--------------------------------------------------------------------
local function mostrarVictoria()
	local aviso = Instance.new("TextLabel")
	aviso.Name = "AvisoVictoria"
	aviso.AnchorPoint = Vector2.new(0.5, 0.5)
	aviso.Position = UDim2.fromScale(0.5, 0.4)
	aviso.Size = UDim2.fromOffset(600, 90)
	aviso.BackgroundTransparency = 1
	aviso.Font = Enum.Font.GothamBlack
	aviso.TextScaled = true
	aviso.TextColor3 = Color3.fromRGB(0, 255, 130)
	aviso.TextStrokeTransparency = 0.2
	aviso.Text = "🚀 ¡NAVE REPARADA! ¡ESCAPE DE ASTROLUNA!"
	aviso.Parent = screenGui
end

nucleosRemote.OnClientEvent:Connect(function(datos)
	contadorNucleos.Text = string.format("⚡ Núcleos: %d/%d", datos.Instalados, datos.Total)

	if datos.Victoria and not screenGui:FindFirstChild("AvisoVictoria") then
		mostrarVictoria()
	end
end)
