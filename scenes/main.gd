extends Node2D

const HUDScript = preload("res://ui/hud.gd")

func _ready() -> void:
	_setup_hud()
	RoomManager.initialize($WorldContainer, $Player, $TransitionLayer/FadeRect)

func _setup_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)
	var hud := HUDScript.new()
	canvas.add_child(hud)
