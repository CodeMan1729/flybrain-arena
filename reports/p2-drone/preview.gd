extends SceneTree

func _initialize() -> void:
	capture.call_deferred()

func capture() -> void:
	root.size = Vector2i(1100,700)
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.025,0.04,0.055)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.6,0.7,0.8)
	environment.environment.ambient_light_energy = 0.8
	scene.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-30,0)
	light.light_energy = 2.0
	scene.add_child(light)
	var drone = load("res://drone.gd").new()
	scene.add_child(drone)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0.42,0.4,-0.55)
	camera.look_at(Vector3.ZERO)
	camera.fov = 38
	camera.current = true
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://../reports/p2-drone/drone-preview.png")
	var error := root.get_texture().get_image().save_png(path)
	print("PREVIEW: "+path+" result="+str(error))
	scene.queue_free()
	await process_frame
	# Capture the actual menu separately, without starting a neural session.
	var game = load("res://main.tscn").instantiate()
	game.settings_path = ""
	root.add_child(game)
	game.director.set_process(false)
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	error = root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../reports/p2-drone/menu-preview.png"))
	print("MENU result="+str(error))
	await game.quit_game(0 if error == OK else 1)
