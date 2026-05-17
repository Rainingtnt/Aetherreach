extends Node

const HW := 450.0
const HH := 300.0

const DIRS: Dictionary = {
	"north": Vector2i(0, -1), "south": Vector2i(0,  1),
	"east":  Vector2i(1,  0), "west":  Vector2i(-1, 0),
}
const OPP: Dictionary = {
	"north": "south", "south": "north", "east": "west", "west": "east"
}
const ENTRY_SPAWN: Dictionary = {
	"north": Vector2(0,  220),
	"south": Vector2(0, -220),
	"east":  Vector2(-380, 0),
	"west":  Vector2( 380, 0),
}

const COMBAT_TEMPLATES: Array = [
	# 0 — Open arena
	{
		"obstacles": [],
		"spawns": [Vector2(-320,-180),Vector2(320,-180),Vector2(-320,180),
				   Vector2(320,180),Vector2(0,-220),Vector2(0,220)],
	},
	# 1 — Central block
	{
		"obstacles": [{"pos":Vector2(0,0),"size":Vector2(110,110)}],
		"spawns": [Vector2(-310,-160),Vector2(310,-160),Vector2(-310,160),
				   Vector2(310,160),Vector2(370,0),Vector2(-370,0)],
	},
	# 2 — Four corner pillars
	{
		"obstacles": [
			{"pos":Vector2(-210,-120),"size":Vector2(70,70)},
			{"pos":Vector2( 210,-120),"size":Vector2(70,70)},
			{"pos":Vector2(-210, 120),"size":Vector2(70,70)},
			{"pos":Vector2( 210, 120),"size":Vector2(70,70)},
		],
		"spawns": [Vector2(0,-220),Vector2(0,220),Vector2(-380,0),Vector2(380,0),Vector2(0,0)],
	},
	# 3 — Two vertical walls (side corridors)
	{
		"obstacles": [
			{"pos":Vector2(-160,0),"size":Vector2(55,220)},
			{"pos":Vector2( 160,0),"size":Vector2(55,220)},
		],
		"spawns": [Vector2(-360,-180),Vector2(360,-180),Vector2(-360,180),
				   Vector2(360,180),Vector2(0,-240),Vector2(0,240)],
	},
	# 4 — Two horizontal walls (top/bottom corridors)
	{
		"obstacles": [
			{"pos":Vector2(0,-140),"size":Vector2(200,50)},
			{"pos":Vector2(0, 140),"size":Vector2(200,50)},
		],
		"spawns": [Vector2(-350,-50),Vector2(350,-50),Vector2(-350,50),
				   Vector2(350,50),Vector2(0,0)],
	},
	# 5 — L-shaped wall
	{
		"obstacles": [
			{"pos":Vector2(-80,-60),"size":Vector2(180,55)},
			{"pos":Vector2(-80, 40),"size":Vector2(55,110)},
		],
		"spawns": [Vector2(250,-180),Vector2(300,80),Vector2(-320,200),
				   Vector2(-320,-200),Vector2(200,200),Vector2(0,-220)],
	},
	# 6 — Scattered rubble (many small pillars)
	{
		"obstacles": [
			{"pos":Vector2(-240,-100),"size":Vector2(50,50)},
			{"pos":Vector2(240,-100), "size":Vector2(50,50)},
			{"pos":Vector2(0,-100),   "size":Vector2(50,50)},
			{"pos":Vector2(-240, 100),"size":Vector2(50,50)},
			{"pos":Vector2(240, 100), "size":Vector2(50,50)},
			{"pos":Vector2(0, 100),   "size":Vector2(50,50)},
		],
		"spawns": [Vector2(-340,-200),Vector2(340,-200),Vector2(-340,200),
				   Vector2(340,200),Vector2(-180,0),Vector2(180,0)],
	},
	# 7 — T-junction obstacle
	{
		"obstacles": [
			{"pos":Vector2(0,-80),"size":Vector2(280,55)},
			{"pos":Vector2(0, 50),"size":Vector2(55,140)},
		],
		"spawns": [Vector2(-340,-200),Vector2(340,-200),Vector2(-340,150),
				   Vector2(340,150),Vector2(-200,-80 + 100),Vector2(200,-80 + 100)],
	},
	# 8 — Central ring of pillars
	{
		"obstacles": [
			{"pos":Vector2( 140, 0),"size":Vector2(55,55)},
			{"pos":Vector2(-140, 0),"size":Vector2(55,55)},
			{"pos":Vector2(0, 110),"size":Vector2(55,55)},
			{"pos":Vector2(0,-110),"size":Vector2(55,55)},
		],
		"spawns": [Vector2(-350,-200),Vector2(350,-200),Vector2(-350,200),
				   Vector2(350,200),Vector2(0,0)],
	},
	# 9 — Fortress: outer ring + center safe zone
	{
		"obstacles": [
			{"pos":Vector2(-280,-160),"size":Vector2(80,80)},
			{"pos":Vector2( 280,-160),"size":Vector2(80,80)},
			{"pos":Vector2(-280, 160),"size":Vector2(80,80)},
			{"pos":Vector2( 280, 160),"size":Vector2(80,80)},
			{"pos":Vector2(0,0),      "size":Vector2(90,90)},
		],
		"spawns": [Vector2(-380,0),Vector2(380,0),Vector2(0,-255),
				   Vector2(0,255),Vector2(-200,-100),Vector2(200,100)],
	},
]

var world: Dictionary = {}
var visited: Dictionary = {}
var current_pos := Vector2i.ZERO
var current_depth := 0
var total_score := 0

var _world_container: Node2D = null
var _player: Node2D = null
var _fade_rect: ColorRect = null
var _current_room: Node2D = null
var _transitioning := false

signal room_loaded(pos: Vector2i, room_type: String, depth: int)

func initialize(container: Node2D, player: Node2D, fade: ColorRect) -> void:
	_world_container = container
	_player = player
	_fade_rect = fade
	GameEvents.enemy_died.connect(_on_enemy_died)
	_generate_world()
	visited[Vector2i.ZERO] = true
	_swap_room(Vector2i.ZERO, "")

func _generate_world() -> void:
	world.clear()
	world[Vector2i.ZERO] = _make_room("start", [])
	var frontier: Array[Vector2i] = [Vector2i.ZERO]
	var target := 12 + randi() % 6

	for _i in target:
		if frontier.is_empty():
			break
		var pos: Vector2i = frontier[randi() % frontier.size()]
		var dirs: Array = DIRS.keys()
		dirs.shuffle()
		for dir in dirs:
			var npos: Vector2i = pos + (DIRS[dir] as Vector2i)
			if world.has(npos):
				continue
			var depth: int = abs(npos.x) + abs(npos.y)
			var type: String = _pick_type(depth)
			var opp_dir: String = OPP[dir] as String
			var data: Dictionary = _make_room(type, [opp_dir])
			world[pos]["exits"].append(dir)
			world[npos] = data
			frontier.append(npos)
			break

	# Guarantee at least one healing room in first 4 depths
	var has_early_heal := false
	for raw_pos in world:
		var p := raw_pos as Vector2i
		var d: int = abs(p.x) + abs(p.y)
		if d <= 4 and (world[raw_pos] as Dictionary)["type"] == "healing":
			has_early_heal = true
			break
	if not has_early_heal:
		# Convert a random depth-2 or depth-3 combat room to healing
		for raw_pos in world:
			var p := raw_pos as Vector2i
			var d: int = abs(p.x) + abs(p.y)
			if d in [2, 3] and (world[raw_pos] as Dictionary)["type"] == "combat":
				world[raw_pos]["type"] = "healing"
				world[raw_pos]["cleared"] = true
				break

	# Deepest room becomes boss
	var boss_pos := Vector2i.ZERO
	var max_d := 0
	for raw_pos in world:
		var p := raw_pos as Vector2i
		var d: int = abs(p.x) + abs(p.y)
		if d > max_d:
			max_d = d
			boss_pos = p
	if boss_pos != Vector2i.ZERO:
		world[boss_pos]["type"] = "boss"
		world[boss_pos]["cleared"] = false

	# Mark elite rooms at depth 5+ (harder combat, better loot)
	for raw_pos in world:
		var p := raw_pos as Vector2i
		var d: int = abs(p.x) + abs(p.y)
		var data := world[raw_pos] as Dictionary
		if d >= 5 and (data["type"] as String) == "combat" and randf() < 0.28:
			data["type"] = "elite"
			data["cleared"] = false

func _make_room(type: String, exits: Array) -> Dictionary:
	return {
		"type": type,
		"exits": exits,
		"cleared": type not in ["combat", "boss", "elite"],
		"template": randi() % COMBAT_TEMPLATES.size(),
	}

func get_cleared(pos: Vector2i) -> bool:
	if world.has(pos):
		return (world[pos] as Dictionary).get("cleared", true) as bool
	return true

func _pick_type(depth: int) -> String:
	if depth <= 1:
		return "combat"
	var r := randf()
	if depth >= 3:
		if r < 0.44: return "combat"
		if r < 0.57: return "healing"
		if r < 0.68: return "shrine"
		if r < 0.80: return "treasure"
		if r < 0.90: return "event"
		return "combat"
	if r < 0.50: return "combat"
	if r < 0.65: return "healing"
	if r < 0.77: return "shrine"
	if r < 0.90: return "treasure"
	return "combat"

func enter_door(direction: String) -> void:
	if _transitioning:
		return
	var npos: Vector2i = current_pos + (DIRS[direction] as Vector2i)
	if not world.has(npos):
		return
	_transitioning = true
	_player.can_move = false
	var tween := _fade_rect.create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 1.0, 0.18)
	tween.tween_callback(func():
		visited[npos] = true
		_swap_room(npos, direction)
	)
	tween.tween_property(_fade_rect, "modulate:a", 0.0, 0.18)
	tween.tween_callback(func():
		_player.can_move = true
		_transitioning = false
	)

func _swap_room(pos: Vector2i, came_from_dir: String) -> void:
	current_pos = pos
	current_depth = abs(pos.x) + abs(pos.y)

	if _current_room != null:
		_current_room.queue_free()
		_current_room = null

	var data: Dictionary = world[pos]
	var RoomClass = load("res://rooms/room.gd")
	var room: Node2D = RoomClass.new()
	_world_container.add_child(room)
	_current_room = room
	room.setup(data["type"] as String, data["exits"] as Array, data["template"] as int, data["cleared"] as bool)

	if came_from_dir != "":
		_player.global_position = ENTRY_SPAWN[came_from_dir] as Vector2
	else:
		_player.global_position = Vector2.ZERO

	var cam: Camera2D = _player.get_node("Camera2D")
	cam.limit_left   = int(-HW)
	cam.limit_top    = int(-HH)
	cam.limit_right  = int( HW)
	cam.limit_bottom = int( HH)

	room.on_enter(_player)
	room.room_cleared.connect(func(): _on_room_cleared(pos))
	room_loaded.emit(pos, data["type"] as String, current_depth)

func _on_room_cleared(pos: Vector2i) -> void:
	if world.has(pos):
		world[pos]["cleared"] = true
	GameEvents.room_cleared_event.emit()

func _on_enemy_died(_pos: Vector2, points: int) -> void:
	total_score += points
	GameEvents.score_changed.emit(total_score)

func reset() -> void:
	world.clear()
	visited.clear()
	total_score = 0
	current_pos = Vector2i.ZERO
	current_depth = 0
	if _current_room != null:
		_current_room.queue_free()
		_current_room = null
