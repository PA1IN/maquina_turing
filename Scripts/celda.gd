extends Node3D

# 1 = Tapa Cerrada (Hueco cubierto, tapa en el centro)
# 0 = Tapa Abierta (Hueco visible, tapa deslizada al lado)
var valor: int = 0 
@onready var tapa = $Tapa

var altura_cinta = 1
var altura_pala = 0.8


func set_valor(nuevo_valor: int):
	valor = nuevo_valor
	actualizar_visual()

func actualizar_visual():
	var tween = create_tween().set_parallel(true)
	# Usamos TRANS_BOUNCE o TRANS_CUBIC para que se vea más mecánico
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	if valor == 1:
		# CERRAR: La tapa vuelve a la posición Z = 0 (Centro del riel)
		tween.tween_property(tapa, "position:z", 0.0, 0.5)
		tween.tween_property(tapa, "position:y", altura_cinta, 0.5)
	else:
		# ABRIR: La tapa se mueve lateralmente en el eje Z
		# Usamos 2.0 para que se salga completamente del camino y deje ver el hueco
		tween.tween_property(tapa, "position:z", 2.0, 0.5)
		tween.tween_property(tapa, "position:y", altura_pala, 0.5)

		
# Función para actualizar el estado lógico sin disparar la animación interna.
# Usaremos esto cuando el "Main" quiera controlar la animación manualmente.
"""func forzar_estado_sin_animar(nuevo_valor: int):
	valor = nuevo_valor
	# Aseguramos que la tapa quede en la posición final correcta
	if valor == 1:
		$Tapa.position.z = 0.0
	else:
		$Tapa.position.z = 2.0
"""
# En Celda.gd -> forzar_estado_sin_animar
func forzar_estado_sin_animar(nuevo_valor: int):
	valor = nuevo_valor
	# Ajusta estos valores según las alturas que definiste en Main
	
	
	if valor == 1: # CERRADO (En la cinta)
		$Tapa.position.z = 0.0
		$Tapa.position.y = altura_cinta
	else: # ABIERTO (En la pala/suelo)
		$Tapa.position.z = 2.0
		$Tapa.position.y = altura_pala

func _on_area_3d_input_event(camera, event, position, normal, shape_idx):
	# Detectar si es clic izquierdo y si acaba de ser presionado
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# INTERRUPTOR: Si es 0 pasa a 1, si es 1 pasa a 0
			if valor == 0:
				set_valor(1)
			else:
				set_valor(0)
			
			print("Celda cambiada manualmente a: ", valor)


func animar_retorno_pala():
	# Referencias locales (Ahora son hijos de la celda)
	var pivote = $SistemaPala/PivotePrincipal
	var tapa_fisica = $Tapa
	
	# Usamos las variables de altura que ya tienes definidas en este script
	# (Asegúrate de que ALTURA_CINTA y ALTURA_PALA tengan los valores correctos arriba)
	
	# 1. LEVANTAR (SCOOP)
	var t_levantar = create_tween().set_parallel(true)
	t_levantar.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# A. La Pala Gira
	t_levantar.tween_property(pivote, "rotation_degrees:x", -60.0, 0.8)
	
	# B. El Cubo sube y entra
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
	
	# Actualizar estado lógico
	valor = 1
