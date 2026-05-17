extends Node

# Relic system — passive run buffs found in treasure rooms and dropped by bosses.

const RELICS: Dictionary = {
	"iron_heart":     {"name": "Iron Heart",     "desc": "+2 max HP",                       "color": Color(1.0, 0.30, 0.30)},
	"swift_boots":    {"name": "Swift Boots",    "desc": "+25% move speed",                 "color": Color(0.30, 0.80, 1.00)},
	"twin_foci":      {"name": "Twin Foci",      "desc": "Fire rate +25%",                  "color": Color(1.00, 0.90, 0.20)},
	"fracture_lens":  {"name": "Fracture Lens",  "desc": "Fracture pickups grant double",   "color": Color(0.55, 0.28, 1.00)},
	"glass_cannon":   {"name": "Glass Cannon",   "desc": "+2 damage / -1 max HP",           "color": Color(1.00, 0.55, 0.10)},
	"thorned_mantle": {"name": "Thorned Mantle", "desc": "On hit: deal 2 to nearby enemies","color": Color(0.28, 0.72, 0.28)},
	"ember_core":     {"name": "Ember Core",     "desc": "Dash leaves a fire explosion",    "color": Color(1.00, 0.38, 0.08)},
	"storm_catalyst": {"name": "Storm Catalyst", "desc": "Every 8 kills: next shot ×3",     "color": Color(0.90, 0.85, 0.20)},
	"void_cloak":     {"name": "Void Cloak",     "desc": "Invincibility +0.5s",             "color": Color(0.45, 0.22, 0.70)},
	"amplifier":      {"name": "Amplifier",      "desc": "Projectile speed +35%",           "color": Color(0.25, 0.75, 1.00)},
	"arcane_echo":    {"name": "Arcane Echo",    "desc": "15% chance to fire twice",        "color": Color(0.80, 0.40, 1.00)},
	"last_stand":     {"name": "Last Stand",     "desc": "At 1 HP: 3s invincibility (once per room)", "color": Color(1.00, 0.72, 0.12)},
	"iron_will":      {"name": "Iron Will",      "desc": "+1 max HP; heal 1 on room clear", "color": Color(0.85, 0.60, 0.40)},
	"compass":        {"name": "Compass",        "desc": "Reveal all rooms on minimap",     "color": Color(0.60, 0.90, 0.60)},
	"bloodrite":      {"name": "Bloodrite",      "desc": "Killing blow deals splash damage","color": Color(0.90, 0.18, 0.18)},
}

var active_relics: Array[String] = []
var kill_counter: int = 0           # for storm_catalyst
var catalyst_ready: bool = false
var last_stand_used: bool = false   # resets per room

func _ready() -> void:
	GameEvents.enemy_died.connect(func(_p: Vector2, _pts: int): _on_kill())
	GameEvents.room_cleared_event.connect(func(): _on_room_clear())

func add_relic(key: String) -> void:
	if not RELICS.has(key):
		return
	active_relics.append(key)
	GameEvents.relic_gained.emit(key, (RELICS[key] as Dictionary)["name"] as String)

func has(key: String) -> bool:
	return active_relics.has(key)

func random_relic_key() -> String:
	var keys := RELICS.keys()
	# Exclude already owned relics
	var available: Array = []
	for k in keys:
		if not has(k as String):
			available.append(k)
	if available.is_empty():
		return ""
	return available[randi() % available.size()] as String

func reset() -> void:
	active_relics.clear()
	kill_counter = 0
	catalyst_ready = false
	last_stand_used = false

# ── Stat queries ────────────────────────────────────────────────────────────
func get_speed_mult() -> float:
	return 1.25 if has("swift_boots") else 1.0

func get_fire_rate_mult() -> float:
	return 0.75 if has("twin_foci") else 1.0

func get_damage_bonus() -> int:
	return 2 if has("glass_cannon") else 0

func get_max_hp_bonus() -> int:
	var b := 0
	if has("iron_heart"): b += 2
	if has("glass_cannon"): b -= 1
	if has("iron_will"): b += 1
	return b

func get_projectile_speed_mult() -> float:
	return 1.35 if has("amplifier") else 1.0

func get_echo_chance() -> float:
	return 0.15 if has("arcane_echo") else 0.0

func get_invincibility_bonus() -> float:
	return 0.5 if has("void_cloak") else 0.0

func get_fracture_multiplier() -> int:
	return 2 if has("fracture_lens") else 1

func should_catalyst_triple() -> bool:
	return catalyst_ready and has("storm_catalyst")

func consume_catalyst() -> void:
	catalyst_ready = false

func can_last_stand() -> bool:
	return has("last_stand") and not last_stand_used

func use_last_stand() -> void:
	last_stand_used = true

# ── Internal ─────────────────────────────────────────────────────────────────
func _on_kill() -> void:
	if not has("storm_catalyst"):
		return
	kill_counter += 1
	if kill_counter >= 8:
		kill_counter = 0
		catalyst_ready = true

func _on_room_clear() -> void:
	last_stand_used = false
