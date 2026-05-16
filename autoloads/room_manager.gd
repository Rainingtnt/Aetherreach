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
	{
		"obstacles": [],
		"spawns": [Vector2(-320,-180),Vector2(320,-180),Vector2(-320,180),
				   Vector2(320,180),Vector2(0,-220),Vector2(0,220)],
	},
	{
		"obstacles": [{"pos":Vector2(0,0),"size":Vector2(110,110)}],
		"spawns": [Vector2(-310,-160),Vector2(310,-160),Vector2(-310,160),
				   Vector2(310,160),Vector2(370,0),Vector2(-370,0)],
	},
	{
		"obstacles": [
			{"pos":Vector2(-210,-120),"size":Vector2(70,70)},
			{"pos":Vector2( 210,-120),"size":Vector2(70,70)},
			{"pos":Vector2(-210, 120),"size":Vector2(70,70)},
			{"pos":Vector2( 210, 120),"size":Vector2(70,70)},
		],
		"spawns": [Vector2(0,-220),Vector2(0,220),Vector2(-380,0),Vector2(380,0),Vector2(0,0)],
	},
	{
		"obstacles": [
			{"pos":Vector2(-160,0),"size":Vector2(55,220)},
			{"pos":Vector2( 160,0),"size":Vector2(55,220)},
		],
		"spawns": [Vector2(-360,-180),Vector2(360,-180),Vector2(-360,180),
				   Vector2(360,180),Vector2(0,-240),Vector2(0,240)],
	},
	{
		"obstacles": [
			{"pos":Vector2(0,-140),"size":Vector2(200,50)},
			{"pos":Vector2(0, 140),"size":Vector2(200,50)},
		],
		"spawns": [Vector2(-350,-50),Vector2(350,-50),Vector2(-350,50),
				   Vector2(350,50),Vector2(0,0)],
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
	var target := 10 + randi() % 6

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
			var type: String = _pick_type(abs(npos.x) + abs(npos.y))
			var opp_dir: String = OPP[dir] as String
			var data: Dictionary = _make_room(type, [opp_dir])
			world[pos]["exits"].append(dir)
			world[npos] = data
			frontier.append(npos)
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

func _make_room(type: String, exits: Array) -> Dictionary:
	return {
		"type": type,
		"exits": exits,
		"cleared": type != "combat" and type != "boss",
		"template": randi() % COMBAT_TEMPLATES.size(),
	}

func _pick_type(depth: int) -> String:
	if depth <= 1:
		return "combat"
	var r := randf()
	if r < 0.55: return "combat"
	if r < 0.70: return "healing"
	if r < 0.82: return "shrine"
	return "treasure"

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
	world[pos]["cleared"] = true

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
