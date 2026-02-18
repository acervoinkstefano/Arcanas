extends Node2D

# Referência para a cena da caixa para reinstanciar
@onready var box_scene: PackedScene = load("res://Entities/Props/Box/Box.tscn")

# Como os pedaços estão diretamente sob o Node2D 'Box' na imagem:
@onready var pieces_nodes = [
	$Fundo1, $Fundo2, $Fundo, $Topo, $Lateral, $Frente1, $Frente2, $Frente3
]

# Variáveis de controle
var broken: bool = false
var flash_count: int = 0
var max_flashes: int = 6
var flash_timer: Timer

func _ready() -> void:
	# Criar o timer programaticamente se não existir na cena
	if not has_node("FlashTimer"):
		flash_timer = Timer.new()
		flash_timer.name = "FlashTimer"
		add_child(flash_timer)
	else:
		flash_timer = $FlashTimer
		
	flash_timer.wait_time = 0.1
	flash_timer.one_shot = false
	if not flash_timer.timeout.is_connected(_on_flash_timeout):
		flash_timer.timeout.connect(_on_flash_timeout)
	
	# Inicialização: Pedaços começam congelados e alguns são escondidos aleatoriamente
	randomize_pieces()

func _process(_delta: float) -> void:
	# Reiniciar com barra de espaço
	if Input.is_key_pressed(KEY_SPACE):
		regenerate()
		
	if broken:
		return
		
	# Ataque multidirecional (WASD)
	var direction := get_input_direction()
	if direction != Vector2.ZERO:
		break_box(direction.normalized(), 1)

func get_input_direction() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): dir.y -= 1
	if Input.is_key_pressed(KEY_S): dir.y += 1
	if Input.is_key_pressed(KEY_A): dir.x -= 1
	if Input.is_key_pressed(KEY_D): dir.x += 1
	return dir

func randomize_pieces() -> void:
	# 'Fundo' deve ser a base que sempre aparece (conforme solicitado)
	for piece in pieces_nodes:
		if piece == null: continue
		
		if piece.name == "Fundo":
			piece.visible = true
		else:
			# 60% de chance de cada outro pedaço aparecer
			piece.visible = randf() > 0.4
		
		# Congela a física inicialmente
		if piece is RigidBody2D:
			piece.freeze = true
		
		# Se não for visível, desativamos completamente
		if not piece.visible:
			piece.process_mode = PROCESS_MODE_DISABLED

func break_box(direction: Vector2, force_level: int) -> void:
	if broken: return
	broken = true
	
	# Ativa a física e aplica impulsos
	activate_physics(direction, force_level)
	
	# Inicia o efeito de sumiço
	flash_timer.start()

func activate_physics(direction: Vector2, force_level: int) -> void:
	var force_strength: float = 450.0 * force_level
	
	for piece in pieces_nodes:
		if piece == null or not piece.visible: continue
		
		if piece is RigidBody2D:
			# Ativa a física real
			piece.freeze = false
			
			# Remove colisões para movimento fluido após quebrar
			piece.collision_layer = 0
			piece.collision_mask = 0
			
			# Cálculo de direção com variação natural
			var random_offset = Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
			var final_dir = (direction + random_offset).normalized()
			
			# Aplica impulso e rotação (torque)
			piece.apply_impulse(final_dir * force_strength)
			piece.apply_torque_impulse(randf_range(-600.0, 600.0))
			
			# Flip aleatório para mais naturalidade
			if randf() > 0.5:
				piece.scale.x *= -1

func _on_flash_timeout() -> void:
	# Efeito de piscar
	for piece in pieces_nodes:
		if piece != null and piece.visible:
			piece.modulate.a = 0.0 if piece.modulate.a == 1.0 else 1.0
		
	flash_count += 1
	if flash_count >= max_flashes:
		flash_timer.stop()
		# Remove os pedaços
		for piece in pieces_nodes:
			if piece != null:
				piece.queue_free()

func regenerate() -> void:
	var new_box = box_scene.instantiate()
	new_box.global_position = global_position
	get_parent().add_child(new_box)
	queue_free()
