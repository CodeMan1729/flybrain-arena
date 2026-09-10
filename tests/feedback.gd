extends SceneTree

func _initialize() -> void:
	run_check.call_deferred()

func run_check() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.decision_interval=2
	var deadline := Time.get_ticks_msec()+12000
	while game.director.info.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	if game.director.info.is_empty():
		push_error("Feedback test: server not ready")
		await game.quit_game(1)
		return
	game.start_game()
	var initial: int=game.director.updates
	while game.director.feedback_id<0 and Time.get_ticks_msec()<deadline: await process_frame
	if game.director.feedback_id<0:
		push_error("Feedback test: no applied event")
		await game.quit_game(1)
		return
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../reports/learning-v3/feedback-open.png")
	var key := InputEventKey.new()
	key.physical_keycode=KEY_3
	key.keycode=KEY_3
	key.pressed=true
	Input.parse_input_event(key)
	await process_frame
	key=key.duplicate()
	key.pressed=false
	Input.parse_input_event(key)
	while game.director.feedback_status!="Geri bildirimin alındı." and Time.get_ticks_msec()<deadline: await process_frame
	var passed: bool=game.director.reward_source=="rating" and game.director.reward==1 and game.director.updates==initial+1
	passed=passed and int(game.director.memory.get("feedback_counts",{}).get("rating",0))==1
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../reports/learning-v3/feedback-accepted.png")
	print("PASS: Real key → Godot → WebSocket → one persistent player rating" if passed else "FAIL: Player feedback round trip")
	await game.quit_game(0 if passed else 1)
