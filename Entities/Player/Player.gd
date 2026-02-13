extends CharacterBody2D

@export var max_speed := 220.0
@export var acceleration := 1200.0
@export var friction := 1500.0
@export var gravity := 1000.0
@export var jump_force := -400.0

@export var coyote_time := 0.12
@export var jump_buffer_time := 0.12
@export var dash_speed := 500.0
@export var dash_time := 0.15

var is_dashing := false
var dash_timer := 0.0
var dash_direction := 0.0

var coyote_timer := 0.0
var jump_buffer_timer := 0.0

func _physics_process(delta):

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		coyote_timer = coyote_time

	if coyote_timer > 0:
		coyote_timer -= delta

	var direction = Input.get_axis("move_left", "move_right")

	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * max_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time

	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta

	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = jump_force
		jump_buffer_timer = 0
		coyote_timer = 0
		
	# DASH INPUT
	if Input.is_action_just_pressed("dash") and not is_dashing:
		is_dashing = true
		dash_timer = dash_time
		dash_direction = sign(velocity.x)
		if dash_direction == 0:
			dash_direction = 1

	# DASH EXECUÇÃO
	if is_dashing:
		dash_timer -= delta
		velocity.y = 0
		velocity.x = dash_direction * dash_speed
		if dash_timer <= 0:
			is_dashing = false

	move_and_slide()
