extends Node

const BIOMES: Dictionary = {
	"emberwild": {
		"name":         "Emberwild Dominion",
		"depth_range":  [1, 3],
		"floor":        Color(0.12, 0.07, 0.04),
		"floor_alt":    Color(0.10, 0.05, 0.02),
		"wall":         Color(0.30, 0.14, 0.06),
		"wall_top":     Color(0.42, 0.20, 0.08),
		"wall_detail":  Color(0.55, 0.25, 0.08, 0.4),
		"grid":         Color(1.0, 0.4, 0.1, 0.028),
		"tile_border":  Color(0.20, 0.10, 0.04, 0.45),
		"border":       Color(1.0, 0.38, 0.08, 0.30),
		"particle":     Color(1.0, 0.48, 0.10),
		"accent":       Color(1.0, 0.32, 0.04),
		"glow":         Color(1.0, 0.28, 0.04, 0.12),
		"decal":        Color(0.55, 0.22, 0.06, 0.28),
		"torch_color":  Color(1.0, 0.52, 0.08),
		"fog_color":    Color(0.18, 0.06, 0.02, 0.0),
		"door_locked":  Color(0.95, 0.22, 0.08, 0.85),
		"door_open":    Color(1.00, 0.62, 0.12, 0.85),
		"fx_type":      "embers",
	},
	"glacia": {
		"name":         "Glacia Cathedral",
		"depth_range":  [4, 6],
		"floor":        Color(0.04, 0.07, 0.14),
		"floor_alt":    Color(0.06, 0.09, 0.18),
		"wall":         Color(0.14, 0.22, 0.38),
		"wall_top":     Color(0.22, 0.34, 0.55),
		"wall_detail":  Color(0.55, 0.78, 1.0, 0.3),
		"grid":         Color(0.4, 0.7, 1.0, 0.028),
		"tile_border":  Color(0.20, 0.35, 0.60, 0.40),
		"border":       Color(0.38, 0.68, 1.0, 0.30),
		"particle":     Color(0.50, 0.80, 1.00),
		"accent":       Color(0.30, 0.65, 1.00),
		"glow":         Color(0.28, 0.55, 1.0, 0.10),
		"decal":        Color(0.45, 0.70, 1.0, 0.22),
		"torch_color":  Color(0.45, 0.78, 1.0),
		"fog_color":    Color(0.05, 0.08, 0.18, 0.0),
		"door_locked":  Color(0.20, 0.30, 0.90, 0.85),
		"door_open":    Color(0.30, 0.90, 1.00, 0.85),
		"fx_type":      "snow",
	},
	"verdant": {
		"name":         "Verdant Burrows",
		"depth_range":  [7, 9],
		"floor":        Color(0.04, 0.10, 0.04),
		"floor_alt":    Color(0.03, 0.08, 0.03),
		"wall":         Color(0.12, 0.24, 0.10),
		"wall_top":     Color(0.18, 0.34, 0.14),
		"wall_detail":  Color(0.28, 0.70, 0.18, 0.35),
		"grid":         Color(0.25, 0.85, 0.20, 0.028),
		"tile_border":  Color(0.10, 0.30, 0.08, 0.45),
		"border":       Color(0.28, 0.82, 0.18, 0.30),
		"particle":     Color(0.32, 0.90, 0.22),
		"accent":       Color(0.22, 0.72, 0.14),
		"glow":         Color(0.18, 0.70, 0.12, 0.10),
		"decal":        Color(0.22, 0.65, 0.12, 0.30),
		"torch_color":  Color(0.28, 0.90, 0.22),
		"fog_color":    Color(0.04, 0.10, 0.02, 0.0),
		"door_locked":  Color(0.55, 0.18, 0.08, 0.85),
		"door_open":    Color(0.22, 0.88, 0.18, 0.85),
		"fx_type":      "spores",
	},
	"tempest": {
		"name":         "Tempest Expanse",
		"depth_range":  [10, 999],
		"floor":        Color(0.07, 0.05, 0.13),
		"floor_alt":    Color(0.05, 0.04, 0.10),
		"wall":         Color(0.20, 0.14, 0.34),
		"wall_top":     Color(0.30, 0.22, 0.50),
		"wall_detail":  Color(0.65, 0.38, 1.0, 0.35),
		"grid":         Color(0.65, 0.35, 1.0, 0.028),
		"tile_border":  Color(0.25, 0.16, 0.42, 0.45),
		"border":       Color(0.68, 0.38, 1.0, 0.30),
		"particle":     Color(0.78, 0.48, 1.00),
		"accent":       Color(0.62, 0.32, 1.00),
		"glow":         Color(0.60, 0.30, 1.0, 0.12),
		"decal":        Color(0.55, 0.28, 0.90, 0.28),
		"torch_color":  Color(0.72, 0.42, 1.0),
		"fog_color":    Color(0.08, 0.05, 0.15, 0.0),
		"door_locked":  Color(0.50, 0.10, 0.80, 0.85),
		"door_open":    Color(0.65, 0.35, 1.00, 0.85),
		"fx_type":      "lightning",
	},
}

func get_biome(depth: int) -> Dictionary:
	for key in BIOMES:
		var b := BIOMES[key] as Dictionary
		var r := b["depth_range"] as Array
		if depth >= (r[0] as int) and depth <= (r[1] as int):
			return b
	return BIOMES["emberwild"] as Dictionary

func get_key(depth: int) -> String:
	for key in BIOMES:
		var b := BIOMES[key] as Dictionary
		var r := b["depth_range"] as Array
		if depth >= (r[0] as int) and depth <= (r[1] as int):
			return key
	return "emberwild"
