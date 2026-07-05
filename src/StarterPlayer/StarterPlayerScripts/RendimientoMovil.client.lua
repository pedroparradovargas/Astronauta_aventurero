--!strict
--[[
	RendimientoMovil.client.lua (LocalScript) — SOLO RAMA MÓVIL
	===========================================================
	Aligera el coste gráfico en el dispositivo. Todo lo que se toca aquí
	es LOCAL del cliente: no afecta al servidor ni a otros jugadores.

	La experiencia está pensada para publicarse restringida a
	teléfono/tablet (Game Settings → Basic Info → Playable Devices),
	pero comprobamos TouchEnabled igualmente para que las pruebas en
	Studio de escritorio no se vean afectadas.

	Ubicación: StarterPlayer/StarterPlayerScripts/RendimientoMovil
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local esMovil = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
if not esMovil then
	return
end

-- 1) Sombras dinámicas: lo más caro de dibujar en un teléfono
Lighting.GlobalShadows = false

-- 2) Efectos de postprocesado (Bloom, DepthOfField, SunRays...)
for _, efecto in Lighting:GetChildren() do
	if efecto:IsA("PostEffect") then
		efecto.Enabled = false
	end
end

-- 3) Decoración animada del Terrain (hierba alienígena, etc.)
local terrain = workspace.Terrain
terrain.Decoration = false

-- 4) Limitar el zoom de cámara: menos mundo visible = menos que dibujar
--    en un mapa abierto de 5 planetas
local player = Players.LocalPlayer
player.CameraMaxZoomDistance = 60
