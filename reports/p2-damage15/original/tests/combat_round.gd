extends SceneTree

# Offline physics fixture, not a neural measurement. Full graph coverage is in smoke.
var failures: Array[String] = []

func verify(condition: bool, description: String) -> void:
	print(("PASS: " if condition else "FAIL: ")+description)
	if not condition: failures.append(description)

func _initialize() -> void:
	run_checks.call_deferred()

func run_checks() -> void:
	var game = load("res://main.tscn").instantiate()
	game.settings_path = ""
	root.add_child(game)
	game.director.set_process(false)
	game.fly.set_physics_process(false)
	game.start_game()
	game.player.position = Vector3(0,0,4)
	game.player.rotation = Vector3.ZERO
	game.player.camera.rotation = Vector3.ZERO
	game.fly.position = Vector3(0,1.65,0)
	await physics_frame
	await physics_frame
	for shot in 10:
		game.player.fire_ready = 0 # Cooldown is separately covered in gameplay.gd.
		game.player.fire()
		verify(game.fly.hp == 100-(shot+1)*10,"Hitscan HP step "+str(shot+1))
	verify(game.completed and game.round_outcome == "won" and game.menu.visible,"Defeated signal settles a win")
	verify(not game.player.active and not game.fly.active and not game.director.running,"Win stops both bodies and decisions")
	verify(not game.fly.buzz.playing and not game.footsteps.playing,"Win clears audio")
	game.lose_game()
	verify(game.round_outcome == "won","Late loss does not overwrite a settled win")
	game.start_game()
	verify(not game.completed and game.round_outcome.is_empty() and game.player.hp == 100 and game.fly.hp == 100,"Restart resets HP and result")
	game.director.has_round = false # Offline fixture has no WebSocket session to finish.
	game.director.connected = true
	game.director.neural = {"output":[0.001,0,0,0]}
	game.director.last_neural_time = game.director.now()
	game.player.position = Vector3(0,0,0)
	game.fly.position = Vector3(0,1.25,0.2)
	await physics_frame
	game.fly._physics_process(0.001)
	verify(game.completed and game.round_outcome == "lost" and game.player.hp == 0,"Contact signal settles defeat without restoring dead HP")
	verify(game.menu.visible and not game.player.active and not game.fly.active and not game.director.running,"Defeat freezes round and returns to menu")
	game.win_game()
	verify(game.round_outcome == "lost" and game.player.hp == 0,"Late win preserves defeat and zero HP")
	game.director.connected = false
	game.start_game()
	verify(game.player.hp == 100 and game.fly.hp == 100 and game.player.active,"Restart after defeat is playable")
	await game.quit_game(0 if failures.is_empty() else 1)
