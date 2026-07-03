# 🛠️ Cómo montar Astroluna en Roblox Studio

Hay dos caminos: **copiar los scripts a mano** (5 minutos, ideal para empezar)
o **sincronizar con Rojo** (el flujo profesional, edita en VS Code y Studio se
actualiza solo).

## Regla de oro: el sufijo del archivo dice qué instancia crear

| Sufijo del archivo | Instancia en Studio | Cómo crearla |
| --- | --- | --- |
| `.lua` | **ModuleScript** | ➕ junto al padre → ModuleScript |
| `.server.lua` | **Script** (servidor) | ➕ junto al padre → Script |
| `.client.lua` | **LocalScript** (cliente) | ➕ junto al padre → LocalScript |

El nombre de la instancia es el nombre del archivo **sin sufijos**:
`PlayerStats.lua` → ModuleScript llamado `PlayerStats`,
`ThirstSystem.server.lua` → Script llamado `ThirstSystem`.

## Opción A — Montaje manual (recomendada para empezar)

1. Abre Roblox Studio → **New** → plantilla **Baseplate**.
2. Activa las ventanas **Explorer** y **Output** (pestaña *View*): el Output
   te mostrará cualquier error de los scripts.
3. En el **Explorer**, pasa el ratón sobre `ServerScriptService`, pulsa el
   **➕** y crea tres **Folder** llamadas: `Modules`, `Core` y `AI`.
4. Crea cada instancia y pégale dentro el contenido del archivo del repo
   (abre el `.lua` en GitHub o en un editor, Ctrl+A, Ctrl+C, y en Studio
   doble clic en la instancia, borra el `print` de ejemplo y Ctrl+V):

```
ServerScriptService
├── Modules (Folder)
│   ├── PlayerStats      → ModuleScript ← src/ServerScriptService/Modules/PlayerStats.lua
│   └── StatsService     → ModuleScript ← src/ServerScriptService/Modules/StatsService.lua
├── Core (Folder)
│   ├── ThirstSystem     → Script       ← src/ServerScriptService/Core/ThirstSystem.server.lua
│   ├── NucleoSystem     → Script       ← src/ServerScriptService/Core/NucleoSystem.server.lua
│   ├── ConsumableSystem → Script       ← src/ServerScriptService/Core/ConsumableSystem.server.lua
│   └── RobotSystem      → Script       ← src/ServerScriptService/Core/RobotSystem.server.lua
└── AI (Folder)
    ├── CriaturaBase     → ModuleScript ← src/ServerScriptService/AI/CriaturaBase.lua
    ├── CucaronLeon      → ModuleScript ← src/ServerScriptService/AI/CucaronLeon.lua
    ├── AranaVeinteOjos  → ModuleScript ← src/ServerScriptService/AI/AranaVeinteOjos.lua
    ├── RobotAliado      → ModuleScript ← src/ServerScriptService/AI/RobotAliado.lua
    └── EnemySpawner     → Script       ← src/ServerScriptService/AI/EnemySpawner.server.lua

StarterPlayer
└── StarterPlayerScripts
    └── StatsHUD         → LocalScript  ← src/StarterPlayer/StarterPlayerScripts/StatsHUD.client.lua
```

> ⚠️ Los tres puntos que más fallan:
> - `StatsHUD` debe ser **LocalScript** (un Script normal ahí no funciona).
> - Los ModuleScripts van en **carpetas con esos nombres exactos**: los
>   `require(script.Parent...)` dependen de esa jerarquía.
> - Respeta mayúsculas/minúsculas en los nombres.

5. Pulsa **Play (F5)**. No necesitas construir nada: los scripts generan
   placeholders (núcleos, nave, manada de bichos) en una Baseplate vacía.

### Qué deberías ver al darle a Play

- Barras de **Salud / Sed / Energía** abajo a la izquierda, y `⚡ Núcleos: 0/5`
  arriba. La sed baja poco a poco (rápido bajo el sol, lento bajo techo).
- 5 esferas azules de neón (núcleos), un panel metálico (la nave), bichos de
  colores merodeando y tu **robot** flotando a tu lado.
- Acércate a un Cucarón (marrón): te perseguirá y tu robot lo interceptará.
- La araña morada cazará Cucarones por su cuenta: el ecosistema vive solo.
- Recoge un núcleo (tecla E), llévalo al panel e instálalo. Con los 5:
  pantalla de victoria.

### Probar en multijugador

Pestaña **Test** → sección *Clients and Servers* → elige **2 Players** →
**Start**. Studio abre un servidor y dos clientes: verás que cada astronauta
tiene su robot y que si un portador muere, el núcleo cae y otro lo recupera.

## Opción B — Rojo (flujo profesional)

[Rojo](https://rojo.space) sincroniza esta carpeta con Studio en tiempo real:
editas en VS Code, guardas, y Studio se actualiza. El repo ya incluye el
`default.project.json` configurado.

1. Instala el CLI: `aftman add rojo-rbx/rojo` (o descarga el binario de
   [github.com/rojo-rbx/rojo/releases](https://github.com/rojo-rbx/rojo/releases)).
2. Instala el **plugin de Rojo** en Studio (botón *Install Rojo Studio Plugin*
   en la web de Rojo, o desde el CLI: `rojo plugin install`).
3. Clona el repo y arranca el servidor de sincronización:
   ```bash
   git clone https://github.com/pedroparradovargas/astronauta_aventurero.git
   cd astronauta_aventurero
   rojo serve
   ```
4. En Studio (con tu place Baseplate abierto): pestaña *Plugins* → **Rojo** →
   **Connect**. Verás aparecer todas las carpetas y scripts en el Explorer.
5. A partir de ahí, cualquier cambio en `src/` aparece en Studio al guardar.

> Con Rojo, los sufijos `.server.lua` / `.client.lua` / `.lua` se convierten
> automáticamente en Script / LocalScript / ModuleScript: por eso los archivos
> se llaman así.

## Sustituir los placeholders por tu mapa real

Cuando construyas el mapa de verdad, los scripts detectan tus modelos y dejan
de generar placeholders:

- **Núcleos**: carpeta `Workspace/Nucleos` con Parts llamadas `Nucleo1`…`Nucleo5`
  (ancladas, donde quieras esconderlas).
- **Nave**: Model `Workspace/NaveEscape` con una Part llamada `PanelNucleos`.
- **Fauna**: carpeta `Workspace/Enemigos` con Models llamados `CucaronLeon*`,
  `AranaVeinteOjos*`, `BichoMenor*`. Cada Model necesita un `Humanoid` y una
  Part `HumanoidRootPart` (usa tus mallas soldadas a esa raíz).
- **Robot**: pon tu modelo bonito en `ServerStorage` llamado `RobotAliado`
  (con `Humanoid` + `HumanoidRootPart`) y el sistema lo clonará en vez del cubo.
- **Consumibles**: carpeta `Workspace/Consumibles` con Parts llamadas
  `CapsulaAgua`, `BateriaTraje` o `RacionMedica`.
- **Refugios**: cualquier techo (Part) sobre el jugador cuenta como sombra
  para el sistema de sed — construye refugios y se notará solo.
- **Zonas peligrosas**: añade un `PathfindingModifier` con Label `LavaSolar`
  a una Part y los Cucarones intentarán rodearla.
