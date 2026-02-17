# DamageHandler.gd
# Attach to: HurtboxArea (Area2D) dentro de Soul
# Responsabilidade: receber sinal de hit e converter para direção normalizada
extends Area2D

# Referência ao controlador pai — ajuste o caminho se necessário
@onready var soul: Node2D = $".."

# ─────────────────────────────────────────────
# SINAL PÚBLICO — outros sistemas podem escutar
# ─────────────────────────────────────────────
signal hit_received(direction: Vector2)

# ─────────────────────────────────────────────
# CHAMADO PELO TEST RIG (ou pelo hitbox real do player)
# direction: vetor normalizado de onde o golpe vem
# ─────────────────────────────────────────────
func receive_hit(direction: Vector2) -> void:
	emit_signal("hit_received", direction)
	soul.apply_hit(direction)
