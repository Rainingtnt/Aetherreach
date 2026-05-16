extends Node2D

var current_health := 5
var max_health := 5
var score_label: Label
var wave_label: Label

func _ready() -> void:
	GameEvents.player_hit.connect(func(h, m): current_health = h; max_health = m; queue_redraw())
	GameEvents.score_changed.connect(func(s): score_label.text = "SCORE  %d" % s)
	GameEvents.wave_started.connect(func(w): wave_label.text = "WAVE  %d" % w)

	score_label = _make_label(Vector2(980, 10), HORIZONTAL_ALIGNMENT_RIGHT, 290)
	score_label.text = "SCORE  0"
	add_child(score_label)

	wave_label = _make_label(Vector2(14, 693))
	wave_label.text = "WAVE  1"
	add_child(wave_label)

	queue_redraw()

func _make_label(pos: Vector2, align := HORIZONTAL_ALIGNMENT_LEFT, min_width := 0) -> Label:
	var lbl := Label.new()
	lbl.position = pos
	lbl.horizontal_alignment = align
	if min_width > 0:
		lbl.custom_minimum_size = Vector2(min_width, 30)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	return lbl

func _draw() -> void:
	for i in max_health:
		var col = Color(1, 0.28, 0.38) if i < current_health else Color(0.18, 0.18, 0.22)
		draw_circle(Vector2(20 + i * 28, 20), 10, col)
		if i < current_health:
			draw_circle(Vector2(20 + i * 28, 20), 5, Color(1, 0.65, 0.72))
