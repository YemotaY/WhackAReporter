extends SceneTree
## Headless smoke test: loads the main scene, starts the game, forces spawns,
## simulates whacks and missed questions through to game over.

func _initialize() -> void:
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	assert(main.holes.size() == 6, "expected 6 holes")
	assert(main.game_state == main.GameState.MENU, "should start in menu")

	# Start game
	main._start_game()
	assert(main.game_state == main.GameState.PLAYING, "should be playing")
	assert(main.lives == 3 and main.score == 0, "fresh state")
	main.spawn_timer = 999.0  # suppress auto-spawn for deterministic test

	# Force a spawn and let the pop-up animation finish
	main.voice.stop()  # intro monologue blocks spawns at early levels
	main._spawn_reporter()
	main.spawn_timer = 999.0
	var busy: Array = main.holes.filter(func(h): return h.is_busy())
	assert(busy.size() == 1, "one reporter should be up")
	var hole: Hole = busy[0]
	await create_timer(0.4).timeout
	assert(hole.state == Hole.State.UP, "reporter should be fully up")

	# Whack it (aim at head)
	var hit: bool = hole.try_whack(hole.global_position + Vector2(0, -85))
	assert(hit, "whack should land")
	assert(main.score == 100, "score should be 100, got %d" % main.score)
	assert(main.combo == 1, "combo should be 1")
	# Bonk cuts the question and the president answers
	assert(main.voice.is_talking(), "president should be answering after bonk")
	assert(main.subtitle_label.text != "", "answer subtitle shown")

	# Whack far away should miss
	await create_timer(0.6).timeout
	main.voice.stop()
	main._spawn_reporter()
	main.spawn_timer = 999.0
	var busy2: Array = main.holes.filter(func(h): return h.is_busy())
	var hole2: Hole = busy2[0]
	var miss: bool = hole2.try_whack(hole2.global_position + Vector2(300, 300))
	assert(not miss, "far whack should miss")
	# Hit window must cover the spoken question at level 1
	var qa_id: String = main.hole_qa[hole2]
	assert(hole2.question_time >= main.voice.question_duration(qa_id), "hit time >= question length")

	# Let the question complete -> lose a life
	await create_timer(hole2.question_time + 1.0).timeout
	assert(main.lives == 2, "should have lost a life, lives=%d" % main.lives)

	# Drain remaining lives -> game over
	main._on_question_asked(hole)
	main._on_question_asked(hole)
	assert(main.lives <= 0, "no lives left")
	assert(main.game_state == main.GameState.GAME_OVER, "should be game over")
	assert(main.game_over_panel.visible, "game over panel visible")

	# Restart works
	main._start_game()
	assert(main.game_state == main.GameState.PLAYING and main.lives == 3, "restart ok")

	# Level 2: time-based, holes move
	assert(main.level == 1, "starts at level 1")
	main.elapsed = main.LEVEL_DURATION + 0.1
	await process_frame
	await process_frame
	assert(main.level == 2, "should be level 2")
	var x_before: float = main.holes[0].position.x
	await create_timer(0.5).timeout
	assert(absf(main.holes[0].position.x - x_before) > 1.0, "holes should move in level 2")

	# Z-order: bottom row must render in front of top row
	assert(main.holes[3].z_index > main.holes[0].z_index, "bottom row in front")

	# Voice system wired
	assert(main.voice != null and main.voice.subtitle_label != null, "voice box wired")
	main.voice.say("prez_whack1")
	assert(main.subtitle_label.text != "", "subtitle shown")

	# Q&A dialogue loaded from dialogue.json
	assert(main.voice.qa_ids.size() >= 8, "qa pairs loaded")
	main.voice.ask_question("economy")
	assert(main.voice.is_talking(), "question playing")
	assert(main.subtitle_label.text.contains("nine percent"), "question subtitle shown")
	main.voice.answer_question("economy")
	assert(main.subtitle_label.text.contains("minus nine percent"), "answer subtitle shown")
	assert(main.voice.question_duration("economy") > 1.0, "question has real duration")

	# Leaderboard
	main.leaderboard = []
	main.add_leaderboard_entry("zz", 500, 2)
	main.add_leaderboard_entry("aaa", 900, 3)
	assert(main.leaderboard[0]["name"] == "AAA" and int(main.leaderboard[0]["score"]) == 900, "sorted board")
	assert(main.leaderboard[1]["name"] == "ZZ", "uppercased name")
	assert(main._qualifies_for_board(1) == true, "qualifies when board not full")
	main._load_leaderboard()
	assert(main.leaderboard.size() >= 2, "leaderboard persisted to disk")

	# Victory path
	main.elapsed = main.LEVEL_DURATION * main.MAX_LEVEL + 0.1
	await process_frame
	await process_frame
	assert(main.game_state == main.GameState.VICTORY, "should reach victory after full term")
	assert(main.game_over_panel.visible, "end panel visible on victory")

	print("ALL SMOKE TESTS PASSED")
	quit(0)
