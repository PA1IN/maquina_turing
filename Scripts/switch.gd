extends Node3D

@onready var palanca: Node3D = $Palanca
@onready var mesh_palanca: Node3D = $Palanca/MeshPalanca
@onready var area: Area3D = $Palanca/Area3D

signal toggled(es_suma: bool)

var estado_suma := true

const ANGULO_SUMA  := 20.0
const ANGULO_RESTA := -20.0

func _ready() -> void:
	# Conectar el click del Area3D
	area.input_event.connect(_on_area_input_event)

	# Asegurar que la palanca parte en el ángulo correcto
	_actualizar_rotacion_instantanea()


func _on_area_input_event(camera, event, position, normal, shape_idx) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		_alternar_estado()


func _alternar_estado() -> void:
	# Cambiar estado lógico
	estado_suma = !estado_suma

	# Elegir ángulo destino
	var angulo_destino := ANGULO_SUMA if estado_suma else ANGULO_RESTA

	# Animación de la palanca
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		palanca,
		"rotation_degrees:z",
		angulo_destino,
		0.25
	)

	# Avisar al Main que el modo cambió
	emit_signal("toggled", estado_suma)


func _actualizar_rotacion_instantanea() -> void:
	var angulo := ANGULO_SUMA if estado_suma else ANGULO_RESTA
	palanca.rotation_degrees.z = angulo
