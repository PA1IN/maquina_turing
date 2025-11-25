extends Node3D

"""
# Sensibilidad del mouse
var sensibilidad = 0.005
var velocidad_zoom = 0.5

func _input(event):
	# Si movemos el mouse con clic derecho presionado, rotamos
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		rotate_y(-event.relative.x * sensibilidad)
		$Camera3D.rotate_x(-event.relative.y * sensibilidad)
		
		# Limitamos la rotación vertical para no dar la vuelta completa
		$Camera3D.rotation.x = clamp($Camera3D.rotation.x, -1.2, 0.0)

	# Zoom con la rueda del mouse
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			$Camera3D.position.z -= velocidad_zoom
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			$Camera3D.position.z += velocidad_zoom
"""

# Configuración
@export var velocidad_movimiento: float = 10.0
@export var velocidad_turbo: float = 20.0  # Velocidad con Shift
@export var sensibilidad_mouse: float = 0.005

@onready var camara: Camera3D = $Camera3D

func _ready() -> void:
	# Aseguramos que la cámara empiece con una rotación limpia
	pass

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		rotate_y(-event.relative.x * sensibilidad_mouse)		
		camara.rotate_x(-event.relative.y * sensibilidad_mouse)		
		camara.rotation.x = clamp(camara.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _process(delta: float) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		mover_camara_libre(delta)

func mover_camara_libre(delta: float) -> void:
	var direccion = Vector3.ZERO	
	var base_camara = camara.global_transform.basis
	if Input.is_key_pressed(KEY_W):
		direccion -= base_camara.z # Hacia adelante donde mira la cámara
	if Input.is_key_pressed(KEY_S):
		direccion += base_camara.z # Hacia atrás
	if Input.is_key_pressed(KEY_A):
		direccion -= base_camara.x # Izquierda
	if Input.is_key_pressed(KEY_D):
		direccion += base_camara.x # Derecha
	if Input.is_key_pressed(KEY_Q):
		direccion -= Vector3.UP    # Bajar verticalmente (Mundo)
	if Input.is_key_pressed(KEY_E):
		direccion += Vector3.UP    # Subir verticalmente (Mundo)

	var velocidad_actual = velocidad_movimiento
	if Input.is_key_pressed(KEY_SHIFT):
		velocidad_actual = velocidad_turbo

	# Aplicar movimiento
	position += direccion.normalized() * velocidad_actual * delta
