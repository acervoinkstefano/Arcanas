extends Node2D

@onready var barrel_scene: PackedScene = preload("res://Scenes/Barrel.tscn")
@onready var sprite: Sprite2D = $Sprite2D
@onready var pieces: Node2D = $Pieces
@onready var particles: GPUParticles2D = $WoodParticles
@onready var flash_timer: Timer = $FlashTimer

var broken: bool = false

var max_hits: int = 1

var flash_count: int = 0
var max_flashes: int = 6


func _ready() -> void:
	pieces.visible = false
	
	flash_timer.wait_time = 0.1
	flash_timer.one_shot = false
	flash_timer.timeout.connect(_on_flash_timeout)

	for piece in pieces.get_children():
		if piece is RigidBody2D:
			piece.freeze = true
			

func _process(_delta: float) -> void:
	if broken == false:
		var direction := get_input_direction()
		if direction != Vector2.ZERO:
			break_barrel(direction.normalized(), 1)

	if Input.is_key_pressed(KEY_SPACE):
		regenerate()

	if broken:
		return
	var direction := get_input_direction()


	if direction != Vector2.ZERO:
		break_barrel(direction.normalized(), 1)


func get_input_direction() -> Vector2:
	var dir := Vector2.ZERO


	if Input.is_key_pressed(KEY_W):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S):
		dir.y += 1
	if Input.is_key_pressed(KEY_A):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		dir.x += 1

	return dir



func break_barrel(direction: Vector2, force_level: int) -> void:
	broken = true
	
	sprite.visible = false
	pieces.visible = true
	
	spawn_particles(direction, force_level)
	activate_physics(direction, force_level)
	
	flash_timer.start()


func activate_physics(direction: Vector2, force_level: int) -> void:
	var force_strength: float = 400.0 * force_level

	for piece in pieces.get_children():
		if piece is RigidBody2D:

			if piece.name == "Piece_Base":
				continue

			piece.freeze = false

			var random_offset = Vector2(
				randf_range(-0.4, 0.4),
				randf_range(-0.4, 0.4)
			)

			var final_dir = (direction + random_offset).normalized()

			piece.apply_impulse(final_dir * force_strength)

			piece.apply_torque_impulse(randf_range(-300.0, 300.0))


func spawn_particles(direction: Vector2, force_level: int) -> void:
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

	flash_count += 1

	if flash_count >= max_flashes:
		flash_timer.stop()

		for piece in pieces.get_children():
			if piece.name != "Piece_Base":
				piece.queue_free()

		particles.emitting = false

func regenerate() -> void:
	var new_barrel = barrel_scene.instantiate()
	new_barrel.global_position = global_position
	get_parent().add_child(new_barrel)
	queue_free()
