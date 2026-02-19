extends Node2D

@onready var box_scene: PackedScene = preload("res://Entities/Props/Box/Box.tscn")
@onready var pieces: Node2D = $Pieces
@onready var particles: GPUParticles2D = $WoodParticles
@onready var flash_timer: Timer = $FlashTimer

var broken: bool = false
var flash_count: int = 2
var max_flashes: int = 6

func _ready() -> void:
	pieces.visible = true  # Peças já visíveis desde o início

	flash_timer.wait_time = 0.2
	flash_timer.one_shot = false
	flash_timer.timeout.connect(_on_flash_timeout)

	for piece in pieces.get_children():
		if piece is RigidBody2D:
			piece.freeze = true

	randomize_pieces()

func randomize_pieces() -> void:
	var visibility_map: Dictionary = {}

	for piece in pieces.get_children():
		if piece.name == "Piece_Base": continue
		if piece.name == "Frente1":   continue
		visibility_map[piece.name] = randf() > 0.4

	var has_adjacent: bool = visibility_map.get("Topo", false) or \
							 visibility_map.get("Lateral", false) or \
							 visibility_map.get("Frente2", false)
	visibility_map["Frente1"] = has_adjacent and (randf() > 0.4)

	for piece in pieces.get_children():
		if piece.name == "Piece_Base": continue
		piece.process_mode = Node.PROCESS_MODE_INHERIT

	for piece in pieces.get_children():
		if piece.name == "Piece_Base": continue
		var should_show: bool = visibility_map.get(piece.name, false)
		piece.visible = should_show
		if not should_show:
			piece.process_mode = Node.PROCESS_MODE_DISABLED

func break_box(direction: Vector2, force_level: int) -> void:
	if broken: return
	broken = true

	spawn_particles(direction, force_level)
	activate_physics(direction, force_level)
	flash_timer.start()

func activate_physics(direction: Vector2, force_level: int) -> void:
	var force_strength: float = 400.0 * force_level

	for piece in pieces.get_children():
		if not piece is RigidBody2D:   continue
		if piece.name == "Piece_Base": continue
		if not piece.visible:          continue

		piece.freeze = false
		piece.set_collision_mask_value(1, false)
		piece.set_collision_mask_value(2, true)

		var random_offset = Vector2(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4))
		var final_dir = (direction + random_offset).normalized()
		piece.apply_impulse(final_dir * force_strength)
		piece.apply_torque_impulse(randf_range(-300.0, 300.0))

func spawn_particles(direction: Vector2, force_level: int) -> void:
	if not particles: return
	var mat := particles.process_material
	if mat:
		mat.direction = Vector3(direction.x, direction.y, 0.0)
		mat.initial_velocity_min = 200.0 * force_level
		mat.initial_velocity_max = 350.0 * force_level
	particles.restart()
	particles.emitting = true

func _on_flash_timeout() -> void:
	for piece in pieces.get_children():
		if piece.name != "Piece_Base":
			piece.visible = not piece.visible

	flash_count += 2
	if flash_count >= max_flashes:
		flash_timer.stop()
		for piece in pieces.get_children():
			if piece.name != "Piece_Base":
				piece.queue_free()
		if particles:
			particles.emitting = false

func regenerate() -> void:
	var new_box = box_scene.instantiate()
	new_box.global_position = global_position
	get_parent().add_child(new_box)
	queue_free()
