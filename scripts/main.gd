extends Node2D
## Main game: spawning, score, approval (lives), difficulty, UI, sound.

const GRID_COLS := 3
const GRID_ROWS := 2
const START_LIVES := 3
const LEVEL2_SCORE := 1500
const HOLE_MOVE_AMPLITUDE := 70.0
const HOLE_MOVE_SPEED := 1.6

enum GameState { MENU, PLAYING, GAME_OVER }

var game_state: int = GameState.MENU
var score := 0
var lives := START_LIVES
var combo := 0
var high_score := 0
var elapsed := 0.0
var spawn_timer := 0.0
var level := 1

var holes: Array[Hole] = []
var hole_base_pos: Array[Vector2] = []
var hammer: Hammer
var voice: VoiceBox

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
@onready var level_label: Label = %LevelLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var coin_label: Label = %CoinLabel

func _ready() -> void:
	_build_background()
	_build_holes()
	# Hammer lives on its own CanvasLayer above all UI (layer > UI's default 1).
	var hammer_layer := CanvasLayer.new()
	hammer_layer.layer = 100
	add_child(hammer_layer)
	hammer = Hammer.new()
	hammer_layer.add_child(hammer)
	voice = VoiceBox.new()
	voice.subtitle_label = subtitle_label
	add_child(voice)
	menu_panel.visible = true
	game_over_panel.visible = false
	%StartButton.pressed.connect(_start_game)
	%RetryButton.pressed.connect(_start_game)
	_blink_coin_label()
	_update_hud()

func _blink_coin_label() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(coin_label, "modulate:a", 0.15, 0.5)
	tw.tween_property(coin_label, "modulate:a", 1.0, 0.5)

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
			hole_base_pos.append(hole.position)

func _start_game() -> void:
	score = 0
	lives = START_LIVES
	combo = 0
	elapsed = 0.0
	spawn_timer = 0.6
	level = 1
	game_state = GameState.PLAYING
	menu_panel.visible = false
	game_over_panel.visible = false
	for i in holes.size():
		holes[i].force_sink()
		holes[i].position = hole_base_pos[i]
	_play("start")
	voice.say("prez_start")
	_update_hud()

func _process(delta: float) -> void:
	if game_state != GameState.PLAYING:
		return
	elapsed += delta
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_reporter()
		spawn_timer = _spawn_interval()
	if level == 1 and score >= LEVEL2_SCORE:
		_enter_level2()
	if level >= 2:
		_move_holes(delta)

func _enter_level2() -> void:
	level = 2
	voice.say("prez_level2")
	_spawn_banner("LEVEL 2 — THEY'RE MOVING!")
	_update_hud()

func _move_holes(_delta: float) -> void:
	for i in holes.size():
		var phase := float(i) * 1.1
		var dir := 1.0 if i % 2 == 0 else -1.0
		holes[i].position.x = hole_base_pos[i].x \
			+ dir * sin(elapsed * HOLE_MOVE_SPEED + phase) * HOLE_MOVE_AMPLITUDE

func _spawn_banner(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 48)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 10)
	lbl.size = Vector2(960, 80)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0, 250)
	lbl.z_index = 60
	lbl.scale = Vector2(0.2, 0.2)
	lbl.pivot_offset = Vector2(480, 40)
	add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(lbl.queue_free)

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
	if randf() < 0.55:
		voice.say_random("reporter_q", 4)

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
	if randf() < 0.4:
		voice.say_random("prez_whack", 3)
	elif combo >= 5 and randf() < 0.5:
		voice.say("prez_taunt1")
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
	voice.say("prez_over")
	final_label.text = "FINAL SCORE %06d\nBEST %06d" % [score, high_score]
	game_over_panel.visible = true

func _update_hud() -> void:
	score_label.text = "SCORE %06d" % score
	lives_label.text = "APPROVAL " + "❤".repeat(max(0, lives)) + "♡".repeat(START_LIVES - max(0, lives))
	combo_label.text = "COMBO x%d" % combo if combo > 1 else ""
	level_label.text = "LEVEL %d" % level

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
