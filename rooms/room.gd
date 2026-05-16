extends Node2D

# Room dimensions — must match RoomManager constants
const HW := 450.0
const HH := 300.0
const WT := 22.0    # wall thickness
const DH := 36.0    # door half-width

const ROOM_COLORS := {
	"start":   Color(0.30, 0.32, 0.38),
	"combat":  Color(0.07, 0.09, 0.13),
	"healing": Color(0.06, 0.14, 0.09),
	"shrine":  Color(0.07, 0.09, 0.16),
	"treasure":Color(0.14, 0.13, 0.06),
	"boss":    Color(0.14, 0.06, 0.06),
}
const WALL_COLOR := Color(0.20, 0.22, 0.28)

const EnemyScene   = preload("res://enemies/enemy.tscn")
const RangedScene  = preload("res://enemies/ranged_enemy.tscn")
const FracturePickup = preload("res://scripts/fracture_pickup.tscn")

var room_type  := "combat"
var exits      : Array[String] = []
var template_i := 0
var pre_cleared := false

var _locked_dirs: Dictionary = {}  # dir → bool
var _blockers:    Dictionary = {}  # dir → StaticBody2D
var _template:    Dictionary = {}
var _enemies_alive := 0
var _player: Node2D = null

signal room_cleared

func setup(type: String, exit_dirs: Array[String], tmpl: int, already_cleared: bool) -> void:
	room_type    = type
	exits        = exit_dirs
	template_i   = tmpl
	pre_cleared  = already_cleared

func on_enter(player: Node2D) -> void:
	_player = player
	_template = RoomManager.COMBAT_TEMPLATES[template_i]
	_build_walls()
	_build_doors()
	_build_obstacles()
	_build_special()
	queue_redraw()

	if room_type in ["combat", "boss"] and not pre_cleared:
		_lock_all()
		await get_tree().create_timer(0.3).timeout
		_spawn_enemies()
	else:
		_unlock_all()

# --- Visual ---
func _draw() -> void:
	var floor_col := ROOM_COLORS.get(room_type, ROOM_COLORS["combat"])
	draw_rect(Rect2(-HW, -HH, HW * 2, HH * 2), floor_col)

	# Grid lines
	var grid := 60
	for x in range(int(-HW), int(HW) + 1, grid):
		draw_line(Vector2(x, -HH), Vector2(x, HH), Color(1, 1, 1, 0.04), 1)
	for y in range(int(-HH), int(HH) + 1, grid):
		draw_line(Vector2(-HW, y), Vector2(HW, y), Color(1, 1, 1, 0.04), 1)

	# Walls
	_draw_wall_segments()

	# Obstacles
	for obs in _template.get("obstacles", []):
		draw_rect(Rect2(obs["pos"] - obs["size"] * 0.5, obs["size"]), WALL_COLOR)
		draw_rect(Rect2(obs["pos"] - obs["size"] * 0.5, obs["size"]), Color(1,1,1,0.06), false, 1.5)

	# Door indicators
	for dir in exits:
		var locked: bool = _locked_dirs.get(dir, false)
		var col := Color(0.85, 0.2, 0.2, 0.8) if locked else Color(0.2, 0.85, 0.45, 0.8)
		var p := _door_pos(dir)
		var is_ns := dir in ["north","south"]
		var sz := Vector2(DH * 2, WT) if is_ns else Vector2(WT, DH * 2)
		draw_rect(Rect2(p - sz * 0.5, sz), col)

	# Room type markers
	match room_type:
		"healing":
			draw_circle(Vector2.ZERO, 22, Color(0.3, 0.9, 0.4, 0.18))
			draw_circle(Vector2.ZERO, 22, Color(0.3, 0.9, 0.4, 0.4), false, 2)
		"shrine":
			for i in 6:
				var a := i * TAU / 6
				draw_circle(Vector2(cos(a), sin(a)) * 28, 5, Color(0.4, 0.5, 1.0, 0.7))
		"treasure":
			draw_rect(Rect2(-18, -14, 36, 28), Color(1, 0.85, 0.2, 0.3))
			draw_rect(Rect2(-18, -14, 36, 28), Color(1, 0.85, 0.2, 0.6), false, 2)
		"boss":
			draw_circle(Vector2.ZERO, 40, Color(0.9, 0.2, 0.1, 0.12))
		"start":
			for dir in exits:
				var p := _door_pos(dir) * 0.5
				var arrow := _dir_vec(dir) * 18
				draw_line(p, p + arrow, Color(0.6, 0.8, 1.0, 0.7), 2)

# --- Wall construction ---
func _build_walls() -> void:
	for dir in ["north","south","east","west"]:
		var segs := _wall_segs(dir, dir in exits)
		for s in segs:
			_add_wall(s[0], s[1])

func _wall_segs(dir: String, has_exit: bool) -> Array:
	match dir:
		"north":
			if has_exit:
				return [[Vector2(-(HW + DH) * 0.5, -HH + WT * 0.5), Vector2(HW - DH, WT)],
				        [Vector2( (HW + DH) * 0.5, -HH + WT * 0.5), Vector2(HW - DH, WT)]]
			return [[Vector2(0, -HH + WT * 0.5), Vector2(HW * 2, WT)]]
		"south":
			if has_exit:
				return [[Vector2(-(HW + DH) * 0.5, HH - WT * 0.5), Vector2(HW - DH, WT)],
				        [Vector2( (HW + DH) * 0.5, HH - WT * 0.5), Vector2(HW - DH, WT)]]
			return [[Vector2(0, HH - WT * 0.5), Vector2(HW * 2, WT)]]
		"east":
			if has_exit:
				return [[Vector2(HW - WT * 0.5, -(HH + DH) * 0.5), Vector2(WT, HH - DH)],
				        [Vector2(HW - WT * 0.5,  (HH + DH) * 0.5), Vector2(WT, HH - DH)]]
			return [[Vector2(HW - WT * 0.5, 0), Vector2(WT, HH * 2)]]
		"west":
			if has_exit:
				return [[Vector2(-HW + WT * 0.5, -(HH + DH) * 0.5), Vector2(WT, HH - DH)],
				        [Vector2(-HW + WT * 0.5,  (HH + DH) * 0.5), Vector2(WT, HH - DH)]]
			return [[Vector2(-HW + WT * 0.5, 0), Vector2(WT, HH * 2)]]
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

# --- Door construction ---
func _build_doors() -> void:
	for dir in exits:
		_locked_dirs[dir] = false

		# Trigger zone
		var door := Area2D.new()
		door.name = "Door_" + dir
		var dshape := CollisionShape2D.new()
		var drect  := RectangleShape2D.new()
		var is_ns := dir in ["north","south"]
		drect.size = Vector2(DH * 2, 40) if is_ns else Vector2(40, DH * 2)
		dshape.shape = drect
		door.position = _door_pos(dir)
		door.add_child(dshape)
		add_child(door)

		var d := dir  # capture for lambda
		door.body_entered.connect(func(body):
			if body.is_in_group("player") and not _locked_dirs.get(d, true):
				RoomManager.enter_door(d)
		)

		# Blocker (thin StaticBody2D in the gap — disabled when open)
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
		"east":  return Vector2( 1,0)
		"west":  return Vector2(-1,0)
	return Vector2.ZERO

# --- Obstacles ---
func _build_obstacles() -> void:
	for obs in _template.get("obstacles", []):
		_add_wall(obs["pos"], obs["size"])

# --- Special room content ---
func _build_special() -> void:
	match room_type:
		"healing":
			_add_healing_zone()
		"shrine":
			_add_shrine()
		"treasure":
			_add_treasure()

func _add_healing_zone() -> void:
	var zone := Area2D.new()
	var zs   := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 30.0
	zs.shape = circ
	zone.add_child(zs)
	add_child(zone)
	zone.body_entered.connect(func(body):
		if body.is_in_group("player") and body.health < body.max_health:
			body.health = body.max_health
			GameEvents.player_hit.emit(body.health, body.max_health)
	)

func _add_shrine() -> void:
	var zone := Area2D.new()
	var zs   := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 32.0
	zs.shape = circ
	zone.add_child(zs)
	add_child(zone)
	var used := false
	zone.body_entered.connect(func(body):
		if body.is_in_group("player") and not used:
			used = true
			var elem = randi() % 4
			FractureManager.add_fracture(elem)
	)

func _add_treasure() -> void:
	var frac := FracturePickup.instantiate()
	add_child(frac)
	frac.setup(randi() % 4, Vector2.ZERO)

# --- Enemy spawning ---
func _spawn_enemies() -> void:
	if _player == null:
		return
	var spawns: Array = _template.get("spawns", []).duplicate()
	spawns.shuffle()

	var depth := RoomManager.current_depth
	var is_boss := room_type == "boss"
	var melee := (4 + depth) if is_boss else mini(depth + 2, 7)
	var ranged := (2 + depth / 2) if is_boss else mini(depth - 1, 4)

	_enemies_alive = melee + ranged
	GameEvents.enemy_died.connect(_count_enemy_death)

	for i in melee:
		var pos := spawns[i % spawns.size()] if spawns.size() > 0 else _rand_pos()
		_spawn(EnemyScene, pos)
	for i in ranged:
		var pos := spawns[(melee + i) % spawns.size()] if spawns.size() > 0 else _rand_pos()
		_spawn(RangedScene, pos)

func _spawn(scene: PackedScene, pos: Vector2) -> void:
	var e := scene.instantiate()
	e.position = pos
	add_child(e)

func _rand_pos() -> Vector2:
	return Vector2(randf_range(-380, 380), randf_range(-240, 240))

func _count_enemy_death(_pos: Vector2, _pts: int) -> void:
	_enemies_alive -= 1
	if _enemies_alive <= 0:
		GameEvents.enemy_died.disconnect(_count_enemy_death)
		_unlock_all()
		room_cleared.emit()

# --- Door locking ---
func _lock_all() -> void:
	for dir in exits:
		_locked_dirs[dir] = true
		if _blockers.has(dir):
			_blockers[dir].disabled = false
	queue_redraw()

func _unlock_all() -> void:
	for dir in exits:
		_locked_dirs[dir] = false
		if _blockers.has(dir):
			_blockers[dir].disabled = true
	queue_redraw()
