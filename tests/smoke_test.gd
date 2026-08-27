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

	# Whack far away should miss
	await create_timer(0.6).timeout
	main._spawn_reporter()
	main.spawn_timer = 999.0
	var busy2: Array = main.holes.filter(func(h): return h.is_busy())
	var hole2: Hole = busy2[0]
	var miss: bool = hole2.try_whack(hole2.global_position + Vector2(300, 300))
	assert(not miss, "far whack should miss")

	# Let the question complete -> lose a life
	await create_timer(3.0).timeout
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

	print("ALL SMOKE TESTS PASSED")
	quit(0)
