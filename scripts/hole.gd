class_name Hole
extends Node2D
## A podium hole a reporter can pop out of. Handles pop-up/hide animation,
## the question timer (speech bubble), and hit detection.

signal whacked(hole: Hole)
signal question_asked(hole: Hole)

enum State { HIDDEN, RISING, UP, SINKING, BONKED }

const UP_Y := -40.0
const DOWN_Y := 78.0

var state: int = State.HIDDEN
var question_time := 2.0
var question_progress := 0.0

var _reporter: Reporter
var _bubble: Node2D
var _tween: Tween

func _ready() -> void:
	z_index = 0
	# Reporter, clipped between back and front of the hole.
	_reporter = Reporter.new()
	_reporter.position = Vector2(0, DOWN_Y)
	_reporter.visible = false
	add_child(_reporter)
	# Front rim drawn on top to hide the reporter when down.
	var front := HoleFront.new()
	front.z_index = 1
	add_child(front)
	_bubble = QuestionBubble.new()
	_bubble.position = Vector2(70, -120)
	_bubble.visible = false
	_bubble.z_index = 2
	add_child(_bubble)

func _draw() -> void:
	# Back of the hole (dark ellipse)
	draw_set_transform(Vector2(0, 70), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 60, Color(0.08, 0.06, 0.05))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _process(delta: float) -> void:
	if state == State.UP:
		question_progress += delta / question_time
		_bubble.progress = question_progress
		_bubble.queue_redraw()
		if question_progress >= 1.0:
			_finish_question()

func is_busy() -> bool:
	return state != State.HIDDEN

func pop_up(up_duration: float, q_time: float) -> void:
	if state != State.HIDDEN:
		return
	question_time = q_time
	question_progress = 0.0
	state = State.RISING
	_reporter.randomize_look()
	_reporter.visible = true
	_reporter.position = Vector2(0, DOWN_Y)
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_reporter, "position:y", UP_Y, up_duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func():
		state = State.UP
		_bubble.visible = true
		_bubble.progress = 0.0)

func try_whack(global_point: Vector2) -> bool:
	if state != State.RISING and state != State.UP:
		return false
	var local := to_local(global_point)
	var head := _reporter.position + Vector2(0, -45)
	if local.distance_to(head) > 65.0 and not Rect2(-40, _reporter.position.y - 90, 80, 140).has_point(local):
		return false
	_get_bonked()
	return true

func force_sink() -> void:
	if state == State.RISING or state == State.UP:
		_sink(0.3)

func _get_bonked() -> void:
	state = State.BONKED
	_bubble.visible = false
	_reporter.bonked = true
	_kill_tween()
	_tween = create_tween()
	# Squash
	_tween.tween_property(_reporter, "scale", Vector2(1.3, 0.5), 0.08)
	_tween.tween_property(_reporter, "scale", Vector2(1.0, 1.0), 0.12)
	_tween.tween_property(_reporter, "position:y", DOWN_Y, 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_reset)
	whacked.emit(self)

func _finish_question() -> void:
	_bubble.visible = false
	question_asked.emit(self)
	_sink(0.35)

func _sink(dur: float) -> void:
	state = State.SINKING
	_bubble.visible = false
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_reporter, "position:y", DOWN_Y, dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_reset)

func _reset() -> void:
	state = State.HIDDEN
	_reporter.visible = false
	_reporter.scale = Vector2.ONE

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


class HoleFront extends Node2D:
	func _draw() -> void:
		# Podium front that masks the reporter below the hole line.
		draw_rect(Rect2(-70, 70, 140, 60), Color(0.45, 0.30, 0.18))
		draw_rect(Rect2(-70, 70, 140, 8), Color(0.55, 0.38, 0.24))
		draw_set_transform(Vector2(0, 74), 0.0, Vector2(1.0, 0.35))
		draw_arc(Vector2.ZERO, 60, 0, TAU, 32, Color(0.30, 0.20, 0.12), 6.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class QuestionBubble extends Node2D:
	var progress := 0.0
	func _draw() -> void:
		var s := 0.5 + progress * 0.7
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
		draw_circle(Vector2.ZERO, 30, Color.WHITE)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-24, 14), Vector2(-8, 22), Vector2(-38, 38)]), Color.WHITE)
		# progress ring (danger meter)
		var col := Color(0.2, 0.7, 0.2).lerp(Color(0.85, 0.1, 0.1), progress)
		draw_arc(Vector2.ZERO, 26, -PI / 2, -PI / 2 + TAU * progress, 32, col, 5.0)
		# question mark
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(-8, 10), "?", HORIZONTAL_ALIGNMENT_CENTER, -1, 32, Color(0.1, 0.1, 0.1))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
