extends StaticBody2D

const EXPLODE_RADIUS := 95.0
const EXPLODE_DMG    := 3

const DeathBurst = preload("res://effects/death_burst.tscn")

var _exploded := false

func _ready() -> void:
	add_to_group("destructible")
	add_to_group("barrels")
	var cs   := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 30)
	cs.shape = rect
	add_child(cs)
	queue_redraw()

func _draw() -> void:
	# Body
	draw_rect(Rect2(-12, -15, 24, 30), Color(0.50, 0.20, 0.06))
	draw_rect(Rect2(-12, -15, 24, 30), Color(0.72, 0.30, 0.08), false, 1.5)
	# Metal rings
	draw_rect(Rect2(-12, -7,  24, 4), Color(0.38, 0.38, 0.42))
	draw_rect(Rect2(-12,  3,  24, 4), Color(0.38, 0.38, 0.42))
	# Top cap
	draw_rect(Rect2(-12, -15, 24, 5), Color(0.40, 0.16, 0.05))
	# Warning dot
	draw_circle(Vector2(0, -1), 4, Color(1.0, 0.78, 0.08))
	draw_circle(Vector2(0, -1), 2, Color(0.85, 0.22, 0.06))

func take_damage(_amount: int) -> void:
	if not _exploded:
		_explode()

func _explode() -> void:
	if _exploded: return
	_exploded = true

	var parent := get_parent()
	var pos    := global_position

	# Main burst
	for i in 3:
		var burst := DeathBurst.instantiate()
		burst.global_position = pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		burst.color = Color(1.0, 0.45 + randf() * 0.25, 0.0)
		parent.add_child(burst)

	Juice.hit_stop(0.07)

	# Damage everything in radius
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(pos) < EXPLODE_RADIUS:
			e.take_damage(EXPLODE_DMG)
	for p in get_tree().get_nodes_in_group("player"):
		if p.global_position.distance_to(pos) < EXPLODE_RADIUS * 0.65:
			p.take_damage(1)

	# Chain nearby barrels (slight delay so they look sequential)
	for barrel in get_tree().get_nodes_in_group("barrels"):
		if barrel == self: continue
		if barrel.global_position.distance_to(pos) < EXPLODE_RADIUS * 1.15:
			get_tree().create_timer(0.12).timeout.connect(func():
				if is_instance_valid(barrel): barrel._explode()
			)
	queue_free.call_deferred()
