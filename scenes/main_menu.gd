extends Node2D

var time       := 0.0
var hovered    := false
var particles  : Array = []

const BIOME_COLORS := [
	Color(1.0, 0.38, 0.06),  # fire
	Color(0.38, 0.70, 1.00), # frost
	Color(0.28, 0.88, 0.20), # nature
	Color(0.72, 0.38, 1.00), # storm
]

func _ready() -> void:
	FractureManager.reset()
	RoomManager.reset()
	for _i in 30:
		particles.append(_make_particle(true))
	queue_redraw()

func _make_particle(random_y := false) -> Dictionary:
	var col: Color = BIOME_COLORS[randi() % 4] as Color
	return {
		"pos":  Vector2(randf_range(0, 1280), 720 if not random_y else randf_range(0, 720)),
		"vel":  Vector2(randf_range(-10, 10), randf_range(-25, -8)),
		"size": randf_range(2, 5),
		"life": randf_range(3.0, 7.0),
		"max":  randf_range(3.0, 7.0),
		"col":  col,
	}

func _process(delta: float) -> void:
	time += delta
	var mouse := get_global_mouse_position()
	var new_hov := Rect2(340, 420, 600, 50).has_point(mouse)
	if new_hov != hovered:
		hovered = new_hov
		queue_redraw()

	var alive: Array = []
	for p in particles:
		p["life"] -= delta
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		if (p["life"] as float) > 0:
			alive.append(p)
		else:
			alive.append(_make_particle())
	particles = alive

	if fmod(time, 0.04) < delta:
		queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if hovered:
			get_tree().change_scene_to_file("res://scenes/main.tscn")

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var pulse := (sin(time * 1.6) + 1.0) * 0.5

	# Background
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.04, 0.04, 0.07))
	for x in range(0, 1281, 80):
		draw_line(Vector2(x, 0), Vector2(x, 720), Color(0.08, 0.08, 0.12), 1)
	for y in range(0, 721, 80):
		draw_line(Vector2(0, y), Vector2(1280, y), Color(0.08, 0.08, 0.12), 1)

	# Corner biome glows
	var corners := [Vector2(0,0), Vector2(1280,0), Vector2(0,720), Vector2(1280,720)]
	for i in 4:
		var c: Vector2 = corners[i] as Vector2
		var col: Color = BIOME_COLORS[i] as Color
		draw_circle(c, 220, Color(col.r, col.g, col.b, 0.06 + pulse * 0.02))

	# Atmospheric particles
	for p in particles:
		var t := clampf((p["life"] as float) / (p["max"] if (p["max"] as float) > 0 else 5.0), 0.0, 1.0)
		var a := t * (1.0 - t) * 4.0 * 0.6
		var col := p["col"] as Color
		draw_circle(p["pos"] as Vector2, p["size"] as float, Color(col.r, col.g, col.b, a))

	# Title
	var tc := Color(0.88 + pulse * 0.10, 0.88 + pulse * 0.04, 1.0)
	draw_string(font, Vector2(0, 270), "AETHERREACH", HORIZONTAL_ALIGNMENT_CENTER, 1280, 76, tc)

	# Subtitle
	draw_string(font, Vector2(0, 322), "an elemental roguelike", HORIZONTAL_ALIGNMENT_CENTER, 1280, 20,
		Color(0.46, 0.46, 0.72))

	# Lore fragment
	draw_string(font, Vector2(0, 358), "THE SPLINTERING BROKE THE WORLD INTO FOUR.", HORIZONTAL_ALIGNMENT_CENTER,
		1280, 13, Color(0.35, 0.35, 0.55))
	draw_string(font, Vector2(0, 374), "THE PRINCESSES STILL BELIEVE THEY ARE SAVING IT.", HORIZONTAL_ALIGNMENT_CENTER,
		1280, 13, Color(0.35, 0.35, 0.55))

	# Start button
	var btn := Color(0.38, 0.88, 1.0) if hovered else Color(0.55, 0.55, 0.80)
	if hovered:
		draw_rect(Rect2(340, 422, 600, 46), Color(0.38, 0.88, 1.0, 0.08))
	draw_string(font, Vector2(0, 452), "[ ENTER THE WORLD ]", HORIZONTAL_ALIGNMENT_CENTER, 1280, 28, btn)

	# Version
	draw_string(font, Vector2(1260, 712), "prototype v0.2", HORIZONTAL_ALIGNMENT_RIGHT, -1, 13,
		Color(0.28, 0.28, 0.38))
