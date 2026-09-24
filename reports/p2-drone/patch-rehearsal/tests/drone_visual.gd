extends SceneTree

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
	game.director.set_process(false)
	game.fly.set_physics_process(false)
	verify(game.fly.name == "Drone", "Scene body is named Drone")
	verify(game.get_window().title == "FlyBrain Arena", "Window title uses arena branding")
	verify(game.fly.body.has_node("Chassis") and game.fly.body.has_node("ForwardSensor"), "Mechanical hull and forward sensor replace insect")
	# get() makes the pre-change baseline fail assertions rather than crash.
	var rotors = game.fly.get("rotors")
	verify(rotors is Array and rotors.size() == 4, "Four independent rotors")
	verify(game.fly.body.scale.is_equal_approx(Vector3.ONE*0.5) and is_equal_approx(game.fly.get_child(0).shape.radius,0.1), "Visual scale and collision envelope preserved")
	verify(game.fly.collision_layer == 2 and game.fly.collision_mask == 1, "Weapon/world collision layers unchanged")
	if rotors is Array and rotors.size() == 4:
		game.start_game()
		game.director.has_round = false
		game.director.connected = true
		game.director.neural = {"output":[0.16,0.06,0.08,0.04]}
		game.director.last_neural_time = game.director.now()
		game.player.active = false
		await physics_frame
		game.fly._physics_process(0.01)
		verify(rotors[0].rotation.y > 0 and rotors[1].rotation.y < 0, "Counter-rotating cosmetic animation")
		game.fly.active = false
		var angle: float = rotors[0].rotation.y
		game.fly._physics_process(0.1)
		verify(is_equal_approx(rotors[0].rotation.y,angle) and not game.fly.buzz.playing, "Inactive body freezes rotors and audio")
	game.director.connected = false
	await game.quit_game(0 if failures.is_empty() else 1)
