extends Node2D

var current_health := 5
var max_health := 5
var score_label: Label
var depth_label: Label
var room_label: Label

var wave_announce_text := ""
var wave_announce_timer := 0.0
const ANNOUNCE_DURATION := 2.2

func _ready() -> void:
	GameEvents.player_hit.connect(func(h, m): current_health = h; max_health = m; queue_redraw())
	GameEvents.score_changed.connect(func(s): score_label.text = "SCORE  %d" % s)
	FractureManager.fractures_changed.connect(func(): queue_redraw())
	RoomManager.room_loaded.connect(_on_room_loaded)

	score_label = _make_label(Vector2(980, 10), HORIZONTAL_ALIGNMENT_RIGHT, 290)
	score_label.text = "SCORE  0"
	add_child(score_label)

	depth_label = _make_label(Vector2(14, 693))
	depth_label.text = "DEPTH  0"
	add_child(depth_label)

	room_label = _make_label(Vector2(580, 10), HORIZONTAL_ALIGNMENT_CENTER, 120)
	room_label.text = ""
	add_child(room_label)

	queue_redraw()

func _make_label(pos: Vector2, align := HORIZONTAL_ALIGNMENT_LEFT, min_w := 0) -> Label:
	var lbl := Label.new()
	lbl.position = pos
	lbl.horizontal_alignment = align
	if min_w > 0:
		lbl.custom_minimum_size = Vector2(min_w, 30)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	return lbl

func _on_room_loaded(pos: Vector2i, type: String, depth: int) -> void:
	depth_label.text = "DEPTH  %d" % depth
	room_label.text = type.to_upper()
	wave_announce_text = _room_announce(type, depth)
	wave_announce_timer = ANNOUNCE_DURATION
	queue_redraw()

func _room_announce(type: String, depth: int) -> String:
	match type:
		"start":   return "WELCOME, DRIFTER"
		"healing": return "HEALING SPRINGS"
		"shrine":  return "ELEMENTAL SHRINE"
		"treasure":return "HIDDEN CACHE"
		"boss":    return "BOSS  DEPTH %d" % depth
	return "DEPTH  %d" % depth

func _process(delta: float) -> void:
	if wave_announce_timer > 0:
		wave_announce_timer -= delta
		queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font

	# Hearts
	for i in max_health:
		var col = Color(1, 0.28, 0.38) if i < current_health else Color(0.18, 0.18, 0.22)
		draw_circle(Vector2(20 + i * 28, 20), 10, col)
		if i < current_health:
			draw_circle(Vector2(20 + i * 28, 20), 5, Color(1, 0.65, 0.72))

	# Fracture orbs
	var fracs := FractureManager.active_fractures
	var fx := 640.0 - (fracs.size() - 1) * 22.0
	for i in fracs.size():
		var col := FractureManager.ELEMENT_COLORS[fracs[i]]
		draw_circle(Vector2(fx + i * 44, 695), 13, col)
		draw_circle(Vector2(fx + i * 44, 695), 7, Color.WHITE.lerp(col, 0.35))
		draw_string(font, Vector2(fx + i * 44 - 4, 700), FractureManager.ELEMENT_NAMES[fracs[i]][0],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

	# Synergy
	var syn := FractureManager.get_synergy()
	if syn != "":
		draw_string(font, Vector2(0, 672), syn, HORIZONTAL_ALIGNMENT_CENTER, 1280, 13, Color(1, 0.88, 0.4))

	# Room announcement
	if wave_announce_timer > 0:
		var t := wave_announce_timer / ANNOUNCE_DURATION
		var alpha := 4.0 * t * (1.0 - t)
		draw_string(font, Vector2(0, 375), wave_announce_text,
			HORIZONTAL_ALIGNMENT_CENTER, 1280, 44, Color(1, 0.88, 0.3, alpha))

	# Minimap
	_draw_minimap(font)

func _draw_minimap(font: Font) -> void:
	if not RoomManager.world.size() > 0:
		return
	var cx := 1190.0
	var cy := 100.0
	var rw := 10.0
	var rh :=  7.0
	var gap_x := 14.0
	var gap_y :=  9.0

	for pos in RoomManager.world:
		if not pos in RoomManager.visited:
			continue
		var data := RoomManager.world[pos]
		var col := _minimap_color(data["type"])
		if pos == RoomManager.current_pos:
			col = Color.WHITE
		var sx := cx + pos.x * gap_x
		var sy := cy + pos.y * gap_y
		draw_rect(Rect2(sx - rw * 0.5, sy - rh * 0.5, rw, rh), col)

		# Draw connections
		for dir in data.get("exits", []):
			var npos: Vector2i = pos + RoomManager.DIRS[dir]
			if npos in RoomManager.visited:
				var nx := cx + npos.x * gap_x
				var ny := cy + npos.y * gap_y
				draw_line(Vector2(sx, sy), Vector2(nx, ny), Color(0.5, 0.5, 0.6, 0.5), 1)

func _minimap_color(type: String) -> Color:
	match type:
		"start":    return Color(0.55, 0.55, 0.60)
		"combat":   return Color(0.85, 0.25, 0.25)
		"healing":  return Color(0.25, 0.85, 0.40)
		"shrine":   return Color(0.35, 0.45, 1.00)
		"treasure": return Color(1.00, 0.82, 0.20)
		"boss":     return Color(1.00, 0.40, 0.10)
	return Color(0.4, 0.4, 0.4)
