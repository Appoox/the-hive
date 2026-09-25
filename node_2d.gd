extends Node2D

# Day 1 sanity check only. This exists to prove that touch input reaches the
# engine on the actual device, and nothing else. Delete it once terrain and
# adhesion movement exist — it is not the start of the input layer.
@onready var square: ColorRect = $ColorRect

func _unhandled_input(event: InputEvent) -> void:
	# Handle real touch explicitly rather than relying on Godot's
	# mouse-emulation, because touch working on device is the thing
	# being tested here.
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		square.position = event.position - square.size * 0.5

	# Mouse fallback so the same scene is usable on desktop during development.
	elif event is InputEventMouseMotion and event.button_mask != 0:
		square.position = event.position - square.size * 0.5
