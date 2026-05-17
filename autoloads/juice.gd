extends Node

# Centralised game-feel effects

func hit_stop(duration: float = 0.055) -> void:
	Engine.time_scale = 0.04
	# ignore_time_scale=true so the timer runs in real time, not game time
	get_tree().create_timer(duration, false, false, true).timeout.connect(func():
		Engine.time_scale = 1.0
	)

func screen_flash(camera: Camera2D, color: Color = Color.WHITE, duration: float = 0.12) -> void:
	if camera == null:
		return
	var orig := camera.offset
	var tween := camera.create_tween()
	tween.tween_property(camera, "offset",
		orig + Vector2(randf_range(-6, 6), randf_range(-6, 6)), 0.04)
	tween.tween_property(camera, "offset", orig, 0.08)
