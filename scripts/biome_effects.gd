extends Node2D

# Per-biome animated atmosphere: particles, lighting pulses, and special FX.
# setup() called once; _process drives animation; _draw renders everything.

const HW := 430.0
const HH := 270.0

var _fx_type: String  = "embers"
var _pcol:    Color   = Color.WHITE
var _acol:    Color   = Color.WHITE
var _gcol:    Color   = Color.WHITE
var _t:       float   = 0.0
var _flash_t: float   = 0.0   # lightning flash countdown

var _particles: Array = []
var _flicker: Array = []         # initialized in _ready
var _torch_positions: Array = [] # initialized in setup

func _ready() -> void:
	for _i in 4:
		_flicker.append({"phase": randf() * TAU, "speed": randf_range(3.5, 6.0)})

func setup(biome: Dictionary) -> void:
	_fx_type = biome.get("fx_type", "embers") as String
	_pcol    = biome.get("particle", Color(1, 0.5, 0.1)) as Color
	_acol    = biome.get("accent",   Color(1, 0.4, 0.1)) as Color
	_gcol    = biome.get("glow",     Color(1, 0.5, 0.1, 0.1)) as Color
	_spawn_initial()
	# Match torch positions to what room.gd draws
	_torch_positions = [
		Vector2(randf_range(-120, 120), -HH + 12),
		Vector2(randf_range(-120, 120),  HH - 12),
		Vector2(-HW + 12, randf_range(-80, 80)),
		Vector2( HW - 12, randf_range(-80, 80)),
	]

func _spawn_initial() -> void:
	_particles.clear()
	var count := 32
	for _i in count:
		_particles.append(_make_particle(true))

func _make_particle(scatter: bool) -> Dictionary:
	var p := {}
	match _fx_type:
		"embers":
			p = {
				"pos":   Vector2(randf_range(-HW, HW),
				                 randf_range(-HH, HH) if scatter else HH),
				"vel":   Vector2(randf_range(-8, 8), randf_range(-30, -10)),
				"size":  randf_range(1.5, 3.5),
				"life":  randf_range(2.0, 5.0),
				"max_life": 0.0,
				"wobble": randf() * TAU,
				"glow":  randf() > 0.6,
			}
		"snow":
			p = {
				"pos":   Vector2(randf_range(-HW, HW),
				                 randf_range(-HH, HH) if scatter else -HH),
				"vel":   Vector2(randf_range(-6, 6), randf_range(8, 22)),
				"size":  randf_range(1.8, 4.0),
				"life":  randf_range(3.0, 7.0),
				"max_life": 0.0,
				"wobble": randf() * TAU,
				"glow":  false,
			}
		"spores":
			p = {
				"pos":   Vector2(randf_range(-HW, HW),
				                 randf_range(-HH, HH) if scatter else HH * 0.5),
				"vel":   Vector2(randf_range(-5, 5), randf_range(-12, -3)),
				"size":  randf_range(2.5, 5.0),
				"life":  randf_range(4.0, 8.0),
				"max_life": 0.0,
				"wobble": randf() * TAU,
				"wobble_spd": randf_range(0.8, 2.2),
				"glow":  randf() > 0.5,
			}
		"lightning":
			p = {
				"pos":   Vector2(randf_range(-HW, HW),
				                 randf_range(-HH, HH)),
				"vel":   Vector2(randf_range(-15, 15), randf_range(-15, 15)),
				"size":  randf_range(1.2, 2.8),
				"life":  randf_range(0.5, 2.0),
				"max_life": 0.0,
				"wobble": randf() * TAU,
				"glow":  true,
			}
	p["max_life"] = p["life"]
	return p

func _process(delta: float) -> void:
	_t += delta

	# Torch flicker update
	for fl in _flicker:
		fl["phase"] = (fl["phase"] as float) + delta * (fl["speed"] as float)

	# Lightning: schedule random flashes
	if _fx_type == "lightning":
		_flash_t -= delta
		if _flash_t <= 0:
			_flash_t = randf_range(3.0, 8.0)
			_trigger_lightning_flash()

	# Particle update
	var alive: Array = []
	for p in _particles:
		p["life"] = (p["life"] as float) - delta
		p["wobble"] = (p["wobble"] as float) + delta * 1.5
		var vel := p["vel"] as Vector2
		var pos := p["pos"] as Vector2
		match _fx_type:
			"embers":
				pos += vel * delta
				pos.x += cos(p["wobble"] as float) * 0.6
			"snow":
				pos += vel * delta
				pos.x += sin((p["wobble"] as float) * 0.7) * 0.5
			"spores":
				var ws := p.get("wobble_spd", 1.5) as float
				pos += vel * delta
				pos.x += cos((p["wobble"] as float) * ws) * 0.9
				pos.y += sin((p["wobble"] as float) * ws * 0.5) * 0.4
			"lightning":
				pos += vel * delta
		p["pos"] = pos
		if (p["life"] as float) > 0:
			alive.append(p)
	_particles = alive

	# Respawn
	var max_p := 40
	while _particles.size() < max_p:
		_particles.append(_make_particle(false))

	queue_redraw()

func _trigger_lightning_flash() -> void:
	# Brief bright overlay — handled via a short-lived modulate on parent? No,
	# we just draw a flash rect this frame using a timer-driven bool.
	_flash_t = randf_range(3.0, 8.0)
	# Draw a white flash rect for one frame via a dedicated var
	var flash_node := ColorRect.new()
	flash_node.color = Color(_acol.r, _acol.g, _acol.b, 0.08)
	flash_node.size = Vector2(HW * 2, HH * 2)
	flash_node.position = Vector2(-HW, -HH)
	add_child(flash_node)
	get_tree().create_timer(0.07).timeout.connect(func(): if is_instance_valid(flash_node): flash_node.queue_free())

func _draw() -> void:
	# Biome-specific lighting effects
	match _fx_type:
		"embers":   _draw_embers()
		"snow":     _draw_snow()
		"spores":   _draw_spores()
		"lightning": _draw_lightning()

func _draw_embers() -> void:
	# Torch glow flicker at wall positions
	for i in mini(_flicker.size(), _torch_positions.size()):
		var fl := _flicker[i] as Dictionary
		var tp := _torch_positions[i] as Vector2
		var flicker_alpha := 0.06 + sin(fl["phase"] as float) * 0.035
		var flicker_r := 28.0 + sin((fl["phase"] as float) * 1.3) * 6.0
		draw_circle(tp, flicker_r, Color(_pcol.r, _pcol.g * 0.6, 0.02, flicker_alpha))
		# Bright inner flicker
		draw_circle(tp, flicker_r * 0.4, Color(1.0, 0.75, 0.2, flicker_alpha * 2.2))

	# Ember particles
	for p in _particles:
		var life := p["life"] as float
		var max_l := p["max_life"] as float
		var t := clampf(life / max_l, 0.0, 1.0)
		var alpha := t * (1.0 - t) * 4.0 * 0.7
		var pos := p["pos"] as Vector2
		var sz  := p["size"] as float
		if p["glow"] as bool:
			draw_circle(pos, sz * 2.2, Color(_pcol.r, _pcol.g * 0.5, 0.04, alpha * 0.35))
		draw_circle(pos, sz, Color(_pcol.r, _pcol.g, _pcol.b * 0.2, alpha))
		# Hot core
		draw_circle(pos, sz * 0.45, Color(1.0, 0.90, 0.5, alpha * 0.9))

	# Floor heat shimmer — horizontal bands
	var shimmer := sin(_t * 2.2) * 0.018
	draw_rect(Rect2(-HW, HH * 0.6, HW * 2, HH * 0.4),
		Color(_gcol.r, _gcol.g, _gcol.b, 0.04 + shimmer), false, 0)

func _draw_snow() -> void:
	# Crystal wall glows
	for i in _torch_positions.size():
		var tp := _torch_positions[i] as Vector2
		var pulse := 0.06 + sin(_t * 1.2 + float(i) * 1.5) * 0.025
		draw_circle(tp, 22, Color(_pcol.r, _pcol.g, _pcol.b, pulse))
		draw_circle(tp, 10, Color(1.0, 1.0, 1.0, pulse * 1.5))

	# Snowflakes
	for p in _particles:
		var life := p["life"] as float
		var max_l := p["max_life"] as float
		var t := clampf(life / max_l, 0.0, 1.0)
		var alpha := t * 0.75
		var pos := p["pos"] as Vector2
		var sz  := p["size"] as float
		# Six-point snowflake approximation
		draw_circle(pos, sz, Color(_pcol.r, _pcol.g, _pcol.b, alpha))
		for arm in 3:
			var a := float(arm) * PI / 3.0
			draw_line(pos - Vector2(cos(a), sin(a)) * sz * 2.2,
			          pos + Vector2(cos(a), sin(a)) * sz * 2.2,
			          Color(1, 1, 1, alpha * 0.6), 0.7)

	# Floor frost accumulation
	draw_rect(Rect2(-HW, HH * 0.7, HW * 2, HH * 0.3),
		Color(_gcol.r, _gcol.g, _gcol.b, 0.05 + sin(_t * 0.4) * 0.01))

func _draw_spores() -> void:
	# Mushroom/crystal glow
	for i in _torch_positions.size():
		var tp := _torch_positions[i] as Vector2
		var pulse := 0.07 + sin(_t * 1.8 + float(i) * 2.0) * 0.03
		draw_circle(tp, 20, Color(_pcol.r, _pcol.g, _pcol.b, pulse))

	# Floating spores
	for p in _particles:
		var life := p["life"] as float
		var max_l := p["max_life"] as float
		var t := clampf(life / max_l, 0.0, 1.0)
		var alpha := sin(t * PI) * 0.65
		var pos := p["pos"] as Vector2
		var sz  := p["size"] as float
		if p["glow"] as bool:
			draw_circle(pos, sz * 2.5, Color(_pcol.r, _pcol.g, _pcol.b, alpha * 0.25))
		draw_circle(pos, sz, Color(_pcol.r, _pcol.g, _pcol.b, alpha))
		# Bright spore center
		draw_circle(pos, sz * 0.4, Color(1, 1, 0.8, alpha * 0.8))

	# Ground fog wisps
	var fog := 0.04 + sin(_t * 0.6) * 0.015
	draw_rect(Rect2(-HW, HH * 0.55, HW * 2, HH * 0.45),
		Color(_gcol.r, _gcol.g, _gcol.b, fog))
	draw_rect(Rect2(-HW, HH * 0.65, HW * 2, HH * 0.35),
		Color(_gcol.r, _gcol.g, _gcol.b, fog * 1.5))

func _draw_lightning() -> void:
	# Electric coil glow
	for i in _torch_positions.size():
		var tp := _torch_positions[i] as Vector2
		var buzz := sin(_t * 18.0 + float(i) * 3.3) * 0.5 + 0.5
		draw_circle(tp, 18, Color(_pcol.r, _pcol.g, _pcol.b, 0.04 + buzz * 0.04))
		draw_circle(tp, 8, Color(1, 1, 1, 0.06 + buzz * 0.08))

	# Electric sparks
	for p in _particles:
		var life := p["life"] as float
		var max_l := p["max_life"] as float
		var t := clampf(life / max_l, 0.0, 1.0)
		var alpha := t * 0.85
		var pos := p["pos"] as Vector2
		var sz  := p["size"] as float
		draw_circle(pos, sz * 1.8, Color(_pcol.r, _pcol.g, _pcol.b, alpha * 0.3))
		draw_circle(pos, sz, Color(_pcol.r, _pcol.g, _pcol.b, alpha))
		draw_circle(pos, sz * 0.4, Color(1, 1, 1, alpha))

	# Random arc between particles (when there are enough)
	if _particles.size() >= 2 and sin(_t * 12.0) > 0.92:
		var a := _particles[randi() % _particles.size()]
		var b := _particles[randi() % _particles.size()]
		var pa := a["pos"] as Vector2
		var pb := b["pos"] as Vector2
		if pa.distance_to(pb) < 180:
			var mid := (pa + pb) * 0.5 + Vector2(randf_range(-20, 20), randf_range(-20, 20))
			draw_polyline(PackedVector2Array([pa, mid, pb]),
				Color(_pcol.r, _pcol.g, _pcol.b, 0.55), 1.0)

	# Subtle ceiling electricity
	var spark_y := -HH + 25.0
	if sin(_t * 7.0) > 0.8:
		var sx := randf_range(-HW * 0.7, HW * 0.7)
		draw_line(Vector2(sx, spark_y), Vector2(sx + randf_range(-12, 12), spark_y + randf_range(8, 20)),
			Color(1, 1, 1, 0.45), 1.0)
