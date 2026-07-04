# 🚀 Astroluna — Núcleo de sistemas (Luau / Roblox Studio)

Juego de supervivencia multijugador: una estación espacial se estrella en un
sistema de **5 planetas y 2 lunas** bajo **5 soles abrasadores** sin una gota
de agua. Los Astronautas y sus Robots aliados deben ensamblar **5 Núcleos de
energía** para escapar, mientras arañas de 20 ojos y **Cucarones-Leones** de
10 patas los cazan sin piedad.

> 🛠️ **¿Cómo lo monto en Roblox Studio?** Sigue la guía paso a paso de
> [INSTALACION.md](INSTALACION.md) (montaje manual en 5 minutos o
> sincronización con Rojo).

## 📁 Estructura del proyecto

El código de `src/` refleja la jerarquía que debes reproducir en Roblox Studio
(o sincronizar automáticamente con [Rojo](https://rojo.space) usando
`default.project.json`):

```
ServerScriptService
├── Modules                  (carpeta de ModuleScripts compartidos del servidor)
│   ├── PlayerStats          ← ModuleScript OOP: Sed, Salud, Energía del traje
│   └── StatsService         ← Registro central: un PlayerStats por jugador
├── Core                     (sistemas centrales del bucle de juego)
│   ├── ThirstSystem         ← Script: deshidratación por los 5 soles
│   ├── NucleoSystem         ← Script: los 5 Núcleos y la Nave de Escape
│   ├── ConsumableSystem     ← Script: cápsulas de agua, baterías, botiquines
│   ├── RobotSystem          ← Script: despliega un Robot aliado por astronauta
│   └── SuitSystem           ← Script: viste a cada jugador con el traje espacial
└── AI                       (inteligencia artificial de la fauna)
    ├── CriaturaBase         ← Clase base: caza + pathfinding configurable
    ├── CucaronLeon          ← Hereda de CriaturaBase (caza jugadores y bichos)
    ├── AranaVeinteOjos      ← Hereda y añade veneno (caza Cucarones también)
    ├── RobotAliado          ← Hereda el movimiento; bucle de escolta propio
    └── EnemySpawner         ← Script: activa la IA de Workspace/Enemigos

StarterPlayer
└── StarterPlayerScripts
    └── StatsHUD             ← LocalScript: barras de supervivencia y contador
```

### ¿Por qué esta estructura en `ServerScriptService`?

1. **Autoridad del servidor.** Las estadísticas (sed, energía) viven SOLO en el
   servidor. Si vivieran en el cliente, un exploiter podría congelarse la sed.
   El cliente recibe copias de solo lectura por el RemoteEvent
   `ReplicatedStorage/Remotes/ActualizarStats` y las usa únicamente para
   dibujar las barras de la interfaz.

2. **Módulos vs Scripts.** Los `ModuleScript` (`PlayerStats`, `CucaronLeon`)
   son *clases reutilizables* que no hacen nada por sí solas. Los `Script`
   (`ThirstSystem`, `EnemySpawner`) son los *puntos de entrada* que las
   instancian y ejecutan los bucles. Esto permite testear las clases de forma
   aislada y añadir más sistemas (hambre, oxígeno, arañas de 20 ojos) sin
   tocar el código existente.

3. **Un solo bucle por sistema.** `ThirstSystem` corre UN bucle que itera
   sobre todos los jugadores, en lugar de un bucle por jugador: mucho más
   barato y fácil de pausar/depurar.

4. **Un registro compartido.** `StatsService` es el único dueño del mapa
   jugador → `PlayerStats`. Cualquier sistema (sed, consumibles, futuros
   power-ups) obtiene las estadísticas con `StatsService.Obtener(player)`
   en lugar de mantener su propia copia.

## 🌡️ Cómo funciona el sistema de sed

Cada segundo, `ThirstSystem`:

1. Lanza un **raycast hacia arriba** desde el `HumanoidRootPart` de cada
   astronauta. Si el rayo no golpea nada, los soles le dan de lleno y pierde
   `0.8` de sed; bajo techo o a la sombra pierde solo `0.2`.
2. Descuenta energía del traje (la refrigeración consume batería). Si la
   energía llega a `0`, la sed baja **el doble de rápido**.
3. Si la sed llega a `0`, aplica daño de deshidratación a través de
   `Humanoid:TakeDamage()` (respeta ForceFields y la muerte estándar).
4. Replica los valores al cliente con `RemoteEvent:FireClient()` para la UI.

Todos los valores son constantes al inicio de cada archivo — balancea el juego
tocando la configuración, no la lógica.

## 🕷️ Ecosistema alienígena (PathfindingService + herencia)

`CriaturaBase.lua` implementa el ciclo clásico de un depredador de forma
**configurable**, y cada especie hereda de ella declarando solo su config:

```
buscar presa → calcular ruta (ComputeAsync) → recorrer waypoints → morder
      ↑                                                              │
      └────────────── recalcular cada 0.35 s ────────────────────────┘
```

| Especie | Caza jugadores | Caza bichos | Rasgo único |
| --- | --- | --- | --- |
| `CucaronLeon` | ✅ sin piedad | `BichoMenor` | mordisco fuerte, salta cráteres |
| `AranaVeinteOjos` | ✅ | `CucaronLeon`, `BichoMenor` | **veneno** (daño residual) y visión de 160 studs |
| `BichoMenor` | ❌ | — | presa pacífica: la base de la cadena alimenticia |

Los bichos **se comen entre sí**: la tabla `PRESAS` de cada especie lista los
prefijos de nombre que caza dentro de `Workspace/Enemigos`. La araña
sobrescribe `IntentarAtacar` para inyectar veneno solo cuando acierta —
ejemplo de cómo extender la base sin duplicar el pathfinding.

Detalles importantes del pathfinding (en `CriaturaBase:IrHacia`):

- `CreatePath` recibe `AgentRadius`/`AgentHeight` acordes al tamaño del bicho
  y `AgentCanJump = true` para saltar cráteres.
- `ComputeAsync` va **siempre dentro de `pcall`** (puede fallar si la presa es
  inalcanzable); como plan B avanza en línea recta.
- El evento `path.Blocked` abandona la ruta si un derrumbe la corta, y el
  bucle de caza calcula una nueva.
- Solo se recorren los primeros waypoints antes de recalcular: los astronautas
  se mueven, y una ruta completa quedaría obsoleta.
- La tabla `Costs` con `PathfindingModifier` permite que el bicho rodee zonas
  de "LavaSolar" que pintes en el mapa.

Para probarlo: pon en `Workspace/Enemigos` Models con `Humanoid` y
`HumanoidRootPart` llamados `CucaronLeon1`, `AranaVeinteOjos1`, `BichoMenor1`…
`EnemySpawner` les da vida automáticamente (también a los que aparezcan
después) y, si la carpeta está vacía, **genera una manada de placeholders**
para ver el ecosistema funcionando en una Baseplate.

## 🤖 Robots aliados

`RobotSystem` despliega un Robot junto a cada astronauta al aparecer (clona
`ServerStorage/RobotAliado` si existe; si no, construye un placeholder con un
ojo de neón). `RobotAliado` hereda el movimiento de `CriaturaBase` pero
reemplaza el bucle de caza por un **bucle de escolta** con prioridades:

1. **Defender**: si un bicho se acerca a menos de 35 studs de su dueño, lo
   intercepta y le lanza descargas eléctricas.
2. **Seguir**: si el dueño se aleja más de 8 studs, lo sigue con pathfinding.
3. **Guardia**: si está al lado de su dueño, espera vigilando.

El robot nunca ataca astronautas (`CAZA_JUGADORES = false`) y renace con su
dueño en cada respawn.

## ⚡ Sistema de los 5 Núcleos (objetivo de escape)

`NucleoSystem` gestiona la condición de victoria:

1. Cada `BasePart` llamada `Nucleo*` dentro de `Workspace/Nucleos` recibe un
   `ProximityPrompt` **"Recoger Núcleo"**.
2. Al recogerlo, el núcleo se **suelda a la espalda** del astronauta con un
   `WeldConstraint`: todos ven quién lo lleva, y los Cucarones-Leones tienen
   un objetivo brillante que perseguir.
3. Solo se puede llevar **un núcleo a la vez** — hay que hacer viajes.
4. Si el portador muere, el núcleo **cae donde murió** y otro jugador puede
   recuperarlo (¡rescates épicos!).
5. En `Workspace/NaveEscape/PanelNucleos` se instala con el prompt
   **"Instalar Núcleo"**. Con los 5 instalados, la nave se enciende y todos
   los clientes ven la pantalla de victoria.

Si el mapa aún no tiene núcleos o nave, el script crea **placeholders** para
poder probar todo el ciclo en una Baseplate vacía.

## 🧃 Consumibles

`ConsumableSystem` usa un catálogo declarativo: cualquier `BasePart` dentro de
`Workspace/Consumibles` cuyo nombre esté en la tabla `CONSUMIBLES` recibe un
prompt y aplica su efecto al usarse (una sola vez, a prueba de doble uso):

| Nombre de la Part | Efecto |
| --- | --- |
| `CapsulaAgua` | +40 de Sed |
| `BateriaTraje` | +50 de Energía del traje |
| `RacionMedica` | +35 de Salud |

Para añadir un consumible nuevo basta con añadir una entrada a la tabla.

## 🖥️ HUD del cliente

`StatsHUD` (LocalScript) construye toda la interfaz por código: barras de
Salud/Sed/Energía con tweens suaves y parpadeo de alerta bajo el 20 %, más el
contador `⚡ Núcleos: X/5`. El cliente **nunca calcula estadísticas**: solo
dibuja lo que llega por `ActualizarStats` y `ActualizarNucleos`.

## 🔜 Próximos pasos sugeridos

- Que los bichos también ataquen a los Robots aliados (y viceversa: combates).
- Robots capaces de cargar núcleos (integrar `RobotAliado` con `NucleoSystem`).
- Efecto visual y aviso en el HUD del estado `Envenenado` (ya es un atributo).
- Progreso persistente con `DataStoreService` (núcleos entre sesiones).
- Sonidos y animaciones por especie (rugido del Cucarón, chasquido de la araña).
