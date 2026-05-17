extends Node2D

# Floating atmospheric particles tinted to the current biome.
# Added as a child of each room on enter.

const MAX_PARTICLES := 28
const ROOM_HW := 430.0
const ROOM_HH := 270.0

var _col := Color.WHITE
var _particles: Array = []
var _spawn_t := 0.0

func setup(color: Color) -> void:
	_col = color
	# Pre-populate room so it doesn't start empty
	for _i in MAX_PARTICLES:
		_particles.append(_make_particle(true))

func _make_particle(random_y := false) -> Dictionary:
	return {
		"pos":   Vector2(randf_range(-ROOM_HW, ROOM_HW),
		                 randf_range(-ROOM_HH, ROOM_HH) if random_y else ROOM_HH),
		"vel":   Vector2(randf_range(-12, 12), randf_range(-28, -8)),
		"size":  randf_range(1.8, 4.5),
		"life":  randf_range(2.5, 5.5),
		"max_life": 0.0,  # filled below
		"wobble": randf_range(0, TAU),
	}

func _ready() -> void:
	for p in _particles:
		p["max_life"] = p["life"]
	queue_redraw()

func _process(delta: float) -> void:
	_spawn_t -= delta
	if _spawn_t <= 0 and _particles.size() < MAX_PARTICLES:
		_spawn_t = 0.35
		var p := _make_particle()
		p["max_life"] = p["life"]
		_particles.append(p)

	var alive: Array = []
	for p in _particles:
		p["life"] -= delta
		p["wobble"] += delta * 1.2
		p["pos"] += (p["vel"] as Vector2) * delta
		p["pos"] = Vector2(
			(p["pos"] as Vector2).x + cos(p["wobble"] as float) * 0.4,
			(p["pos"] as Vector2).y
		)
		if (p["life"] as float) > 0:
			alive.append(p)
	_particles = alive
	queue_redraw()

func _draw() -> void:
	for p in _particles:
		var t := clampf((p["life"] as float) / (p["max_life"] as float), 0.0, 1.0)
		var alpha := t * (1.0 - t) * 4.0 * 0.55
		draw_circle(p["pos"] as Vector2, p["size"] as float,
			Color(_col.r, _col.g, _col.b, alpha))
