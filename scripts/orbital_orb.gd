extends Area2D

# Orbiting thorn — spawned by Nature Orbital weapon. Follows player, damages on contact.

const RADIUS      := 54.0
const ORBIT_SPEED := 2.6
const LIFETIME    := 9.0
const HIT_CD      := 0.55

var _player: Node2D = null
var _slot:   int    = 0
var _t:      float  = 0.0
var _hit_t:  float  = 0.0
var _col:    Color  = Color(0.30, 0.92, 0.25)
var damage:  int    = 1

func setup(player_node: Node2D, slot: int, dmg: int, col: Color) -> void:
	_player = player_node
	_slot   = slot
	damage  = dmg
	_col    = col
	_t      = float(slot) * TAU / 5.0  # stagger start angles
	var cs  := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 9.0
	cs.shape = circ
	add_child(cs)
	body_entered.connect(_on_body)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)

func _process(delta: float) -> void:
	_t     += delta * ORBIT_SPEED
	_hit_t -= delta
	if not is_instance_valid(_player):
		queue_free()
		return
	global_position = _player.global_position + Vector2(cos(_t), sin(_t)) * RADIUS
	queue_redraw()

func _draw() -> void:
	var pulse := sin(_t * 3.0) * 0.15 + 0.85
	# Glow halo
	draw_circle(Vector2.ZERO, 14 * pulse, Color(_col.r, _col.g, _col.b, 0.18))
	# Thorn body
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -9), Vector2(6, 2), Vector2(3, 7), Vector2(0, 5), Vector2(-3, 7), Vector2(-6, 2),
	]), _col)
	# Center shine
	draw_circle(Vector2.ZERO, 3.5, _col.lightened(0.4))
	draw_circle(Vector2.ZERO, 1.5, Color.WHITE)

func _on_body(body: Node) -> void:
	if _hit_t > 0:
		return
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
		_hit_t = HIT_CD
	elif body.is_in_group("destructible") and body.has_method("take_damage"):
		body.take_damage(damage)
		_hit_t = HIT_CD
