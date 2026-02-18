# HurtBox.gd
extends Area2D

func receive_hit(direction: Vector2) -> void:
	var soul = get_parent()
	if soul.has_method("apply_hit"):
		soul.apply_hit(direction)
