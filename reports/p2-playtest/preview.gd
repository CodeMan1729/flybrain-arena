extends SceneTree
func _initialize() -> void:
	capture.call_deferred()
func save_frame(path: String) -> void:
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../reports/p2-playtest/"+path))
	print(path+" result="+str(error))
func capture() -> void:
	root.size = Vector2i(1280,720)
	var game = load("res://main.tscn").instantiate()
	game.settings_path = ""
	root.add_child(game)
	game.director.set_process(false)
	game.fly.set_physics_process(false)
	game.start_game()
	# Do not let OS focus events pause this automated render fixture.
	for c in root.focus_exited.get_connections(): root.focus_exited.disconnect(c.callable)
	game.player.set_physics_process(false)
	await save_frame("weapon-idle.png")
	game.player.weapon_view.set_process(false)
	game.player.fire()
	await save_frame("weapon-fire.png")
	game.pause_game()
	await save_frame("weapon-paused.png")
	await game.quit_game(0)
