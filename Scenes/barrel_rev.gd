extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var pieces: Node2D = $Pieces
@onready var particles: GPUParticles2D = $WoodParticles
@onready var flash_timer: Timer = $FlashTimer

var broken: bool = false

var hit_direction: Vector2 = Vector2.ZERO
var hit_count: int = 0
var max_hits: int = 3

var flash_count: int = 0
var max_flashes: int = 6

func _ready() -> void:
	pieces.visible = false
	
	flash_timer.wait_time = 0.1
	flash_timer.one_shot = false
	flash_timer.timeout.connect(_on_flash_timeout)

func _process(_delta: float) -> void:
	if broken:
		return

	if Input.is_action_just_pressed("hit_left"):
		register_hit(Vector2.RIGHT)

	if Input.is_action_just_pressed("hit_right"):
		register_hit(Vector2.LEFT)

	if Input.is_action_just_pressed("hit_top"):
		register_hit(Vector2.DOWN)

	if Input.is_action_just_pressed("hit_bottom"):
		register_hit(Vector2.UP)

func register_hit(direction: Vector2) -> void:
	# Se mudar a direção, reinicia contagem
	if hit_direction != direction:
		hit_direction = direction
		hit_count = 0

	hit_count += 1

	if hit_count >= max_hits:
		break_barrel(hit_direction, hit_count)

func break_barrel(direction: Vector2, force_level: int) -> void:
	broken = true
	
	sprite.visible = false
	pieces.visible = true
	
	spawn_particles(direction, force_level)
	apply_fake_impulse(direction, force_level)
	
	flash_timer.start()

func apply_fake_impulse(direction: Vector2, force_level: int) -> void:
	var force_multiplier: float = 20.0 * force_level
	
	for piece in pieces.get_children():
		if piece is Sprite2D:
			var pos: Vector2 = piece.position
			var offset: Vector2 = pos.normalized()
			piece.position = pos + (offset + direction) * force_multiplier

func spawn_particles(direction: Vector2, force_level: int) -> void:
	var mat := particles.process_material
	if mat:
		mat.direction = Vector3(direction.x, direction.y, 0.0)
		mat.initial_velocity_min = 150.0 * force_level
		mat.initial_velocity_max = 250.0 * force_level
	
	particles.restart()
	particles.emitting = true

func _on_flash_timeout() -> void:
	pieces.visible = not pieces.visible
	flash_count += 1

	if flash_count >= max_flashes:
		flash_timer.stop()
		queue_free()
