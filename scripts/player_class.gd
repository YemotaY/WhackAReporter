class_name Player
extends Node2D
'''
Das ist die Spielerklasse.
Hält die wichtigsten stati zum spieler + versucht zu laden aus cache  (itch)
'''

var user_info = collect()

var lifes = 5;
var money = 9999;
var money_multiplier = 1.0;
var selected_hammer = "BASICHAMMER";
var unlocked_hammer = ["BASICHAMMER"]
var cheating_detected = false;
var time_played = 0;
var iterations = 0;

const SAVE_PATH = "user://player_class_progress.json"

static func collect() -> Dictionary:
	return {
		"system": _get_system_info(),
		"engine": _get_engine_info(),
		"display": _get_display_info(),
		"performance": _get_performance_info(),
	}

func save_player_progress(player_class: String, level: int, experience: float, unlocked_skills: Array) -> void:
	var save_data = {
		"player_class": player_class,
		"level": level,
		"experience": experience,
		"unlocked_skills": unlocked_skills
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_data)
		file.store_string(json_string)
		file.close()
	else:
		push_error("Failed to open save file. Error code: ", FileAccess.get_open_error())

func load_player_progress() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found. Returning default stats.")
		return {} # Handle default character creation/stats here
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			return json.get_data()
		else:
			push_error("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
			
	return {}

static func _get_system_info() -> Dictionary:
	var info := {
		"os_name": OS.get_name(),
		"model_name": OS.get_model_name(),
		"processor_name": OS.get_processor_name(),
		"processor_count": OS.get_processor_count(),
		"executable_path": OS.get_executable_path(),
		"user_data_dir": OS.get_user_data_dir(),
		"locale": OS.get_locale(),
		"is_debug_build": OS.is_debug_build(),
		"has_feature_vulkan": OS.has_feature("vulkan"),
		"has_feature_opengl3": OS.has_feature("opengl3"),
	}

	# Memory information is available on supported Godot 4 versions.
	info["memory"] = OS.get_memory_info()

	return info


static func _get_engine_info() -> Dictionary:
	return {
		"version": Engine.get_version_info(),
		"is_editor_hint": Engine.is_editor_hint(),
		"time_scale": Engine.time_scale,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"max_fps": Engine.max_fps
	}


static func _get_display_info() -> Dictionary:
	var screen := DisplayServer.window_get_current_screen()

	return {
		"screen_count": DisplayServer.get_screen_count(),
		"current_screen": screen,
		"screen_size": DisplayServer.screen_get_size(screen),
		"screen_dpi": DisplayServer.screen_get_dpi(screen),
		"screen_scale": DisplayServer.screen_get_scale(screen),
		"screen_refresh_rate": DisplayServer.screen_get_refresh_rate(screen),
		"window_size": DisplayServer.window_get_size(),
		"window_position": DisplayServer.window_get_position(),
		"window_mode": DisplayServer.window_get_mode(),
		"window_vsync_mode": DisplayServer.window_get_vsync_mode(),
		"rendering_method": _get_rendering_method(),
	}


static func _get_rendering_method() -> String:
	if Engine.has_meta("unused_system_info_key"):
		return "unknown"

	# Rendering method is configured in project settings.
	return str(
		ProjectSettings.get_setting(
			"rendering/renderer/rendering_method",
            "unknown"
		)
	)


static func _get_performance_info() -> Dictionary:
	return {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"process_time": Performance.get_monitor(Performance.TIME_PROCESS),
		"physics_process_time": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
		"static_memory": Performance.get_monitor(Performance.MEMORY_STATIC),
		"static_memory_max": Performance.get_monitor(Performance.MEMORY_STATIC_MAX),
		"object_count": Performance.get_monitor(Performance.OBJECT_COUNT),
		"resource_count": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphan_node_count": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"render_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"render_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
	}
