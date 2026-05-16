extends StaticBody2D

var health     := 3
var max_health := 3

const DeathBurst     = preload("res://effects/death_burst.tscn")
const FracturePickup = preload("res://scripts/fracture_pickup.tscn")

func _ready() -> void:
	add_to_group("destructible")
	var cs   := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 28)
	cs.shape = rect
	add_child(cs)
	queue_redraw()

func _draw() -> void:
	var dmg := 1.0 - float(health) / float(max_health)
	var col := Color(0.52, 0.38, 0.22).lerp(Color(0.30, 0.20, 0.10), dmg)
	draw_rect(Rect2(-14, -14, 28, 28), col)
	draw_rect(Rect2(-14, -14, 28, 28), Color(0.70, 0.52, 0.30), false, 2)
	draw_line(Vector2(-14, -14), Vector2(14, 14), Color(0.60, 0.44, 0.24), 1)
	draw_line(Vector2(-14,  14), Vector2(14,-14), Color(0.60, 0.44, 0.24), 1)
	if health < max_health:
		draw_line(Vector2(-10,-14), Vector2(2, 0), Color(0.15, 0.10, 0.05), 1.5)
		draw_line(Vector2(2,  0),  Vector2(8,14), Color(0.15, 0.10, 0.05), 1.5)

func take_damage(amount: int) -> void:
	health -= amount
	queue_redraw()
	if health <= 0:
		var burst := DeathBurst.instantiate()
		burst.global_position = global_position
		burst.color = Color(0.52, 0.38, 0.22)
		get_parent().add_child(burst)
		if randf() < 0.5:
			var frac := FracturePickup.instantiate()
			get_parent().add_child(frac)
			frac.setup(randi() % 4, global_position)
		queue_free()
