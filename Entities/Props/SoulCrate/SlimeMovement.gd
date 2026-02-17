# SlimeMovement.gd
# Attach to: Slime (Node2D)
# Responsabilidade: movimento orgânico da gosma entre posições
extends Node2D

# ─────────────────────────────────────────────
# CONFIGURAÇÃO
# ─────────────────────────────────────────────
@export var speed        := 120.0  # pixels/segundo
@export var wobble_amp   := 6.0    # amplitude do wobble lateral
@export var wobble_freq  := 8.0    # frequência do wobble

# ─────────────────────────────────────────────
# ESTADO INTERNO
# ─────────────────────────────────────────────
var _target:     Vector2 = Vector2.ZERO
var _moving:     bool    = false
var _wobble_acc: float   = 0.0

signal reached_target

# ─────────────────────────────────────────────
# INTERFACE PÚBLICA
# ─────────────────────────────────────────────
func move_to(target_global: Vector2) -> void:
	_target  = target_global
	_moving  = true
	_wobble_acc = 0.0

func stop() -> void:
	_moving = false

# ─────────────────────────────────────────────
# PROCESS — chamado quando ativo
# Node2D não precisa do servidor de física (_physics_process),
# _process com delta é suficiente para movimento controlado
# ─────────────────────────────────────────────
func _process(delta: float) -> void:
	if not _moving:
		return

	_wobble_acc += delta * wobble_freq

	var to_target := _target - global_position
	var dist      := to_target.length()

	if dist < 4.0:
		_moving = false
		global_position = _target
		emit_signal("reached_target")
		return

	# Direção base + perturbação perpendicular (wobble)
	var dir      := to_target.normalized()
	var perp     := Vector2(-dir.y, dir.x)
	var wobble   := sin(_wobble_acc) * wobble_amp * (dist / 60.0)  # diminui perto do alvo

	global_position += (dir * speed + perp * wobble) * delta

	# Escala vertical para efeito de "pulsação"
	var pulse  := 1.0 + sin(_wobble_acc * 1.5) * 0.08
	scale = Vector2(1.0 / pulse, pulse)  # conserva área visual
