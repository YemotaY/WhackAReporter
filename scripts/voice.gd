class_name VoiceBox
extends Node
## Plays neural-TTS voice clips with matching on-screen subtitles.
## Text and clip keys come from assets/voice/dialogue.json — regenerate the
## WAVs with `python3 tools/tts_pipeline.py` after editing the dialogue.
##
## Q&A flow: a reporter pops up and asks `qa_<id>_q`; if bonked, playback stops
## and the president delivers the matching `qa_<id>_a` punchline.

const DIALOGUE_PATH := "res://assets/voice/dialogue.json"
const VOICE_DIR := "res://assets/voice/"

var subtitle_label: Label
var qa_ids: Array[String] = []

var _lines := {}  # key -> {stream, text, is_prez}
var _player: AudioStreamPlayer
var _sub_tween: Tween

func _ready() -> void:
	_load_dialogue()
	_player = AudioStreamPlayer.new()
	add_child(_player)

func _load_dialogue() -> void:
	var f := FileAccess.open(DIALOGUE_PATH, FileAccess.READ)
	var data: Array = JSON.parse_string(f.get_as_text())
	for i in range(0,len(data)):
		var lang = str(Array(data[i].keys())[0])
		#push_error("lang : " + lang)
		for key in data[i][lang]["lines"]: # HIER NICHT DAS LOCALE NUTZEN SONDERN AUS DER ITERATION DEN LÄNDESCHLÜSSEL
			#push_error("data[i][lang]['qa']"+str(data[i][lang]["lines"]))
			_register(key +"_"+ lang, data[i][lang]["lines"][key],lang)
		for qa in data[i][lang]["qa"]:
			#push_error("data[i][lang]['qa']"+str(data[i][lang]["qa"]))
			var id: String = qa["id"] + "_" + lang
			_register("qa_%s_q" % id, qa["question"],lang)
			_register("qa_%s_a" % id, qa["answer"],lang)
			qa_ids.append(id)


func _register(key: String, line: Dictionary, language:String) -> void:
	#push_error("_register key/line : " + str(key) + " / " + str(line))
	var path := VOICE_DIR + language  +"/"+ key + ".wav"
	
	if not ResourceLoader.exists(path):
		push_warning("VoiceBox: missing clip %s (run tools/tts_pipeline.py)" % path)
		return
	_lines[key] = {
		"stream": load(path),
		"text": "\"%s\"" % line["text"],
		"is_prez": String(line["speaker"]) == "president",
	}

func say(key: String) -> void:

	if not _lines.has(key):
		return

	var line: Dictionary = _lines[key]
	#push_error("line : " + str(line))
	#push_error("key : " + key)
	_player.stop()
	_player.stream = line["stream"]
	_player.play()
	_show_subtitle(line["text"], line["is_prez"])

func say_random(prefix: String, count: int) -> void:
	#push_error("say_random: prefix/count" + prefix + "/" + str(count))
	say("%s%d" % [prefix, randi() % count + 1])

func random_qa() -> String:
	var target = qa_ids[randi() % qa_ids.size()]
	#push_error("random_qa target: " + target)
	return target

func ask_question(qa_id: String) -> void:
	#push_error("ask_question: " + qa_id)
	say("qa_%s_q" % qa_id)

func answer_question(qa_id: String) -> void:
	#push_error("answer_question: " + qa_id)
	stop()  # cut the reporter off mid-question
	say("qa_%s_a" % qa_id)

func question_duration(qa_id: String) -> float:
	#push_error("question_duration: " + qa_id)
	var key := "qa_%s_q" % qa_id
	if not _lines.has(key):
		return 0.0
	return (_lines[key]["stream"] as AudioStream).get_length()

func stop() -> void:
	_player.stop()

func is_talking() -> bool:
	return _player.playing

func _show_subtitle(text: String, is_prez: bool) -> void:
	#push_error(text)
	if subtitle_label == null:
		return
	subtitle_label.text = text
	subtitle_label.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.3) if is_prez else Color(0.75, 0.9, 1.0))
	subtitle_label.modulate.a = 1.0
	if _sub_tween and _sub_tween.is_valid():
		_sub_tween.kill()
	_sub_tween = create_tween()
	_sub_tween.tween_interval(3.0)
	_sub_tween.tween_property(subtitle_label, "modulate:a", 0.0, 0.5)
