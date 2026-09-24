extends SceneTree

func _initialize() -> void:
	capture.call_deferred()

func save_frame(path: String) -> void:
	await create_timer(.25).timeout # Settle native cursor-mode/window redraw and 10 Hz HUD.
	for _frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../reports/p4-feedback/"+path))
	print(path+" result="+str(error))
	if error!=OK: quit(1)

func capture() -> void:
	root.size=Vector2i(1280,720)
	var game=load("res://main.tscn").instantiate()
	game.settings_path=""
	root.add_child(game)
	game.director.set_process(false)
	game.fly.set_physics_process(false)
	game.player.set_physics_process(false)
	game.combat_feedback.set_process(false)
	game.player.weapon_view.set_process(false)
	for connection in root.focus_exited.get_connections(): root.focus_exited.disconnect(connection.callable)
	game.start_game()
	game.player.position=Vector3(0,0,4)
	game.player.rotation=Vector3.ZERO
	game.player.camera.rotation=Vector3.ZERO
	game.fly.position=Vector3(0,1.65,0)
	await physics_frame
	await save_frame("arena-ready.png")
	game.player.fire()
	await save_frame("arena-hit.png")
	game.pause_game()
	await save_frame("arena-paused.png")
	game.resume_game()
	await process_frame
	await process_frame
	# Complete the remaining six real hitscans; only the fixture cooldown is bypassed.
	for _shot in 6:
		game.player.fire_ready=0
		game.player.fire()
		await process_frame
	print("Victory fixture: outcome=",game.round_outcome," hp=",game.fly.hp," menu=",game.menu.visible," title=",game.menu_title.text)
	if not game.completed or game.round_outcome!="won" or game.fly.hp!=0 or not game.menu.visible:
		await game.quit_game(1)
		return
	await save_frame("arena-won.png")
	await game.quit_game()
