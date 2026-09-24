extends SceneTree

# Offline body-controller regression. Recorded drives are not a live neural run.
var failures: Array[String] = []

func verify(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures.append(label)

func _initialize() -> void:
	run_checks.call_deferred()

func run_checks() -> void:
	var game = load("res://main.tscn").instantiate()
	game.settings_path = ""
	root.add_child(game)
	game.set_process(false)
	game.director.set_process(false)
	game.set_volume(0)
	var drives := [[0.16,0.06,0.08,0.04],
		[-0.05011754855513573,-0.03581318259239197,-0.015312639996409416,0.01400546170771122],
		[-0.19101500511169434,-0.141165092587471,-0.0650838315486908,0.05314510688185692]]
	for drive in drives:
		for seed_value in [3,17,42]:
			game.playing = false
			game.director.connected = false
			game.start_game()
			game.director.has_round = false
			game.director.seed_value = seed_value
			game.fly.reset_body()
			game.director.connected = true
			game.director.neural = {"output":drive}
			var peak := 0.0
			var frames := 0
			while not game.completed and frames<600:
				game.director.last_neural_time = game.director.now()
				await physics_frame
				peak = maxf(peak,game.fly.velocity.length())
				frames += 1
			verify(game.round_outcome == "lost" and game.player.hp == 0,"Default spawn autonomous contact: "+str([drive[0],seed_value]))
			verify(peak<=8.01,"Speed bound during pursuit")
			print(JSON.stringify({"seed":seed_value,"drive":drive,"frames":frames,"peak_speed":peak}))
	game.playing = false
	game.director.connected = false
	# Nearby but occluded: proximity alone must not damage through a wall.
	game.start_game()
	game.director.has_round = false
	game.director.connected = true
	game.director.neural = {"output":drives[0]}
	game.player.set_physics_process(false)
	game.player.position = Vector3(0,0,0)
	game.fly.position = Vector3(0,1.25,0.4)
	game.fly.gaze = Vector3.FORWARD
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4,4,0.1)
	collision.shape = box
	wall.add_child(collision)
	wall.position = Vector3(0,1.25,0.2)
	game.add_child(wall)
	for frame in 12:
		game.director.last_neural_time = game.director.now()
		await physics_frame
	verify(game.player.hp == 100 and not game.completed and game.fly.sight.is_empty(),"Wall blocks close-range contact and telemetry")
	game.director.connected = false
	await game.quit_game(0 if failures.is_empty() else 1)
