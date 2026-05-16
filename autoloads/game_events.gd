extends Node

signal player_hit(current_health: int, max_health: int)
signal player_died
signal enemy_died(position: Vector2, points: int)
signal score_changed(new_score: int)
signal wave_started(wave_number: int)
