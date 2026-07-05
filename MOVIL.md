# 📱 Astroluna Móvil — guía de la rama para celular

Esta rama (`claude/astroluna-movil`) adapta Astroluna para publicarse **solo
en teléfonos y tablets**. En Roblox no existe "compilar para móvil": es la
misma experiencia, restringida a esos dispositivos y optimizada para pantalla
táctil. La rama principal sigue siendo la versión multiplataforma.

## Qué cambia esta rama respecto a la principal

| Área | Cambio | Motivo |
| --- | --- | --- |
| `StatsHUD` | Barras **arriba a la derecha**, más altas y con texto mayor; lista de jugadores oculta | Abajo-izquierda vive el joystick virtual y abajo-derecha el botón de salto |
| `RendimientoMovil` (nuevo) | Sombras dinámicas off, postprocesado off, decoración del terreno off, zoom máximo 60 | Son lo más caro de dibujar en un teléfono |
| Prompts de Núcleos | Recoger 1 s → **0.5 s**, instalar 2 s → **1 s**, más alcance | Mantener pulsada la pantalla cansa; el joystick apunta peor que un ratón |
| Prompts de consumibles | 0.5 s → **0.25 s**, más alcance | Ídem |
| `EnemySpawner` | Manada de prueba de 5 → **4 criaturas** | Cada Humanoid en movimiento se replica y anima en el teléfono de todos |

Los controles de movimiento no hay que programarlos: **Roblox añade solo**
el joystick virtual y el botón de salto en pantallas táctiles, y los
`ProximityPrompt` muestran botón táctil automáticamente.

## Pasos obligatorios en Studio (no se pueden hacer por código)

1. **Restringir a móvil**: *Home* → **Game Settings** → **Basic Info** →
   sección **Playable Devices**: deja marcados solo ✅ *Phone* y ✅ *Tablet*
   (desmarca *Desktop* y *Console*). Guarda y publica.
2. **Activar streaming**: selecciona `Workspace` en el Explorer y en
   *Properties* marca **StreamingEnabled = true**. El mundo se carga por
   trozos alrededor del jugador — imprescindible en un mapa de 5 planetas
   para la memoria de un teléfono (los scripts ya usan `WaitForChild`, que
   es la práctica compatible con streaming).
3. *(Recomendado)* En cada MeshPart de criaturas/traje:
   `RenderFidelity = Automatic` y `CollisionFidelity = Hull` o `Box`.

## Cómo probarlo sin un teléfono

Pestaña **Test** → botón **Device** (emulador): elige un perfil (iPhone,
tablet Android…) y Studio simula esa pantalla, con joystick y todo.
Comprueba que:

- Las barras no chocan con el joystick (abajo-izq) ni el salto (abajo-dcha).
- El contador de Núcleos no queda tapado por el notch (la zona segura la
  gestiona Roblox, pero verifícalo en perfiles con muesca).
- Los prompts se disparan bien con el botón táctil.

Para probar en tu teléfono real: publica la experiencia (privada), abre
Roblox en el celular con tu cuenta y entra desde tu perfil → Creaciones.

## Mantener las dos ramas

- Rama principal (`claude/astroluna-core-systems-fz1p2s`): versión
  multiplataforma. Desarrolla ahí las mecánicas nuevas.
- Rama móvil (`claude/astroluna-movil`): trae los cambios de esta tabla.
  Cuando añadas mecánicas en la principal, intégralas aquí con
  `git merge <rama-principal>` y revisa que la UI nueva respete las zonas
  táctiles.
