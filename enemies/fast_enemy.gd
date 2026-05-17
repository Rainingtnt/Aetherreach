extends CharacterBody2D

# Speeder — blade-like silhouette, zigzag movement, one-shot fragile

const SPEED            := 165.0
const ZIGZAG_AMP       := 85.0
const ZIGZAG_FREQ      := 4.0
const CONTACT_COOLDOWN := 0.45

var health     := 1
var max_health := 1
var damage     := 1
var player: Node2D = null
var zigzag_t   := randf() * TAU
var contact_t  := 0.0
var _anim_t    := randf() * TAU

const DeathBurst     = preload("res://effects/death_burst.tscn")
const FracturePickup = preload("res://scripts/fracture_pickup.tscn")

func _ready() -> void:
	add_to_group("enemies")
	queue_redraw()
	var pl := get_tree().get_nodes_in_group("player")
	if pl.size() > 0:
		player = pl[0]

func _process(delta: float) -> void:
	_anim_t += delta
	queue_redraw()

func _draw() -> void:
	var wobble := sin(_anim_t * 4.5) * 1.0
	draw_set_transform(Vector2(0, wobble))
	# Blade/arrowhead body
	var pts := PackedVector2Array([
		Vector2(0, -13), Vector2(9, 4),
		Vector2(4, 8), Vector2(0, 6),
		Vector2(-4, 8), Vector2(-9, 4),
	])
	draw_colored_polygon(pts, Color(0.12, 0.90, 0.72))
	draw_polyline(PackedVector2Array([Vector2(0,-13),Vector2(9,4),Vector2(0,6),Vector2(-9,4),Vector2(0,-13)]),
		Color(0.5, 1.0, 0.88, 0.7), 1.2)
	# Speed streak
	draw_line(Vector2(0, 6), Vector2(0, 14), Color(0.12, 0.90, 0.72, 0.35), 2)
	draw_set_transform(Vector2.ZERO)

func _physics_process(delta: float) -> void:
	if player == null: return
	zigzag_t  += delta
	contact_t -= delta
	var to_p := (player.global_position - global_position).normalized()
	var perp := Vector2(-to_p.y, to_p.x)
	velocity = (to_p * SPEED + perp * sin(zigzag_t * ZIGZAG_FREQ) * ZIGZAG_AMP).normalized() * SPEED
	move_and_slide()
	if global_position.distance_to(player.global_position) < 18 and contact_t <= 0.0:
		player.take_damage(damage)
		contact_t = CONTACT_COOLDOWN

func heal(_a: int) -> void: pass
func apply_slow(_d: float) -> void: pass

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		Juice.hit_stop(0.03)
		var burst := DeathBurst.instantiate()
		burst.global_position = global_position
		burst.color = Color(0.12, 0.90, 0.72)
		get_parent().add_child(burst)
		if randf() < 0.35:
			var frac := FracturePickup.instantiate()
			get_parent().add_child(frac)
			frac.setup(randi() % 4, global_position)
		GameEvents.enemy_died.emit(global_position, 2)
		queue_free.call_deferred()
