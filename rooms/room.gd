extends Node2D

const HW := 450.0
const HH := 300.0
const WT := 22.0
const DH := 36.0

const ROOM_COLORS: Dictionary = {
	"start":    Color(0.28, 0.30, 0.36),
	"combat":   Color(0.07, 0.09, 0.13),
	"healing":  Color(0.06, 0.14, 0.09),
	"shrine":   Color(0.07, 0.09, 0.16),
	"treasure": Color(0.14, 0.13, 0.06),
	"boss":     Color(0.14, 0.06, 0.06),
}
const WALL_COLOR  := Color(0.20, 0.22, 0.28)
const FLOOR_GRID  := Color(1, 1, 1, 0.038)
const PIT_COLOR   := Color(0.06, 0.03, 0.12)

# --- Enemy scenes ---
const EnemyScene    = preload("res://enemies/enemy.tscn")
const RangedScene   = preload("res://enemies/ranged_enemy.tscn")
const FastScene     = preload("res://enemies/fast_enemy.tscn")
const TankScene     = preload("res://enemies/tank_enemy.tscn")
const HealerScene   = preload("res://enemies/healer_enemy.tscn")
const BossPyra      = preload("res://enemies/boss_pyra.tscn")
const FracturePickup = preload("res://scripts/fracture_pickup.tscn")
const CrateScript        = preload("res://scripts/crate.gd")
const BarrelScript       = preload("res://scripts/barrel.gd")
const AmbientScript      = preload("res://scripts/ambient_particles.gd")
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
	_build_walls()
	_build_doors()
	_build_obstacles()
	_build_env_objects()
	_build_special()
	_add_ambient_particles()
	queue_redraw()

	if room_type in ["combat", "boss"] and not pre_cleared:
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
# Visual
# ---------------------------------------------------------------
func _draw() -> void:
	# Biome-themed floor
	var floor_col: Color = _biome.get("floor", ROOM_COLORS.get(room_type, ROOM_COLORS["combat"]) as Color) as Color
	if room_type == "boss":
		floor_col = floor_col.darkened(0.18)
	draw_rect(Rect2(-HW, -HH, HW * 2, HH * 2), floor_col)

	var grid_col: Color = _biome.get("grid", FLOOR_GRID) as Color
	for x in range(int(-HW), int(HW) + 1, 60):
		draw_line(Vector2(x, -HH), Vector2(x, HH), grid_col, 1)
	for y in range(int(-HH), int(HH) + 1, 60):
		draw_line(Vector2(-HW, y), Vector2(HW, y), grid_col, 1)

	_draw_wall_segments()

	for raw_obs in _template.get("obstacles", []):
		var obs := raw_obs as Dictionary
		var op  := obs["pos"]  as Vector2
		var os  := obs["size"] as Vector2
		var wc: Color = _biome.get("wall", WALL_COLOR) as Color
		draw_rect(Rect2(op - os * 0.5, os), wc)
		draw_rect(Rect2(op - os * 0.5, os), Color(1, 1, 1, 0.07), false, 1.5)

	for dir in exits:
		var locked: bool = _locked_dirs.get(dir, false) as bool
		var col: Color = (_biome.get("door_locked", Color(0.85,0.18,0.18,0.85)) as Color) if locked \
		               else (_biome.get("door_open",   Color(0.18,0.85,0.45,0.85)) as Color)
		var p   := _door_pos(dir)
		var is_ns := dir in ["north", "south"]
		var sz  := Vector2(DH * 2, WT) if is_ns else Vector2(WT, DH * 2)
		draw_rect(Rect2(p - sz * 0.5, sz), col)

	match room_type:
		"healing":
			draw_circle(Vector2.ZERO, 24, Color(0.28, 0.9, 0.4, 0.16))
			draw_arc(Vector2.ZERO, 24, 0, TAU, 32, Color(0.28, 0.9, 0.4, 0.5), 2)
		"shrine":
			for i in 6:
				var a := i * TAU / 6.0
				draw_circle(Vector2(cos(a), sin(a)) * 30, 5, Color(0.4, 0.5, 1.0, 0.7))
			draw_circle(Vector2.ZERO, 6, Color(0.6, 0.7, 1.0, 0.8))
		"treasure":
			draw_rect(Rect2(-20, -14, 40, 28), Color(1, 0.85, 0.2, 0.28))
			draw_rect(Rect2(-20, -14, 40, 28), Color(1, 0.85, 0.2, 0.6), false, 2)
		"boss":
			draw_arc(Vector2.ZERO, 50, 0, TAU, 32, Color(0.9, 0.15, 0.1, 0.18), 3)
		"start":
			for dir in exits:
				var p := _door_pos(dir) * 0.5
				draw_line(p, p + _dir_vec(dir) * 20, Color(0.5, 0.75, 1.0, 0.7), 2)

func _draw_wall_segments() -> void:
	var wc: Color = _biome.get("wall", WALL_COLOR) as Color
	var border_col: Color = _biome.get("border", Color(0.5, 0.6, 1, 0.12)) as Color
	for dir in ["north", "south", "east", "west"]:
		for s in _wall_segs(dir, dir in exits):
			var wp := s[0] as Vector2
			var ws := s[1] as Vector2
			draw_rect(Rect2(wp - ws * 0.5, ws), wc)
	# Room border glow
	draw_rect(Rect2(-HW, -HH, HW * 2, HH * 2), border_col, false, 3)

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
# Obstacles (collision only — drawn separately)
# ---------------------------------------------------------------
func _build_obstacles() -> void:
	for raw_obs in _template.get("obstacles", []):
		var obs := raw_obs as Dictionary
		_add_wall(obs["pos"] as Vector2, obs["size"] as Vector2)

# ---------------------------------------------------------------
# Environmental objects
# ---------------------------------------------------------------
func _build_env_objects() -> void:
	if room_type not in ["combat", "boss"]:
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
		# 30% chance to spawn a barrel instead of a crate
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

	# Draw pit visually via a dedicated Node2D child
	var vis := Node2D.new()
	vis.set_script(load("res://scripts/hazard_vis.gd"))
	zone.add_child(vis)

	var timer := 0.0
	var inside: Array = []
	zone.body_entered.connect(func(b: Node2D): if b.is_in_group("player"): inside.append(b))
	zone.body_exited.connect(func(b: Node2D): inside.erase(b))
	# Damage handled via a repeating timer set up inline
	var tick := get_tree().create_timer(1.0, false)
	tick.timeout.connect(func(): _pit_tick(inside, zone, tick))

func _pit_tick(inside: Array, zone: Area2D, _prev_tick: Object) -> void:
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

func _add_healing_zone() -> void:
	var zone := Area2D.new()
	var zcs  := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 28.0
	zcs.shape = circ
	zone.add_child(zcs)
	add_child(zone)
	var used := false
	zone.body_entered.connect(func(b: Node2D):
		if b.is_in_group("player") and not used:
			used = true
			b.set("health", b.get("max_health"))
			GameEvents.player_hit.emit(b.get("max_health"), b.get("max_health"))
	)

func _add_shrine() -> void:
	var zone := Area2D.new()
	var zcs  := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 30.0
	zcs.shape = circ
	zone.add_child(zcs)
	add_child(zone)
	var used := false
	zone.body_entered.connect(func(b: Node2D):
		if b.is_in_group("player") and not used:
			used = true
			FractureManager.add_fracture(randi() % 4)
	)

func _add_treasure() -> void:
	# Weapon pickup (guaranteed)
	var wp := Area2D.new()
	wp.set_script(WeaponPickupScript)
	add_child(wp)
	wp.setup(WeaponManager.random_drop_key(), Vector2(0, -30))
	# Fracture pickup
	var frac := FracturePickup.instantiate()
	add_child(frac)
	frac.setup(randi() % 4, Vector2(0, 40))

# ---------------------------------------------------------------
# Enemy spawning — weighted by depth
# ---------------------------------------------------------------
func _spawn_enemies() -> void:
	if _player == null:
		return
	var raw_spawns = _template.get("spawns", [])
	var spawns: Array[Vector2] = []
	for s in raw_spawns:
		spawns.append(s as Vector2)
	spawns.shuffle()

	var depth    := RoomManager.current_depth
	var is_boss  := room_type == "boss"
	var count    := (6 + depth) if is_boss else mini(depth + 3, 9)

	_enemies_alive = 0
	for i in count:
		var pos: Vector2 = spawns[i % spawns.size()] if spawns.size() > 0 else _rand_pos()
		_spawn(_pick_enemy(depth, is_boss), pos)

func _pick_enemy(depth: int, is_boss: bool) -> PackedScene:
	if is_boss:
		var r := randf()
		if r < 0.35: return TankScene
		if r < 0.60: return EnemyScene
		if r < 0.80: return RangedScene
		return HealerScene

	var r := randf()
	if depth <= 1:
		return FastScene if r < 0.25 else EnemyScene
	elif depth <= 3:
		if r < 0.35: return EnemyScene
		if r < 0.55: return RangedScene
		if r < 0.75: return FastScene
		return TankScene
	else:
		if r < 0.25: return EnemyScene
		if r < 0.45: return RangedScene
		if r < 0.60: return FastScene
		if r < 0.75: return TankScene
		return HealerScene

func _spawn(scene: PackedScene, pos: Vector2) -> void:
	var e := scene.instantiate()
	e.position = pos
	add_child(e)
	_enemies_alive += 1
	# tree_exited fires when enemy is queue_free'd — reliable regardless of how it dies
	e.tree_exited.connect(_on_enemy_removed)

func _rand_pos() -> Vector2:
	return Vector2(randf_range(-360, 360), randf_range(-220, 220))

func _spawn_boss() -> void:
	var boss := BossPyra.instantiate()
	boss.position = Vector2(0, -80)
	add_child(boss)
	_enemies_alive = 1
	boss.tree_exited.connect(_on_enemy_removed)

func _add_ambient_particles() -> void:
	var pcol: Color = _biome.get("particle", Color(0.6, 0.7, 1.0)) as Color
	var ap := Node2D.new()
	ap.set_script(AmbientScript)
	add_child(ap)
	ap.setup(pcol)

# KEY FIX: use tree_exited + _room_alive guard instead of GameEvents signal counting
func _on_enemy_removed() -> void:
	if not _room_alive:
		return
	_enemies_alive -= 1
	if _enemies_alive <= 0 and not pre_cleared:
		pre_cleared = true
		_unlock_all()
		room_cleared.emit()

# ---------------------------------------------------------------
# Door locking
# ---------------------------------------------------------------
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
