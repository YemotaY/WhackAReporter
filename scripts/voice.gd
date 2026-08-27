class_name VoiceBox
extends Node
## Plays voice clips with matching on-screen subtitles.
## Clips are retro babble placeholders — drop real voice-actor WAVs with the
## same filenames into assets/voice/ to replace them.

const LINES := {
	"reporter_q1": ["res://assets/voice/reporter_q1.wav", "\"Mr. Präsident, about those classified emails...?\""],
	"reporter_q2": ["res://assets/voice/reporter_q2.wav", "\"Sir, is it true the budget was spent on golf carts?\""],
	"reporter_q3": ["res://assets/voice/reporter_q3.wav", "\"Can you explain the missing 40 billion?\""],
	"reporter_q4": ["res://assets/voice/reporter_q4.wav", "\"Why does your cousin run the treasury?\""],
	"prez_whack1": ["res://assets/voice/prez_whack1.wav", "\"FAKE NEWS!\""],
	"prez_whack2": ["res://assets/voice/prez_whack2.wav", "\"NEXT QUESTION!\""],
	"prez_whack3": ["res://assets/voice/prez_whack3.wav", "\"WRONG!\""],
	"prez_start": ["res://assets/voice/prez_start.wav", "\"This briefing will be tremendous. The best briefing.\""],
	"prez_over": ["res://assets/voice/prez_over.wav", "\"I am being impeached bigly. Very unfair!\""],
	"prez_taunt1": ["res://assets/voice/prez_taunt1.wav", "\"Nobody asks questions better than me.\""],
	"prez_level2": ["res://assets/voice/prez_level2.wav", "\"They're moving?! Tremendous cowards!\""],
}

var subtitle_label: Label
var _streams := {}
var _player: AudioStreamPlayer
var _sub_tween: Tween

func _ready() -> void:
	for key in LINES:
		_streams[key] = load(LINES[key][0])
	_player = AudioStreamPlayer.new()
	add_child(_player)

func say(key: String) -> void:
	if not _streams.has(key):
		return
	_player.stop()
	_player.stream = _streams[key]
	_player.pitch_scale = randf_range(0.97, 1.03)
	_player.play()
	_show_subtitle(LINES[key][1], key.begins_with("prez"))

func say_random(prefix: String, count: int) -> void:
	say("%s%d" % [prefix, randi() % count + 1])

func _show_subtitle(text: String, is_prez: bool) -> void:
	if subtitle_label == null:
		return
	subtitle_label.text = text
	subtitle_label.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.3) if is_prez else Color(0.75, 0.9, 1.0))
	subtitle_label.modulate.a = 1.0
	if _sub_tween and _sub_tween.is_valid():
		_sub_tween.kill()
	_sub_tween = create_tween()
	_sub_tween.tween_interval(1.8)
	_sub_tween.tween_property(subtitle_label, "modulate:a", 0.0, 0.5)
