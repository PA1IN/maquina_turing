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
@onready var tapa_visual: MeshInstance3D = $Tapa/Tapa
var tween_animacion: Tween

var altura_cinta := 1.0
var altura_pala := 0.8

@export var escala_base: Vector3 = Vector3(1.5, 1.5, 1.5)
# Opcional: materiales distintos para UNO y SEPARADOR
@export var material_uno: StandardMaterial3D
@export var material_separador: StandardMaterial3D

func _ready() -> void:
	#escala_base = Vector3(1.5,1.5,1.5)
	var altura_calculada = calcular_altura()
	altura_cinta = altura_calculada
	altura_pala = altura_calculada - 0.2
	actualizar_visual()

func set_valor(nuevo_valor: int) -> void:
	valor = nuevo_valor
	actualizar_visual()


func actualizar_visual() -> void:
	if tween_animacion and tween_animacion.is_valid():
		tween_animacion.kill()
	tapa.scale = Vector3.ONE
	print("debug click: ", valor, " / escala base: ", escala_base)
	
	tween_animacion = create_tween().set_parallel(true)
	tween_animacion.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	tapa_visual.material_override = null
	
	match valor:
		Simbolo.BLANCO:
			# 0 → cubo fuera de la plataforma (hueco)
			tween_animacion.tween_property(tapa, "position:z", 2.0, 0.5)
			tween_animacion.tween_property(tapa, "position:y", altura_pala, 0.5)
			tween_animacion.tween_property(tapa_visual, "scale", escala_base, 0.3)
			if material_uno:
				tapa_visual.material_override = material_uno

		Simbolo.UNO:
			# 1 → cubo normal sobre la plataforma
			tween_animacion.tween_property(tapa, "position:z", 0.0, 0.5)
			tween_animacion.tween_property(tapa, "position:y", altura_cinta, 0.5)
			tween_animacion.tween_property(tapa_visual, "scale", escala_base, 0.3)
			if material_uno:
				tapa_visual.material_override = material_uno

		Simbolo.SEPARADOR:
			# 2 → cubo de resta más alto / otro color
			tween_animacion.tween_property(tapa, "position:z", 0.0, 0.5)
			tween_animacion.tween_property(tapa, "position:y", altura_cinta + 0.2, 0.5)
			var escala_sep = Vector3(escala_base.x, escala_base.y * 1.3, escala_base.z)
			tween_animacion.tween_property(tapa_visual, "scale", escala_sep, 0.3)
			if material_separador:
				tapa_visual.material_override = material_separador


# Para la lógica "Arduino": hay cubo si NO es blanco
func hay_cubo() -> bool:
	return valor != Simbolo.BLANCO


func calcular_altura() -> float:
	# 1. Obtener nodos de forma segura
	var nodo_fisico_pala = $SistemaPala/PivotePrincipal/BasePala/CuerpoFisico
	var col_pala = nodo_fisico_pala.get_node("CollisionShape3D")
	var col_tapa = $Tapa/CollisionShape3D
	
	# 2. Obtener la altura base de las formas (Shape Resources)
	var alto_base_pala = 0.2
	if col_pala.shape is BoxShape3D:
		alto_base_pala = col_pala.shape.size.y
		
	var alto_base_cubo = 1.0 
	if col_tapa.shape is BoxShape3D:
		alto_base_cubo = col_tapa.shape.size.y

	# 3. Obtener la escala LOCAL (Más seguro que global_scale para evitar errores de Callable)
	var escala_pala_y = col_pala.scale.y
	var escala_cubo_y = col_tapa.scale.y
	
	# 4. Calcular alturas reales
	var alto_real_pala = alto_base_pala * escala_pala_y
	var alto_real_cubo = alto_base_cubo * escala_cubo_y
	
	var y_pala_local = nodo_fisico_pala.global_position.y - self.global_position.y
	var altura_final = y_pala_local + (alto_real_pala / 2.0) + (alto_real_cubo / 2.0)
	
	return altura_final + 0.002

# Actualiza sin animar (para iniciar la cinta desde Main)
func forzar_estado_sin_animar(nuevo_valor: int) -> void:
	if tween_animacion and tween_animacion.is_valid():
		tween_animacion.kill()
	
	valor = nuevo_valor
	print("Valor : ", valor)
	print("escala: ", escala_base)
	#var y_real = calcular_altura()
	tapa.scale = Vector3.ONE
	tapa_visual.material_override = null
	match valor:
		Simbolo.BLANCO:
			tapa.position.z = 2.0
			tapa.position.y = altura_pala
			tapa_visual.scale = escala_base
			if material_uno:
				tapa_visual.material_override = material_uno

		Simbolo.UNO:
			tapa.position.z = 0.0
			tapa.position.y = altura_cinta
			tapa_visual.scale = escala_base
			#tapa.scale = Vector3.ONE
			if material_uno:
				tapa_visual.material_override = material_uno

		Simbolo.SEPARADOR:
			tapa.position.z = 0.0
			tapa.position.y = altura_cinta + 0.2
			var escala_sep = Vector3(escala_base.x, escala_base.y * 1.3, escala_base.z)
			tapa_visual.scale = escala_sep
			#tapa.scale = Vector3.ONE
			if material_separador:
				tapa_visual.material_override = material_separador


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
	
	tapa.scale = Vector3.ONE
	t_depositar.parallel().tween_property(tapa_visual, "scale", escala_base, 0.3)
	await t_depositar.finished

	# 3. BAJAR PALA VACÍA
	var t_bajar = create_tween()
	t_bajar.tween_property(pivote, "rotation_degrees:x", 0.0, 0.6)
	await t_bajar.finished

	# Después de depositar, queda como UNO normal (cubo sobre la plataforma)
	valor = Simbolo.UNO
	
	tapa_visual.scale = escala_base
