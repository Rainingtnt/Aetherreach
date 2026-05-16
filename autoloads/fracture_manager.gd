extends Node

enum Element { FIRE = 0, FROST = 1, NATURE = 2, STORM = 3 }

const MAX_FRACTURES := 3
const ELEMENT_NAMES := ["FIRE", "FROST", "NATURE", "STORM"]
const ELEMENT_COLORS := [
	Color(1.0, 0.45, 0.1),   # Fire
	Color(0.3, 0.75, 1.0),   # Frost
	Color(0.3, 0.92, 0.38),  # Nature
	Color(0.95, 0.85, 0.15), # Storm
]

var active_fractures: Array[int] = []

signal fractures_changed

func add_fracture(element: int) -> void:
	if active_fractures.size() >= MAX_FRACTURES:
		active_fractures.pop_front()
	active_fractures.append(element)
	fractures_changed.emit()

func reset() -> void:
	active_fractures.clear()
	fractures_changed.emit()

func get_damage_bonus() -> int:
	return active_fractures.count(Element.FIRE)

func get_projectile_speed_bonus() -> float:
	return active_fractures.count(Element.FIRE) * 55.0

func has_frost() -> bool:
	return Element.FROST in active_fractures

func has_storm() -> bool:
	return Element.STORM in active_fractures

func get_nature_regen_interval() -> float:
	var count = active_fractures.count(Element.NATURE)
	return 9.0 / max(count, 1) if count > 0 else 0.0

func get_synergy() -> String:
	if active_fractures.size() < 2:
		return ""
	var counts := {}
	for e in active_fractures:
		counts[e] = counts.get(e, 0) + 1
	for e in counts:
		if counts[e] >= 2:
			match e:
				Element.FIRE:   return "INFERNO"
				Element.FROST:  return "BLIZZARD"
				Element.NATURE: return "BLOOM"
				Element.STORM:  return "TEMPEST"
	var has := func(e): return e in counts
	if has.call(Element.FIRE)  and has.call(Element.STORM):   return "THUNDERFIRE"
	if has.call(Element.FROST) and has.call(Element.NATURE):  return "THORNFROST"
	if has.call(Element.FIRE)  and has.call(Element.FROST):   return "STEAM"
	if has.call(Element.NATURE)and has.call(Element.STORM):   return "STORMBLOOM"
	if has.call(Element.FIRE)  and has.call(Element.NATURE):  return "MAGMAROOT"
	if has.call(Element.FROST) and has.call(Element.STORM):   return "FREEZING GALE"
	return ""

func get_projectile_color() -> Color:
	if active_fractures.is_empty():
		return Color(1, 0.95, 0.3)
	var col := Color.BLACK
	for e in active_fractures:
		col += ELEMENT_COLORS[e]
	col /= active_fractures.size()
	col.a = 1.0
	return col
