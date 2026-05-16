extends Node2D

const ROOM_HALF := Vector2(900, 600)

const EnemyScene = preload("res://enemies/enemy.tscn")
const RangedScene = preload("res://enemies/ranged_enemy.tscn")
const HUDScript = preload("res://ui/hud.gd")

var wave := 0
var score := 0
var alive_count := 0
var wave_active := false

func _ready() -> void:
	queue_redraw()
	_build_walls()
	_setup_hud()
	GameEvents.enemy_died.connect(_on_enemy_died)
	await get_tree().process_frame
	_start_wave()

func _draw() -> void:
	draw_rect(Rect2(-ROOM_HALF, ROOM_HALF * 2), Color(0.07, 0.09, 0.13))
	var grid := 80
	for x in range(int(-ROOM_HALF.x), int(ROOM_HALF.x) + 1, grid):
		draw_line(Vector2(x, -ROOM_HALF.y), Vector2(x, ROOM_HALF.y), Color(0.11, 0.13, 0.18), 1)
	for y in range(int(-ROOM_HALF.y), int(ROOM_HALF.y) + 1, grid):
		draw_line(Vector2(-ROOM_HALF.x, y), Vector2(ROOM_HALF.x, y), Color(0.11, 0.13, 0.18), 1)
	draw_rect(Rect2(-ROOM_HALF, ROOM_HALF * 2), Color(0.5, 0.6, 1, 0.12), false, 3)

func _setup_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var hud := HUDScript.new()
	canvas.add_child(hud)

func _build_walls() -> void:
	var w := 60.0
	var defs := [
		[Vector2(0, -ROOM_HALF.y - w * 0.5), Vector2(ROOM_HALF.x * 2 + w * 2, w)],
		[Vector2(0,  ROOM_HALF.y + w * 0.5), Vector2(ROOM_HALF.x * 2 + w * 2, w)],
		[Vector2(-ROOM_HALF.x - w * 0.5, 0), Vector2(w, ROOM_HALF.y * 2)],
		[Vector2( ROOM_HALF.x + w * 0.5, 0), Vector2(w, ROOM_HALF.y * 2)],
	]
	for d in defs:
		var body := StaticBody2D.new()
		var cshape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = d[1]
		cshape.shape = rect
		body.position = d[0]
		body.add_child(cshape)
		add_child(body)

func _start_wave() -> void:
	wave += 1
	wave_active = true
	var melee_count := mini(wave + 2, 10)
	var ranged_count := mini(wave - 1, 5)
	alive_count = melee_count + ranged_count
	GameEvents.wave_started.emit(wave)

	for _i in melee_count:
		_spawn(_get_spawn_pos(), EnemyScene)
	for _i in ranged_count:
		_spawn(_get_spawn_pos(), RangedScene)

func _spawn(pos: Vector2, scene: PackedScene) -> void:
	var e = scene.instantiate()
	e.position = pos
	add_child(e)

func _get_spawn_pos() -> Vector2:
	var player_pos = $Player.global_position
	for _attempt in 20:
		var pos := Vector2(
			randf_range(-ROOM_HALF.x + 60, ROOM_HALF.x - 60),
			randf_range(-ROOM_HALF.y + 60, ROOM_HALF.y - 60)
		)
		if pos.distance_to(player_pos) > 220:
			return pos
	return Vector2(randf_range(-300, 300), randf_range(-300, 300))

func _on_enemy_died(_pos: Vector2, points: int) -> void:
	score += points
	alive_count -= 1
	GameEvents.score_changed.emit(score)
	if alive_count <= 0 and wave_active:
		wave_active = false
		await get_tree().create_timer(1.8).timeout
		_start_wave()
