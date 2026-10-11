class_name Hammer
extends Node2D
## Gavel cursor that follows the mouse and swings on click.

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
	var tw := create_tween()
	tw.tween_property(self, "rotation", -1.2, 0.05)
	tw.tween_property(self, "rotation", 0.0, 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(func(): _swinging = false)

@onready var hammer_texture: Texture2D = preload("res://assets/hammers/Basic_hammer.png")

func _draw() -> void:
	var target_width := 100.0
	var scale_factor := target_width / hammer_texture.get_width()
	var size := Vector2(hammer_texture.get_size()) * scale_factor

	draw_set_transform(Vector2.ZERO, -PI / 4, Vector2.ONE)
	draw_texture_rect(
		hammer_texture,
		Rect2(-size / 2.0, size),
		false
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
