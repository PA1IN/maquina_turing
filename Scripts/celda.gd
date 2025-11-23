extends Node3D

# 0 = Blanco (hueco visible, tapa a un lado)
# 1 = Uno normal (cubo normal, tapa en el centro)
# 2 = Separador de resta "-" (cubo especial, un poco más alto / otro color)
enum Simbolo {
	BLANCO = 0,   # Hueco (no hay cubo / fuera de la plataforma)
	UNO = 1,      # Cubo azul normal sobre la plataforma
	SEPARADOR = 2 # Cubo separador (más alto / rojo) sobre la plataforma
}

var valor: int = Simbolo.BLANCO

@onready var tapa: Node3D = $Tapa

var altura_cinta := 1.0
var altura_pala := 0.8

# Opcional: materiales distintos para UNO y SEPARADOR
@export var material_uno: StandardMaterial3D
@export var material_separador: StandardMaterial3D


func set_valor(nuevo_valor: int) -> void:
	valor = nuevo_valor
	actualizar_visual()


func actualizar_visual() -> void:
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	match valor:
		Simbolo.BLANCO:
			# 0 → cubo fuera de la plataforma (hueco)
			tween.tween_property(tapa, "position:z", 2.0, 0.5)
			tween.tween_property(tapa, "position:y", altura_pala, 0.5)
			tween.tween_property(tapa, "scale", Vector3.ONE, 0.3)
			if material_uno:
				tapa.material_override = material_uno

		Simbolo.UNO:
			# 1 → cubo normal sobre la plataforma
			tween.tween_property(tapa, "position:z", 0.0, 0.5)
			tween.tween_property(tapa, "position:y", altura_cinta, 0.5)
			tween.tween_property(tapa, "scale", Vector3.ONE, 0.3)
			if material_uno:
				tapa.material_override = material_uno

		Simbolo.SEPARADOR:
			# 2 → cubo de resta más alto / otro color
			tween.tween_property(tapa, "position:z", 0.0, 0.5)
			tween.tween_property(tapa, "position:y", altura_cinta + 0.2, 0.5)
			tween.tween_property(tapa, "scale", Vector3(1, 1.3, 1), 0.3)
			if material_separador:
				tapa.material_override = material_separador


# Para la lógica "Arduino": hay cubo si NO es blanco
func hay_cubo() -> bool:
	return valor != Simbolo.BLANCO


# Actualiza sin animar (para iniciar la cinta desde Main)
func forzar_estado_sin_animar(nuevo_valor: int) -> void:
	valor = nuevo_valor

	match valor:
		Simbolo.BLANCO:
			tapa.position.z = 2.0
			tapa.position.y = altura_pala
			tapa.scale = Vector3.ONE
			if material_uno:
				tapa.material_override = material_uno

		Simbolo.UNO:
			tapa.position.z = 0.0
			tapa.position.y = altura_cinta
			tapa.scale = Vector3.ONE
			if material_uno:
				tapa.material_override = material_uno

		Simbolo.SEPARADOR:
			tapa.position.z = 0.0
			tapa.position.y = altura_cinta + 0.2
			tapa.scale = Vector3(1, 1.3, 1)
			if material_separador:
				tapa.material_override = material_separador


func _on_area_3d_input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed:
		# Ciclo manual: 0 -> 1 -> 2 -> 0
		if valor == Simbolo.BLANCO:
			set_valor(Simbolo.UNO)
		elif valor == Simbolo.UNO:
			set_valor(Simbolo.SEPARADOR)
		else:
			set_valor(Simbolo.BLANCO)
		print("Celda cambiada manualmente a: ", valor)


func animar_retorno_pala() -> void:
	var pivote = $SistemaPala/PivotePrincipal
	var tapa_fisica = tapa

	# 1. LEVANTAR
	var t_levantar = create_tween().set_parallel(true)
	t_levantar.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t_levantar.tween_property(pivote, "rotation_degrees:x", -60.0, 0.8)
	t_levantar.tween_property(tapa_fisica, "position:y", altura_cinta + 0.5, 0.6)
	t_levantar.tween_property(tapa_fisica, "position:z", 0.5, 0.8)
	await t_levantar.finished

	# 2. DEPOSITAR
	var t_depositar = create_tween()
	t_depositar.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t_depositar.parallel().tween_property(tapa_fisica, "position:z", 0.0, 0.3)
	t_depositar.parallel().tween_property(tapa_fisica, "position:y", altura_cinta, 0.3)
	await t_depositar.finished

	# 3. BAJAR PALA VACÍA
	var t_bajar = create_tween()
	t_bajar.tween_property(pivote, "rotation_degrees:x", 0.0, 0.6)
	await t_bajar.finished

	# Después de depositar, queda como UNO normal (cubo sobre la plataforma)
	valor = Simbolo.UNO
