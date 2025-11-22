extends Node3D

# --- REFERENCIAS A ESCENAS Y NODOS 3D ---
var celda_scene = preload("res://Escenas/Celda.tscn")
@onready var nodo_cinta = $Cinta
@onready var cabezal = $Cabezal

# --- REFERENCIAS A LA INTERFAZ DE USUARIO (UI) ---
# Ajusta estas rutas si tu UI tiene nombres distintos
@onready var ui_input_a = $CanvasLayer/Control/Panel/InputA
@onready var ui_input_b = $CanvasLayer/Control/Panel/InputB
@onready var btn_start = $CanvasLayer/Control/Panel/BotonStart
@onready var btn_reset = $CanvasLayer/Control/Panel/BotonReset

# --- VARIABLES DE CONFIGURACIÓN ---
var separacion_celdas = 4.0  # Distancia física entre bloques
var posicion_home_x = 0.5   # Donde descansa la máquina (fuera de la cinta)

# --- VARIABLES DE ESTADO DE LA MÁQUINA ---
var cinta_datos = []      # Array lógico (0, 1, 0...)
var celdas_visuales = []  # Array de nodos 3D
var posicion_cabezal = 0  # Índice en el array
var estado_actual = "q0"  # Estado del autómata
var maquina_corriendo = false

# --- TABLA DE ESTADOS (SUMA UNARIA) ---
# Algoritmo: Borra el primer 1, viaja al hueco, lo rellena con 1.
var reglas = {
	"q0": { 
		1: {"escribir": 0, "mover": 1, "next": "q1"}, 
		0: {"escribir": 0, "mover": 0, "next": "FINAL"} 
	},
	"q1": { 
		1: {"escribir": 1, "mover": 1, "next": "q1"}, 
		0: {"escribir": 1, "mover": 0, "next": "FINAL"} 
	}
}

func _ready():
	# 1. Conectar señales de la UI
	# Cada vez que cambies un número, se regenera la cinta visual
	ui_input_a.value_changed.connect(actualizar_vista_previa)
	ui_input_b.value_changed.connect(actualizar_vista_previa)
	
	# Botones de control
	btn_start.pressed.connect(iniciar_simulacion)
	btn_reset.pressed.connect(resetear_todo)
	
	# 2. Inicialización Física
	cabezal.position.x = posicion_home_x # Mandar a "Home"
	
	# 3. Generar primera cinta con los valores por defecto de los SpinBox
	#actualizar_vista_previa(0)
	generar_cinta_vacia(21)
# ==============================================================================
#  SECCIÓN 1: PREPARACIÓN Y UI (MODO EDICIÓN)
# ==============================================================================

func actualizar_vista_previa(_valor_ignorado):
	# Si la máquina está trabajando, no dejamos cambiar los cubos
	if maquina_corriendo: return
	
	# 1. Leer valores de la UI
	var num_a = int(ui_input_a.value)
	var num_b = int(ui_input_b.value)
	
	# 2. Limpiar escenario anterior
	for c in celdas_visuales: c.queue_free()
	celdas_visuales.clear()
	cinta_datos.clear()
	
	# 3. Construir Lógica (Input A + Separador + Input B + Margen)
	for i in range(num_a): cinta_datos.append(1)
	cinta_datos.append(0) # El separador
	for i in range(num_b): cinta_datos.append(1)
	# Añadimos espacio extra al final
	for i in range(5): cinta_datos.append(0)
	
	# 4. Construir Visuales
	for i in range(cinta_datos.size()):
		var nueva = celda_scene.instantiate()
		nodo_cinta.add_child(nueva)
		nueva.position.x = i * separacion_celdas
		nueva.set_valor(cinta_datos[i])
		
		var tapa = nueva.get_node("Tapa")
		# Posicionar tapas físicamente sin animación (Instantáneo)
		if cinta_datos[i] == 0: 
			#nueva.get_node("Tapa").position.z = 2.0 # Abierta
			tapa.position.z = 2.0
			tapa.position.y = ALTURA_PALA
		else: 
			#nueva.get_node("Tapa").position.z = 0.0 # Cerrada
			tapa.position.z = 0.0
			tapa.position.y = ALTURA_CINTA
			
			
		celdas_visuales.append(nueva)

# ==============================================================================
#  SECCIÓN 2: CONTROL DE SIMULACIÓN
# ==============================================================================

func iniciar_simulacion():
	if maquina_corriendo: return
	maquina_corriendo = true
	
	# Bloquear UI
	btn_start.disabled = true
	ui_input_a.editable = false
	ui_input_b.editable = false
	
	print("--- ENCENDIENDO MOTORES ---")
	print("Leyendo configuración manual de los cubos...")
	cinta_datos.clear() # Borramos la memoria lógica vieja
	
	# Recorremos cada objeto 3D en la mesa y preguntamos su valor
	for celda in celdas_visuales:
		cinta_datos.append(celda.valor) # Guardamos 1 o 0 según cómo dejaste la tapa
		
	print("Datos cargados en memoria: ", cinta_datos)
	# --- CAMBIO AQUÍ ---
	# Como ya estamos en la posición 0.0, no necesitamos movernos hacia ella.
	# Simplemente hacemos una pequeña pausa o un movimiento del servo para mostrar que despertó.
	
	var tween_wake = create_tween()
	# Pequeño "saludo" del servo para indicar que está viva
	var eje_servo = cabezal.get_node("EjeServo")
	tween_wake.tween_property(eje_servo, "rotation_degrees:x", 15.0, 0.2)
	tween_wake.tween_property(eje_servo, "rotation_degrees:x", 0.0, 0.2)
	await tween_wake.finished
	
	# 2. Arrancar lógica de Turing directamente
	posicion_cabezal = 0
	estado_actual = "q0"
	print("--- INICIANDO LECTURA ---")
	ejecutar_paso()

func resetear_todo():
	print("--- RESET DE EMERGENCIA ---")
	# Romper el ciclo de ejecución
	maquina_corriendo = false
	estado_actual = "STOP" 
	
	# Reactivar UI
	btn_start.disabled = false
	ui_input_a.editable = true
	ui_input_b.editable = true
	
	# Animar retorno a Home
	var tween = create_tween()
	tween.tween_property(cabezal, "position:x", posicion_home_x, 1.0).set_trans(Tween.TRANS_QUAD)
	
	# Restaurar la cinta original (como estaba antes de operar)
	#actualizar_vista_previa(0)
	generar_cinta_vacia(21)
# ==============================================================================
#  SECCIÓN 3: LÓGICA DE LA MÁQUINA DE TURING (EL CEREBRO)
# ==============================================================================

func ejecutar_paso():
	# Chequeo de seguridad: Si pulsamos reset, paramos aquí.
	if not maquina_corriendo: return
	
	if estado_actual == "FINAL":
		print("--- CÁLCULO COMPLETADO CON ÉXITO ---")
		print("Resultado Lógico: ", cinta_datos)
		# Aquí podrías lanzar fuegos artificiales o un sonido de éxito
		return

	# 1. LEER (Simulación de Sensor)
	var valor_leido = cinta_datos[posicion_cabezal]
	print("Estado: ", estado_actual, " | Pos: ", posicion_cabezal, " | Lee: ", valor_leido)
	
	# Tiempo de procesamiento simulado (0.5s)
	await get_tree().create_timer(0.5).timeout 
	
	# 2. CONSULTAR TABLA
	if not reglas.has(estado_actual) or not reglas[estado_actual].has(valor_leido):
		print("ERROR CRÍTICO: Estado no definido en la tabla.")
		return
	
	var accion = reglas[estado_actual][valor_leido]
	
	# 3. ESCRIBIR (Acción Mecánica del Servo)
	if accion["escribir"] != valor_leido:
		cinta_datos[posicion_cabezal] = accion["escribir"]
		# Llamamos a la animación del brazo robótico
		await animar_servo_mecanico(posicion_cabezal, accion["escribir"])
	
	# 4. MOVER (Acción del Motor Stepper)
	if accion["mover"] != 0:
		posicion_cabezal += accion["mover"]
		
		# Calcular posición física en metros
		var nueva_pos_x = posicion_cabezal * separacion_celdas
		
		var tween_mov = create_tween()
		# Movimiento lineal pesado
		tween_mov.tween_property(cabezal, "position:x", nueva_pos_x, 1.0).set_trans(Tween.TRANS_QUAD)
		await tween_mov.finished
	
	# 5. TRANSICIÓN DE ESTADO
	estado_actual = accion["next"]
	
	# Siguiente ciclo (Recursión)
	ejecutar_paso()

# ==============================================================================
#  SECCIÓN 4: ANIMACIÓN FÍSICA (INGENIERÍA)
# ==============================================================================
func animar_servo_mecanico(indice_celda, nuevo_valor):
	var celda_visual = celdas_visuales[indice_celda]
	
	if nuevo_valor == 0:
		# =================================================
		# CASO 0: EMPUJAR HACIA AFUERA (USA EL PALO VERDE)
		# =================================================
		await maniobra_empujar_palo(celda_visual)
		
	else:
		# =================================================
		# CASO 1: LEVANTAR HACIA ADENTRO (USA LA PALA)
		# =================================================
		await maniobra_levantar_pala(celda_visual)

# --- SUB-RUTINA 1: EL PALO (Lo que ya tenías) ---


# Altura a la que descansa el cubo sobre la cinta (Ajusta según tu escena Celda)
var ALTURA_CINTA = 1
# Altura a la que está la pala esperando abajo (Ajusta según tu SistemaPala)
var ALTURA_PALA = 0.4

# --- SUB-RUTINA 1: EL PALO EMPUJA Y EL CUBO CAE ---
func maniobra_empujar_palo(celda_visual):
	var eje_servo = cabezal.get_node("EjeServo")
	var tapa_fisica = celda_visual.get_node("Tapa")
	
	# 1. Preparar Servo
	var t1 = create_tween()
	t1.tween_property(eje_servo, "rotation_degrees:x", 0.0, 0.1)
	await t1.finished
	
	# 2. GOLPE + DESLIZAMIENTO (Sale de la cinta)
	var t2 = create_tween().set_parallel(true)
	t2.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t2.tween_property(eje_servo, "rotation_degrees:x", -25.0, 0.4)
	# El cubo se mueve hacia afuera (Z=2.0) MIENTRAS mantiene la altura de la cinta
	t2.tween_property(tapa_fisica, "position:z", 2.0, 0.4)
	await t2.finished
	
	# 3. CAÍDA POR GRAVEDAD (NUEVO)
	"""# Una vez afuera, el cubo cae hacia la pala
	var t_caida = create_tween()
	t_caida.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t_caida.tween_property(tapa_fisica, "position:y", ALTURA_PALA, 0.5)
	await t_caida.finished
	"""
	tapa_fisica.freeze = false
	await get_tree().create_timer(0.8).timeout

	tapa_fisica.freeze = true	
	
	# 4. Retorno del Servo
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
		ALTURA_PALA = tapa_fisica.position.y

# --- SUB-RUTINA 2: LA PALA LEVANTA Y DEPOSITA ---
func maniobra_levantar_pala(celda_visual):
	await celda_visual.animar_retorno_pala()
	"""var pivote = cabezal.get_node("SistemaPala/PivotePrincipal")
	var tapa_fisica = celda_visual.get_node("Tapa")
	
	# Asumimos que el cubo está abajo (Y = ALTURA_PALA, Z = 2.0)
	
	# 1. LEVANTAR (SCOOP) - Arco parabólico
	var t_levantar = create_tween().set_parallel(true)
	t_levantar.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# A. La Pala Gira hacia arriba
	t_levantar.tween_property(pivote, "rotation_degrees:x", -55.0, 0.8)
	
	# B. El Cubo sube desde el suelo hasta un poco más arriba de la cinta
	t_levantar.tween_property(tapa_fisica, "position:y", ALTURA_CINTA + 0.5, 0.6) 
	# C. El Cubo se acerca a la cinta en Z
	t_levantar.tween_property(tapa_fisica, "position:z", 0.5, 0.8)
	
	await t_levantar.finished
	
	# 2. DEPOSITAR SUAVE
	var t_depositar = create_tween()
	t_depositar.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# Cae en su lugar final sobre el riel
	t_depositar.parallel().tween_property(tapa_fisica, "position:z", 0.0, 0.3)
	t_depositar.parallel().tween_property(tapa_fisica, "position:y", ALTURA_CINTA, 0.3)
	
	await t_depositar.finished
	
	# 3. BAJAR PALA VACÍA
	var t_bajar = create_tween()
	t_bajar.tween_property(pivote, "rotation_degrees:x", 0.0, 0.6)
	await t_bajar.finished

	if celda_visual.has_method("forzar_estado_sin_animar"):
		celda_visual.forzar_estado_sin_animar(1)
		# Aseguramos posición final correcta
		tapa_fisica.position.y = ALTURA_CINTA
	"""






"""func maniobra_empujar_palo(celda_visual):
	var eje_servo = cabezal.get_node("EjeServo")
	var tapa_fisica = celda_visual.get_node("Tapa")
	
	# 1. Preparar (Palo vertical)
	var t1 = create_tween()
	t1.tween_property(eje_servo, "rotation_degrees:x", 0.0, 0.1)
	await t1.finished
	
	# 2. Golpe (-45 grados) + Deslizamiento del bloque
	var t2 = create_tween().set_parallel(true)
	t2.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t2.tween_property(eje_servo, "rotation_degrees:x", -25.0, 0.4)
	# El bloque va a la posición Z=2.0 (donde está la pala esperando)
	t2.tween_property(tapa_fisica, "position:z", 2.0, 0.4)
	await t2.finished
	
	# 3. Retorno
	var t3 = create_tween()
	t3.tween_property(eje_servo, "rotation_degrees:x", 0.0, 0.3)
	await t3.finished
	
	# Actualizar lógica interna
	if celda_visual.has_method("forzar_estado_sin_animar"):
		celda_visual.forzar_estado_sin_animar(0)
		

func maniobra_levantar_pala(celda_visual):
	# Referencias
	# Asegúrate de que el nombre coincida con lo que creaste en el paso 1
	var pivote = cabezal.get_node("SistemaPala/PivotePrincipal") 
	var tapa_fisica = celda_visual.get_node("Tapa")
	
	# --- FASE 1: LEVANTAR (SCOOP) ---
	# Según tu dibujo, la pala hace un arco hacia arriba y hacia la cinta.
	
	var t_levantar = create_tween().set_parallel(true)
	t_levantar.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# A. La Pala Gira (Simulando el empuje del servo)
	# Giramos -90 grados (o el ángulo necesario) para que la 'L' vuelque el cubo
	t_levantar.tween_property(pivote, "rotation_degrees:x", -110.0, 0.8)
	
	# B. El Cubo sigue el arco (Esto es el truco visual)
	# El cubo debe subir (Y) y moverse hacia adentro (Z) al mismo tiempo
	t_levantar.tween_property(tapa_fisica, "position:y", 0.8, 0.4) # Sube primero
	t_levantar.tween_property(tapa_fisica, "position:z", 0.5, 0.8) # Se mueve hacia la cinta
	
	await t_levantar.finished
	
	# --- FASE 2: DEPOSITAR EN LA CINTA ---
	# Ahora que está arriba, terminamos de empujarlo a su sitio final (0.0)
	var t_depositar = create_tween()
	t_depositar.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# El cubo cae en su lugar (Z=0, Y=0)
	t_depositar.parallel().tween_property(tapa_fisica, "position:z", 0.0, 0.3)
	t_depositar.parallel().tween_property(tapa_fisica, "position:y", 0.0, 0.3)
	
	await t_depositar.finished
	
	# --- FASE 3: RETORNO DE LA PALA ---
	# La pala baja vacía a su posición de espera
	var t_bajar = create_tween()
	t_bajar.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t_bajar.tween_property(pivote, "rotation_degrees:x", 0.0, 0.6)
	
	await t_bajar.finished

	# Actualizar lógica interna
	if celda_visual.has_method("forzar_estado_sin_animar"):
		celda_visual.forzar_estado_sin_animar(1)
# --- SUB-RUTINA 2: LA PALA (Nueva lógica) ---
"""

"""func maniobra_levantar_pala(celda_visual):
	# Referencia al nuevo nodo que creaste
	var eje_pala = cabezal.get_node("SistemaPala/PivotePrincipal")
	var tapa_fisica = celda_visual.get_node("Tapa")
	
	# Asumimos que la pala empieza horizontal (Rotación 0) aguantando el cubo
	
	# 1. LEVANTAR PALA (Rotar hacia la cinta)
	# Giramos, por ejemplo, 45 grados hacia la máquina para que el cubo "resbale"
	var t1 = create_tween().set_parallel(true)
	t1.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# A. La pala gira subiendo
	t1.tween_property(eje_pala, "rotation_degrees:x", -45.0, 0.6)
	
	# B. El cubo se mueve de vuelta a Z=0.0 (Sincronizado con la pala)
	# Hacemos que empiece a moverse un poquito después de que la pala inicie (delay)
	t1.tween_property(tapa_fisica, "position:z", 0.0, 0.5).set_delay(0.1)
	
	await t1.finished
	
	# 2. BAJAR PALA (Retorno a posición de espera)
	var t2 = create_tween()
	t2.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT) # Rebote al caer
	t2.tween_property(eje_pala, "rotation_degrees:x", 0.0, 0.5)
	await t2.finished

	# Actualizar lógica interna
	if celda_visual.has_method("forzar_estado_sin_animar"):
		celda_visual.forzar_estado_sin_animar(1)
"""


"""func animar_servo_mecanico(indice_celda, nuevo_valor):
	# Referencias a partes mecánicas
	var eje_servo = cabezal.get_node("EjeServo") 
	var celda_visual = celdas_visuales[indice_celda]
	var tapa_fisica = celda_visual.get_node("Tapa")
	
	# --- CONFIGURACIÓN DE ÁNGULOS ---
	# 0 = Abajo (Vertical)
	# -90 = Afuera (Horizontal hacia el usuario)
	
	var rotacion_inicio = 0.0
	var rotacion_final = 0.0
	
	if nuevo_valor == 0: # ABRIR (Empujar hacia afuera)
		rotacion_inicio = 0.0   # Empieza vertical
		rotacion_final = -25.0  # Termina horizontal (golpeando)
	else: # CERRAR (Traer hacia adentro)
		rotacion_inicio = -90.0 # Empieza horizontal (ya está afuera)
		rotacion_final = 0.0    # Termina vertical (trayendo el bloque)
	
	# 1. PREPARACIÓN
	# Colocar el brazo en posición de ataque instantáneamente
	var tween_prep = create_tween()
	tween_prep.tween_property(eje_servo, "rotation_degrees:x", rotacion_inicio, 0.1)
	await tween_prep.finished

	# 2. ACCIÓN FÍSICA (GOLPE + DESLIZAMIENTO)
	# Movemos el brazo y la tapa AL MISMO TIEMPO (Parallel)
	var tween_fisico = create_tween().set_parallel(true)
	tween_fisico.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# A. Girar Servo
	tween_fisico.tween_property(eje_servo, "rotation_degrees:x", rotacion_final, 0.5)
	
	# B. Deslizar Bloque (Consecuencia del golpe)
	var destino_z = 0.0
	if nuevo_valor == 0: destino_z = 2.0
	tween_fisico.tween_property(tapa_fisica, "position:z", destino_z, 0.5)
	
	await tween_fisico.finished
	
	# Actualizamos estado interno de la celda (función nueva en celda.gd)
	# Si no tienes esa función, asegúrate de agregarla en Celda.gd o usa set_valor() con cuidado
	if celda_visual.has_method("forzar_estado_sin_animar"):
		celda_visual.forzar_estado_sin_animar(nuevo_valor)
	else:
		celda_visual.valor = nuevo_valor # Fallback simple
	
	# 3. RETORNO A REPOSO (SAFE POSITION)
	# Devolvemos el brazo a vertical suavemente para que no choque al avanzar
	var tween_reset = create_tween()
	tween_reset.tween_property(eje_servo, "rotation_degrees:x", 0.0, 0.3)
	await tween_reset.finished
"""
func generar_cinta_vacia(cantidad: int):
	# 1. Limpiar lo que exista
	for c in celdas_visuales: c.queue_free()
	celdas_visuales.clear()
	cinta_datos.clear()
	
	# 2. Crear 'cantidad' de celdas, todas en 0 (Abiertas)
	for i in range(cantidad):
		cinta_datos.append(0) # Lógicamente es un 0
		
		var nueva = celda_scene.instantiate()
		nodo_cinta.add_child(nueva)
		nueva.position.x = i * separacion_celdas
		nueva.set_valor(0) 
		
		# Visualmente la tapa empieza abierta (afuera)
		var tapa = nueva.get_node("Tapa")
		tapa.position.y = ALTURA_PALA		
		
		celdas_visuales.append(nueva)
