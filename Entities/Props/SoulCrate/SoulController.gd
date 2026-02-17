# SoulController.gd
# Attach to: Soul (Node2D) — nó raiz da entidade
extends Node2D

# ─────────────────────────────────────────────
# SINAL — Deve estar no topo para garantir visibilidade
# ─────────────────────────────────────────────
signal state_changed(new_state: int)

# ─────────────────────────────────────────────
# ESTADOS
# ─────────────────────────────────────────────
enum State {
	HEAD_BURIED,      # 0
	GROWING,          # 1
	FULL_IDLE,        # 2
	HEAD_SEPARATED,   # 3
	SLIME_MOVING,     # 4
	DEAD              # 5
}

var state: State = State.HEAD_BURIED

# ─────────────────────────────────────────────
# REFERÊNCIAS DE NÓS
# ─────────────────────────────────────────────
@onready var head: RigidBody2D         = $Head
@onready var body: CharacterBody2D     = $Body
@onready var slime: Node2D             = $Slime

@export var tex_head_buried: Texture2D
@export var tex_head_normal: Texture2D

@onready var head_sprite: Sprite2D     = $Head/Sprite2D
@onready var body_sprite: Sprite2D     = $Body/Sprite2D

@onready var head_col: CollisionShape2D  = $Head/CollisionShape2D
@onready var body_col: CollisionShape2D  = $Body/CollisionShape2D

@onready var anim: AnimationPlayer       = $AnimationPlayer
@onready var blood_particles: GPUParticles2D = $BloodParticles

# ─────────────────────────────────────────────
# INIT
# ─────────────────────────────────────────────
func _ready() -> void:
	if anim.animation_finished.is_connected(_on_animation_finished):
		anim.animation_finished.disconnect(_on_animation_finished)
	anim.animation_finished.connect(_on_animation_finished)
	
	set_state(State.HEAD_BURIED)

# ─────────────────────────────────────────────
# INPUT - CRESCIMENTO
# ─────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if state == State.HEAD_BURIED and event.is_action_pressed("ui_up"):
		set_state(State.GROWING)

# ─────────────────────────────────────────────
# MÁQUINA DE ESTADOS
# ─────────────────────────────────────────────
func set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(state) # Usando a sintaxe moderna do Godot 4

	match state:
		State.HEAD_BURIED:    _enter_head_buried()
		State.GROWING:        _enter_growing()
		State.FULL_IDLE:      _enter_full_idle()
		State.HEAD_SEPARATED: _enter_head_separated()
		State.SLIME_MOVING:   _enter_slime()
		State.DEAD:           _enter_dead()

func _enter_head_buried() -> void:
	head.visible  = true
	body.visible  = false
	slime.visible = false
	head_col.disabled = true
	body_col.disabled = true
	head.freeze = true
	head.position = Vector2.ZERO
	if tex_head_buried: head_sprite.texture = tex_head_buried
	anim.play("head_buried")

func _enter_growing() -> void:
	body.visible  = true
	slime.visible = false
	body.scale    = Vector2(0.05, 0.05)
	body_col.disabled = true
	anim.play("grow")

func _enter_full_idle() -> void:
	head.visible  = true
	body.visible  = true
	slime.visible = false
	body.scale    = Vector2.ONE
	head.scale    = Vector2.ONE
	head.freeze = true
	head.position = Vector2(0, -50)
	head_col.disabled = false
	body_col.disabled = false
	if tex_head_normal: head_sprite.texture = tex_head_normal
	anim.play("full_idle")

func _enter_head_separated() -> void:
	head.visible  = true
	body.visible  = true
	slime.visible = false
	head_col.disabled = false
	body_col.disabled = false
	head.freeze = false
	var impulse := Vector2(randf_range(150.0, 250.0) * (1 if randf() > 0.5 else -1), -100.0)
	head.apply_central_impulse(impulse)
	head.apply_torque_impulse(randf_range(-50.0, 50.0))

var _slime_target: Vector2 = Vector2.ZERO
func _enter_slime() -> void:
	body.visible  = false
	slime.visible = true
	slime.position = body.position
	_slime_target = head.global_position
	anim.play("slime_move")

func _physics_process(delta: float) -> void:
	if state != State.SLIME_MOVING: return
	_slime_target = head.global_position
	var dir := (slime.global_position.direction_to(_slime_target))
	slime.global_position += dir * 100.0 * delta
	if slime.global_position.distance_to(_slime_target) < 10.0:
		set_state(State.GROWING)

func _enter_dead() -> void:
	head.visible  = false
	body.visible  = false
	slime.visible = false
	head_col.disabled = true
	body_col.disabled = true

func apply_hit(direction: Vector2) -> void:
	match state:
		State.FULL_IDLE:
			set_state(State.HEAD_SEPARATED)
			_spawn_vfx(head.global_position, direction, "blood_dripping")
		State.HEAD_SEPARATED:
			set_state(State.SLIME_MOVING)
			_spawn_vfx(body.global_position, direction, "blood_explosion")
		State.SLIME_MOVING:
			_spawn_vfx(slime.global_position, direction, "blood_explosion")
			set_state(State.DEAD)
		_: pass

func _spawn_vfx(pos: Vector2, direction: Vector2, type: String) -> void:
	if blood_particles == null: return
	blood_particles.global_position = pos
	var mat := blood_particles.process_material as ParticleProcessMaterial
	if mat == null: return
	mat.direction = Vector3(direction.x, direction.y, 0)
	mat.spread = 45.0
	mat.gravity = Vector3(0, 400, 0)
	mat.color = Color(0.6, 0, 0, 1)
	match type:
		"blood_dripping":
			blood_particles.amount = 30
			mat.initial_velocity_min = 50
			mat.initial_velocity_max = 150
		"blood_explosion":
			blood_particles.amount = 60
			mat.initial_velocity_min = 200
			mat.initial_velocity_max = 400
	blood_particles.restart()
	blood_particles.emitting = true

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "grow":
		set_state(State.FULL_IDLE)
