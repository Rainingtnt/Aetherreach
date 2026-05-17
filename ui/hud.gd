extends Node2D

var current_health := 5
var max_health := 5
var score_label: Label
var depth_label: Label
var room_label: Label

var wave_announce_text := ""
var wave_announce_timer := 0.0
const ANNOUNCE_DURATION := 2.5

var boss_hp      := 0
var boss_max_hp  := 0
var boss_active  := false
var boss_name    := ""
var weapon_name  := ""
var weapon_color := Color.WHITE

var _relic_announce_text  := ""
var _relic_announce_timer := 0.0
var _relic_announce_col   := Color.WHITE

func _ready() -> void:
	GameEvents.player_hit.connect(func(h: int, m: int): current_health = h; max_health = m; queue_redraw())
	GameEvents.score_changed.connect(func(s: int): score_label.text = "SCORE  %d" % s)
	FractureManager.fractures_changed.connect(func(): queue_redraw())
	RoomManager.room_loaded.connect(_on_room_loaded)
	GameEvents.boss_hp_changed.connect(func(c: int, m: int, n: String):
		boss_hp = c; boss_max_hp = m; boss_name = n; boss_active = true; queue_redraw()
	)
	GameEvents.boss_defeated.connect(func(): boss_active = false; queue_redraw())
	GameEvents.weapon_changed.connect(func(_k: String, wn: String, wc: Color):
		weapon_name = wn; weapon_color = wc; queue_redraw()
	)
	GameEvents.relic_gained.connect(func(key: String, relic_name: String):
		var rdata := RelicManager.RELICS.get(key, {}) as Dictionary
		_relic_announce_col  = rdata.get("color", Color.WHITE) as Color
		_relic_announce_text = "RELIC: " + relic_name
		_relic_announce_timer = 3.0
		queue_redraw()
	)

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

func _on_room_loaded(_pos: Vector2i, type: String, depth: int) -> void:
	depth_label.text = "DEPTH  %d" % depth
	room_label.text = _room_display_name(type)
	boss_active = false

	var curr_key := BiomeManager.get_key(depth)
	var prev_key := BiomeManager.get_key(maxi(0, depth - 1))
	if curr_key != prev_key or depth == 1:
		var biome := BiomeManager.get_biome(depth)
		wave_announce_text = "ENTERING  " + (biome["name"] as String)
	else:
		wave_announce_text = _room_announce(type, depth)
	wave_announce_timer = ANNOUNCE_DURATION
	queue_redraw()

func _room_display_name(type: String) -> String:
	match type:
		"combat":   return "COMBAT"
		"healing":  return "HEALING"
		"shrine":   return "SHRINE"
		"treasure": return "CACHE"
		"boss":     return "BOSS"
		"elite":    return "ELITE"
		"start":    return "START"
	return type.to_upper()

func _room_announce(type: String, depth: int) -> String:
	match type:
		"start":    return "WELCOME, DRIFTER"
		"healing":  return "HEALING SPRINGS"
		"shrine":   return "ELEMENTAL SHRINE"
		"treasure": return "HIDDEN CACHE"
		"boss":     return "BOSS  DEPTH %d" % depth
		"elite":    return "ELITE THREAT"
	return "DEPTH  %d" % depth

func _process(delta: float) -> void:
	if wave_announce_timer > 0:
		wave_announce_timer -= delta
		queue_redraw()
	if _relic_announce_timer > 0:
		_relic_announce_timer -= delta
		queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font

	# Hearts
	for i in max_health:
		var col := Color(1, 0.28, 0.38) if i < current_health else Color(0.18, 0.18, 0.22)
		draw_circle(Vector2(20 + i * 28, 20), 10, col)
		if i < current_health:
			draw_circle(Vector2(20 + i * 28, 20), 5, Color(1, 0.65, 0.72))

	# Fracture orbs
	var fracs: Array[int] = FractureManager.active_fractures
	var fx := 640.0 - (fracs.size() - 1) * 22.0
	for i in fracs.size():
		var col: Color = FractureManager.ELEMENT_COLORS[fracs[i]] as Color
		draw_circle(Vector2(fx + i * 44, 695), 13, col)
		draw_circle(Vector2(fx + i * 44, 695), 7, Color.WHITE.lerp(col, 0.35))
		var elem_name: String = FractureManager.ELEMENT_NAMES[fracs[i]] as String
		draw_string(font, Vector2(fx + i * 44 - 4, 700), elem_name[0],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

	# Synergy
	var syn := FractureManager.get_synergy()
	if syn != "":
		draw_string(font, Vector2(0, 672), syn, HORIZONTAL_ALIGNMENT_CENTER, 1280, 13, Color(1, 0.88, 0.4))

	# Relic row (bottom-right area, above weapon)
	_draw_relic_bar(font)

	# Room announcement
	if wave_announce_timer > 0:
		var t := wave_announce_timer / ANNOUNCE_DURATION
		var alpha := 4.0 * t * (1.0 - t)
		draw_string(font, Vector2(0, 375), wave_announce_text,
			HORIZONTAL_ALIGNMENT_CENTER, 1280, 44, Color(1, 0.88, 0.3, alpha))

	# Relic pickup announcement
	if _relic_announce_timer > 0:
		var t := _relic_announce_timer / 3.0
		var alpha := minf(t * 3.0, 1.0) * minf((1.0 - t) * 4.0, 1.0)
		draw_string(font, Vector2(0, 420), _relic_announce_text,
			HORIZONTAL_ALIGNMENT_CENTER, 1280, 32,
			Color(_relic_announce_col.r, _relic_announce_col.g, _relic_announce_col.b, alpha))

	# Weapon slots (bottom-left)
	_draw_weapon_slots(font)

	# Boss health bar
	if boss_active and boss_max_hp > 0:
		var bp := float(boss_hp) / float(boss_max_hp)
		var bw := 500.0
		var bx := 640.0 - bw * 0.5
		var by := 640.0
		draw_rect(Rect2(bx - 2, by - 2, bw + 4, 18), Color(0.05, 0.03, 0.02))
		draw_rect(Rect2(bx, by, bw, 14), Color(0.18, 0.08, 0.06))
		draw_rect(Rect2(bx, by, bw * bp, 14), _boss_bar_color())
		draw_rect(Rect2(bx, by, bw, 14), Color(0.9, 0.35, 0.08, 0.5), false, 1.5)
		draw_string(font, Vector2(640, by - 4), boss_name if boss_name != "" else "BOSS",
			HORIZONTAL_ALIGNMENT_CENTER, -1, 13, _boss_bar_color().lightened(0.3))

	# Minimap
	_draw_minimap(font)

func _boss_bar_color() -> Color:
	# Tint bar color to match current biome boss
	var key := BiomeManager.get_key(RoomManager.current_depth)
	match key:
		"emberwild": return Color(1.0, 0.28, 0.04)
		"glacia":    return Color(0.35, 0.70, 1.00)
		"verdant":   return Color(0.28, 0.90, 0.22)
		"tempest":   return Color(0.75, 0.50, 1.00)
	return Color(1.0, 0.28, 0.04)

func _draw_relic_bar(font: Font) -> void:
	var relics := RelicManager.active_relics
	if relics.is_empty():
		return
	var start_x := 900.0
	var y       := 690.0
	draw_string(font, Vector2(start_x - 48, y + 5), "RELICS", HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		Color(0.7, 0.7, 0.8, 0.8))
	for i in relics.size():
		var key := relics[i] as String
		var rdata := RelicManager.RELICS.get(key, {}) as Dictionary
		var col: Color = rdata.get("color", Color.WHITE) as Color
		var rx := start_x + i * 22.0
		draw_circle(Vector2(rx, y), 8, col)
		draw_circle(Vector2(rx, y), 4.5, col.lightened(0.3))
		draw_circle(Vector2(rx, y), 2, Color.WHITE)

func _draw_weapon_slots(font: Font) -> void:
	var player_nodes := get_tree().get_nodes_in_group("player") if get_tree() else []
	var owned: Array = []
	if player_nodes.size() > 0:
		var p := player_nodes[0]
		if "owned_weapons" in p:
			owned = p.owned_weapons as Array
	if owned.is_empty():
		owned = ["wand"]

	for i in owned.size():
		var key := owned[i] as String
		var wdata := WeaponManager.get_weapon(key)
		var wcol  := wdata["color"] as Color
		var wname := wdata["name"] as String
		var rx    := 14.0 + i * 130.0
		var ry    := 660.0
		var is_active := (key == weapon_name.to_lower().replace(" ", "_") or wname == weapon_name)

		# Slot background
		var slot_col := Color(0.12, 0.12, 0.18, 0.85) if not is_active else Color(wcol.r * 0.3, wcol.g * 0.3, wcol.b * 0.3, 0.90)
		draw_rect(Rect2(rx - 2, ry - 2, 120, 28), slot_col)
		draw_rect(Rect2(rx - 2, ry - 2, 120, 28), wcol if is_active else Color(0.3, 0.3, 0.4, 0.5), false, 1.2)

		# Key number
		draw_string(font, Vector2(rx + 3, ry + 13), "[%d]" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.6, 0.6, 0.7, 0.8))
		# Color dot
		draw_circle(Vector2(rx + 24, ry + 10), 5, wcol)
		draw_circle(Vector2(rx + 24, ry + 10), 2.5, Color.WHITE.lerp(wcol, 0.4))
		# Name
		draw_string(font, Vector2(rx + 33, ry + 14), wname, HORIZONTAL_ALIGNMENT_LEFT, -1,
			11 if is_active else 10, wcol if is_active else Color(0.7, 0.7, 0.8))

func _draw_minimap(_font: Font) -> void:
	if RoomManager.world.is_empty():
		return
	var cx    := 1190.0
	var cy    :=  100.0
	var rw    :=   10.0
	var rh    :=    7.0
	var gap_x :=   14.0
	var gap_y :=    9.0

	var show_all := RelicManager.has("compass")

	for raw_pos in RoomManager.world:
		var gp  := raw_pos as Vector2i
		var visible := RoomManager.visited.has(raw_pos) or show_all
		if not visible:
			# Show unvisited rooms as dim dots if compass active
			continue
		var data: Dictionary = RoomManager.world[raw_pos] as Dictionary
		var col: Color = _minimap_color(data["type"] as String)
		if not RoomManager.visited.has(raw_pos):
			col.a = 0.35  # Compass: dim for unvisited
		if gp == RoomManager.current_pos:
			col = Color.WHITE
		var sx := cx + gp.x * gap_x
		var sy := cy + gp.y * gap_y
		draw_rect(Rect2(sx - rw * 0.5, sy - rh * 0.5, rw, rh), col)

		for raw_dir in (data.get("exits", []) as Array):
			var dir := raw_dir as String
			var npos: Vector2i = gp + (RoomManager.DIRS[dir] as Vector2i)
			if RoomManager.visited.has(npos) or show_all:
				var nx := cx + npos.x * gap_x
				var ny := cy + npos.y * gap_y
				draw_line(Vector2(sx, sy), Vector2(nx, ny), Color(0.5, 0.5, 0.6, 0.5), 1)

func _minimap_color(type: String) -> Color:
	match type:
		"start":    return Color(0.55, 0.55, 0.60)
		"combat":   return Color(0.85, 0.25, 0.25)
		"elite":    return Color(1.00, 0.50, 0.10)
		"healing":  return Color(0.25, 0.85, 0.40)
		"shrine":   return Color(0.35, 0.45, 1.00)
		"treasure": return Color(1.00, 0.82, 0.20)
		"boss":     return Color(1.00, 0.40, 0.10)
	return Color(0.4, 0.4, 0.4)
