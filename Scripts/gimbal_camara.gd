extends Node3D

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
