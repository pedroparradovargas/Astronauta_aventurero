"""Genera el traje de astronauta de Astroluna (casco + mochila) y lo exporta a FBX.

El personaje jugable en Roblox es el avatar del propio jugador (rig R15 con
todas sus animaciones); el "look astronauta" se consigue soldándole este
equipo por código (Core/SuitSystem). Por eso el FBX contiene solo el equipo,
dimensionado para un avatar R15 estándar:
  - Casco esférico (diámetro ~1.9 studs, cubre la cabeza de 1.2)
  - Visor dorado espejado
  - Mochila de soporte vital con 2 tanques y antena
Para la vista previa se renderiza también un maniquí gris que NO se exporta.
Ejes Blender: Z arriba, el personaje mira hacia -Y. Suelo en Z=0.
"""

import math

import bpy
from mathutils import Vector

# ------------------------------------------------------------------
# Limpieza
# ------------------------------------------------------------------
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete()
for block in (bpy.data.meshes, bpy.data.materials, bpy.data.lights, bpy.data.cameras):
    for item in list(block):
        block.remove(item)

# ------------------------------------------------------------------
# Materiales
# ------------------------------------------------------------------
def hacer_material(nombre, color, rough=0.6, metal=0.0, emision=None, fuerza=0.0):
    mat = bpy.data.materials.new(nombre)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emision:
        bsdf.inputs["Emission Color"].default_value = (*emision, 1.0)
        bsdf.inputs["Emission Strength"].default_value = fuerza
    return mat

MAT_CASCO = hacer_material("CascoBlanco", (0.92, 0.92, 0.95), rough=0.35)
MAT_VISOR = hacer_material("VisorDorado", (0.95, 0.65, 0.15), rough=0.08, metal=1.0)
MAT_MOCHILA = hacer_material("MochilaGris", (0.75, 0.78, 0.82), rough=0.5)
MAT_TANQUES = hacer_material("TanqueNaranja", (0.95, 0.45, 0.08), rough=0.4, metal=0.3)
MAT_DETALLE = hacer_material("DetalleOscuro", (0.15, 0.16, 0.2), rough=0.6)
MAT_LUZ = hacer_material("LuzEstado", (0.1, 0.9, 0.4), rough=0.3,
                         emision=(0.1, 0.95, 0.4), fuerza=5.0)
MAT_MANIQUI = hacer_material("Maniqui", (0.5, 0.52, 0.55), rough=0.9)

# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------
def esfera(nombre, loc, radios, mat, seg=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg - 4,
                                         radius=1.0, location=loc)
    obj = bpy.context.active_object
    obj.name = nombre
    obj.scale = radios
    obj.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return obj


def caja(nombre, loc, dims, mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    obj = bpy.context.active_object
    obj.name = nombre
    obj.scale = dims
    obj.data.materials.append(mat)
    return obj


def cilindro(nombre, loc, radio, alto, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=radio, depth=alto,
                                        location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = nombre
    obj.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return obj

# ==================================================================
# CASCO — centrado en el origen (el script lo coloca sobre la cabeza)
# ==================================================================
ALTURA_CABEZA = 5.1  # solo para el render con maniquí; el FBX se centra luego

casco_partes = [
    esfera("CascoBurbuja", (0, 0, ALTURA_CABEZA), (0.95, 0.95, 0.9), MAT_CASCO),
    # anillo del cuello
    cilindro("CascoCuello", (0, 0, ALTURA_CABEZA - 0.85), 0.55, 0.3, MAT_DETALLE),
    # orejeras de radio
    cilindro("OrejeraIzq", (0.92, 0, ALTURA_CABEZA), 0.22, 0.18, MAT_DETALLE,
             rot=(0, math.radians(90), 0)),
    cilindro("OrejeraDer", (-0.92, 0, ALTURA_CABEZA), 0.22, 0.18, MAT_DETALLE,
             rot=(0, math.radians(90), 0)),
    # foco frontal pequeño sobre el visor
    caja("Foco", (0, -0.82, ALTURA_CABEZA + 0.55), (0.35, 0.18, 0.14), MAT_DETALLE),
]

visor_partes = [
    # burbuja dorada aplastada, incrustada en el frente del casco
    esfera("Visor", (0, -0.42, ALTURA_CABEZA + 0.02), (0.62, 0.62, 0.55), MAT_VISOR),
]

# ==================================================================
# MOCHILA — centrada en el origen en X/Y (va a la espalda del torso)
# ==================================================================
Y_ESPALDA = 0.55       # detrás del torso del maniquí (torso en y=0)
Z_TORSO = 3.4

mochila_partes = [
    caja("MochilaCuerpo", (0, Y_ESPALDA + 0.35, Z_TORSO), (1.7, 0.7, 2.0), MAT_MOCHILA),
    caja("MochilaTapa", (0, Y_ESPALDA + 0.35, Z_TORSO + 1.05), (1.5, 0.6, 0.25), MAT_DETALLE),
    # panel de estado con luz
    caja("Panel", (0, Y_ESPALDA + 0.74, Z_TORSO + 0.5), (0.8, 0.1, 0.5), MAT_DETALLE),
    esfera("LuzPanel", (0.2, Y_ESPALDA + 0.8, Z_TORSO + 0.5), (0.09, 0.09, 0.09), MAT_LUZ),
    # antena
    cilindro("Antena", (-0.7, Y_ESPALDA + 0.35, Z_TORSO + 1.7), 0.04, 1.1, MAT_DETALLE),
    esfera("AntenaPunta", (-0.7, Y_ESPALDA + 0.35, Z_TORSO + 2.3), (0.09, 0.09, 0.09), MAT_LUZ),
]

tanques_partes = [
    cilindro("TanqueIzq", (0.45, Y_ESPALDA + 0.85, Z_TORSO - 0.1), 0.32, 1.7, MAT_TANQUES),
    esfera("TanqueIzqTapa", (0.45, Y_ESPALDA + 0.85, Z_TORSO + 0.75), (0.32, 0.32, 0.2), MAT_TANQUES),
    cilindro("TanqueDer", (-0.45, Y_ESPALDA + 0.85, Z_TORSO - 0.1), 0.32, 1.7, MAT_TANQUES),
    esfera("TanqueDerTapa", (-0.45, Y_ESPALDA + 0.85, Z_TORSO + 0.75), (0.32, 0.32, 0.2), MAT_TANQUES),
]

# ------------------------------------------------------------------
# Unir por grupo → un MeshPart por grupo en Roblox
# ------------------------------------------------------------------
def unir(nombre, partes):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in partes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = partes[0]
    bpy.ops.object.join()
    grupo = bpy.context.active_object
    grupo.name = nombre
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return grupo

grupo_casco = unir("Casco", casco_partes)
grupo_visor = unir("Visor", visor_partes)
grupo_mochila = unir("Mochila", mochila_partes)
grupo_tanques = unir("Tanques", tanques_partes)
EQUIPO = [grupo_casco, grupo_visor, grupo_mochila, grupo_tanques]

# ==================================================================
# MANIQUÍ solo para el render (NO se exporta)
# ==================================================================
maniqui = [
    caja("M_Cabeza", (0, 0, ALTURA_CABEZA), (1.1, 1.1, 1.1), MAT_MANIQUI),
    caja("M_Torso", (0, 0, Z_TORSO), (1.9, 1.0, 2.1), MAT_MANIQUI),
    caja("M_BrazoIzq", (1.35, 0, 3.3), (0.8, 0.8, 1.9), MAT_MANIQUI),
    caja("M_BrazoDer", (-1.35, 0, 3.3), (0.8, 0.8, 1.9), MAT_MANIQUI),
    caja("M_PiernaIzq", (0.5, 0, 1.15), (0.85, 0.85, 2.3), MAT_MANIQUI),
    caja("M_PiernaDer", (-0.5, 0, 1.15), (0.85, 0.85, 2.3), MAT_MANIQUI),
]

# ------------------------------------------------------------------
# Exportar SOLO el equipo a FBX
# ------------------------------------------------------------------
bpy.ops.object.select_all(action="DESELECT")
for obj in EQUIPO:
    obj.select_set(True)
bpy.ops.export_scene.fbx(
    filepath="/home/user/Astronauta_aventurero/assets/TrajeAstronauta.fbx",
    use_selection=True,
    apply_unit_scale=True,
    add_leaf_bones=False,
    path_mode="AUTO",
)

# ------------------------------------------------------------------
# Renders de vista previa
# ------------------------------------------------------------------
escena = bpy.context.scene
escena.render.engine = "CYCLES"
escena.cycles.samples = 48
escena.render.resolution_x = 960
escena.render.resolution_y = 720

mundo = bpy.data.worlds["World"]
mundo.use_nodes = True
mundo.node_tree.nodes["Background"].inputs["Color"].default_value = (0.02, 0.02, 0.04, 1)

sol = bpy.data.lights.new("Sol", type="SUN")
sol.energy = 4.0
obj_sol = bpy.data.objects.new("Sol", sol)
obj_sol.rotation_euler = (math.radians(50), math.radians(-15), math.radians(35))
escena.collection.objects.link(obj_sol)

relleno = bpy.data.lights.new("Relleno", type="AREA")
relleno.energy = 800.0
relleno.size = 14.0
obj_relleno = bpy.data.objects.new("Relleno", relleno)
obj_relleno.location = (-8, -8, 8)
obj_relleno.rotation_euler = (math.radians(55), 0, math.radians(-45))
escena.collection.objects.link(obj_relleno)

camara = bpy.data.cameras.new("Camara")
obj_camara = bpy.data.objects.new("Camara", camara)
escena.collection.objects.link(obj_camara)
escena.camera = obj_camara

def render(nombre, posicion):
    obj_camara.location = posicion
    mira = Vector((0, 0, 3.2)) - obj_camara.location
    obj_camara.rotation_euler = mira.to_track_quat("-Z", "Y").to_euler()
    escena.render.filepath = (
        "/tmp/claude-0/-home-user-Astronauta-aventurero/"
        "6ba5a3dc-b929-5059-8025-c3a362394590/scratchpad/" + nombre
    )
    bpy.ops.render.render(write_still=True)

render("astronauta_frente.png", (5.5, -9.0, 5.5))
render("astronauta_espalda.png", (-4.5, 9.5, 6.0))

total_tris = sum(len(o.data.polygons) for o in EQUIPO)
print(f"LISTO: {total_tris} polígonos en el equipo exportado")
