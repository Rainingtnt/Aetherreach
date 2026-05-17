extends Area2D

# Relic pickup — floats in room, grants a relic on player contact.

var _relic_key := ""
var _t         := randf() * TAU

func setup(key: String, pos: Vector2) -> void:
	_relic_key = key
	global_position = pos
	var cs    := CollisionShape2D.new()
	var circ  := CircleShape2D.new()
	circ.radius = 16.0
	cs.shape = circ
	add_child(cs)
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	position.y += sin(_t * 2.2) * 0.35
	queue_redraw()

func _draw() -> void:
	if _relic_key == "" or not RelicManager.RELICS.has(_relic_key):
		return
	var rdata := RelicManager.RELICS[_relic_key] as Dictionary
	var col   := rdata["color"] as Color

	# Outer glow
	draw_circle(Vector2.ZERO, 18, Color(col.r, col.g, col.b, 0.12 + sin(_t * 2.5) * 0.05))
	# Main orb
	draw_circle(Vector2.ZERO, 10, col)
	draw_circle(Vector2.ZERO, 6,  col.lightened(0.3))
	draw_circle(Vector2.ZERO, 3,  Color.WHITE)
	# Rotating outer ring
	for i in 6:
		var a := _t * 1.5 + i * TAU / 6.0
		draw_circle(Vector2(cos(a), sin(a)) * 15, 2.2, Color(col.r, col.g, col.b, 0.75))
	# Label
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0, 28), "RELIC", HORIZONTAL_ALIGNMENT_CENTER, -1, 9,
		Color(col.r, col.g, col.b, 0.9))

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and _relic_key != "":
		RelicManager.add_relic(_relic_key)
		# Apply immediate HP bonus if relevant
		if _relic_key in ["iron_heart", "iron_will", "glass_cannon"]:
			var bonus := RelicManager.get_max_hp_bonus()
			body.set("max_health", body.get("max_health") + bonus)
			body.set("health", mini(body.get("health") + bonus, body.get("max_health")))
			GameEvents.player_hit.emit(body.get("health"), body.get("max_health"))
		call_deferred("queue_free")
