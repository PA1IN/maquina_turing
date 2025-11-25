extends Node3D

@export var textura_suma: Texture2D
@export var textura_resta: Texture2D

# Altura fija que quieres que tenga el cartel (en metros)
# El ancho se calculará solo.
const ALTURA_FIJA = 2.0 

@onready var tablero: MeshInstance3D = $TableroPadre/Tablero

func _ready() -> void:
	# Aseguramos que sea único para no afectar otros objetos
	var material = StandardMaterial3D.new()
	tablero.material_override = material
	
	# Configuración visual para que se vea nítido
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Hacer que brille
	material.emission_enabled = true
	material.emission_energy_multiplier = 0.5 
	
	# Iniciamos en modo suma
	cambiar_modo(true)

func cambiar_modo(es_suma: bool) -> void:
	if not tablero.material_override: return
	
	var mat = tablero.material_override as StandardMaterial3D
	var textura_elegida: Texture2D
	
	if es_suma:
		textura_elegida = textura_suma
	else:
		textura_elegida = textura_resta
	
	if not textura_elegida: return

	# 1. Asignar Textura (Color y Emisión para que brille igual)
	mat.albedo_texture = textura_elegida
	mat.emission_texture = textura_elegida 
	
	# 2. AUTO-AJUSTE DE TAMAÑO (La magia)
	# Calculamos la proporción de la imagen original
	var ancho_img = float(textura_elegida.get_width())
	var alto_img = float(textura_elegida.get_height())
	var aspecto = ancho_img / alto_img
	
	# Aplicamos el tamaño al Mesh 3D
	# Si es QuadMesh o PlaneMesh, usamos la propiedad 'size'
	if tablero.mesh is QuadMesh:
		# Mantenemos la altura fija y ajustamos el ancho según el aspecto
		tablero.mesh.size = Vector2(ALTURA_FIJA * aspecto, ALTURA_FIJA)
		
	elif tablero.mesh is BoxMesh:
		# Si prefieres seguir usando BoxMesh, ajustamos su size.x y size.y
		tablero.mesh.size.y = ALTURA_FIJA
		tablero.mesh.size.x = ALTURA_FIJA * aspecto
