class_name Hammer
extends Sprite2D
## Gavel cursor that follows the mouse and swings on click.

var TOOL_SVG = preload("res://assets/hammers/Basic_hammer.png")

var _swinging := false

func _ready() -> void:
	z_index = 100
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _process(_delta: float) -> void:
	# Works inside a CanvasLayer: track the raw viewport mouse position.
	position = get_viewport().get_mouse_position()

func swing() -> void:
	if _swinging:
		return
	_swinging = true

	var pivot := Vector2(0, -64)
	var original_rotation := rotation
	var original_position := position

	var tw := create_tween()

	tw.tween_method(func(angle: float):
		rotation = angle
		position = original_position + pivot.rotated(angle) - pivot.rotated(original_rotation),
		original_rotation, -1.2, 0.05
	)

	tw.tween_method(func(angle: float):
		rotation = angle
		position = original_position + pivot.rotated(angle) - pivot.rotated(original_rotation),
		-1.2, original_rotation, 0.12
	).set_trans(Tween.TRANS_BACK)

	tw.tween_callback(func():
		position = original_position
		rotation = original_rotation
		_swinging = false
	)

func basic_inline() -> void:
	# Handle
	draw_line(Vector2(6, 6), Vector2(34, 42), Color(0.5, 0.33, 0.18), 9.0)
	# Head
	draw_set_transform(Vector2.ZERO, -PI / 4, Vector2.ONE)
	draw_rect(Rect2(-26, -14, 52, 28), Color(0.62, 0.42, 0.22))
	draw_rect(Rect2(-26, -14, 8, 28), Color(0.45, 0.30, 0.15))
	draw_rect(Rect2(18, -14, 8, 28), Color(0.45, 0.30, 0.15))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func replace_hammer(texture):
	TOOL_SVG = texture
	queue_redraw() # Requests a redraw, which calls _draw() safely

func _draw() -> void:
	push_error("Drawing hammer :" + str(TOOL_SVG))
	var target_rect = Rect2(-32, 0, 64, 64)
	draw_texture_rect(TOOL_SVG, target_rect, false)
