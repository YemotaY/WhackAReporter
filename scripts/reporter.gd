class_name Reporter
extends Node2D
## The reporter that pops out of a hole. Drawn procedurally.

const SKIN := Color(0.96, 0.80, 0.66)
const SUITS := [Color(0.25, 0.28, 0.40), Color(0.35, 0.22, 0.22), Color(0.20, 0.35, 0.28)]
const HAIRS := [Color(0.25, 0.18, 0.12), Color(0.55, 0.45, 0.30), Color(0.15, 0.15, 0.15), Color(0.6, 0.6, 0.6)]

var suit_color: Color = SUITS[0]
var hair_color: Color = HAIRS[0]
var bonked := false
var mic_wobble := 0.0

func _ready() -> void:
	randomize_look()

func randomize_look() -> void:
	suit_color = SUITS[randi() % SUITS.size()]
	hair_color = HAIRS[randi() % HAIRS.size()]
	bonked = false
	queue_redraw()

func _process(delta: float) -> void:
	mic_wobble += delta * 8.0
	queue_redraw()

func _draw() -> void:
	# Body / suit
	draw_rect(Rect2(-26, -30, 52, 70), suit_color)
	# Shirt + tie
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -30), Vector2(10, -30), Vector2(0, -6)]), Color.WHITE)
	draw_colored_polygon(PackedVector2Array([Vector2(-4, -28), Vector2(4, -28), Vector2(2, -8), Vector2(-2, -8)]), Color(0.8, 0.15, 0.15))
	# Head
	draw_circle(Vector2(0, -52), 22, SKIN)
	# Hair
	draw_circle(Vector2(0, -62), 18, hair_color)
	draw_rect(Rect2(-20, -66, 40, 8), hair_color)
	# Press hat card
	draw_rect(Rect2(-14, -80, 28, 10), Color(0.9, 0.9, 0.85))
	# Eyes
	if bonked:
		_draw_x(Vector2(-8, -54)); _draw_x(Vector2(8, -54))
	else:
		draw_circle(Vector2(-8, -54), 3, Color.BLACK)
		draw_circle(Vector2(8, -54), 3, Color.BLACK)
	# Mouth (open = asking)
	draw_circle(Vector2(0, -42), 4 if not bonked else 2, Color(0.5, 0.1, 0.1))
	# Microphone arm + mic (wobbles)
	var mw := sin(mic_wobble) * 3.0
	draw_line(Vector2(24, -10), Vector2(34, -40 + mw), suit_color.darkened(0.2), 8.0)
	draw_circle(Vector2(-30, -5), 7, SKIN)  # left hand with notepad
	draw_rect(Rect2(-40, -14, 16, 20), Color(0.95, 0.95, 0.9))
	draw_circle(Vector2(34, -44 + mw), 8, Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(31, -40 + mw, 6, 14), Color(0.35, 0.35, 0.35))

func _draw_x(p: Vector2) -> void:
	draw_line(p + Vector2(-4, -4), p + Vector2(4, 4), Color.BLACK, 2.0)
	draw_line(p + Vector2(-4, 4), p + Vector2(4, -4), Color.BLACK, 2.0)
