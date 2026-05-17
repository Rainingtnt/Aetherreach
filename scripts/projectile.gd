extends Area2D

var direction   := Vector2.RIGHT
var damage      := 1
var speed       := 450.0
var is_split    := false   # prevents STORMBLOOM infinite split
var proj_color  := Color(0, 0, 0, 0)  # if set, overrides fracture color
var proj_scale  := 1.0     # visual size multiplier
var bounces     := 0       # ricochet: remaining wall bounces
var explosive   := false   # cannon: AoE on impact
var explosion_radius := 72.0
var chain_shot  := false   # chain: leaps to next enemy
var chain_range := 130.0
var _bounces_left := 0

const DeathBurst = preload("res://effects/death_burst.tscn")

func _ready() -> void:
	damage += FractureManager.get_damage_bonus()
	speed  += FractureManager.get_projectile_speed_bonus()
	speed  *= RelicManager.get_projectile_speed_mult()
	_bounces_left = bounces
	body_entered.connect(_on_body_entered)
	queue_redraw()
	get_tree().create_timer(3.5).timeout.connect(queue_free)

func _draw() -> void:
	var col := proj_color if proj_color.a > 0.01 else FractureManager.get_projectile_color()
	var sz  := 5.0 * proj_scale
	# Glow
	draw_circle(Vector2.ZERO, sz * 1.8, Color(col.r, col.g, col.b, 0.22))
	draw_circle(Vector2.ZERO, sz, col)
	draw_circle(Vector2.ZERO, sz * 0.55, Color.WHITE.lerp(col, 0.3))
	# Trail
	for i in 4:
		var tp := -direction * (sz * 1.4 + i * sz * 0.9)
		draw_circle(tp, sz * (0.75 - i * 0.15), Color(col.r, col.g, col.b, (4 - i) * 0.09))

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

	# Ricochet wall bounce
	if _bounces_left > 0:
		var hit := false
		if abs(global_position.x) > 425:
			direction.x *= -1
			global_position.x = clampf(global_position.x, -425, 425)
			hit = true
		if abs(global_position.y) > 275:
			direction.y *= -1
			global_position.y = clampf(global_position.y, -275, 275)
			hit = true
		if hit:
			_bounces_left -= 1
			# Slow any enemy near the bounce point
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.global_position.distance_to(global_position) < 50 and e.has_method("apply_slow"):
					e.apply_slow(1.2, 0.4)
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("destructible") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free.call_deferred()
		return
	if not body.is_in_group("enemies"):
		return

	body.take_damage(damage)

	# Explosive (cannon)
	if explosive:
		_explode()
		return  # skip other effects, already queuing free

	# Chain shot (storm chain)
	if chain_shot:
		_do_chain(body)

	# Frost slow / Blizzard freeze
	if FractureManager.has_frost() and body.has_method("apply_slow"):
		var syn := FractureManager.get_synergy()
		if syn == "BLIZZARD":
			body.apply_slow(3.0, 0.0)
		else:
			body.apply_slow(1.5, 0.35)

	# Storm chain lightning (fracture)
	if FractureManager.has_storm():
		_chain_lightning(body)

	# Synergy effects
	match FractureManager.get_synergy():
		"INFERNO":
			_inferno_explosion()
		"STORMBLOOM":
			if not is_split:
				_stormbloom_split()
		"STEAM":
			_steam_slow_aoe()
		"MAGMAROOT":
			if body.has_method("apply_slow"):
				body.apply_slow(2.0, 0.2)

	queue_free.call_deferred()

func _explode() -> void:
	var burst := DeathBurst.instantiate()
	burst.global_position = global_position
	burst.color = proj_color if proj_color.a > 0.01 else Color(1.0, 0.38, 0.06)
	get_parent().call_deferred("add_child", burst)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(global_position) < explosion_radius:
			e.take_damage(damage)
	queue_free.call_deferred()

func _do_chain(source: Node) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var best: Node = null
	var best_d := chain_range
	for e in enemies:
		if e == source: continue
		var d := (e as Node2D).global_position.distance_to(global_position)
		if d < best_d:
			best   = e
			best_d = d
	if best == null: return
	var chain := load("res://scripts/projectile.tscn").instantiate()
	chain.set("damage",    damage)
	chain.set("speed",     speed * 0.85)
	chain.set("direction", ((best as Node2D).global_position - global_position).normalized())
	chain.set("chain_shot", false)   # no infinite chain
	chain.set("proj_color", proj_color)
	get_parent().call_deferred("add_child", chain)
	chain.global_position = global_position

func _chain_lightning(source: Node) -> void:
	var chain_cnt := 2 if FractureManager.get_synergy() == "TEMPEST" else 1
	var enemies := get_tree().get_nodes_in_group("enemies")
	var candidates := enemies.filter(func(e):
		return e != source and (e as Node2D).global_position.distance_to((source as Node2D).global_position) < 200
	)
	candidates.sort_custom(func(a, b):
		return (a as Node2D).global_position.distance_to((source as Node2D).global_position) < \
		       (b as Node2D).global_position.distance_to((source as Node2D).global_position)
	)
	for e in candidates.slice(0, chain_cnt):
		e.take_damage(damage)

func _inferno_explosion() -> void:
	var burst := DeathBurst.instantiate()
	burst.global_position = global_position
	burst.color = Color(1.0, 0.38, 0.06)
	get_parent().call_deferred("add_child", burst)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(global_position) < 60:
			e.take_damage(1)

func _stormbloom_split() -> void:
	for i in 3:
		var proj := load("res://scripts/projectile.tscn").instantiate() as Area2D
		proj.set("is_split",  true)
		proj.set("damage",    1)
		proj.set("speed",     360.0)
		proj.set("direction", direction.rotated(TAU / 3.0 * (i + 1)))
		get_parent().call_deferred("add_child", proj)
		proj.global_position = global_position

func _steam_slow_aoe() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(global_position) < 70 and e.has_method("apply_slow"):
			e.apply_slow(2.0, 0.4)
