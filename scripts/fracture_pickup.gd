extends Area2D

var element := FractureManager.Element.FIRE
var base_y := 0.0
var float_time := 0.0
var lifetime := 12.0

func setup(elem: int, pos: Vector2) -> void:
	element = elem
	position = pos
	base_y = pos.y
	queue_redraw()

func _process(delta: float) -> void:
	float_time += delta
	lifetime -= delta
	position.y = base_y + sin(float_time * 3.2) * 5.0
	queue_redraw()
	if lifetime <= 0:
		queue_free()

func _draw() -> void:
	var col := FractureManager.ELEMENT_COLORS[element]
	var pulse := (sin(float_time * 5.0) + 1.0) * 0.5
	var r := 9.0 + pulse * 3.0
	draw_circle(Vector2.ZERO, r, col)
	draw_circle(Vector2.ZERO, r * 0.5, Color.WHITE.lerp(col, 0.4))
	var name_initial := FractureManager.ELEMENT_NAMES[element][0]
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-4, 5), name_initial, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		FractureManager.add_fracture(element)
		queue_free()
