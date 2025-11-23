extends Node3D

signal pressed

@export var color_material: StandardMaterial3D      # opcional
@export var albedo_color: Color = Color.WHITE       # color directo

@onready var area: Area3D = $Area3D
@onready var mesh: MeshInstance3D = $MeshBoton

var escala_base: Vector3

func _ready() -> void:
	escala_base = scale

	# Habilitar que el Area3D reciba clicks de ratón (propiedad correcta en Godot 4)
	area.input_ray_pickable = true
	area.input_event.connect(_on_area_3d_input_event)

	# Crear / elegir material
	var mat: StandardMaterial3D
	if color_material:
		mat = color_material
	else:
		mat = StandardMaterial3D.new()
		mat.albedo_color = albedo_color

	mesh.material_override = mat


func _on_area_3d_input_event(camera, event, position, normal, shape_idx) -> void:
	if event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed:
		emit_signal("pressed")
