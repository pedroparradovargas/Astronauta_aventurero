# 🚀 Astroluna — Núcleo de sistemas (Luau / Roblox Studio)

Juego de supervivencia multijugador: una estación espacial se estrella en un
sistema de **5 planetas y 2 lunas** bajo **5 soles abrasadores** sin una gota
de agua. Los Astronautas y sus Robots aliados deben ensamblar **5 Núcleos de
energía** para escapar, mientras arañas de 20 ojos y **Cucarones-Leones** de
10 patas los cazan sin piedad.

## 📁 Estructura del proyecto

El código de `src/` refleja la jerarquía que debes reproducir en Roblox Studio
(o sincronizar automáticamente con [Rojo](https://rojo.space) usando
`default.project.json`):

```
ServerScriptService
├── Modules                  (carpeta de ModuleScripts compartidos del servidor)
│   └── PlayerStats          ← ModuleScript OOP: Sed, Salud, Energía del traje
├── Core                     (sistemas centrales del bucle de juego)
│   └── ThirstSystem         ← Script: deshidratación por los 5 soles
└── AI                       (inteligencia artificial de la fauna)
    ├── CucaronLeon          ← ModuleScript OOP: caza con PathfindingService
    └── EnemySpawner         ← Script: activa la IA de Workspace/Enemigos
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

## 🕷️ IA del Cucarón-León (PathfindingService)

`CucaronLeon.lua` implementa el ciclo clásico de un depredador:

```
buscar presa → calcular ruta (ComputeAsync) → recorrer waypoints → morder
      ↑                                                              │
      └────────────── recalcular cada 0.35 s ────────────────────────┘
```

Detalles importantes del ejemplo:

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

Para probarlo: crea en `Workspace` una carpeta `Enemigos` con un Model llamado
`CucaronLeon1` (con `Humanoid` y `HumanoidRootPart`). `EnemySpawner` le dará
vida automáticamente, incluso a los que aparezcan después.

## 🔜 Próximos pasos sugeridos

- UI del cliente (`StarterGui`) que escuche `ActualizarStats` y dibuje barras.
- Objetos consumibles (cápsulas de agua reciclada) que llamen a `ModificarSed`.
- Sistema de los 5 Núcleos con `ProximityPrompt` y progreso guardado en
  `DataStoreService`.
- IA de la araña de 20 ojos reutilizando `CucaronLeon` como clase base.
