# Head.gd
# Attach to: Head (RigidBody2D)
# Responsabilidade: física autônoma da cabeça separada
extends RigidBody2D

# ─────────────────────────────────────────────
# CONFIGURAÇÃO
# ─────────────────────────────────────────────
@export var bounce_damping   := 0.6   # quanto rebate no chão
@export var angular_damping  := 2.0   # quanto para de girar com o tempo
@export var max_roll_speed   := 400.0 # velocidade máxima de rolamento

func _ready() -> void:
	# Física padrão — será sobrescrita pelo SoulController
	freeze = true

	# Configura amortecimento para rolamento natural
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce   = bounce_damping
	physics_material_override.friction = 0.8

	self.angular_damp = angular_damping
	self.linear_damp  = 0.2

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Limita velocidade de rolamento para não escapar da tela
	if state.linear_velocity.length() > max_roll_speed:
		state.linear_velocity = state.linear_velocity.normalized() * max_roll_speed
