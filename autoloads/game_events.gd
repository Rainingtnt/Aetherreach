extends Node

signal player_hit(current_health: int, max_health: int)
signal player_died
signal enemy_died(position: Vector2, points: int)
signal score_changed(new_score: int)
signal wave_started(wave_number: int)
signal room_entered(room_type: String, depth: int)
signal boss_hp_changed(current_hp: int, max_hp: int)
signal boss_defeated
signal weapon_changed(weapon_key: String, weapon_name: String, weapon_color: Color)
