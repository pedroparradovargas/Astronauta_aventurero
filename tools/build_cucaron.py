"""Genera el modelo 3D low-poly del Cucarón-León de Astroluna y lo exporta a FBX.

Anatomía: abdomen + tórax + cabeza (quitina marrón), melena de púas (el "León"),
10 patas articuladas (2 segmentos cada una), mandíbulas, 4 ojos emisivos y antenas.
Ejes: el bicho mira hacia -Y en Blender (frente estándar), suelo en Z=0.
"""

import math

import bpy
from mathutils import Vector

# ------------------------------------------------------------------
# Limpieza de escena
# ------------------------------------------------------------------
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete()
for block in (bpy.data.meshes, bpy.data.materials, bpy.data.lights, bpy.data.cameras):
    for item in list(block):
        block.remove(item)

# ------------------------------------------------------------------
# Materiales
# ------------------------------------------------------------------
def hacer_material(nombre, color, rough=0.7, emision=None, fuerza=0.0):
    mat = bpy.data.materials.new(nombre)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    if emision:
        bsdf.inputs["Emission Color"].default_value = (*emision, 1.0)
        bsdf.inputs["Emission Strength"].default_value = fuerza
    return mat

MAT_QUITINA = hacer_material("Quitina", (0.45, 0.22, 0.08), rough=0.55)
MAT_MELENA = hacer_material("Melena", (0.55, 0.13, 0.04), rough=0.8)
MAT_PATAS = hacer_material("PatasChitina", (0.16, 0.08, 0.04), rough=0.75)
MAT_MANDIBULA = hacer_material("Mandibula", (0.06, 0.06, 0.06), rough=0.4)
MAT_OJOS = hacer_material("OjoBrillante", (0.75, 0.9, 0.1), rough=0.2,
                          emision=(0.75, 0.95, 0.1), fuerza=4.0)

# ------------------------------------------------------------------
# Helpers de primitivas
# ------------------------------------------------------------------
def esfera(nombre, loc, radios, mat, suave=True):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=10, radius=1.0, location=loc)
    obj = bpy.context.active_object
    obj.name = nombre
    obj.scale = radios
    obj.data.materials.append(mat)
    if suave:
        bpy.ops.object.shade_smooth()
    return obj


def cilindro_entre(nombre, p1, p2, radio, mat):
    p1, p2 = Vector(p1), Vector(p2)
    diferencia = p2 - p1
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=8, radius=radio, depth=diferencia.length, location=(p1 + p2) / 2
    )
    obj = bpy.context.active_object
    obj.name = nombre
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = diferencia.to_track_quat("Z", "Y")
    obj.data.materials.append(mat)
    return obj


def cono(nombre, loc, direccion, largo, radio, mat):
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=radio, radius2=0.0,
                                    depth=largo, location=loc)
    obj = bpy.context.active_object
    obj.name = nombre
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector(direccion).to_track_quat("Z", "Y")
    # desplazar para que la base quede en `loc` y la punta hacia `direccion`
    obj.location = Vector(loc) + Vector(direccion).normalized() * (largo / 2)
    obj.data.materials.append(mat)
    return obj

# ------------------------------------------------------------------
# Cuerpo: abdomen + tórax + cabeza
# ------------------------------------------------------------------
cuerpo_partes = [
    esfera("Abdomen", (0, 1.6, 1.5), (1.3, 1.9, 1.1), MAT_QUITINA),
    esfera("Torax", (0, -0.4, 1.45), (1.1, 1.2, 0.95), MAT_QUITINA),
    esfera("Cabeza", (0, -1.9, 1.55), (0.8, 0.75, 0.7), MAT_QUITINA),
]

# ------------------------------------------------------------------
# Melena de púas alrededor del cuello (el rasgo "León")
# ------------------------------------------------------------------
melena_partes = []
CENTRO_MELENA = Vector((0, -1.15, 1.5))
for i in range(10):
    angulo = math.radians(i * 36 + 18)
    dir_radial = Vector((math.cos(angulo), 0, math.sin(angulo)))
    if dir_radial.z < -0.8:
        continue  # sin púas clavadas en el suelo
    base = CENTRO_MELENA + dir_radial * 0.95
    direccion = (dir_radial + Vector((0, -0.25, 0))).normalized()  # abanico hacia delante
    melena_partes.append(
        cono(f"Pua{i}", base, direccion, 1.2, 0.28, MAT_MELENA)
    )

# ------------------------------------------------------------------
# Las 10 patas (5 por lado, 2 segmentos cada una)
# ------------------------------------------------------------------
patas_partes = []
POSICIONES_Y = [-1.4, -0.6, 0.2, 1.0, 1.8]
for lado in (1, -1):
    for i, y in enumerate(POSICIONES_Y):
        cadera = (lado * 0.9, y, 1.3)
        rodilla = (lado * 1.9, y + 0.15, 2.05)
        pie = (lado * 2.6, y + 0.3, 0.05)
        patas_partes.append(
            cilindro_entre(f"Femur_{lado}_{i}", cadera, rodilla, 0.13, MAT_PATAS)
        )
        patas_partes.append(
            cilindro_entre(f"Tibia_{lado}_{i}", rodilla, pie, 0.10, MAT_PATAS)
        )

# Antenas (mismo material oscuro que las patas)
patas_partes.append(cilindro_entre("AntenaIzq", (0.25, -2.3, 2.0), (0.75, -3.3, 2.9), 0.05, MAT_PATAS))
patas_partes.append(cilindro_entre("AntenaDer", (-0.25, -2.3, 2.0), (-0.75, -3.3, 2.9), 0.05, MAT_PATAS))

# ------------------------------------------------------------------
# Mandíbulas: dos garfios que se cierran hacia el centro
# ------------------------------------------------------------------
mandibula_partes = []
for lado in (1, -1):
    base = (lado * 0.38, -2.5, 1.35)
    direccion = (-lado * 0.35, -1.0, -0.15)
    mandibula_partes.append(
        cono(f"Mandibula_{lado}", base, direccion, 1.0, 0.16, MAT_MANDIBULA)
    )

# ------------------------------------------------------------------
# 4 ojos brillantes
# ------------------------------------------------------------------
ojos_partes = []
for lado in (1, -1):
    ojos_partes.append(esfera(f"OjoA_{lado}", (lado * 0.3, -2.52, 1.85), (0.14, 0.14, 0.14), MAT_OJOS))
    ojos_partes.append(esfera(f"OjoB_{lado}", (lado * 0.52, -2.38, 1.65), (0.11, 0.11, 0.11), MAT_OJOS))

# ------------------------------------------------------------------
# Unir por grupo de material → un MeshPart por grupo en Roblox
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

unir("Cuerpo", cuerpo_partes)
unir("Melena", melena_partes)
unir("Patas", patas_partes)
unir("Mandibulas", mandibula_partes)
unir("Ojos", ojos_partes)

# ------------------------------------------------------------------
# Exportar FBX (binario, listo para el 3D Importer de Roblox Studio)
# ------------------------------------------------------------------
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.fbx(
    filepath="/home/user/Astronauta_aventurero/assets/CucaronLeon.fbx",
    use_selection=True,
    apply_unit_scale=True,
    add_leaf_bones=False,
    path_mode="AUTO",
)

# ------------------------------------------------------------------
# Render de vista previa (para verlo sin abrir Studio)
# ------------------------------------------------------------------
escena = bpy.context.scene
escena.render.engine = "CYCLES"
escena.cycles.samples = 48
escena.render.resolution_x = 960
escena.render.resolution_y = 720

mundo = bpy.data.worlds["World"]
mundo.use_nodes = True
mundo.node_tree.nodes["Background"].inputs["Color"].default_value = (0.02, 0.02, 0.04, 1)
mundo.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0

sol = bpy.data.lights.new("Sol", type="SUN")
sol.energy = 4.0
obj_sol = bpy.data.objects.new("Sol", sol)
obj_sol.rotation_euler = (math.radians(50), math.radians(-15), math.radians(30))
escena.collection.objects.link(obj_sol)

relleno = bpy.data.lights.new("Relleno", type="AREA")
relleno.energy = 600.0
relleno.size = 12.0
obj_relleno = bpy.data.objects.new("Relleno", relleno)
obj_relleno.location = (-7, -7, 7)
obj_relleno.rotation_euler = (math.radians(55), 0, math.radians(-45))
escena.collection.objects.link(obj_relleno)

camara = bpy.data.cameras.new("Camara")
obj_camara = bpy.data.objects.new("Camara", camara)
obj_camara.location = (7.5, -8.5, 5.0)
mira = Vector((0, 0, 1.2)) - obj_camara.location
obj_camara.rotation_euler = mira.to_track_quat("-Z", "Y").to_euler()
escena.collection.objects.link(obj_camara)
escena.camera = obj_camara

escena.render.filepath = "/tmp/claude-0/-home-user-Astronauta-aventurero/6ba5a3dc-b929-5059-8025-c3a362394590/scratchpad/cucaron_frente.png"
bpy.ops.render.render(write_still=True)

obj_camara.location = (-8.0, 6.5, 4.5)
mira = Vector((0, 0, 1.2)) - obj_camara.location
obj_camara.rotation_euler = mira.to_track_quat("-Z", "Y").to_euler()
escena.render.filepath = "/tmp/claude-0/-home-user-Astronauta-aventurero/6ba5a3dc-b929-5059-8025-c3a362394590/scratchpad/cucaron_trasera.png"
bpy.ops.render.render(write_still=True)

# Estadísticas
total_tris = sum(
    len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH"
)
print(f"LISTO: {total_tris} polígonos totales")
