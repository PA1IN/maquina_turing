extends Node3D

const Celda = preload("res://Scripts/celda.gd")

# --- REFERENCIAS A ESCENAS Y NODOS 3D ---
var celda_scene = preload("res://Escenas/Celda.tscn")
@onready var nodo_cinta       = $Cinta
@onready var cabezal          = $Cabezal
@onready var switch3d         = $Switch3D      # Palanca 3D
@onready var boton_start_3d   = $BotonStart3D
@onready var boton_reset_3d   = $BotonReset3D
@onready var cartel_instrucciones = $EstructuraMaquina/CartelEstados

# --- REFERENCIAS A LA INTERFAZ DE USUARIO (UI) ---
@onready var ui_input_a = $CanvasLayer/Control/Panel/InputA
@onready var ui_input_b = $CanvasLayer/Control/Panel/InputB
@onready var btn_start  = $CanvasLayer/Control/Panel/BotonStart
@onready var btn_reset  = $CanvasLayer/Control/Panel/BotonReset
@onready var btn_modo   = $CanvasLayer/Control/Panel/Button   # Botón de modo en la UI
@onready var label_lectura = $Cabezal/LabelLectura
# --- VARIABLES DE CONFIGURACIÓN ---
var separacion_celdas = 4.0   # Distancia física entre bloques
var posicion_home_x   = 0.5   # Donde descansa la máquina

# --- VARIABLES DE ESTADO DE LA MÁQUINA ---
var cinta_datos      : Array = []   # Array lógico (0,1,2,...)
var celdas_visuales  : Array = []   # Nodos 3D Celda
var posicion_cabezal : int  = 0
var estado_actual    : String = "q0"
var maquina_corriendo: bool = false

# Alturas coherentes con Celda.gd
#var ALTURA_CINTA = 1.0
#var ALTURA_PALA  = 0.8

# -----------------------------------------------------
#  TABLAS DE ESTADOS
# -----------------------------------------------------

# SUMA UNARIA  (A + B)
# Cinta SUMA: 1^A 0 1^B 0 0 0...
"""
var reglas_suma = {
	"q0": {
		1: {"escribir": 0, "mover": 1, "next": "q1"},
		0: {"escribir": 0, "mover": 1, "next": "q0"}
	},
	"q1": {
		1: {"escribir": 1, "mover": 1, "next": "q1"},
		0: {"escribir": 1, "mover": 0, "next": "FINAL"}
	}
}
"""
var reglas_suma = {
	"q0": {
		1: {"escribir": 0, "mover": 1, "next": "q1"},
		0: {"escribir": 0, "mover": 1, "next": "q0"} 
	},
	"q1": {
		1: {"escribir": 1, "mover": 1, "next": "q1"},
		0: {"escribir": 0, "mover": 1, "next": "q2"} 
	},
	"q2": {
		1: {"escribir": 1, "mover": -1, "next": "q3"},
		
		0: {"escribir": 0, "mover": 1, "next": "q2"},
		
		2: {"escribir": 2, "mover": -1, "next": "FINAL"}
	},
	"q3": {
		0: {"escribir": 1, "mover": 0, "next": "FINAL"}
	}
}

# RESTA UNARIA (A - B, con A >= B)
# Cinta RESTA: 1^A 2 1^B 2 0 0 0...
# Símbolos:
# 0 = blanco, 1 = "1" unario, 2 = separador (cubo alto/rojo)
var reglas_resta = {
	# q0: ir hacia la derecha hasta encontrar el primer 2 (separador izquierdo)
	"q0": {
		0: {"escribir": 0, "mover": 1, "next": "q0"},
		1: {"escribir": 1, "mover": 1, "next": "q0"},
		2: {"escribir": 2, "mover": 1, "next": "q1"},  # estamos sobre la primera celda de B
	},
	# q1: recorrer B desde el separador izquierdo hacia la derecha para encontrar un 1
	# - Si encuentra 1 -> lo borra (1->0) y vuelve a la izquierda (q2)
	# - Si llega al separador derecho (2) sin encontrar 1 -> B vacío -> FIN
	"q1": {
		0: {"escribir": 0, "mover": 1, "next": "q1"},             # saltar ceros dentro de B
		1: {"escribir": 0, "mover": -1, "next": "q2"},            # borrar 1 de B y volver
		2: {"escribir": 2, "mover": 0, "next": "FINAL"},          # B vacío -> terminar
	},
	# q2: volver hacia la izquierda hasta el separador (2) entre A y B
	"q2": {
		0: {"escribir": 0, "mover": -1, "next": "q2"},
		1: {"escribir": 1, "mover": -1, "next": "q2"},
		2: {"escribir": 2, "mover": -1, "next": "q5"},            # entrar a A por la izquierda
	},
	# q5: buscar un 1 en A hacia la izquierda para borrarlo
	# (por la condición A >= B, siempre habrá un 1 aquí mientras queden 1 en B)
	"q5": {
		0: {"escribir": 0, "mover": -1, "next": "q5"},            # seguir hacia la izquierda
		1: {"escribir": 0, "mover": 1, "next": "q6"},             # borrar 1 de A y volver hacia el separador
		2: {"escribir": 2, "mover": 0, "next": "FINAL"},          # caso teórico de error (A < B), no debería ocurrir
	},
	# q6: volver hacia la derecha hasta el separador izquierdo y pasar a B de nuevo
	"q6": {
		0: {"escribir": 0, "mover": 1, "next": "q6"},
		1: {"escribir": 1, "mover": 1, "next": "q6"},
		2: {"escribir": 2, "mover": 1, "next": "q1"},             # ya estamos otra vez en B (siguiente ciclo)
	},
}

# La tabla que se usa realmente
var reglas = reglas_suma
var modo_actual : String = "suma"   # "suma" o "resta"

# =====================================================
#  _ready
# =====================================================
func _ready() -> void:
	# UI
	ui_input_a.value_changed.connect(actualizar_vista_previa)
	ui_input_b.value_changed.connect(actualizar_vista_previa)
	btn_start.pressed.connect(iniciar_simulacion)
	btn_reset.pressed.connect(resetear_todo)
	btn_modo.pressed.connect(_on_modo_pressed)

	# Switch 3D
	if switch3d and switch3d.has_signal("toggled"):
		switch3d.toggled.connect(_on_switch_toggled)

	# BOTONES 3D FÍSICOS
	if boton_start_3d and boton_start_3d.has_signal("pressed"):
		boton_start_3d.pressed.connect(_on_boton_start_3d_pressed)

	if boton_reset_3d and boton_reset_3d.has_signal("pressed"):
		boton_reset_3d.pressed.connect(_on_boton_reset_3d_pressed)

	btn_modo.text = "Modo: SUMA"
	cabezal.position.x = posicion_home_x
	generar_cinta_vacia(21)

# Handlers de los botones 3D
func _on_boton_start_3d_pressed() -> void:
	iniciar_simulacion()

func _on_boton_reset_3d_pressed() -> void:
	resetear_todo()

# =====================================================
#  CAMBIO DE MODO (función común)
# =====================================================
func _cambiar_modo(es_suma: bool) -> void:
	if maquina_corriendo:
		return
	
	var nuevo_modo = "suma" if es_suma else "resta"
	if modo_actual == nuevo_modo and celdas_visuales.size() > 0:
		return
	print("cambiando de operacion ")
	btn_start.disabled = true
	btn_reset.disabled = true
	btn_modo.disabled = true
	ui_input_a.editable = false
	ui_input_b.editable = false

	if celdas_visuales.size() > 0:
		await limpiar_cinta()
	
	if abs(cabezal.position.x - posicion_home_x) > 0.1:
		var tween = create_tween()
		tween.tween_property(cabezal, "position:x", posicion_home_x, 1.0).set_trans(Tween.TRANS_QUAD)
		await tween.finished
		
	if es_suma:
		modo_actual = "suma"
		reglas = reglas_suma
		btn_modo.text = "Modo: SUMA"
	else:
		modo_actual = "resta"
		reglas = reglas_resta
		btn_modo.text = "Modo: RESTA"
		
	if cartel_instrucciones:
		cartel_instrucciones.cambiar_modo(es_suma)
		

	print("Cambiado a modo: ", modo_actual)
	#actualizar_vista_previa(0)
	generar_cinta_vacia(21)
	ui_input_a.set_value_no_signal(0)
	ui_input_b.set_value_no_signal(0)
	
	btn_start.disabled = false
	btn_reset.disabled = false
	btn_modo.disabled = false
	ui_input_a.editable = true
	ui_input_b.editable = true

# =====================================================
#  BOTÓN MODO (Suma / Resta)
# =====================================================
func _on_modo_pressed() -> void:
	_cambiar_modo(modo_actual != "suma")

# =====================================================
#  SWITCH 3D (Señal toggled)
# =====================================================
func _on_switch_toggled(es_suma: bool) -> void:
	_cambiar_modo(es_suma)

# =====================================================
# 1) PREPARACIÓN Y UI
# =====================================================
func actualizar_vista_previa(_ignorar) -> void:
	if maquina_corriendo:
		return

	var num_a = int(ui_input_a.value)
	var num_b = int(ui_input_b.value)

	for c in celdas_visuales:
		c.queue_free()
	celdas_visuales.clear()
	cinta_datos.clear()

	if modo_actual == "suma":
		# SUMA: 1^A 0 1^B 00000
		for i in range(num_a):
			cinta_datos.append(1)
		cinta_datos.append(0)
		for i in range(num_b):
			cinta_datos.append(1)
	else:
		# RESTA: 1^A 2 1^B 2 00000
		for i in range(num_a):
			cinta_datos.append(1)   # A
		cinta_datos.append(2)       # separador izquierdo
		for i in range(num_b):
			cinta_datos.append(1)   # B
		cinta_datos.append(2)       # separador derecho

	var ocupadas = cinta_datos.size()
	var tamano_mesa = 21
	var celdas_relleno = max(5, tamano_mesa - ocupadas)
	# Zonas en blanco al final
	for i in range(celdas_relleno):
		cinta_datos.append(0)

	# Construcción visual
	for i in range(cinta_datos.size()):
		var nueva = celda_scene.instantiate()
		nodo_cinta.add_child(nueva)
		nueva.position.x = i * separacion_celdas

		var simbolo_visual : int
		match cinta_datos[i]:
			0: simbolo_visual = Celda.Simbolo.BLANCO
			1: simbolo_visual = Celda.Simbolo.UNO
			2: simbolo_visual = Celda.Simbolo.SEPARADOR
			_: simbolo_visual = Celda.Simbolo.BLANCO

		nueva.forzar_estado_sin_animar(simbolo_visual)
		celdas_visuales.append(nueva)

# =====================================================
# 2) CONTROL DE SIMULACIÓN
# =====================================================
func iniciar_simulacion() -> void:
	if maquina_corriendo:
		return
	maquina_corriendo = true

	btn_start.disabled = true
	ui_input_a.editable = false
	ui_input_b.editable = false

	if modo_actual == "suma":
		print("--- ENCENDIENDO MOTORES (SUMA) ---")
	else:
		print("--- ENCENDIENDO MOTORES (RESTA) ---")

	# Leer desde las celdas visuales → convertir a 0/1/2 lógico
	cinta_datos.clear()
	for celda in celdas_visuales:
		var v:int = celda.valor
		var logico:int = 0
		match v:
			Celda.Simbolo.BLANCO:    logico = 0
			Celda.Simbolo.UNO:       logico = 1
			Celda.Simbolo.SEPARADOR: logico = 2
			_:                       logico = 0
		cinta_datos.append(logico)

	print("Cinta lógica inicial: ", cinta_datos)

	var eje_servo = cabezal.get_node("EjeServo")
	var tween_wake = create_tween()
	tween_wake.tween_property(eje_servo, "rotation_degrees:x", 15.0, 0.2)
	tween_wake.tween_property(eje_servo, "rotation_degrees:x", 0.0, 0.2)
	await tween_wake.finished

	posicion_cabezal = 0
	estado_actual = "q0"
	ejecutar_paso()

func resetear_todo() -> void:
	print("--- RESET ---")
	maquina_corriendo = false
	estado_actual = "STOP"

	btn_start.disabled = true
	btn_reset.disabled = true
	ui_input_a.editable = true
	ui_input_b.editable = true
	
	await limpiar_cinta()

	var tween = create_tween()
	tween.tween_property(cabezal, "position:x", posicion_home_x, 1.0).set_trans(Tween.TRANS_QUAD)
	await tween.finished

	generar_cinta_vacia(21)
	
	btn_start.disabled = false
	btn_reset.disabled = false
	ui_input_a.editable = true
	ui_input_b.editable = true

func limpiar_cinta() -> void:
	for i in range(celdas_visuales.size()):
		var celda = celdas_visuales[i]
		if celda.valor != Celda.Simbolo.BLANCO:
			# A. Mover el cabezal hasta esa posición
			# (Lo hacemos un poco más rápido que lo normal: 0.4s en vez de 1.0s)
			var destino_x = i * separacion_celdas
			
			# Solo nos movemos si no estamos ya ahí (pequeña optimización)
			if abs(cabezal.position.x - destino_x) > 0.1:
				var t_mov = create_tween()
				t_mov.tween_property(cabezal, "position:x", destino_x, 0.4).set_trans(Tween.TRANS_QUAD)
				await t_mov.finished
			
			# Actualizamos la posición lógica del cabezal por si acaso
			posicion_cabezal = i
			
			# B. Empujar el cubo (Usamos tu función existente)
			# Nota: maniobra_empujar_palo espera recibir la celda visual
			await maniobra_empujar_palo(celda)
			
			# C. Actualizar el valor lógico inmediatamente para evitar errores si se vuelve a iterar
			celda.valor = Celda.Simbolo.BLANCO
			cinta_datos[i] = 0
# =====================================================
# 3) LÓGICA DE LA MÁQUINA DE TURING
# =====================================================
func ejecutar_paso() -> void:
	if not maquina_corriendo:
		return

	if estado_actual == "FINAL":
		if modo_actual == "suma":
			print("--- SUMA COMPLETADA ---")
		else:
			print("--- RESTA COMPLETADA ---")
		print("Cinta final: ", cinta_datos)
		var resultado = cinta_datos.count(1)
		animar_resultado_final(resultado)
		maquina_corriendo = false
		btn_reset.disabled = false
		btn_modo.disabled = false
		return

	var valor_leido = cinta_datos[posicion_cabezal]
	print("Estado: ", estado_actual, " | Pos: ", posicion_cabezal, " | Lee: ", valor_leido)
	animar_etiqueta_lectura(valor_leido)

	await get_tree().create_timer(0.5).timeout

	if not reglas.has(estado_actual) or not reglas[estado_actual].has(valor_leido):
		print("ERROR CRÍTICO: Estado no definido en la tabla: ", estado_actual, " leyendo ", valor_leido)
		maquina_corriendo = false
		return

	var accion = reglas[estado_actual][valor_leido]

	# 3. ESCRIBIR
	if accion["escribir"] != valor_leido:
		cinta_datos[posicion_cabezal] = accion["escribir"]
		await animar_servo_mecanico(posicion_cabezal, accion["escribir"])

	# 4. MOVER
	if accion["mover"] != 0:
		posicion_cabezal += accion["mover"]
		if posicion_cabezal < 0:
			posicion_cabezal = 0
		if posicion_cabezal >= cinta_datos.size():
			posicion_cabezal = cinta_datos.size() - 1

		var nueva_pos_x = posicion_cabezal * separacion_celdas
		var tween_mov = create_tween()
		tween_mov.tween_property(cabezal, "position:x", nueva_pos_x, 1.0).set_trans(Tween.TRANS_QUAD)
		await tween_mov.finished

	estado_actual = accion["next"]
	ejecutar_paso()

# =====================================================
# 4) ANIMACIÓN FÍSICA
# =====================================================
func animar_servo_mecanico(indice_celda:int, nuevo_valor:int) -> void:
	var celda_visual = celdas_visuales[indice_celda]

	if nuevo_valor == 0:
		await maniobra_empujar_palo(celda_visual)
	else:
		# nuevo_valor == 1 (en suma) — en resta nunca escribimos 2, los separadores no cambian
		await maniobra_levantar_pala(celda_visual)

func maniobra_empujar_palo(celda_visual) -> void:
	# SEGURIDAD 1
	if not is_instance_valid(celda_visual): return
	
	var eje_servo   = cabezal.get_node("EjeServo")
	var tapa_fisica = celda_visual.get_node("Tapa")
	var tapa_visual = tapa_fisica.get_node("Tapa")
	
	# Calculamos el destino final exacto
	# (Usamos la lógica que ya tenías para saber dónde debe quedar en la pala)
	var altura_final_reposo = celda_visual.altura_pala
	
	# --- FASE 1: PREPARAR BRAZO ---
	var t1 = create_tween()
	t1.tween_property(eje_servo, "rotation_degrees:x", 0.0, 0.1)
	await t1.finished

	# SEGURIDAD 2
	if not is_instance_valid(tapa_fisica): return

	# ASEGURARNOS DE QUE LA FÍSICA ESTÁ APAGADA
	# Esto es la clave: no dejamos que el motor de física calcule colisiones
	tapa_fisica.freeze = true 

	# --- FASE 2: EMPUJAR HACIA AFUERA (Eje Z) ---
	# Movemos el brazo y el cubo a la vez hacia afuera
	var t2 = create_tween().set_parallel(true)
	t2.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Animación del servo
	t2.tween_property(eje_servo, "rotation_degrees:x", -25.0, 0.3)
	
	# Empujamos el cubo SOLO en Z (hacia afuera de la repisa)
	# Mantenemos su altura Y actual un momento para que parezca que desliza
	t2.tween_property(tapa_fisica, "position:z", 2.0, 0.3)
	tapa_fisica.scale = Vector3.ONE
	#t2.tween_property(tapa_visual, "scale", celda_visual.escala_base, 0.3)
	print("Escala aplicada: ", celda_visual.escala_base)
	tapa_visual.scale = celda_visual.escala_base
	
	await t2.finished
	
	# SEGURIDAD 3
	if not is_instance_valid(tapa_fisica): return
	
	# --- FASE 3: CAÍDA CONTROLADA (Simulando Gravedad) ---
	# En lugar de physics.freeze = false, usamos un Tween hacia abajo.
	
	var t_caida = create_tween()
	# Usamos TRANS_BOUNCE para que de un pequeño "saltito" al caer, simulando impacto
	t_caida.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# Le decimos: "Cae exactamente a la altura de la pala"
	# Así es IMPOSIBLE que se hunda, porque el Tween para en el milímetro exacto.
	t_caida.tween_property(tapa_fisica, "position:y", altura_final_reposo, 0.5)
	
	# Retirar el brazo servo mientras cae el cubo
	if is_instance_valid(eje_servo):
		var t3 = create_tween()
		t3.tween_property(eje_servo, "rotation_degrees:x", 0.0, 0.3)

	await t_caida.finished
	
	# --- FASE 4: LIMPIEZA FINAL ---
	# Aseguramos rotación cero por si acaso
	tapa_fisica.rotation = Vector3.ZERO
	
	# Actualizar lógica interna
	if is_instance_valid(celda_visual):
		celda_visual.valor = 0
		if tapa_visual:
			tapa_visual.scale = celda_visual.escala_base
		#if celda_visual.has_method("set_valor"):
		#	celda_visual.valor = 0 
		#else:
		#	celda_visual.valor = 0
	"""
	var eje_servo   = cabezal.get_node("EjeServo")
	var tapa_fisica = celda_visual.get_node("Tapa")
	var altura_dest = celda_visual.altura_pala
	
	var t1 = create_tween()
	t1.tween_property(eje_servo, "rotation_degrees:x", 0.0, 0.1)
	await t1.finished

	var t2 = create_tween().set_parallel(true)
	t2.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t2.tween_property(eje_servo, "rotation_degrees:x", -25.0, 0.4)
	t2.tween_property(tapa_fisica, "position:z", 2.0, 0.4)
	await t2.finished
	
	tapa_fisica.freeze = false
	await get_tree().create_timer(0.8).timeout

	tapa_fisica.freeze = true	
	
	var t3 = create_tween()
	t3.tween_property(eje_servo, "rotation_degrees:x", 0.0, 0.3)
	await t3.finished
	
	# Actualizar lógica interna (0 = Abajo en la pala)
	if celda_visual.has_method("forzar_estado_sin_animar"):
		celda_visual.valor = 0 
		#celda_visual.forzar_estado_sin_animar(0)
		# IMPORTANTE: Forzamos visualmente que se quede abajo
		#tapa_fisica.position.y = ALTURA_PALA
		#tapa_fisica.position.z = 2.0
		#ALTURA_PALA = tapa_fisica.position.y
	"""
	"""
	var t3 = create_tween()
	t3.tween_property(eje_servo, "rotation_degrees:x", 0.0, 0.3)
	await t3.finished

	if celda_visual.has_method("forzar_estado_sin_animar"):
		celda_visual.forzar_estado_sin_animar(Celda.Simbolo.BLANCO)
	else:
		celda_visual.valor = Celda.Simbolo.BLANCO
	"""

func maniobra_levantar_pala(celda_visual) -> void:
	await celda_visual.animar_retorno_pala()

# =====================================================
# 5) GENERAR CINTA VACÍA
# =====================================================
func generar_cinta_vacia(cantidad:int) -> void:
	for c in celdas_visuales:
		c.queue_free()
	celdas_visuales.clear()
	cinta_datos.clear()

	for i in range(cantidad):
		cinta_datos.append(0)

		var nueva = celda_scene.instantiate()
		nodo_cinta.add_child(nueva)
		nueva.position.x = i * separacion_celdas
		nueva.forzar_estado_sin_animar(Celda.Simbolo.BLANCO)

		celdas_visuales.append(nueva)


func animar_etiqueta_lectura(valor_leido: int) -> void:
	if not label_lectura: return	
	var texto_valor = ""
	match valor_leido:
		0: texto_valor = "0"
		1: texto_valor = "1"
		2: texto_valor = "SEPARADOR"
	
	label_lectura.text = estado_actual + " | Lee: " + texto_valor
	
	match valor_leido:
		0: label_lectura.modulate = Color.WHITE
		1: label_lectura.modulate = Color.CYAN 
		2: label_lectura.modulate = Color.RED
	
	var t = create_tween()
	t.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_property(label_lectura, "scale", Vector3(1.5, 1.5, 1.5), 0.2)
	t.tween_property(label_lectura, "scale", Vector3.ONE, 0.2)
	
	
func animar_resultado_final(resultado: int) -> void:
	if not label_lectura: return
	
	
	label_lectura.text = "OPERACIÓN TERMINADA\nResultado: " + str(resultado)
	
	label_lectura.modulate = Color(0.2, 1.0, 0.2) 
	
	var t = create_tween()
	t.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	t.tween_property(label_lectura, "scale", Vector3(2.0, 2.0, 2.0), 0.5)
	t.tween_property(label_lectura, "scale", Vector3(1.5, 1.5, 1.5), 0.3)
