extends Area2D

var weapon_key := "shotgun"
var base_y     := 0.0
var _t         := 0.0

func setup(key: String, pos: Vector2) -> void:
	weapon_key = key
	position   = pos
	base_y     = pos.y
	queue_redraw()

func _ready() -> void:
	var cs   := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 18.0
	cs.shape = circ
	add_child(cs)
	body_entered.connect(func(b: Node2D):
		if b.is_in_group("player") and b.has_method("equip_weapon"):
			b.equip_weapon(weapon_key)
			queue_free.call_deferred()
	)
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	position.y = base_y + sin(_t * 2.8) * 4.0
	queue_redraw()

func _draw() -> void:
	var wdata := WeaponManager.get_weapon(weapon_key)
	var col: Color = wdata["color"] as Color
	var pulse := (sin(_t * 4.2) + 1.0) * 0.5
	var r := 10.0 + pulse * 2.5
	draw_circle(Vector2.ZERO, r + 4, Color(col.r, col.g, col.b, 0.18))
	draw_circle(Vector2.ZERO, r, col)
	draw_circle(Vector2.ZERO, r * 0.45, Color.WHITE.lerp(col, 0.28))
	# Weapon icon
	match weapon_key:
		"shotgun":
			draw_rect(Rect2(-7, -2.5, 14, 5), Color(1,1,1,0.7))
			for i in 3:
				draw_circle(Vector2(-5 + i * 5, 0), 1.5, col.darkened(0.3))
		"burst":
			for i in 3:
				var a := _t * 2.0 + i * TAU / 3.0
				draw_circle(Vector2(cos(a), sin(a)) * 5, 2, Color(1,1,1,0.7))
		"staff":
			draw_line(Vector2(0, -9), Vector2(0, 7), Color(1,1,1,0.7), 2)
			draw_circle(Vector2(0, -9), 3.5, Color(1,1,1,0.7))
		_: # wand
			draw_line(Vector2(-7, 4), Vector2(7, -4), Color(1,1,1,0.7), 2)
			draw_circle(Vector2(7, -4), 2.5, col.lightened(0.3))
	# Name tag
	var font := ThemeDB.fallback_font
	var wname: String = wdata["name"] as String
	draw_string(font, Vector2(-30, 20), wname, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(col.r, col.g, col.b, 0.85))
