extends Node

const WEAPONS: Dictionary = {
	# ── Balanced ─────────────────────────────────────────────────────────────
	"wand": {
		"name": "Arcane Wand",      "desc": "Fast. Reliable. Your starting weapon.",
		"fire_rate": 0.16, "damage": 1, "count": 1, "spread": 0.0,
		"speed": 455.0,   "color": Color(1.00, 0.92, 0.28),
	},
	# ── Rapid ────────────────────────────────────────────────────────────────
	"smg": {
		"name": "Ember SMG",        "desc": "Blisteringly fast. Burns through enemies.",
		"fire_rate": 0.07, "damage": 1, "count": 1, "spread": 0.10,
		"speed": 420.0,   "color": Color(1.00, 0.52, 0.10),
	},
	# ── Spread ───────────────────────────────────────────────────────────────
	"shotgun": {
		"name": "Frost Shotgun",    "desc": "Close-range chaos. Slows on hit.",
		"fire_rate": 0.62, "damage": 1, "count": 5, "spread": 0.44,
		"speed": 330.0,   "color": Color(0.38, 0.75, 1.00),
	},
	# ── Burst ─────────────────────────────────────────────────────────────────
	"burst": {
		"name": "Storm Burst",      "desc": "Triple burst. Chains lightning.",
		"fire_rate": 0.21, "damage": 1, "count": 3, "spread": 0.14,
		"speed": 530.0,   "color": Color(0.75, 0.38, 1.00),
	},
	# ── Heavy ─────────────────────────────────────────────────────────────────
	"cannon": {
		"name": "Magma Cannon",     "desc": "Slow. Devastating. Explodes on impact.",
		"fire_rate": 1.20, "damage": 5, "count": 1, "spread": 0.0,
		"speed": 195.0,   "color": Color(1.00, 0.30, 0.0),
		"proj_scale": 2.2, "explosive": true, "explosion_radius": 72.0,
	},
	"staff": {
		"name": "Nature Staff",     "desc": "Slow heavy shot. High damage. Heals on kill.",
		"fire_rate": 0.58, "damage": 3, "count": 1, "spread": 0.0,
		"speed": 255.0,   "color": Color(0.28, 0.88, 0.25),
	},
	# ── Ricochet ─────────────────────────────────────────────────────────────
	"ricochet": {
		"name": "Frost Ricochet",   "desc": "Bounces off walls. Each bounce slows.",
		"fire_rate": 0.38, "damage": 2, "count": 1, "spread": 0.0,
		"speed": 370.0,   "color": Color(0.35, 0.90, 1.00),
		"bounces": 3,
	},
	# ── Chain ─────────────────────────────────────────────────────────────────
	"chain": {
		"name": "Storm Chain",      "desc": "Leaps to nearby enemies. Chains up to 3.",
		"fire_rate": 0.45, "damage": 2, "count": 1, "spread": 0.0,
		"speed": 520.0,   "color": Color(0.88, 0.72, 1.00),
		"chain_shot": true, "chain_range": 130.0,
	},
	# ── Orbital ──────────────────────────────────────────────────────────────
	"orbital": {
		"name": "Nature Orbital",   "desc": "Spawns orbiting thorns. Max 5 active.",
		"fire_rate": 1.60, "damage": 1, "count": 1, "spread": 0.0,
		"speed": 0.0,     "color": Color(0.30, 0.92, 0.25),
		"is_orbital": true,
	},
	# ── Beam ─────────────────────────────────────────────────────────────────
	"beam": {
		"name": "Crystal Beam",     "desc": "Rapid thin shots. Slows on every hit.",
		"fire_rate": 0.055,"damage": 1, "count": 1, "spread": 0.0,
		"speed": 640.0,   "color": Color(0.55, 0.90, 1.00),
		"proj_scale": 0.6,
	},
}

func get_weapon(key: String) -> Dictionary:
	return WEAPONS.get(key, WEAPONS["wand"]) as Dictionary

func random_drop_key() -> String:
	var droppable := ["shotgun", "burst", "staff", "smg", "cannon",
	                  "ricochet", "chain", "orbital", "beam"]
	return droppable[randi() % droppable.size()]
