extends CharacterBody2D

# Fast, fragile, zigzag movement. Dies in one hit. Punishes standing still.

const SPEED           := 165.0
const ZIGZAG_AMP      := 85.0
const ZIGZAG_FREQ     := 4.0
const CONTACT_COOLDOWN := 0.45

var health     := 1
var max_health := 1
var damage     := 1
var player: Node2D = null
var zigzag_time   := randf() * TAU  # stagger so enemies don't sync
var contact_timer := 0.0

const DeathBurst     = preload("res://effects/death_burst.tscn")
const FracturePickup = preload("res://scripts/fracture_pickup.tscn")

func _ready() -> void:
	add_to_group("enemies")
	queue_redraw()
	var pl := get_tree().get_nodes_in_group("player")
	if pl.size() > 0:
		player = pl[0]

func _draw() -> void:
	var pts := PackedVector2Array([Vector2(0,-10), Vector2(8,0), Vector2(0,10), Vector2(-8,0)])
	draw_colored_polygon(pts, Color(0.15, 0.92, 0.75))
	draw_polyline(PackedVector2Array([Vector2(0,-10),Vector2(8,0),Vector2(0,10),Vector2(-8,0),Vector2(0,-10)]),
		Color(0.5, 1.0, 0.9), 1.2)

func _physics_process(delta: float) -> void:
	if player == null:
		return
	zigzag_time  += delta
	contact_timer -= delta
	var to_player := (player.global_position - global_position).normalized()
	var perp      := Vector2(-to_player.y, to_player.x)
	velocity = (to_player * SPEED + perp * sin(zigzag_time * ZIGZAG_FREQ) * ZIGZAG_AMP).normalized() * SPEED
	move_and_slide()
	if global_position.distance_to(player.global_position) < 18 and contact_timer <= 0.0:
		player.take_damage(damage)
		contact_timer = CONTACT_COOLDOWN

func heal(_amount: int) -> void:
	pass  # one-hit; healing irrelevant

func apply_slow(duration: float) -> void:
	# Freeze briefly — stuns the zigzag
	zigzag_time = 0.0
	await get_tree().create_timer(duration).timeout

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		var burst := DeathBurst.instantiate()
		burst.global_position = global_position
		burst.color = Color(0.15, 0.92, 0.75)
		get_parent().add_child(burst)
		if randf() < 0.35:
			var frac := FracturePickup.instantiate()
			get_parent().add_child(frac)
			frac.setup(randi() % 4, global_position)
		GameEvents.enemy_died.emit(global_position, 2)
		queue_free()
