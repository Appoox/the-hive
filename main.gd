extends Node2D

# Day 1 sanity check, drawn through the most primitive path available:
# Node2D._draw(). This bypasses Control anchors, layout, size flags and
# stretch resolution entirely — if this does not appear, nothing will.
# Delete once terrain and adhesion movement exist.

var square_pos: Vector2 = Vector2.ZERO
var square_size: Vector2 = Vector2(200, 200)


func _ready() -> void:
	# Centre on the viewport at startup so something is visible before input.
	square_pos = get_viewport_rect().size * 0.5 - square_size * 0.5
	print("Day 1 ready. Viewport: ", get_viewport_rect().size)


func _draw() -> void:
	# draw_rect on a Node2D goes straight to the canvas. No node to lay out.
	draw_rect(Rect2(square_pos, square_size), Color(1.0, 0.35, 0.15))

	# A second rect pinned to the origin, as a fixed reference point. If this
	# one appears but the movable one does not, the problem is the position
	# value, not the drawing.
	draw_rect(Rect2(Vector2(0, 0), Vector2(100, 100)), Color(0, 1, 0))


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		square_pos = event.position
		queue_redraw()   # _draw only runs when explicitly requested
	elif event is InputEventMouseMotion and event.button_mask != 0:
		square_pos = event.position
		queue_redraw()
