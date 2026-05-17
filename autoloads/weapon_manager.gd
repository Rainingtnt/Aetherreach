extends Node

# Central weapon data — accessible by player, HUD, and pickups
const WEAPONS: Dictionary = {
	"wand": {
		"name":      "Arcane Wand",
		"desc":      "Fast. Reliable. Balanced.",
		"fire_rate": 0.16,
		"damage":    1,
		"count":     1,
		"spread":    0.0,
		"speed":     455.0,
		"color":     Color(1.00, 0.92, 0.28),
	},
	"shotgun": {
		"name":      "Frost Shotgun",
		"desc":      "Close range chaos. Slows on hit.",
		"fire_rate": 0.62,
		"damage":    1,
		"count":     5,
		"spread":    0.44,
		"speed":     330.0,
		"color":     Color(0.38, 0.75, 1.00),
	},
	"burst": {
		"name":      "Storm Burst",
		"desc":      "Triple burst. Chains lightning.",
		"fire_rate": 0.21,
		"damage":    1,
		"count":     3,
		"spread":    0.14,
		"speed":     530.0,
		"color":     Color(0.75, 0.38, 1.00),
	},
	"staff": {
		"name":      "Nature Staff",
		"desc":      "Slow heavy shot. High damage.",
		"fire_rate": 0.58,
		"damage":    3,
		"count":     1,
		"spread":    0.0,
		"speed":     255.0,
		"color":     Color(0.28, 0.88, 0.25),
	},
}

func get_weapon(key: String) -> Dictionary:
	return WEAPONS.get(key, WEAPONS["wand"]) as Dictionary

func random_drop_key() -> String:
	var keys := ["shotgun", "burst", "staff"]
	return keys[randi() % keys.size()]
