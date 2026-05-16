extends Node2D

var time := 0.0
var start_hovered := false

func _ready() -> void:
	FractureManager.reset()
	RoomManager.reset()
	queue_redraw()

func _process(delta: float) -> void:
	time += delta
	var mouse := get_global_mouse_position()
	var was_hovered := start_hovered
	start_hovered = Rect2(340, 420, 600, 50).has_point(mouse)
	if start_hovered != was_hovered or time < 0.1:
		queue_redraw()
	if fmod(time, 1.0) < delta * 2:
		queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if start_hovered:
			get_tree().change_scene_to_file("res://scenes/main.tscn")

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var pulse := (sin(time * 1.8) + 1.0) * 0.5

	draw_rect(Rect2(0, 0, 1280, 720), Color(0.05, 0.05, 0.08))
	for x in range(0, 1281, 80):
		draw_line(Vector2(x, 0), Vector2(x, 720), Color(0.09, 0.1, 0.14), 1)
	for y in range(0, 721, 80):
		draw_line(Vector2(0, y), Vector2(1280, y), Color(0.09, 0.1, 0.14), 1)

	var title_col := Color(0.82 + pulse * 0.12, 0.82 + pulse * 0.06, 1.0)
	draw_string(font, Vector2(0, 278), "AETHERREACH", HORIZONTAL_ALIGNMENT_CENTER, 1280, 74, title_col)

	draw_string(font, Vector2(0, 330), "an elemental roguelike", HORIZONTAL_ALIGNMENT_CENTER, 1280, 20, Color(0.48, 0.48, 0.72))

	var btn_col := Color(0.4, 0.85, 1.0) if start_hovered else Color(0.58, 0.58, 0.82)
	draw_string(font, Vector2(0, 448), "[ ENTER THE WORLD ]", HORIZONTAL_ALIGNMENT_CENTER, 1280, 28, btn_col)

	draw_string(font, Vector2(1260, 712), "prototype v0.1", HORIZONTAL_ALIGNMENT_RIGHT, -1, 13, Color(0.28, 0.28, 0.36))
