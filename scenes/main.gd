extends Node2D

const ROOM_HALF := Vector2(900, 600)

func _ready() -> void:
	queue_redraw()
	_build_walls()

func _draw() -> void:
	draw_rect(Rect2(-ROOM_HALF, ROOM_HALF * 2), Color(0.07, 0.09, 0.13))
	var grid := 80
	for x in range(int(-ROOM_HALF.x), int(ROOM_HALF.x) + 1, grid):
		draw_line(Vector2(x, -ROOM_HALF.y), Vector2(x, ROOM_HALF.y), Color(0.11, 0.13, 0.18), 1)
	for y in range(int(-ROOM_HALF.y), int(ROOM_HALF.y) + 1, grid):
		draw_line(Vector2(-ROOM_HALF.x, y), Vector2(ROOM_HALF.x, y), Color(0.11, 0.13, 0.18), 1)
	draw_rect(Rect2(-ROOM_HALF, ROOM_HALF * 2), Color(0.5, 0.6, 1, 0.15), false, 3)

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
