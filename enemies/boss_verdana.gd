extends CharacterBody2D

# Princess Verdana — Verdant Burrows
# Phase 1 (HP > 60%): Vine lash 3-way + spawns 1 fast minion every 5s
# Phase 2 (HP 30-60%): 4-way thorns, healing aura, spawns more
# Phase 3 (HP < 30%): Explosive spore barrage + vine cage burst

const MAX_HP      := 95
const SPEED_P     := [35.0, 58.0, 100.0]
const ATCK_CD     := [2.60, 1.80, 1.10]
const SUMMON_CD   := [5.50, 3.80, 2.50]
const SPREAD_CNT  := [3, 4, 6]
const CONTACT_CD  := 0.8
const MAX_MINIONS := 4
const REGEN_TICK  := 3.5

var health  := MAX_HP
var phase   := 1
var _dying  := false
var _t           := 0.0
var _attack_t    := 2.5
var _summon_t    := 3.0
var _regen_t     := REGEN_TICK
var _contact_t   := 0.0
var _minion_count := 0
var player: Node2D = null

const BossThorn   = preload("res://scripts/boss_thorn.tscn")
const FastEnemy   = preload("res://enemies/fast_enemy.tscn")
const DeathBurst  = preload("res://effects/death_burst.tscn")
const FracturePickup = preload("res://scripts/fracture_pickup.tscn")
const BossTexture = preload("res://assets/sprites/boss_verdana.svg")

var _sprite: Sprite2D = null

func _ready() -> void:
	add_to_group("enemies")
	_sprite = Sprite2D.new()
	_sprite.texture = BossTexture
	_sprite.scale   = Vector2(0.60, 0.60)
	add_child(_sprite)
	var pl := get_tree().get_nodes_in_group("player")
	if pl.size() > 0:
		player = pl[0]
	GameEvents.boss_hp_changed.emit(health, MAX_HP, "PRINCESS VERDANA")

func _process(delta: float) -> void:
	_t += delta
	_update_sprite()
	# Phase 2 healing aura
	if phase >= 2:
		_regen_t -= delta
		if _regen_t <= 0.0:
			_regen_t = REGEN_TICK
			health = mini(health + 2, MAX_HP)
			GameEvents.boss_hp_changed.emit(health, MAX_HP, "PRINCESS VERDANA")
	queue_redraw()

func _update_sprite() -> void:
	if _sprite == null: return
	var breathe := sin(_t * 1.3) * 0.012
	_sprite.scale = Vector2(0.60 + breathe, 0.60 - breathe)
	match phase:
		1: _sprite.modulate = Color(0.85, 1.0, 0.80)
		2: _sprite.modulate = Color(0.65, 1.0, 0.55)
		3: _sprite.modulate = Color(0.45, 0.90, 0.30)

func _draw() -> void:
	# Vine orbit
	if phase >= 2:
		var cnt := 3 + (phase - 2) * 2
		for i in cnt:
			var a := _t * 1.1 + i * TAU / cnt
			var r := 46.0
			draw_circle(Vector2(cos(a), sin(a)) * r, 5.0, Color(0.28, 0.80, 0.22, 0.65))
			# Vine segment
			var a2 := a - 0.4
			draw_line(Vector2(cos(a), sin(a)) * r, Vector2(cos(a2), sin(a2)) * (r - 8),
				Color(0.18, 0.60, 0.12, 0.50), 2.0)
	if phase == 3:
		draw_arc(Vector2.ZERO, 52, 0, TAU, 32, Color(0.28, 0.80, 0.22, 0.22), 3)
		# Healing aura ring
		draw_arc(Vector2.ZERO, 38, 0, TAU, 24, Color(0.22, 0.90, 0.35, 0.15), 2)

func _physics_process(delta: float) -> void:
	if _dying or player == null: return
	_update_phase()
	_contact_t -= delta
	_attack_t  -= delta
	_summon_t  -= delta

	velocity = (player.global_position - global_position).normalized() * (SPEED_P[phase - 1] as float)
	move_and_slide()

	if global_position.distance_to(player.global_position) < 32 and _contact_t <= 0.0:
		player.take_damage(2 + (phase - 1))
		_contact_t = CONTACT_CD
	if _attack_t <= 0.0:
		_attack_t = ATCK_CD[phase - 1] as float
		_spread_shot()
	if _summon_t <= 0.0 and _minion_count < MAX_MINIONS:
		_summon_t = SUMMON_CD[phase - 1] as float
		_summon_minion()

const DIALOGUE := [
	"", "The forest always reclaims what is lost...", "Wither.  Return to the earth.",
]

func _update_phase() -> void:
	var new_p := 1
	if health <= MAX_HP * 0.60: new_p = 2
	if health <= MAX_HP * 0.30: new_p = 3
	if new_p != phase:
		phase = new_p
		GameEvents.boss_hp_changed.emit(health, MAX_HP, "PRINCESS VERDANA")
		if new_p - 1 < DIALOGUE.size() and DIALOGUE[new_p - 1] != "":
			GameEvents.boss_dialogue.emit(DIALOGUE[new_p - 1], Color(0.28, 0.90, 0.22))

func _spread_shot() -> void:
	var cnt: int = SPREAD_CNT[phase - 1] as int
	var base_dir := (player.global_position - global_position).normalized()
	var step := deg_to_rad(26.0)
	var start := -step * float(cnt - 1) / 2.0
	for i in cnt:
		_fire(base_dir.rotated(start + i * step))
	# Phase 3: also ring burst
	if phase == 3:
		for i in 8:
			_fire(Vector2(1, 0).rotated(i * TAU / 8.0))

func _fire(dir: Vector2) -> void:
	if not is_inside_tree(): return
	var fb := BossThorn.instantiate()
	fb.direction = dir
	fb.global_position = global_position
	get_parent().call_deferred("add_child", fb)

func _summon_minion() -> void:
	if not is_inside_tree(): return
	var minion := FastEnemy.instantiate()
	minion.global_position = global_position + Vector2(randf_range(-60, 60), randf_range(-40, 40))
	get_parent().call_deferred("add_child", minion)
	_minion_count += 1
	minion.tree_exited.connect(func(): _minion_count = maxi(0, _minion_count - 1))

func apply_slow(_d: float, _m: float = 0.35) -> void: pass
func heal(_a: int) -> void: pass

func take_damage(amount: int) -> void:
	if _dying: return
	health -= amount
	GameEvents.boss_hp_changed.emit(health, MAX_HP, "PRINCESS VERDANA")
	Juice.hit_stop(0.04)
	if _sprite != null:
		_sprite.modulate = Color(2.0, 2.0, 2.0)
		get_tree().create_timer(0.08).timeout.connect(func():
			if is_instance_valid(self): _update_sprite()
		)
	if health <= 0:
		_dying = true
		_die()

func _die() -> void:
	var parent := get_parent()
	var pos    := global_position
	for i in 7:
		var burst := DeathBurst.instantiate()
		burst.global_position = pos + Vector2(randf_range(-55, 55), randf_range(-55, 55))
		burst.color = Color(0.28, 0.85, 0.22)
		parent.call_deferred("add_child", burst)
	if randf() < 0.85:
		var frac := FracturePickup.instantiate()
		frac.setup(FractureManager.Element.NATURE, pos)
		parent.call_deferred("add_child", frac)
	GameEvents.enemy_died.emit(pos, 25)
	GameEvents.boss_defeated.emit()
	queue_free.call_deferred()
