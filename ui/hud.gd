extends Node2D

var current_health := 5
var max_health := 5
var score_label: Label
var wave_label: Label

var wave_announce_text := ""
var wave_announce_timer := 0.0
const WAVE_ANNOUNCE_DURATION := 2.5

func _ready() -> void:
	GameEvents.player_hit.connect(func(h, m): current_health = h; max_health = m; queue_redraw())
	GameEvents.score_changed.connect(func(s): score_label.text = "SCORE  %d" % s)
	GameEvents.wave_started.connect(_on_wave_started)
	FractureManager.fractures_changed.connect(func(): queue_redraw())

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

func _on_wave_started(w: int) -> void:
	wave_label.text = "WAVE  %d" % w
	wave_announce_text = "WAVE  %d" % w
	wave_announce_timer = WAVE_ANNOUNCE_DURATION
	queue_redraw()

func _process(delta: float) -> void:
	if wave_announce_timer > 0:
		wave_announce_timer -= delta
		queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font

	# Hearts
	for i in max_health:
		var col = Color(1, 0.28, 0.38) if i < current_health else Color(0.18, 0.18, 0.22)
		draw_circle(Vector2(20 + i * 28, 20), 10, col)
		if i < current_health:
			draw_circle(Vector2(20 + i * 28, 20), 5, Color(1, 0.65, 0.72))

	# Fractures
	var fracs := FractureManager.active_fractures
	var frac_start_x := 640.0 - (fracs.size() - 1) * 22.0
	for i in fracs.size():
		var elem := fracs[i]
		var col := FractureManager.ELEMENT_COLORS[elem]
		var cx := frac_start_x + i * 44.0
		draw_circle(Vector2(cx, 695), 13, col)
		draw_circle(Vector2(cx, 695), 7, Color.WHITE.lerp(col, 0.35))
		draw_string(font, Vector2(cx - 4, 700), FractureManager.ELEMENT_NAMES[elem][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

	# Synergy name
	var synergy := FractureManager.get_synergy()
	if synergy != "":
		draw_string(font, Vector2(0, 672), synergy, HORIZONTAL_ALIGNMENT_CENTER, 1280, 13, Color(1, 0.88, 0.4))

	# Wave announcement
	if wave_announce_timer > 0:
		var t := wave_announce_timer / WAVE_ANNOUNCE_DURATION
		var alpha := 4.0 * t * (1.0 - t)
		draw_string(font, Vector2(0, 375), wave_announce_text, HORIZONTAL_ALIGNMENT_CENTER, 1280, 52, Color(1, 0.88, 0.3, alpha))
