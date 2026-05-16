extends Area2D

var direction := Vector2.RIGHT
var damage := 1
var speed := 450.0

func _ready() -> void:
	damage += FractureManager.get_damage_bonus()
	speed += FractureManager.get_projectile_speed_bonus()
	body_entered.connect(_on_body_entered)
	queue_redraw()
	get_tree().create_timer(3.0).timeout.connect(queue_free)

func _draw() -> void:
	var col := FractureManager.get_projectile_color()
	draw_circle(Vector2.ZERO, 5, col)
	draw_circle(Vector2.ZERO, 3, Color.WHITE.lerp(col, 0.3))

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("enemies"):
		return
	body.take_damage(damage)
	if FractureManager.has_frost() and body.has_method("apply_slow"):
		body.apply_slow(1.5)
	if FractureManager.has_storm():
		_chain_lightning(body)
	queue_free()

func _chain_lightning(source: Node) -> void:
	var chain_count := 2 if FractureManager.get_synergy() == "TEMPEST" else 1
	var enemies := get_tree().get_nodes_in_group("enemies")
	var candidates := enemies.filter(func(e): return e != source and e.global_position.distance_to(source.global_position) < 200)
	candidates.sort_custom(func(a, b): return a.global_position.distance_to(source.global_position) < b.global_position.distance_to(source.global_position))
	for e in candidates.slice(0, chain_count):
		e.take_damage(damage)
