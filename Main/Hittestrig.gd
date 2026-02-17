# HitTestRig.gd
# Attach to: HitTestRig (Node2D) — nó na raiz da cena de teste
extends Node2D

# ─────────────────────────────────────────────
# REFERÊNCIAS — ALMA
# ─────────────────────────────────────────────
@onready var soul_controller: Node2D = $"../SoulCrate"
var soul_damage_handler: Area2D = null

# ─────────────────────────────────────────────
# REFERÊNCIAS — BARRIL
# ─────────────────────────────────────────────
@onready var barrel_root: Node2D = $"../BarrelRev"
var _barrel_ref: Node2D = null

# ─────────────────────────────────────────────
# UI
# ─────────────────────────────────────────────
@onready var label_state: Label = $UI/LabelState
@onready var label_dir: Label   = $UI/LabelDir
@onready var label_hint: Label  = $UI/LabelHint

# ─────────────────────────────────────────────
# DEBOUNCE
# ─────────────────────────────────────────────
const HIT_COOLDOWN  := 0.25
var _cooldown_timer := 0.0
var _origin: Vector2 = Vector2.ZERO

# ─────────────────────────────────────────────
# MAPS
# ─────────────────────────────────────────────
const DIRECTION_MAP := {
	"W":   Vector2(0, -1),
	"S":   Vector2(0,  1),
	"A":   Vector2(-1, 0),
	"D":   Vector2(1,  0),
	"W+A": Vector2(-1, -1),
	"W+D": Vector2(1,  -1),
	"S+A": Vector2(-1,  1),
	"S+D": Vector2(1,   1),
}

const DIRECTION_LABEL := {
	"W":   "↑  CIMA",
	"S":   "↓  BAIXO",
	"A":   "←  ESQUERDA",
	"D":   "→  DIREITA",
	"W+A": "↖  CIMA-ESQ (45°)",
	"W+D": "↗  CIMA-DIR (45°)",
	"S+A": "↙  BAIXO-ESQ (45°)",
	"S+D": "↘  BAIXO-DIR (45°)",
}

const STATE_NAMES := {
	0: "HEAD_BURIED",
	1: "GROWING",
	2: "FULL_IDLE",
	3: "HEAD_SEPARATED",
	4: "SLIME_MOVING",
	5: "DEAD",
}

# ─────────────────────────────────────────────
# READY
# ─────────────────────────────────────────────
func _ready() -> void:
	# Pequeno delay para garantir que todos os scripts foram compilados e carregados
	await get_tree().process_frame
	
	if is_instance_valid(soul_controller):
		for child in soul_controller.get_children():
			if child is Area2D:
				soul_damage_handler = child
				break
		
		_origin = soul_controller.global_position
		
		# Conexão segura de sinal
		if soul_controller.has_signal("state_changed"):
			soul_controller.state_changed.connect(_on_state_changed)
		
		_update_ui("Nenhum", soul_controller.get("state"))

	_barrel_ref = barrel_root

	label_hint.text = (
		"[WASD + combinações] → Golpe nos dois alvos\n"
		+ "[SPACE] → Reset alma (FULL_IDLE)\n"
		+ "[R]     → Regenera barril\n"
		+ "[TAB]   → Força próximo estado da alma"
	)

# ─────────────────────────────────────────────
# INPUT
# ─────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	match event.keycode:
		KEY_SPACE:
			_reset_soul()
			return
		KEY_R:
			_regenerate_barrel()
			return
		KEY_TAB:
			_force_next_state()
			return

	if _cooldown_timer > 0.0:
		return

	var combo := _read_wasd_combo()
	if combo == "":
		return

	var direction: Vector2 = DIRECTION_MAP[combo].normalized()
	_send_hit(direction, combo)

func _read_wasd_combo() -> String:
	var up    := Input.is_key_pressed(KEY_W)
	var down  := Input.is_key_pressed(KEY_S)
	var left  := Input.is_key_pressed(KEY_A)
	var right := Input.is_key_pressed(KEY_D)
	if up   and left:  return "W+A"
	if up   and right: return "W+D"
	if down and left:  return "S+A"
	if down and right: return "S+D"
	if up:    return "W"
	if down:  return "S"
	if left:  return "A"
	if right: return "D"
	return ""

func _send_hit(direction: Vector2, combo: String) -> void:
	if is_instance_valid(soul_controller) and soul_damage_handler != null:
		soul_damage_handler.receive_hit(direction)
		_update_ui(DIRECTION_LABEL.get(combo, combo), soul_controller.get("state"))
	else:
		label_state.text = "Estado: MORTO / DELETADO"
		label_dir.text   = "Golpe:  %s" % DIRECTION_LABEL.get(combo, combo)

	if is_instance_valid(_barrel_ref) and _barrel_ref.has_method("break_barrel"):
		if not _barrel_ref.broken:
			_barrel_ref.break_barrel(direction, 1)

	_cooldown_timer = HIT_COOLDOWN

func _reset_soul() -> void:
	if not is_instance_valid(soul_controller): return
	var head: RigidBody2D = soul_controller.get_node("Head")
	head.freeze           = true
	head.linear_velocity  = Vector2.ZERO
	head.angular_velocity = 0.0
	head.position         = Vector2(0, -50)
	head.rotation         = 0.0
	soul_controller.global_position = _origin
	soul_controller.set_state(soul_controller.State.FULL_IDLE)
	_update_ui("REINÍCIO", soul_controller.get("state"))

func _regenerate_barrel() -> void:
	if is_instance_valid(_barrel_ref) and _barrel_ref.has_method("regenerate"):
		_barrel_ref.regenerate()
		await get_tree().process_frame
		for child in barrel_root.get_parent().get_children():
			if child != barrel_root and child.has_method("break_barrel"):
				_barrel_ref = child
				break

func _force_next_state() -> void:
	if is_instance_valid(soul_controller):
		var current: int = soul_controller.get("state")
		var next: int    = (current + 1) % soul_controller.State.size()
		soul_controller.set_state(next)

func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

func _on_state_changed(new_state: int) -> void:
	if is_instance_valid(soul_controller):
		_update_ui(label_dir.text.replace("Golpe:  ", ""), new_state)

func _update_ui(dir_text: String, s: int) -> void:
	label_state.text = "Estado: %s" % STATE_NAMES.get(s, "?")
	label_dir.text   = "Golpe:  %s" % dir_text
