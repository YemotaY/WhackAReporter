extends Node2D
## Main game: spawning, score, approval (lives), difficulty, UI, sound.

const GRID_COLS := 3
const GRID_ROWS := 2
const START_LIVES := 3

enum GameState { MENU, PLAYING, GAME_OVER }

var game_state: int = GameState.MENU
var score := 0
var lives := START_LIVES
var combo := 0
var high_score := 0
var elapsed := 0.0
var spawn_timer := 0.0

var holes: Array[Hole] = []
var hammer: Hammer

@onready var sfx := {
	"whack": preload("res://assets/sfx/whack.wav"),
	"pop": preload("res://assets/sfx/pop.wav"),
	"question": preload("res://assets/sfx/question.wav"),
	"miss": preload("res://assets/sfx/miss.wav"),
	"fail": preload("res://assets/sfx/fail.wav"),
	"start": preload("res://assets/sfx/start.wav"),
	"tick": preload("res://assets/sfx/tick.wav"),
}

@onready var score_label: Label = %ScoreLabel
@onready var lives_label: Label = %LivesLabel
@onready var combo_label: Label = %ComboLabel
@onready var menu_panel: Control = %MenuPanel
@onready var game_over_panel: Control = %GameOverPanel
@onready var final_label: Label = %FinalLabel

func _ready() -> void:
	_build_background()
	_build_holes()
	hammer = Hammer.new()
	add_child(hammer)
	menu_panel.visible = true
	game_over_panel.visible = false
	%StartButton.pressed.connect(_start_game)
	%RetryButton.pressed.connect(_start_game)
	_update_hud()

func _build_background() -> void:
	var bg := BriefingRoomBG.new()
	bg.z_index = -10
	add_child(bg)

func _build_holes() -> void:
	for r in GRID_ROWS:
		for c in GRID_COLS:
			var hole := Hole.new()
			hole.position = Vector2(240 + c * 240, 280 + r * 210)
			hole.whacked.connect(_on_whacked)
			hole.question_asked.connect(_on_question_asked)
			add_child(hole)
			holes.append(hole)

func _start_game() -> void:
	score = 0
	lives = START_LIVES
	combo = 0
	elapsed = 0.0
	spawn_timer = 0.6
	game_state = GameState.PLAYING
	menu_panel.visible = false
	game_over_panel.visible = false
	for h in holes:
		h.force_sink()
	_play("start")
	_update_hud()

func _process(delta: float) -> void:
	if game_state != GameState.PLAYING:
		return
	elapsed += delta
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_reporter()
		spawn_timer = _spawn_interval()

func _spawn_interval() -> float:
	# Gets faster over time: 1.5s -> 0.55s
	return max(0.55, 1.5 - elapsed * 0.02) * randf_range(0.8, 1.2)

func _question_time() -> float:
	# Reporters ask faster over time: 2.4s -> 1.0s
	return max(1.0, 2.4 - elapsed * 0.025)

func _spawn_reporter() -> void:
	var free := holes.filter(func(h): return not h.is_busy())
	if free.is_empty():
		return
	var hole: Hole = free[randi() % free.size()]
	hole.pop_up(0.25, _question_time())
	_play("pop")

func _unhandled_input(event: InputEvent) -> void:
	if game_state != GameState.PLAYING:
		return
	if event.is_action_pressed("whack"):
		hammer.swing()
		var pos := get_global_mouse_position()
		var hit := false
		for h in holes:
			if h.try_whack(pos):
				hit = true
				break
		if not hit:
			combo = 0
			_play("miss")
			_update_hud()

func _on_whacked(hole: Hole) -> void:
	combo += 1
	score += 100 * combo
	_play("whack")
	_shake()
	_spawn_score_popup(hole.global_position + Vector2(0, -120), "+%d" % (100 * combo))
	_update_hud()

func _on_question_asked(_hole: Hole) -> void:
	lives -= 1
	combo = 0
	_play("question")
	_update_hud()
	if lives <= 0:
		_game_over()

func _game_over() -> void:
	game_state = GameState.GAME_OVER
	high_score = max(high_score, score)
	for h in holes:
		h.force_sink()
	_play("fail")
	final_label.text = "Final Score: %d\nBest: %d" % [score, high_score]
	game_over_panel.visible = true

func _update_hud() -> void:
	score_label.text = "Score: %d" % score
	lives_label.text = "Approval: " + "❤".repeat(max(0, lives)) + "♡".repeat(START_LIVES - max(0, lives))
	combo_label.text = "Combo x%d" % combo if combo > 1 else ""

func _spawn_score_popup(pos: Vector2, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.position = pos
	lbl.z_index = 50
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", pos.y - 60, 0.7)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tw.chain().tween_callback(lbl.queue_free)

func _shake() -> void:
	var cam := get_viewport().get_camera_2d()
	var tw := create_tween()
	var orig := Vector2.ZERO
	tw.tween_method(func(t: float):
		position = orig + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 8.0 * (1.0 - t),
		0.0, 1.0, 0.2)
	tw.tween_callback(func(): position = orig)

func _play(sfx_name: String) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = sfx[sfx_name]
	p.pitch_scale = randf_range(0.95, 1.05)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


class BriefingRoomBG extends Node2D:
	func _draw() -> void:
		# Wall
		draw_rect(Rect2(0, 0, 960, 640), Color(0.16, 0.22, 0.36))
		# Curtains
		for i in 12:
			var x := i * 80.0
			draw_rect(Rect2(x, 0, 40, 170), Color(0.12, 0.17, 0.30))
		# Presidential seal
		draw_circle(Vector2(480, 100), 55, Color(0.85, 0.75, 0.35))
		draw_circle(Vector2(480, 100), 46, Color(0.16, 0.22, 0.36))
		draw_circle(Vector2(480, 100), 38, Color(0.85, 0.75, 0.35))
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(480 - 34, 108), "POTUS", HORIZONTAL_ALIGNMENT_CENTER, 68, 18, Color(0.16, 0.22, 0.36))
		# Floor (press room carpet)
		draw_rect(Rect2(0, 175, 960, 465), Color(0.35, 0.15, 0.16))
		draw_rect(Rect2(0, 175, 960, 10), Color(0.25, 0.10, 0.11))
