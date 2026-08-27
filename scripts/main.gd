extends Node2D
## Main game: spawning, score, approval (lives), difficulty, UI, sound.

const GRID_COLS := 3
const GRID_ROWS := 2
const START_LIVES := 3
const LEVEL_DURATION := 120.0      # seconds per level
const MAX_LEVEL := 10              # 10 levels x 2 min = 20 min campaign
const HOLE_MOVE_AMPLITUDE := 70.0
const LEADERBOARD_PATH := "user://leaderboard.json"
const LEADERBOARD_SIZE := 10
const URL_GITHUB := "https://github.com/YemotaY/WhackAReporter"
const URL_ITCH := "https://yemotay.itch.io/whack-a-reporter"
const URL_PAYPAL := "https://www.paypal.me/YemotaY"

enum GameState { MENU, PLAYING, GAME_OVER, VICTORY }

var game_state: int = GameState.MENU
var score := 0
var lives := START_LIVES
var combo := 0
var high_score := 0
var elapsed := 0.0
var spawn_timer := 0.0
var level := 1
var leaderboard: Array = []  # [{name, score, level}]
var heard_qa := {}          # qa_id -> true, once its question played fully
var arcade_mode := false    # true after every Q&A has been heard once
var vocal_timer := 0.0      # background vocal replay countdown (arcade mode)

var holes: Array[Hole] = []
var hole_base_pos: Array[Vector2] = []
var hole_qa := {}  # Hole -> qa id currently being asked
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
@onready var timer_label: Label = %TimerLabel
@onready var board_menu_label: Label = %BoardMenuLabel
@onready var board_over_label: Label = %BoardOverLabel
@onready var name_edit: LineEdit = %NameEdit
@onready var name_row: Control = %NameRow

func _ready() -> void:
	_load_leaderboard()
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
	%SubmitButton.pressed.connect(_submit_score)
	name_edit.text_submitted.connect(func(_t): _submit_score())
	_blink_coin_label()
	_build_link_buttons()
	_refresh_board_labels()
	_update_hud()

func _build_link_buttons() -> void:
	for panel: Control in [menu_panel, game_over_panel]:
		var vbox: VBoxContainer = panel.get_node("VBox")
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		vbox.add_child(row)
		for entry in [
			["\u2b50 GitHub", URL_GITHUB],
			["\U0001F3AE itch.io", URL_ITCH],
			["\u2764 Donate", URL_PAYPAL],
		]:
			var btn := Button.new()
			btn.text = " %s " % entry[0]
			btn.add_theme_font_size_override("font_size", 16)
			btn.tooltip_text = entry[1]
			btn.pressed.connect(OS.shell_open.bind(entry[1]))
			row.add_child(btn)

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
			# Lower rows render in front so their reporters aren't hidden
			# behind podiums of the row above.
			hole.z_index = r * 10
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
	hole_qa.clear()
	heard_qa.clear()
	arcade_mode = false
	vocal_timer = 0.0
	for i in holes.size():
		holes[i].force_sink()
		holes[i].position = hole_base_pos[i]
	_play("start")
	voice.say("prez_start")
	# Give the opening monologue room before the first reporter pops.
	spawn_timer = 6.0
	_update_hud()

func _process(delta: float) -> void:
	if game_state != GameState.PLAYING:
		return
	elapsed += delta
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_reporter()
		spawn_timer = _spawn_interval()
	if arcade_mode:
		vocal_timer -= delta
		if vocal_timer <= 0.0 and not voice.is_talking():
			# Background chatter: replay a random Q&A line, purely atmospheric.
			voice.ask_question(voice.random_qa())
			vocal_timer = _vocal_interval()
	var new_level := mini(int(elapsed / LEVEL_DURATION) + 1, MAX_LEVEL)
	if new_level > level:
		_enter_level(new_level)
	if level >= 2:
		_move_holes(delta)
	if elapsed >= LEVEL_DURATION * MAX_LEVEL:
		_victory()
	_update_timer()

func _enter_level(new_level: int) -> void:
	level = new_level
	lives = mini(lives + 1, START_LIVES + 2)  # small approval bonus per term stage
	match level:
		2:
			voice.say("prez_level2")
			_spawn_banner("LEVEL 2 — THEY'RE MOVING!")
		5:
			_spawn_banner("LEVEL 5 — MIDTERMS! FASTER!")
			voice.say("prez_taunt1")
		MAX_LEVEL:
			_spawn_banner("FINAL LEVEL — LAME DUCK FURY!")
			voice.say("prez_taunt1")
		_:
			_spawn_banner("LEVEL %d" % level)
	_play("start")
	_update_hud()

func _hole_move_speed() -> float:
	# Ramps from 1.2 at level 2 up to ~3.2 at level 10.
	return 1.2 + (level - 2) * 0.25

func _move_holes(_delta: float) -> void:
	for i in holes.size():
		var phase := float(i) * 1.1
		var dir := 1.0 if i % 2 == 0 else -1.0
		holes[i].position.x = hole_base_pos[i].x \
			+ dir * sin(elapsed * _hole_move_speed() + phase) * HOLE_MOVE_AMPLITUDE
		# From level 6 the podiums also bob vertically.
		if level >= 6:
			holes[i].position.y = hole_base_pos[i].y \
				+ cos(elapsed * _hole_move_speed() * 0.7 + phase) * 25.0

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
	var t := float(level - 1) / float(MAX_LEVEL - 1)
	if arcade_mode:
		# Pure whacking phase: frantic pace, ramping even faster with level.
		return lerpf(1.8, 0.45, t) * randf_range(0.85, 1.15)
	# Intro phase: slow, listenable pace so every Q&A plays fully once.
	return lerpf(4.0, 2.0, t) * randf_range(0.9, 1.1)

func _vocal_interval() -> float:
	# Background vocal replays start relaxed, tighten as levels ramp up.
	var t := float(level - 1) / float(MAX_LEVEL - 1)
	return lerpf(12.0, 4.0, t)

func _arcade_hit_window() -> float:
	# Fixed reaction window once vocals no longer gate the reporters.
	var t := float(level - 1) / float(MAX_LEVEL - 1)
	return lerpf(2.4, 0.9, t)

func _spawn_reporter() -> void:
	var free := holes.filter(func(h): return not h.is_busy())
	if free.is_empty():
		return
	var hole: Hole = free[randi() % free.size()]
	if not arcade_mode:
		# Intro phase: one full, uninterrupted question at a time.
		if voice.is_talking():
			return
		var unheard: Array[String] = []
		for id in voice.qa_ids:
			if not heard_qa.has(id):
				unheard.append(id)
		var qa_id: String = unheard[randi() % unheard.size()]
		heard_qa[qa_id] = true
		hole_qa[hole] = qa_id
		# Hit window = full spoken question length + grace, so it plays out.
		var q_time: float = maxf(voice.question_duration(qa_id) + 1.2, 1.2)
		hole.pop_up(0.25, q_time)
		_play("pop")
		voice.ask_question(qa_id)
		if heard_qa.size() >= voice.qa_ids.size():
			arcade_mode = true
			vocal_timer = _vocal_interval()
			_spawn_banner("NO MORE QUESTIONS — WHACK!")
		return
	# Arcade phase: reporters just pop, vocals only chatter in the background.
	hole.pop_up(0.25, _arcade_hit_window())
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
	# Question audio stops dead; the president delivers his answer.
	if hole_qa.has(hole):
		voice.answer_question(hole_qa[hole])
		hole_qa.erase(hole)
	elif arcade_mode and not voice.is_talking() and randf() < 0.3:
		voice.say_random("prez_whack", 3)
	_update_hud()

func _on_question_asked(hole: Hole) -> void:
	hole_qa.erase(hole)
	lives -= 1
	combo = 0
	_play("question")
	_update_hud()
	if lives <= 0:
		_game_over()

func _game_over() -> void:
	game_state = GameState.GAME_OVER
	_end_round("IMPEACHED!", "Too many serious questions were asked.")
	_play("fail")
	voice.say("prez_over")

func _victory() -> void:
	game_state = GameState.VICTORY
	score += 5000  # term-completion bonus
	_end_round("RE-ELECTED!", "You survived the full 20-minute term!")
	_play("start")
	voice.say("prez_won")

func _end_round(title: String, sub: String) -> void:
	high_score = max(high_score, score)
	for h in holes:
		h.force_sink()
	%OverTitle.text = title
	%OverSub.text = sub
	final_label.text = "FINAL SCORE %06d" % score
	name_row.visible = _qualifies_for_board(score)
	name_edit.text = ""
	if name_row.visible:
		name_edit.grab_focus()
	_refresh_board_labels()
	game_over_panel.visible = true

# --- Leaderboard -----------------------------------------------------------

func _load_leaderboard() -> void:
	leaderboard = []
	if FileAccess.file_exists(LEADERBOARD_PATH):
		var f := FileAccess.open(LEADERBOARD_PATH, FileAccess.READ)
		var data: Variant = JSON.parse_string(f.get_as_text())
		if data is Array:
			leaderboard = data

func _save_leaderboard() -> void:
	var f := FileAccess.open(LEADERBOARD_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(leaderboard))

func _qualifies_for_board(s: int) -> bool:
	if s <= 0:
		return false
	if leaderboard.size() < LEADERBOARD_SIZE:
		return true
	return s > int(leaderboard[-1]["score"])

func add_leaderboard_entry(entry_name: String, s: int, lvl: int) -> void:
	entry_name = entry_name.strip_edges().to_upper().substr(0, 3)
	if entry_name.is_empty():
		entry_name = "AAA"
	leaderboard.append({"name": entry_name, "score": s, "level": lvl})
	leaderboard.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	if leaderboard.size() > LEADERBOARD_SIZE:
		leaderboard.resize(LEADERBOARD_SIZE)
	_save_leaderboard()

func _submit_score() -> void:
	add_leaderboard_entry(name_edit.text, score, level)
	name_row.visible = false
	_play("tick")
	_refresh_board_labels()

func _board_text() -> String:
	if leaderboard.is_empty():
		return "— HIGH SCORES —\n(no entries yet)"
	var lines := ["— HIGH SCORES —"]
	for i in leaderboard.size():
		var e: Dictionary = leaderboard[i]
		lines.append("%2d. %-3s  %06d  LV%d" % [i + 1, e["name"], int(e["score"]), int(e["level"])])
	return "\n".join(lines)

func _refresh_board_labels() -> void:
	board_menu_label.text = _board_text()
	board_over_label.text = _board_text()

func _update_timer() -> void:
	var remaining: float = maxf(0.0, LEVEL_DURATION * MAX_LEVEL - elapsed)
	timer_label.text = "TERM %02d:%02d" % [int(remaining) / 60, int(remaining) % 60]

func _update_hud() -> void:
	score_label.text = "SCORE %06d" % score
	lives_label.text = "APPROVAL " + "❤".repeat(max(0, lives)) + "♡".repeat(maxi(0, START_LIVES - max(0, lives)))
	combo_label.text = "COMBO x%d" % combo if combo > 1 else ""
	level_label.text = "LEVEL %d/%d" % [level, MAX_LEVEL]

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
