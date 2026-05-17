extends Area2D

var direction  := Vector2.RIGHT
var damage     := 1
var speed      := 450.0
var is_split   := false  # Prevents STORMBLOOM infinite split

const DeathBurst = preload("res://effects/death_burst.tscn")

func _ready() -> void:
	# Fracture bonuses are ADDED on top of weapon base values (set before _ready by player)
	damage += FractureManager.get_damage_bonus()
	speed  += FractureManager.get_projectile_speed_bonus()
	body_entered.connect(_on_body_entered)
	queue_redraw()
	get_tree().create_timer(3.0).timeout.connect(queue_free)

func _draw() -> void:
	var col := FractureManager.get_projectile_color()
	draw_circle(Vector2.ZERO, 5, col)
	draw_circle(Vector2.ZERO, 3, Color.WHITE.lerp(col, 0.3))
	# Trail
	for i in 3:
		draw_circle(-direction * (6 + i * 4), 3.5 - i * 0.7, Color(col.r, col.g, col.b, (3-i)*0.12))

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("destructible") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free.call_deferred()
		return
	if not body.is_in_group("enemies"):
		return

	body.take_damage(damage)

	# Frost slow / Blizzard freeze
	if FractureManager.has_frost() and body.has_method("apply_slow"):
		var syn := FractureManager.get_synergy()
		if syn == "BLIZZARD":
			body.apply_slow(3.0, 0.0)  # Complete freeze
		else:
			body.apply_slow(1.5, 0.35)

	# Storm chain lightning
	if FractureManager.has_storm():
		_chain_lightning(body)

	# Synergy special effects
	match FractureManager.get_synergy():
		"INFERNO":
			_inferno_explosion()
		"STORMBLOOM":
			if not is_split:
				_stormbloom_split()
		"STEAM":
			_steam_slow_aoe()

	queue_free.call_deferred()

func _chain_lightning(source: Node) -> void:
	var chain_cnt := 2 if FractureManager.get_synergy() == "TEMPEST" else 1
	var enemies := get_tree().get_nodes_in_group("enemies")
	var candidates := enemies.filter(func(e):
		return e != source and e.global_position.distance_to(source.global_position) < 200
	)
	candidates.sort_custom(func(a, b):
		return a.global_position.distance_to(source.global_position) < \
		       b.global_position.distance_to(source.global_position)
	)
	for e in candidates.slice(0, chain_cnt):
		e.take_damage(damage)

func _inferno_explosion() -> void:
	var burst := DeathBurst.instantiate()
	burst.global_position = global_position
	burst.color = Color(1.0, 0.38, 0.06)
	get_parent().add_child(burst)
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
		get_parent().add_child(proj)
		proj.global_position = global_position

func _steam_slow_aoe() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(global_position) < 70 and e.has_method("apply_slow"):
			e.apply_slow(2.0, 0.4)
