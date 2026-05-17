extends Node2D

const HW := 450.0
const HH := 300.0
const WT := 22.0
const DH := 36.0

# --- Enemy scenes ---
const EnemyScene     = preload("res://enemies/enemy.tscn")
const RangedScene    = preload("res://enemies/ranged_enemy.tscn")
const FastScene      = preload("res://enemies/fast_enemy.tscn")
const TankScene      = preload("res://enemies/tank_enemy.tscn")
const HealerScene    = preload("res://enemies/healer_enemy.tscn")
const ArcherScene    = preload("res://enemies/archer_enemy.tscn")
const SummonerScene  = preload("res://enemies/summoner_enemy.tscn")
# Biome signature enemies
const EmblerlingScene  = preload("res://enemies/emberling.tscn")
const CrystalRavenScene = preload("res://enemies/crystal_raven.tscn")
const SporelingScene   = preload("res://enemies/sporeling.tscn")
const SparkDroneScene  = preload("res://enemies/spark_drone.tscn")
const BossPyra       = preload("res://enemies/boss_pyra.tscn")
const BossGlacira    = preload("res://enemies/boss_glacira.tscn")
const BossVerdana    = preload("res://enemies/boss_verdana.tscn")
const BossTempestine = preload("res://enemies/boss_tempestine.tscn")
const FracturePickup  = preload("res://scripts/fracture_pickup.tscn")
const RelicPickupScript = preload("res://scripts/relic_pickup.gd")
const CrateScript        = preload("res://scripts/crate.gd")
const BarrelScript       = preload("res://scripts/barrel.gd")
const BiomeEffectsScript = "res://scripts/biome_effects.gd"  # loaded at runtime to avoid preload parse cycle
const WeaponPickupScript = preload("res://scripts/weapon_pickup.gd")

# --- State ---
var room_type   := "combat"
var exits       : Array[String] = []
var template_i  := 0
var pre_cleared := false

var _locked_dirs: Dictionary = {}
var _blockers:    Dictionary = {}
var _template:    Dictionary = {}
var _biome:       Dictionary = {}
var _enemies_alive := 0
var _player: Node2D = null
var _room_alive := true

# Tile decals — baked once in on_enter so _draw is deterministic
var _decals: Array = []
var _wall_props: Array = []

signal room_cleared

# ---------------------------------------------------------------
func setup(type: String, exit_dirs: Array, tmpl: int, already_cleared: bool) -> void:
	room_type   = type
	template_i  = tmpl
	pre_cleared = already_cleared
	exits.clear()
	for d in exit_dirs:
		exits.append(d as String)

func on_enter(player: Node2D) -> void:
	_player = player
	_template = RoomManager.COMBAT_TEMPLATES[template_i] as Dictionary
	_biome = BiomeManager.get_biome(RoomManager.current_depth)
	_bake_decals()
	_bake_wall_props()
	_build_walls()
	_build_doors()
	_build_obstacles()
	_build_env_objects()
	_build_special()
	_add_biome_effects()
	queue_redraw()

	if room_type in ["combat", "boss", "elite"] and not pre_cleared:
		_lock_all()
		await get_tree().create_timer(0.28).timeout
		if room_type == "boss":
			_spawn_boss()
		else:
			_spawn_enemies()
	else:
		_unlock_all()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_room_alive = false

# ---------------------------------------------------------------
# Decal and prop baking (done once so _draw stays pure)
# ---------------------------------------------------------------
func _bake_decals() -> void:
	_decals.clear()
	var fx_type: String = _biome.get("fx_type", "embers") as String
	var dcol: Color = _biome.get("decal", Color(0.5, 0.5, 0.5, 0.2)) as Color
	var count := 14
	for _i in count:
		var pos := Vector2(randf_range(-HW + 40, HW - 40), randf_range(-HH + 40, HH - 40))
		match fx_type:
			"embers":
				# Cracks
				_decals.append({"type": "crack", "pos": pos,
					"pts": _rand_crack(pos), "col": dcol})
			"snow":
				# Frost vein
				_decals.append({"type": "vein", "pos": pos,
					"pts": _rand_vein(pos), "col": dcol})
			"spores":
				# Root tendrils
				_decals.append({"type": "root", "pos": pos,
					"pts": _rand_root(pos), "col": dcol})
			"lightning":
				# Circuit trace
				_decals.append({"type": "circuit", "pos": pos,
					"pts": _rand_circuit(pos), "col": dcol})

func _rand_crack(origin: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var p := origin
	pts.append(p)
	for _i in randi_range(2, 5):
		p += Vector2(randf_range(-22, 22), randf_range(-16, 16))
		pts.append(p)
	return pts

func _rand_vein(origin: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var p := origin
	pts.append(p)
	var dir := Vector2(randf_range(-1,1), randf_range(-1,1)).normalized()
	for i in randi_range(3, 6):
		dir = dir.rotated(randf_range(-0.5, 0.5))
		p += dir * randf_range(10, 22)
		pts.append(p)
		if i % 2 == 0:
			# Branch
			pts.append(p + dir.rotated(PI * 0.4) * randf_range(6, 14))
			pts.append(p)
	return pts

func _rand_root(origin: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var p := origin
	pts.append(p)
	for _i in randi_range(4, 7):
		p += Vector2(randf_range(-18, 18), randf_range(-12, 12))
		pts.append(p)
	return pts

func _rand_circuit(origin: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var p := origin
	pts.append(p)
	var dir := Vector2(1, 0).rotated(float(randi() % 4) * PI * 0.5)
	for _i in randi_range(3, 6):
		var len := float(randi_range(12, 32))
		p += dir * len
		pts.append(p)
		if randf() < 0.5:
			pts.append(p)
			dir = dir.rotated(PI * 0.5 * (1 if randf() > 0.5 else -1))
	return pts

func _bake_wall_props() -> void:
	_wall_props.clear()
	var fx_type: String = _biome.get("fx_type", "embers") as String
	var tcol: Color = _biome.get("torch_color", Color(1, 0.5, 0.1)) as Color
	# Place 4 wall props (one near each wall) with slight random offset
	var positions := [
		Vector2(randf_range(-120, 120), -HH + WT + 12),  # north
		Vector2(randf_range(-120, 120),  HH - WT - 12),  # south
		Vector2(-HW + WT + 12, randf_range(-80, 80)),    # west
		Vector2( HW - WT - 12, randf_range(-80, 80)),    # east
	]
	for pos in positions:
		_wall_props.append({"pos": pos, "type": fx_type, "col": tcol})

# ---------------------------------------------------------------
# Visual
# ---------------------------------------------------------------
func _draw() -> void:
	if _biome.is_empty():
		return

	var floor_col:    Color = _biome.get("floor",       Color(0.1, 0.1, 0.1)) as Color
	var floor_alt:    Color = _biome.get("floor_alt",   floor_col.darkened(0.06)) as Color
	var tile_border:  Color = _biome.get("tile_border", Color(0.5, 0.5, 0.5, 0.3)) as Color
	var border_col:   Color = _biome.get("border",      Color(0.5, 0.6, 1, 0.15)) as Color
	var glow_col:     Color = _biome.get("glow",        Color(0.5, 0.5, 1, 0.08)) as Color

	# --- Tiled floor ---
	_draw_tiled_floor(floor_col, floor_alt, tile_border)

	# --- Floor decals ---
	_draw_decals()

	# --- Obstacle fill ---
	var wc: Color = _biome.get("wall", Color(0.2, 0.2, 0.3)) as Color
	for raw_obs in _template.get("obstacles", []):
		var obs := raw_obs as Dictionary
		var op  := obs["pos"]  as Vector2
		var os  := obs["size"] as Vector2
		var wt: Color = _biome.get("wall_top", wc.lightened(0.12)) as Color
		_draw_block(op, os, wc, wt)

	# --- Walls ---
	_draw_walls_with_depth()

	# --- Wall props ---
	_draw_wall_props()

	# --- Doors ---
	for dir in exits:
		var locked: bool = _locked_dirs.get(dir, false) as bool
		var col: Color = (_biome.get("door_locked", Color(0.85,0.18,0.18,0.85)) as Color) if locked \
		               else (_biome.get("door_open", Color(0.18,0.85,0.45,0.85)) as Color)
		var p   := _door_pos(dir)
		var is_ns := dir in ["north", "south"]
		var sz  := Vector2(DH * 2, WT) if is_ns else Vector2(WT, DH * 2)
		draw_rect(Rect2(p - sz * 0.5, sz), col)
		# Door frame highlight
		draw_rect(Rect2(p - sz * 0.5, sz), col.lightened(0.3), false, 1.5)

	# --- Room border glow ---
	draw_rect(Rect2(-HW, -HH, HW * 2, HH * 2), border_col, false, 4)
	draw_rect(Rect2(-HW + 4, -HH + 4, HW * 2 - 8, HH * 2 - 8), border_col.darkened(0.2), false, 1.5)

	# --- Biome ambient glow (corner wash) ---
	_draw_corner_glow(glow_col)

	# --- Vignette (dark edges) ---
	_draw_vignette()

	# --- Room type overlays ---
	_draw_room_type_dressing()

func _draw_tiled_floor(base: Color, alt: Color, border: Color) -> void:
	const TILE := 60
	for x in range(int(-HW), int(HW), TILE):
		for y in range(int(-HH), int(HH), TILE):
			# Checkerboard-like subtle variation
			var use_alt := ((int(x / TILE) + int(y / TILE)) % 3 == 0)
			var col := alt if use_alt else base
			# Slight per-tile brightness noise
			var noise := randf_range(-0.015, 0.015)
			col = Color(col.r + noise, col.g + noise, col.b + noise)
			var w := mini(TILE, int(HW) - x)
			var h := mini(TILE, int(HH) - y)
			draw_rect(Rect2(x, y, w, h), col)
			# Tile border
			draw_rect(Rect2(x, y, w, h), border, false, 0.8)

func _draw_decals() -> void:
	for d in _decals:
		var pts := d["pts"] as PackedVector2Array
		var col := d["col"] as Color
		if pts.size() >= 2:
			draw_polyline(pts, col, 1.2)

func _draw_block(pos: Vector2, size: Vector2, side_col: Color, top_col: Color) -> void:
	var r := Rect2(pos - size * 0.5, size)
	# Shadow under block
	draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Color(0, 0, 0, 0.35))
	# Side face (slightly darker)
	draw_rect(r, side_col)
	# Top face (lighter strip — gives 3D illusion)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 5)), top_col)
	# Outline
	draw_rect(r, top_col.lightened(0.1), false, 1.2)
	# Inner detail line
	var wd: Color = side_col.lightened(0.08)
	draw_line(r.position + Vector2(4, 10), r.position + Vector2(r.size.x - 4, 10), wd, 0.7)

func _draw_walls_with_depth() -> void:
	var wc: Color = _biome.get("wall", Color(0.2, 0.2, 0.3)) as Color
	var wt: Color = _biome.get("wall_top", wc.lightened(0.14)) as Color
	var wd: Color = _biome.get("wall_detail", Color(0.5, 0.5, 0.8, 0.3)) as Color
	for dir in ["north", "south", "east", "west"]:
		for s in _wall_segs(dir, dir in exits):
			var wp := s[0] as Vector2
			var ws := s[1] as Vector2
			var r := Rect2(wp - ws * 0.5, ws)
			# Shadow
			draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.4))
			# Wall body
			draw_rect(r, wc)
			# Top edge highlight (makes it look like a raised block)
			var is_horiz := ws.x > ws.y
			if is_horiz:
				draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), wt)
				# Horizontal stone line details
				for i in range(0, int(r.size.x), 55):
					draw_line(Vector2(r.position.x + i, r.position.y + 6),
					          Vector2(r.position.x + i + 42, r.position.y + 6), wd, 0.8)
			else:
				draw_rect(Rect2(r.position, Vector2(4, r.size.y)), wt)
				for i in range(0, int(r.size.y), 40):
					draw_line(Vector2(r.position.x + 6, r.position.y + i),
					          Vector2(r.position.x + 6, r.position.y + i + 30), wd, 0.8)
			# Outline
			draw_rect(r, wt, false, 1.2)

func _draw_wall_props() -> void:
	var fx_type: String = _biome.get("fx_type", "embers") as String
	for prop in _wall_props:
		var pos := prop["pos"] as Vector2
		var col := prop["col"] as Color
		match fx_type:
			"embers":
				_draw_torch(pos, col)
			"snow":
				_draw_ice_crystal(pos, col)
			"spores":
				_draw_mushroom(pos, col)
			"lightning":
				_draw_coil(pos, col)

func _draw_torch(pos: Vector2, col: Color) -> void:
	# Torch bracket
	draw_rect(Rect2(pos.x - 3, pos.y - 10, 6, 14), Color(0.35, 0.25, 0.12))
	# Flame layers
	draw_circle(pos + Vector2(0, -12), 5, Color(col.r, col.g * 0.6, 0.04, 0.9))
	draw_circle(pos + Vector2(0, -14), 3.5, Color(col.r, col.g, col.b * 0.3, 0.8))
	draw_circle(pos + Vector2(0, -15.5), 2, Color(1.0, 0.95, 0.6, 0.9))
	# Glow halo
	draw_circle(pos + Vector2(0, -13), 12, Color(col.r, col.g, col.b, 0.08))

func _draw_ice_crystal(pos: Vector2, col: Color) -> void:
	# Crystal spires
	for i in 3:
		var h := 14.0 - i * 3.0
		var ox := float(i - 1) * 6.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(pos.x + ox, pos.y - h),
			Vector2(pos.x + ox - 3, pos.y),
			Vector2(pos.x + ox + 3, pos.y),
		]), Color(col.r, col.g, col.b, 0.6 - i * 0.1))
		draw_line(Vector2(pos.x + ox, pos.y - h),
		          Vector2(pos.x + ox, pos.y), Color(1, 1, 1, 0.35), 0.8)
	# Glow
	draw_circle(pos + Vector2(0, -7), 10, Color(col.r, col.g, col.b, 0.10))

func _draw_mushroom(pos: Vector2, col: Color) -> void:
	# Stem
	draw_rect(Rect2(pos.x - 2, pos.y - 8, 4, 12), Color(0.55, 0.42, 0.30))
	# Cap
	draw_colored_polygon(PackedVector2Array([
		Vector2(pos.x, pos.y - 16), Vector2(pos.x + 10, pos.y - 6),
		Vector2(pos.x - 10, pos.y - 6),
	]), Color(col.r, col.g, col.b, 0.85))
	# Spots
	draw_circle(pos + Vector2(-3, -10), 2, Color(1, 1, 1, 0.55))
	draw_circle(pos + Vector2(4, -9), 1.5, Color(1, 1, 1, 0.55))
	# Bioluminescent glow
	draw_circle(pos + Vector2(0, -10), 14, Color(col.r, col.g, col.b, 0.09))

func _draw_coil(pos: Vector2, col: Color) -> void:
	# Machine housing
	draw_rect(Rect2(pos.x - 5, pos.y - 12, 10, 16), Color(0.18, 0.14, 0.28))
	draw_rect(Rect2(pos.x - 5, pos.y - 12, 10, 16), Color(col.r, col.g, col.b, 0.4), false, 1)
	# Coil rings
	for i in 3:
		draw_arc(pos + Vector2(0, -5 + i * 3), 3.5, 0, TAU, 8,
			Color(col.r, col.g, col.b, 0.6), 1.2)
	# Electric top arc
	draw_arc(pos + Vector2(0, -13), 5, PI, TAU, 8, Color(1, 1, 1, 0.7), 1.5)
	# Glow
	draw_circle(pos + Vector2(0, -8), 12, Color(col.r, col.g, col.b, 0.10))

func _draw_corner_glow(col: Color) -> void:
	# Soft biome-colored wash at corners/edges
	for i in 4:
		var alpha := col.a * (1.0 - float(i) * 0.22)
		if alpha <= 0: break
		var inset := float(i) * 28.0
		draw_rect(Rect2(-HW + inset, -HH + inset, (HW - inset) * 2, (HH - inset) * 2),
			Color(col.r, col.g, col.b, alpha), false, 28.0 - float(i) * 6.0)

func _draw_vignette() -> void:
	# Dark edge vignette — pure black, fades inward
	var layers := 5
	for i in layers:
		var t := float(i) / float(layers)
		var alpha := (1.0 - t) * 0.22
		var inset := t * 90.0
		draw_rect(Rect2(-HW, -HH, HW * 2, HH * 2),
			Color(0, 0, 0, alpha), false, 90.0 - t * 80.0)
		# Also darken the floor corners
		if i < 3:
			draw_rect(Rect2(-HW + inset * 0.3, -HH + inset * 0.3,
			               (HW - inset * 0.3) * 2, (HH - inset * 0.3) * 2),
				Color(0, 0, 0, alpha * 0.5), false, 40.0 - t * 35.0)

func _draw_room_type_dressing() -> void:
	var accent: Color = _biome.get("accent", Color(0.5, 0.5, 1.0)) as Color
	match room_type:
		"healing":
			# Rune circle with inner sigil
			draw_circle(Vector2.ZERO, 36, Color(0.18, 0.8, 0.32, 0.08))
			draw_arc(Vector2.ZERO, 36, 0, TAU, 32, Color(0.28, 0.9, 0.4, 0.55), 2)
			draw_arc(Vector2.ZERO, 28, 0, TAU, 32, Color(0.28, 0.9, 0.4, 0.25), 1)
			# Inner cross sigil
			for i in 4:
				var a := i * TAU / 4.0
				draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * 18,
					Color(0.28, 0.9, 0.4, 0.6), 1.5)
			# Rune dots
			for i in 8:
				var a := i * TAU / 8.0
				draw_circle(Vector2(cos(a), sin(a)) * 36, 2.5, Color(0.4, 1.0, 0.5, 0.7))
		"shrine":
			# Star constellation
			var pts: Array[Vector2] = []
			for i in 6:
				pts.append(Vector2(cos(i * TAU / 6.0), sin(i * TAU / 6.0)) * 38)
			for i in 6:
				draw_line(pts[i], pts[(i + 2) % 6], Color(accent.r, accent.g, accent.b, 0.4), 1.2)
				draw_line(pts[i], pts[(i + 3) % 6], Color(accent.r, accent.g, accent.b, 0.2), 0.8)
			for p in pts:
				draw_circle(p, 3, Color(accent.r, accent.g, accent.b, 0.8))
			draw_circle(Vector2.ZERO, 6, Color(1, 1, 1, 0.75))
			draw_circle(Vector2.ZERO, 3, accent)
		"treasure":
			# Ornate treasure border
			draw_rect(Rect2(-26, -18, 52, 36), Color(1, 0.85, 0.2, 0.18))
			draw_rect(Rect2(-26, -18, 52, 36), Color(1, 0.85, 0.2, 0.65), false, 2.5)
			draw_rect(Rect2(-22, -14, 44, 28), Color(1, 0.85, 0.2, 0.2), false, 1.0)
			# Corner gems
			for cx in [-26, 26]:
				for cy in [-18, 18]:
					draw_circle(Vector2(cx, cy), 3.5, Color(1, 0.85, 0.2, 0.9))
		"boss":
			# Ritual summoning circle
			draw_circle(Vector2.ZERO, 60, Color(0.85, 0.12, 0.06, 0.08))
			draw_arc(Vector2.ZERO, 60, 0, TAU, 40, Color(0.9, 0.15, 0.1, 0.35), 2.5)
			draw_arc(Vector2.ZERO, 46, 0, TAU, 32, Color(0.7, 0.1, 0.05, 0.22), 1.5)
			# Pentagram-style lines
			var pts_b: Array[Vector2] = []
			for i in 5:
				pts_b.append(Vector2(cos(-PI * 0.5 + i * TAU / 5.0),
				                     sin(-PI * 0.5 + i * TAU / 5.0)) * 52)
			for i in 5:
				draw_line(pts_b[i], pts_b[(i + 2) % 5], Color(0.9, 0.15, 0.1, 0.28), 1.2)
				draw_circle(pts_b[i], 3.5, Color(0.9, 0.15, 0.1, 0.55))
		"start":
			# Welcome arrow guides toward exits
			for dir in exits:
				var p := _door_pos(dir) * 0.55
				var dv := _dir_vec(dir)
				draw_line(p, p + dv * 22, Color(0.5, 0.75, 1.0, 0.65), 2)
				var perp := dv.rotated(PI * 0.5) * 5.0
				draw_colored_polygon(PackedVector2Array([
					p + dv * 28, p + dv * 18 + perp, p + dv * 18 - perp,
				]), Color(0.5, 0.75, 1.0, 0.65))

# ---------------------------------------------------------------
# Walls
# ---------------------------------------------------------------
func _build_walls() -> void:
	for dir in ["north", "south", "east", "west"]:
		for s in _wall_segs(dir, dir in exits):
			_add_wall(s[0] as Vector2, s[1] as Vector2)

func _wall_segs(dir: String, has_exit: bool) -> Array:
	match dir:
		"north":
			if has_exit:
				return [[Vector2(-(HW+DH)*0.5,-HH+WT*0.5),Vector2(HW-DH,WT)],
				        [Vector2( (HW+DH)*0.5,-HH+WT*0.5),Vector2(HW-DH,WT)]]
			return [[Vector2(0,-HH+WT*0.5),Vector2(HW*2,WT)]]
		"south":
			if has_exit:
				return [[Vector2(-(HW+DH)*0.5,HH-WT*0.5),Vector2(HW-DH,WT)],
				        [Vector2( (HW+DH)*0.5,HH-WT*0.5),Vector2(HW-DH,WT)]]
			return [[Vector2(0,HH-WT*0.5),Vector2(HW*2,WT)]]
		"east":
			if has_exit:
				return [[Vector2(HW-WT*0.5,-(HH+DH)*0.5),Vector2(WT,HH-DH)],
				        [Vector2(HW-WT*0.5, (HH+DH)*0.5),Vector2(WT,HH-DH)]]
			return [[Vector2(HW-WT*0.5,0),Vector2(WT,HH*2)]]
		"west":
			if has_exit:
				return [[Vector2(-HW+WT*0.5,-(HH+DH)*0.5),Vector2(WT,HH-DH)],
				        [Vector2(-HW+WT*0.5, (HH+DH)*0.5),Vector2(WT,HH-DH)]]
			return [[Vector2(-HW+WT*0.5,0),Vector2(WT,HH*2)]]
	return []

func _add_wall(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	var cs   := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape  = rect
	body.position = pos
	body.add_child(cs)
	add_child(body)

# ---------------------------------------------------------------
# Doors
# ---------------------------------------------------------------
func _build_doors() -> void:
	for dir in exits:
		_locked_dirs[dir] = false
		var is_ns := dir in ["north", "south"]

		var door   := Area2D.new()
		var dcs    := CollisionShape2D.new()
		var drect  := RectangleShape2D.new()
		drect.size = Vector2(DH * 2, 40) if is_ns else Vector2(40, DH * 2)
		dcs.shape  = drect
		door.position = _door_pos(dir)
		door.add_child(dcs)
		add_child(door)
		var d: String = dir
		door.body_entered.connect(func(body: Node2D):
			if body.is_in_group("player") and not (_locked_dirs.get(d, true) as bool):
				RoomManager.enter_door(d)
		)

		var blocker := StaticBody2D.new()
		var bcs     := CollisionShape2D.new()
		var brect   := RectangleShape2D.new()
		brect.size  = drect.size
		bcs.shape   = brect
		bcs.disabled = true
		blocker.position = _door_pos(dir)
		blocker.add_child(bcs)
		add_child(blocker)
		_blockers[dir] = bcs

func _door_pos(dir: String) -> Vector2:
	match dir:
		"north": return Vector2(0, -HH)
		"south": return Vector2(0,  HH)
		"east":  return Vector2( HW, 0)
		"west":  return Vector2(-HW, 0)
	return Vector2.ZERO

func _dir_vec(dir: String) -> Vector2:
	match dir:
		"north": return Vector2(0,-1)
		"south": return Vector2(0, 1)
		"east":  return Vector2( 1, 0)
		"west":  return Vector2(-1, 0)
	return Vector2.ZERO

# ---------------------------------------------------------------
# Obstacles
# ---------------------------------------------------------------
func _build_obstacles() -> void:
	for raw_obs in _template.get("obstacles", []):
		var obs := raw_obs as Dictionary
		_add_wall(obs["pos"] as Vector2, obs["size"] as Vector2)

# ---------------------------------------------------------------
# Environmental objects
# ---------------------------------------------------------------
func _build_env_objects() -> void:
	if room_type not in ["combat", "boss", "elite"]:
		return
	var depth := RoomManager.current_depth
	_scatter_crates(2)
	if depth >= 2:
		_scatter_hazard_pits(1 + (depth / 4))
	if depth >= 3:
		_scatter_slow_zones(1)

func _scatter_crates(count: int) -> void:
	for _i in count:
		var pos := _safe_random_pos(50)
		var obj := StaticBody2D.new()
		obj.set_script(BarrelScript if randf() < 0.30 else CrateScript)
		obj.position = pos
		add_child(obj)

func _scatter_hazard_pits(count: int) -> void:
	for _i in count:
		var pos := _safe_random_pos(80)
		_add_hazard_pit(pos)

func _scatter_slow_zones(count: int) -> void:
	for _i in count:
		var pos := _safe_random_pos(60)
		_add_slow_zone(pos, Vector2(randf_range(80, 140), randf_range(60, 100)))

func _add_hazard_pit(pos: Vector2) -> void:
	var zone := Area2D.new()
	var zcs  := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 22.0
	zcs.shape = circ
	zone.position = pos
	zone.add_child(zcs)
	add_child(zone)

	var vis := Node2D.new()
	vis.set_script(load("res://scripts/hazard_vis.gd"))
	zone.add_child(vis)

	var inside: Array = []
	zone.body_entered.connect(func(b: Node2D): if b.is_in_group("player"): inside.append(b))
	zone.body_exited.connect(func(b: Node2D): inside.erase(b))
	var tick := get_tree().create_timer(1.0, false)
	tick.timeout.connect(func(): _pit_tick(inside, zone, tick))

func _pit_tick(inside: Array, zone: Area2D, _prev: Object) -> void:
	if not is_instance_valid(zone) or not zone.is_inside_tree():
		return
	for p in inside:
		if is_instance_valid(p):
			p.take_damage(1)
	var next := get_tree().create_timer(1.0, false)
	next.timeout.connect(func(): _pit_tick(inside, zone, next))

func _add_slow_zone(pos: Vector2, size: Vector2) -> void:
	var zone := Area2D.new()
	var zcs  := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	zcs.shape = rect
	zone.position = pos
	zone.add_child(zcs)
	add_child(zone)

	var vis := Node2D.new()
	vis.set_script(load("res://scripts/slow_zone_vis.gd"))
	vis.set_meta("zone_size", size)
	zone.add_child(vis)

	zone.body_entered.connect(func(b: Node2D):
		if b.is_in_group("player") and "speed_mult" in b:
			b.speed_mult = 0.42
	)
	zone.body_exited.connect(func(b: Node2D):
		if b.is_in_group("player") and "speed_mult" in b:
			b.speed_mult = 1.0
	)

func _safe_random_pos(min_dist_from_obs: float) -> Vector2:
	for _attempt in 15:
		var pos := Vector2(randf_range(-360, 360), randf_range(-220, 220))
		var ok := true
		for raw_obs in _template.get("obstacles", []):
			var obs := raw_obs as Dictionary
			if pos.distance_to(obs["pos"] as Vector2) < min_dist_from_obs:
				ok = false
				break
		if ok:
			return pos
	return Vector2(randf_range(-200, 200), randf_range(-140, 140))

# ---------------------------------------------------------------
# Special room content
# ---------------------------------------------------------------
func _build_special() -> void:
	match room_type:
		"healing":  _add_healing_zone()
		"shrine":   _add_shrine()
		"treasure": _add_treasure()
		"event":    _add_event_room()

func _add_healing_zone() -> void:
	var zone := Area2D.new()
	var zcs  := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 36.0
	zcs.shape = circ
	zone.add_child(zcs)
	add_child(zone)
	zone.body_entered.connect(func(b: Node2D):
		if b.is_in_group("player"):
			b.set("health", b.get("max_health"))
			GameEvents.player_hit.emit(b.get("max_health"), b.get("max_health"))
			zone.call_deferred("queue_free")
	)

func _add_shrine() -> void:
	var zone := Area2D.new()
	var zcs  := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 38.0
	zcs.shape = circ
	zone.add_child(zcs)
	add_child(zone)
	zone.body_entered.connect(func(b: Node2D):
		if b.is_in_group("player"):
			FractureManager.add_fracture(randi() % 4)
			zone.call_deferred("queue_free")
	)

func _add_event_room() -> void:
	# Wandering Drifter — choose ONE of three offerings
	var choices: Array[Node] = []
	var positions := [Vector2(-110, 0), Vector2(0, -60), Vector2(110, 0)]

	# Offering 1: weapon
	var wkey := WeaponManager.random_drop_key()
	var wp := Area2D.new()
	wp.set_script(WeaponPickupScript)
	add_child(wp)
	wp.setup(wkey, positions[0])
	choices.append(wp)

	# Offering 2: relic
	var rkey := RelicManager.random_relic_key()
	if rkey != "":
		var rp := Area2D.new()
		rp.set_script(RelicPickupScript)
		add_child(rp)
		rp.setup(rkey, positions[1])
		choices.append(rp)
	else:
		var frac2 := FracturePickup.instantiate()
		add_child(frac2)
		frac2.setup(randi() % 4, positions[1])
		choices.append(frac2)

	# Offering 3: fracture
	var frac := FracturePickup.instantiate()
	add_child(frac)
	frac.setup(randi() % 4, positions[2])
	choices.append(frac)

	# When any choice is taken, free the others
	for node in choices:
		if node.has_method("connect"):
			node.tree_exited.connect(func():
				for other in choices:
					if is_instance_valid(other) and other != node:
						other.call_deferred("queue_free")
			)

func _add_treasure() -> void:
	var wp := Area2D.new()
	wp.set_script(WeaponPickupScript)
	add_child(wp)
	wp.setup(WeaponManager.random_drop_key(), Vector2(0, -40))
	# Relic pickup (50% chance, or always if no relics yet)
	var relic_key := RelicManager.random_relic_key()
	if relic_key != "" and (RelicManager.active_relics.is_empty() or randf() < 0.5):
		var rp := Area2D.new()
		rp.set_script(RelicPickupScript)
		add_child(rp)
		rp.setup(relic_key, Vector2(0, 40))
	else:
		var frac := FracturePickup.instantiate()
		add_child(frac)
		frac.setup(randi() % 4, Vector2(0, 40))

# ---------------------------------------------------------------
# Biome effects (animated atmosphere)
# ---------------------------------------------------------------
func _add_biome_effects() -> void:
	var fx := Node2D.new()
	fx.set_script(load(BiomeEffectsScript))
	add_child(fx)
	fx.setup(_biome)

# ---------------------------------------------------------------
# Enemy spawning
# ---------------------------------------------------------------
func _spawn_enemies() -> void:
	if _player == null:
		return
	var raw_spawns = _template.get("spawns", [])
	var spawns: Array[Vector2] = []
	for s in raw_spawns:
		spawns.append(s as Vector2)
	spawns.shuffle()

	var depth := RoomManager.current_depth
	# Elite rooms get more enemies
	var count := mini(depth + 3, 9)
	if room_type == "elite":
		count = mini(count + 2, 11)

	_enemies_alive = 0
	for i in count:
		var pos: Vector2 = spawns[i % spawns.size()] if spawns.size() > 0 else _rand_pos()
		_spawn(_pick_enemy(depth), pos)

	# Elite rooms: guaranteed fracture drop after clear + sometimes a relic
	if room_type == "elite":
		_elite_loot_pending = true

func _pick_enemy(depth: int) -> PackedScene:
	var biome := BiomeManager.get_key(depth)
	var r     := randf()
	match biome:
		"emberwild":
			# Emberlings are the signature creature — chaotic and explosive
			if r < 0.35: return EmblerlingScene
			if r < 0.60: return EnemyScene
			if r < 0.78: return FastScene
			if r < 0.90: return ArcherScene
			return TankScene
		"glacia":
			# Crystal Ravens are the signature — dive attackers
			if r < 0.30: return CrystalRavenScene
			if r < 0.52: return RangedScene
			if r < 0.68: return ArcherScene
			if r < 0.82: return TankScene
			return HealerScene
		"verdant":
			# Sporelings are the signature — slow but AoE danger
			if r < 0.28: return SporelingScene
			if r < 0.50: return EnemyScene
			if r < 0.66: return HealerScene
			if r < 0.82: return ArcherScene
			return SummonerScene
		"tempest":
			# Spark Drones are the signature — teleporting electric
			if r < 0.32: return SparkDroneScene
			if r < 0.52: return RangedScene
			if r < 0.68: return ArcherScene
			if r < 0.82: return SummonerScene
			return FastScene
		_:
			if r < 0.35: return EnemyScene
			if r < 0.60: return RangedScene
			if r < 0.78: return FastScene
			return TankScene

var _elite_loot_pending := false

func _spawn(scene: PackedScene, pos: Vector2) -> void:
	var e := scene.instantiate()
	e.position = pos
	add_child(e)
	_enemies_alive += 1
	e.tree_exited.connect(_on_enemy_removed)

func _rand_pos() -> Vector2:
	return Vector2(randf_range(-360, 360), randf_range(-220, 220))

func _spawn_boss() -> void:
	var biome_key := BiomeManager.get_key(RoomManager.current_depth)
	var boss_scene: PackedScene
	match biome_key:
		"emberwild": boss_scene = BossPyra
		"glacia":    boss_scene = BossGlacira
		"verdant":   boss_scene = BossVerdana
		"tempest":   boss_scene = BossTempestine
		_:           boss_scene = BossPyra
	var boss := boss_scene.instantiate()
	boss.position = Vector2(0, -80)
	add_child(boss)
	_enemies_alive = 1
	boss.tree_exited.connect(_on_enemy_removed)

# ---------------------------------------------------------------
# Door locking
# ---------------------------------------------------------------
func _on_enemy_removed() -> void:
	if not _room_alive:
		return
	_enemies_alive -= 1
	if _enemies_alive <= 0 and not pre_cleared:
		pre_cleared = true
		_unlock_all()
		room_cleared.emit()
		# Elite room: spawn bonus loot after clear
		if _elite_loot_pending:
			_elite_loot_pending = false
			var frac := FracturePickup.instantiate()
			frac.setup(randi() % 4, Vector2.ZERO)
			add_child(frac)
			if randf() < 0.35:
				var rkey := RelicManager.random_relic_key()
				if rkey != "":
					var rp := Area2D.new()
					rp.set_script(RelicPickupScript)
					add_child(rp)
					rp.setup(rkey, Vector2(0, 50))

func _lock_all() -> void:
	for dir in exits:
		_locked_dirs[dir] = true
		if _blockers.has(dir):
			(_blockers[dir] as CollisionShape2D).disabled = false
	queue_redraw()

func _unlock_all() -> void:
	for dir in exits:
		_locked_dirs[dir] = false
		if _blockers.has(dir):
			(_blockers[dir] as CollisionShape2D).disabled = true
	queue_redraw()
