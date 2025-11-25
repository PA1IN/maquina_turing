extends MeshInstance3D

@export var nodo_a: Node3D
@export var nodo_b: Node3D
@export var grosor: float = 0.05

func _ready() -> void:
	if not nodo_a or not nodo_b: return
	actualizar_cable()

func actualizar_cable() -> void:
	# 1. Calcular punto medio
	var pos_a = nodo_a.global_position
	var pos_b = nodo_b.global_position
	var distancia = pos_a.distance_to(pos_b)
	
	# 2. Posicionar el cilindro en el centro
	global_position = (pos_a + pos_b) / 2.0
	
	# 3. Mirar hacia uno de los puntos
	look_at(pos_b, Vector3.UP)
	
	# 4. Ajustar el tamaño del cilindro
	# Giramos -90 en X porque el cilindro de Godot está de pie (Y) y look_at usa Z
	rotation_degrees.x -= 90 
	
	# Ajustar la malla (CylinderMesh)
	mesh.top_radius = grosor
	mesh.bottom_radius = grosor
	mesh.height = distancia
