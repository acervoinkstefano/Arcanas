# SoulController.gd
extends Node2D

signal state_changed(new_state: int)

enum State {
	HEAD_BURIED,    # 0
	GROWING,        # 1
	FULL_IDLE,      # 2
	HEADLESS_IDLE,  # 3
	BODYLESS_IDLE,  # 4
	DEAD            # 5
}

var state: State = State.HEAD_BURIED

# ── Nós ──────────────────────────────────────
@onready var head:  RigidBody2D      = $Head
@onready var body:  CharacterBody2D  = $Body
@onready var slime: Node2D           = $Slime

@onready var head_sprite: Sprite2D   = $Head/Sprite2D
@onready var body_sprite: Sprite2D   = $Body/Sprite2D

@onready var head_col: CollisionShape2D = $Head/CollisionShape2D
@onready var body_col: CollisionShape2D = $Body/CollisionShape2D
@onready var _scene: PackedScene = preload("res://Entities/Props/SoulCrate/SoulCrate.tscn")

@onready var anim:            AnimationPlayer  = $AnimationPlayer
@onready var blood_particles: GPUParticles2D   = $BloodParticles

# ── Configurações ─────────────────────────────
@export var head_force_strength: float = 400.0
@export var head_torque_range:   float = 300.0
@export var head_random_offset:  float = 0.4
@export var slime_linger_time:   float = 2.5

# ── Init ──────────────────────────────────────
func _ready() -> void:
	anim.animation_finished.connect(_on_animation_finished)
	set_state(State.HEAD_BURIED)

# ── Input — shift para crescer ────────────────
func _input(event: InputEvent) -> void:
	if state == State.HEAD_BURIED:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_SHIFT:
				set_state(State.GROWING)

# ── Máquina de estados ────────────────────────
func set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(state)
	match state:
		State.HEAD_BURIED:   _enter_head_buried()
		State.GROWING:       _enter_growing()
		State.FULL_IDLE:     _enter_full_idle()
		State.HEADLESS_IDLE: _enter_headless_idle()
		State.BODYLESS_IDLE: _enter_bodyless_idle()
		State.DEAD:          _enter_dead()

func _enter_head_buried() -> void:
	anim.stop()
	# Reseta física da cabeça
	head.freeze           = true
	head.linear_velocity  = Vector2.ZERO
	head.angular_velocity = 0.0
	head.rotation         = 0.0
	head.position         = Vector2(0, -50)
	# Visibilidade
	head.visible          = true    # cabeça enterrada aparece
	body.visible          = false
	slime.visible         = false
	# Colisões
	head_col.disabled     = true
	body_col.disabled     = true
	anim.play("head_buried")

func _enter_growing() -> void:
	anim.stop()
	head.visible          = false
	body.visible          = true
	slime.visible         = false
	body.scale            = Vector2(0.5, 0.5)
	body_col.disabled     = true
	anim.play("grow")
	# Quando "grow" terminar → _on_animation_finished → FULL_IDLE

func _enter_full_idle() -> void:
	anim.stop()
	# Reseta e freeza cabeça na posição correta
	head.freeze           = true
	head.linear_velocity  = Vector2.ZERO
	head.angular_velocity = 0.0
	head.rotation         = 0.0
	head.position         = Vector2(0, -50)
	head.scale            = Vector2.ONE
	# Corpo na posição correta
	body.position         = Vector2.ZERO
	body.scale            = Vector2.ONE
	# Visibilidade
	head.visible          = false
	body.visible          = true
	slime.visible         = false
	# Colisões
	head_col.disabled     = false
	body_col.disabled     = false
	anim.play("full_idle")

func _enter_headless_idle(direction: Vector2 = Vector2.ZERO) -> void:
	anim.stop()
	# Cabeça voa
	head.freeze           = false   # ANTES do impulso
	head.visible          = true
	head_col.disabled     = false
	# Tronco fica parado
	body.visible          = true
	body_col.disabled     = false
	slime.visible         = false
	# Aplica impulso
	if direction != Vector2.ZERO:
		var offset := Vector2(
			randf_range(-head_random_offset, head_random_offset),
			randf_range(-head_random_offset, head_random_offset)
		)
		var launch_dir := Vector2(direction.x + offset.x, -1.0).normalized()
		head.apply_impulse(launch_dir * head_force_strength)
		head.apply_torque_impulse(randf_range(-head_torque_range, head_torque_range))
	else:
		head.apply_central_impulse(Vector2(randf_range(-200.0, 200.0), -300.0))
		head.apply_torque_impulse(randf_range(-head_torque_range, head_torque_range))
	anim.play("headless_idle")   # animação do tronco sem cabeça

func _enter_bodyless_idle() -> void:
	anim.stop()
	# Tronco some, cabeça continua rolando intocada
	body.visible      = false
	body_col.disabled = true
	slime.visible     = true
	# Cabeça: não toca, física continua ativa
	anim.play("bodyless_idle")

func _enter_dead() -> void:
	anim.stop()
	head.visible      = false
	head.freeze       = true
	head_col.disabled = true
	body.visible      = false
	body_col.disabled = true
	slime.visible     = false
	slime.global_position = body.global_position
	var tween := create_tween()
	tween.tween_interval(slime_linger_time)
	tween.tween_callback(func(): slime.visible = false)

# ── Recebimento de golpe ──────────────────────
func apply_hit(direction: Vector2) -> void:
	match state:
		State.FULL_IDLE:
			_spawn_vfx(head_sprite.global_position, direction, "blood_dripping")
			state = State.HEADLESS_IDLE
			state_changed.emit(state)
			_enter_headless_idle(direction)
		State.HEADLESS_IDLE:
			_spawn_vfx(body_sprite.global_position, direction, "body_explosion")
			set_state(State.BODYLESS_IDLE)
		State.BODYLESS_IDLE:
			_spawn_vfx(head.global_position, direction, "blood_dripping")
			set_state(State.DEAD)
		_: pass

# ── VFX ───────────────────────────────────────
func _spawn_vfx(pos: Vector2, direction: Vector2, type: String) -> void:
	if blood_particles == null: return
	blood_particles.global_position = pos
	var mat := blood_particles.process_material as ParticleProcessMaterial
	if mat == null: return
	mat.direction = Vector3(direction.x, direction.y, 0.0)
	mat.gravity   = Vector3(0, 400, 0)
	mat.color     = Color(0.6, 0, 0, 1)
	match type:
		"blood_dripping":
			blood_particles.amount   = 40
			mat.spread               = 35.0
			mat.initial_velocity_min = 150.0
			mat.initial_velocity_max = 300.0
		"body_explosion":
			blood_particles.amount   = 120
			mat.spread               = 180.0
			mat.initial_velocity_min = 300.0
			mat.initial_velocity_max = 600.0
			mat.gravity              = Vector3(0, 600, 0)
			mat.color                = Color(0.5, 0, 0, 1)
	blood_particles.restart()
	blood_particles.emitting = true

# ── Callback de animação ──────────────────────
func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "grow":
		set_state(State.FULL_IDLE)

func regenerate() -> void:
	var new_soul := _scene.instantiate() as Node2D
	new_soul.global_position = global_position
	get_parent().add_child(new_soul)
	queue_free()
