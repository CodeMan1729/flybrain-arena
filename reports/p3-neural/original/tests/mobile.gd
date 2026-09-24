extends SceneTree

var failures: Array[String] = []

func verify(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ")+message)
	if not condition: failures.append(message)

func _initialize() -> void:
	run_checks.call_deferred()

func touch(index: int, position: Vector2, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index=index; event.position=position; event.pressed=pressed; event.canceled=canceled
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func drag(index: int, position: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index=index; event.position=position; event.relative=relative; event.screen_relative=relative
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run_checks() -> void:
	root.size=Vector2i(390,844)
	var game=load("res://main.tscn").instantiate()
	game.settings_path=""
	game.touch_mode=true
	root.add_child(game)
	game.director.set_process(false)
	game.set_volume(0)
	game.ambience.stop()
	await process_frame
	await process_frame
	for screen in [Vector2i(320,568),Vector2i(390,844),Vector2i(844,390),Vector2i(568,320)]:
		game.pause_game()
		root.size=screen
		await process_frame
		await process_frame
		verify(game.get_viewport().get_visible_rect().size.is_equal_approx(Vector2(screen)),"Mobile viewport matches "+str(screen))
		var fits := true
		for part in game.mobile_scroll.find_children("*","Control",true,false):
			if part.is_visible_in_tree() and part is BaseButton:
				fits = fits and part.get_global_rect().position.x>=0 and part.get_global_rect().end.x<=screen.x
				fits = fits and part.size.y>=44
		verify(fits,"Menu buttons fit horizontally with 44px targets: "+str(screen))
		game.toggle_settings()
		await process_frame
		await process_frame
		verify(game.mobile_scroll.get_v_scroll_bar().max_value>game.mobile_scroll.size.y,"Settings remain scrollable: "+str(screen))
		game.toggle_settings()
		for source in ["server","settings"]:
			game.director.reason="Shared learning memory cannot be reset by players"
			game.settings_notice="Settings could not be opened or backed up; the previous file is kept, changes apply to this session only." if source=="settings" else ""
			game._process(0.1)
			for expanded in [false,true]:
				if game.settings.visible!=expanded: game.toggle_settings()
				await process_frame
				await process_frame
				var scroll: Rect2=game.mobile_scroll.get_global_rect()
				var labels=game.mobile_scroll.find_children("*","Label",true,false).filter(func(part): return part.is_visible_in_tree())
				var buttons=game.mobile_scroll.find_children("*","BaseButton",true,false).filter(func(part): return part.is_visible_in_tree())
				var readable: bool=game.menu.is_visible_in_tree() and not labels.is_empty() and not buttons.is_empty() and game.get_viewport().get_visible_rect().encloses(scroll)
				for part in labels+buttons:
					var rect: Rect2=part.get_global_rect()
					readable=readable and rect.position.x>=scroll.position.x and rect.end.x<=scroll.end.x
					if part is Label:
						readable=readable and part.get_visible_line_count()==part.get_line_count()
						for target in buttons: readable=readable and not rect.intersects(target.get_global_rect())
				for target in buttons+[game.notice]:
					game.mobile_scroll.ensure_control_visible(target)
					await process_frame
					readable=readable and scroll.encloses(target.get_global_rect())
				readable=readable and (game.settings_notice if source=="settings" else game.director.reason) in game.notice.text
				verify(readable,"Long "+source+" error wraps, avoids buttons and scrolls into view (settings="+str(expanded)+"): "+str(screen))
			game.toggle_settings()
		game.settings_notice=""
		game.director.reason="Connecting to the brain"
		game.start_game()
		await process_frame
		game.director.connected=true
		game.director.info={"neurons":166700}
		for action in ["lights","steps","silhouette"]:
			game.director.feedback_id=90
			game.director.feedback_until=game.director.now()+8
			game.director.feedback_action=action
			game.director.feedback_status=""
			game._process(0.1)
			await process_frame
			await process_frame
			var occupied: Array[Rect2]=[]
			var readable: bool=game.player.active and game.feedback_text.is_visible_in_tree() and game.ACTION_NAMES[action] in game.feedback_text.text
			for label in [game.objective,game.badge,game.feedback_text]:
				readable=readable and label.get_visible_line_count()==label.get_line_count()
				occupied.append(Rect2(label.global_position,Vector2(label.size.x,label.get_minimum_size().y)))
			for target in game.touch_controls.ratings:
				readable=readable and target.is_visible_in_tree() and target.shape.size.x>=44 and target.shape.size.y>=44
				occupied.append(Rect2(target.global_position-target.shape.size/2,target.shape.size))
			for i in occupied.size():
				readable=readable and game.get_viewport().get_visible_rect().encloses(occupied[i])
				for j in range(i): readable=readable and not occupied[i].intersects(occupied[j])
			verify(readable,"Mobile "+action+" rating text and targets fit without covering the HUD: "+str(screen))
		game.director.connected=false
		game.director.feedback_id=-1
		game.toggle_brain_details()
		await process_frame
		await process_frame
		verify(game.brain_view.get_global_rect().end.x<=screen.x and game.brain_view.graph_rect().end.y+104<=game.brain_view.size.y,"Mobile brain view fits: "+str(screen))
		game.close_brain_details()
	root.size=Vector2i(390,844)
	game.layout_mobile()
	game.resume_game()
	await process_frame
	await physics_frame
	var controls=game.touch_controls
	touch(0,Vector2(90,700),true)
	drag(0,Vector2(90,650),Vector2(0,-50))
	var position: Vector3=game.player.position
	var yaw: float=game.player.rotation.y
	touch(1,Vector2(250,500),true)
	drag(1,Vector2(290,500),Vector2(40,0))
	await create_timer(0.2).timeout
	verify(game.player.position.distance_to(position)>0.4 and absf(game.player.rotation.y-yaw)>0.2,"Two fingers move and aim together")
	verify(game.player.telemetry().speed<=3.21,"Touch movement respects the existing speed limit")
	var torch: bool=game.player.torch.visible
	touch(2,controls.buttons[1].position,true)
	touch(2,controls.buttons[1].position,false)
	verify(game.player.torch.visible!=torch and controls.move_finger==0 and controls.look_finger==1,"Third finger toggles torch without stealing either gesture")
	touch(0,Vector2(90,650),false)
	await create_timer(0.1).timeout
	verify(game.player.touch_axis==Vector2.ZERO and game.player.telemetry().speed==0 and controls.look_finger==1,"Releasing movement stops immediately and retains look finger")
	yaw=game.player.rotation.y
	drag(0,Vector2(140,650),Vector2(50,0))
	verify(game.player.rotation.y==yaw,"Released finger cannot turn the camera")
	touch(1,Vector2(290,500),false,true)
	verify(not game.player.active and controls.move_finger<0 and controls.look_finger<0,"Canceled touch pauses and clears all gesture ownership")
	game.resume_game()
	await process_frame
	touch(0,Vector2(90,700),true)
	drag(0,Vector2(90,650),Vector2(0,-50))
	touch(1,controls.buttons[0].position,true)
	verify(not game.player.active and game.player.touch_axis==Vector2.ZERO,"On-screen pause cancels held movement")
	touch(1,controls.buttons[0].position,false)
	game.resume_game()
	await create_timer(0.1).timeout
	verify(game.player.telemetry().speed==0,"Explicit resume never replays stale touch input")
	touch(0,Vector2(90,700),true)
	drag(0,Vector2(90,650),Vector2(0,-50))
	root.size=Vector2i(844,390)
	await process_frame
	await process_frame
	verify(not game.player.active and game.player.touch_axis==Vector2.ZERO,"Rotation pauses play and cancels held touch")
	root.size=Vector2i(390,844)
	await process_frame
	await process_frame
	game.resume_game()
	game.director.feedback_id=90
	game.director.feedback_until=game.director.now()+8
	game.director.feedback_status=""
	await process_frame
	await process_frame
	touch(2,controls.ratings[1].position,true)
	touch(2,controls.ratings[1].position,false)
	verify(game.director.feedback_status=="Sending…","Touch rating uses the existing feedback validation path")
	# TODO(P2 combat): touch/mobile has no fire control yet (mission only specified
	# mouse-left-click hitscan). Add a touch fire button + this coverage when mobile
	# combat input is designed; do not fake a pass here in the meantime.
	game.pause_game()
	await game.quit_game(0 if failures.is_empty() else 1)
