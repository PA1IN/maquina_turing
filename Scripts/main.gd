extends Node3D

# --- REFERENCIAS A ESCENAS Y NODOS 3D ---
var celda_scene = preload("res://Escenas/Celda.tscn")
@onready var nodo_cinta = $Cinta
@onready var cabezal    = $Cabezal

# --- REFERENCIAS A LA INTERFAZ DE USUARIO (UI) ---
@onready var ui_input_a = $CanvasLayer/Control/Panel/InputA
@onready var ui_input_b = $CanvasLayer/Control/Panel/InputB
@onready var btn_start  = $CanvasLayer/Control/Panel/BotonStart
@onready var btn_reset  = $CanvasLayer/Control/Panel/BotonReset
@onready var btn_modo   = $CanvasLayer/Control/Panel/Button   # <--- tu botón “Button”

# --- VARIABLES DE CONFIGURACIÓN ---
var separacion_celdas = 4.0   # Distancia física entre bloques
var posicion_home_x   = 0.5   # Donde descansa la máquina

# --- VARIABLES DE ESTADO DE LA MÁQUINA ---
var cinta_datos      : Array = []   # Array lógico (0,1,0,...)
var celdas_visuales  : Array = []   # Nodos 3D Celda
var posicion_cabezal : int  = 0
var estado_actual    : String = "q0"
var maquina_corriendo: bool = false

# Alturas coherentes con Celda.gd
var ALTURA_CINTA = 1.0
var ALTURA_PALA  = 0.8

# -----------------------------------------------------
#  TABLAS DE ESTADOS
# -----------------------------------------------------

# SUMA UNARIA  (A + B)
# Cinta: 1^A 0 1^B 0 0 0...
var reglas_suma = {
	"q0": {
		1: {"escribir": 0, "mover": 1, "next": "q1"},
		0: {"escribir": 0, "mover": 0, "next": "FINAL"}
	},
	"q1": {
		1: {"escribir": 1, "mover": 1, "next": "q1"},
		0: {"escribir": 1, "mover": 0, "next": "FINAL"}
	}
}

# RESTA UNARIA  (A - B, con A >= B)
# Cinta: 1^A 0 1^B 0 0 0...
var reglas_resta = {
	"q0": { # recorre A hasta el separador
		1: {"escribir": 1, "mover": 1, "next": "q0"},
		0: {"escribir": 0, "mover": 1, "next": "q1"}
	},
	"q1": { # mira si B está vacío o no
		0: {"escribir": 0, "mover": 0, "next": "FINAL"}, # B vacío → termina
		1: {"escribir": 1, "mover": 1, "next": "q2"}     # hay al menos un 1 en B
	},
	"q2": { # recorre el bloque de unos de B
		1: {"escribir": 1, "mover": 1, "next": "q2"},
		0: {"escribir": 0, "mover": -1, "next": "q3"}    # llega al 0 después de B
	},
	"q3": { # borra el último 1 de B (el que está a la izquierda)
		1: {"escribir": 0, "mover": -1, "next": "q4"},
		0: {"escribir": 0, "mover": -1, "next": "q4"}    # protección
	},
	"q4": { # vuelve hacia la izquierda cruzando B
		1: {"escribir": 1, "mover": -1, "next": "q4"},
		0: {"escribir": 0, "mover": -1, "next": "q5"}    # cruza el separador
	},
	"q5": { # busca un 1 en A para borrarlo
		0: {"escribir": 0, "mover": -1, "next": "q5"},
		1: {"escribir": 0, "mover": 1, "next": "q0"}     # borra un 1 de A y reinicia
	}
}

# La tabla que se usa realmente
var reglas = reglas_suma
var modo_actual : String = "suma"   # "suma" o "resta"

# =====================================================
#  _ready
# =====================================================
func _ready():
	# Conectar UI
	ui_input_a.value_changed.connect(actualizar_vista_previa)
	ui_input_b.value_changed.connect(actualizar_vista_previa)
	btn_start.pressed.connect(iniciar_simulacion)
	btn_reset.pressed.connect(resetear_todo)
	btn_modo.pressed.connect(_on_modo_pressed)
	
	# Texto inicial del botón de modo
	btn_modo.text = "Modo: SUMA"
	
	# Posición inicial del cabezal
	cabezal.position.x = posicion_home_x
	
	# Cinta vacía inicial
	generar_cinta_vacia(21)

# =====================================================
#  BOTÓN MODO (Suma / Resta)
# =====================================================
func _on_modo_pressed():
	if maquina_corriendo:
		return  # no cambiar modo en medio de una operación
	
	if modo_actual == "suma":
		modo_actual = "resta"
		reglas = reglas_resta
		btn_modo.text = "Modo: RESTA"
	else:
		modo_actual = "suma"
		reglas = reglas_suma
		btn_modo.text = "Modo: SUMA"
	
	print("Cambiado a modo: ", modo_actual)
	# Regenerar vista previa con el nuevo modo (la cinta es la misma, solo cambia la lógica)
	actualizar_vista_previa(0)

# =====================================================
# 1) PREPARACIÓN Y UI
# =====================================================
func actualizar_vista_previa(_ignorar):
	if maquina_corriendo:
		return
	
	var num_a = int(ui_input_a.value)
	var num_b = int(ui_input_b.value)
	
	for c in celdas_visuales:
		c.queue_free()
	celdas_visuales.clear()
	cinta_datos.clear()
	
	# Cinta lógica: A 0 B 00000 (misma representación para suma y resta)
	for i in range(num_a):
		cinta_datos.append(1)
	cinta_datos.append(0)
	for i in range(num_b):
		cinta_datos.append(1)
	for i in range(5):
		cinta_datos.append(0)
	
	# Construcción visual
	for i in range(cinta_datos.size()):
		var nueva = celda_scene.instantiate()
		nodo_cinta.add_child(nueva)
		nueva.position.x = i * separacion_celdas
		nueva.set_valor(cinta_datos[i])
		
		var tapa = nueva.get_node("Tapa")
		if cinta_datos[i] == 0:
			tapa.position.z = 2.0
			tapa.position.y = ALTURA_PALA
		else:
			tapa.position.z = 0.0
			tapa.position.y = ALTURA_CINTA
		
		celdas_visuales.append(nueva)

# =====================================================
# 2) CONTROL DE SIMULACIÓN
# =====================================================
func iniciar_simulacion():
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
	
	# Leer desde las celdas visuales
	cinta_datos.clear()
	for celda in celdas_visuales:
		cinta_datos.append(celda.valor)
	print("Cinta lógica inicial: ", cinta_datos)
	
	# Pequeño "saludo" del servo
	var eje_servo = cabezal.get_node("EjeServo")
	var tween_wake = create_tween()
	tween_wake.tween_property(eje_servo, "rotation_degrees:x", 15.0, 0.2)
	tween_wake.tween_property(eje_servo, "rotation_degrees:x", 0.0, 0.2)
	await tween_wake.finished
	
	posicion_cabezal = 0
	estado_actual = "q0"
	ejecutar_paso()

func resetear_todo():
	print("--- RESET ---")
	maquina_corriendo = false
	estado_actual = "STOP"
	
	btn_start.disabled = false
	ui_input_a.editable = true
	ui_input_b.editable = true
	
	var tween = create_tween()
	tween.tween_property(cabezal, "position:x", posicion_home_x, 1.0).set_trans(Tween.TRANS_QUAD)
	
	generar_cinta_vacia(21)

# =====================================================
# 3) LÓGICA DE LA MÁQUINA DE TURING
# =====================================================
func ejecutar_paso():
	if not maquina_corriendo:
		return
	
	if estado_actual == "FINAL":
		if modo_actual == "suma":
			print("--- SUMA COMPLETADA ---")
		else:
			print("--- RESTA COMPLETADA ---")
		print("Cinta final: ", cinta_datos)
		return
	
	var valor_leido = cinta_datos[posicion_cabezal]
	print("Estado: ", estado_actual, " | Pos: ", posicion_cabezal, " | Lee: ", valor_leido)
	
	await get_tree().create_timer(0.5).timeout
	
	if not reglas.has(estado_actual) or not reglas[estado_actual].has(valor_leido):
		print("ERROR CRÍTICO: Estado no definido en la tabla.")
		return
	
	var accion = reglas[estado_actual][valor_leido]
	
	# 3. ESCRIBIR
	if accion["escribir"] != valor_leido:
		cinta_datos[posicion_cabezal] = accion["escribir"]
		await animar_servo_mecanico(posicion_cabezal, accion["escribir"])
	
	# 4. MOVER
	if accion["mover"] != 0:
		posicion_cabezal += accion["mover"]
		var nueva_pos_x = posicion_cabezal * separacion_celdas
		var tween_mov = create_tween()
		tween_mov.tween_property(cabezal, "position:x", nueva_pos_x, 1.0).set_trans(Tween.TRANS_QUAD)
		await tween_mov.finished
	
	# 5. SIGUIENTE ESTADO
	estado_actual = accion["next"]
	ejecutar_paso()

# =====================================================
# 4) ANIMACIÓN FÍSICA (IGUAL QUE EN LA SUMA)
# =====================================================
func animar_servo_mecanico(indice_celda:int, nuevo_valor:int):
	var celda_visual = celdas_visuales[indice_celda]
	
	if nuevo_valor == 0:
		await maniobra_empujar_palo(celda_visual)
	else:
		await maniobra_levantar_pala(celda_visual)

# --- SUB-RUTINA 1: EL PALO (empuja y desliza a Z=2.0) ---
func maniobra_empujar_palo(celda_visual):
	var eje_servo   = cabezal.get_node("EjeServo")
	var tapa_fisica = celda_visual.get_node("Tapa")
	
	var t1 = create_tween()
	t1.tween_property(eje_servo, "rotation_degrees:x", 0.0, 0.1)
	await t1.finished
	
	var t2 = create_tween().set_parallel(true)
	t2.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t2.tween_property(eje_servo, "rotation_degrees:x", -25.0, 0.4)
	t2.tween_property(tapa_fisica, "position:z", 2.0, 0.4)
	await t2.finished
	
	var t3 = create_tween()
	t3.tween_property(eje_servo, "rotation_degrees:x", 0.0, 0.3)
	await t3.finished
	
	if celda_visual.has_method("forzar_estado_sin_animar"):
		celda_visual.forzar_estado_sin_animar(0)
	else:
		celda_visual.valor = 0

# --- SUB-RUTINA 2: LA PALA (usa animación local de Celda.gd) ---
func maniobra_levantar_pala(celda_visual):
	await celda_visual.animar_retorno_pala()

# =====================================================
# 5) GENERAR CINTA VACÍA
# =====================================================
func generar_cinta_vacia(cantidad:int):
	for c in celdas_visuales:
		c.queue_free()
	celdas_visuales.clear()
	cinta_datos.clear()
	
	for i in range(cantidad):
		cinta_datos.append(0)
		
		var nueva = celda_scene.instantiate()
		nodo_cinta.add_child(nueva)
		nueva.position.x = i * separacion_celdas
		nueva.set_valor(0)
		
		var tapa = nueva.get_node("Tapa")
		tapa.position.y = ALTURA_PALA
		tapa.position.z = 2.0
		
		celdas_visuales.append(nueva)
