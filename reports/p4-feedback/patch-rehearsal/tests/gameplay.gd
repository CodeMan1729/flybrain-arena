extends SceneTree

# Offline regression fixture; prescribed numbers below are not biological measurements.
var failures: Array[String] = []

func verify(condition: bool, text: String) -> void:
	print(("PASS: " if condition else "FAIL: ")+text)
	if not condition: failures.append(text)

func _initialize() -> void:
	run_checks.call_deferred()

func sound_levels(capture: AudioEffectCapture, duration := 0.18) -> Vector2:
	await create_timer(0.12).timeout # Let the audio mixer update the source position.
	capture.clear_buffer()
	await create_timer(duration).timeout
	var frames := capture.get_buffer(capture.get_frames_available())
	var energy := Vector2.ZERO
	for frame in frames: energy += frame*frame
	return energy / maxf(frames.size(),1)

func run_checks() -> void:
	var game = load("res://main.tscn").instantiate()
	game.settings_path = ""
	root.add_child(game)
	game.director.set_process(false)
	game.ui_clock=0.1
	game._process(0)
	var initial_badge: String=game.badge.text
	game.director.connected=not game.director.connected
	game._process(0.01)
	verify(game.badge.text==initial_badge,"HUD text is reused between 10 Hz updates")
	game._process(0.1)
	verify(game.badge.text!=initial_badge,"HUD refreshes changed gameplay state at the next update")
	game.debug_text.text="hidden sentinel"
	game._process(0.1)
	verify(game.debug_text.text=="hidden sentinel","Hidden debug text does not rebuild every update")
	game.director.connected=false
	game.fly.set_physics_process(false)
	for side in [-1,1]:
		game.fly.position=Vector3(0,1.6,-9)
		var hit=game.fly.move_and_collide(Vector3(side*4,0,0))
		verify(hit==null,"Fly fits through side-room doorway: "+str(side))
		game.fly.position=Vector3(side*6,1.6,-14)
		hit=game.fly.move_and_collide(Vector3(0,0,-4.5))
		verify(hit==null,"Fly fits through rear service doorway: "+str(side))
	game.fly.position=Vector3(0,1.6,-18.5)
	verify(game.fly.move_and_collide(Vector3(0,0,-3))!=null,"Rear wall contains fly")
	game.player.position=Vector3(0,0,-18.5)
	verify(game.player.move_and_collide(Vector3(0,0,-3))!=null,"Rear wall contains player")
	game.player.position=Vector3(0,0,-18.5)
	verify(game.player.move_and_collide(Vector3(0,0,4))!=null,"Rear passage cannot bypass sealed exit wall")

	# Combat: weapon hitscan, cooldown, wall blocking, HP-driven win/lose.
	game.player.active=true
	game.fly.active=true
	game.fly.hp=game.fly.max_hp
	game.player.position=Vector3(0,0,4)
	game.player.rotation=Vector3.ZERO
	game.player.camera.rotation=Vector3.ZERO
	game.fly.position=Vector3(0,1.65,0)
	await physics_frame
	await physics_frame
	game.player.fire_ready=0
	game.player.fire()
	verify(game.fly.hp==game.fly.max_hp-game.player.weapon_damage,"Direct hit on drone deals weapon_damage")
	var hp_after_first_shot: int=game.fly.hp
	game.player.fire()
	verify(game.fly.hp==hp_after_first_shot,"Fire cooldown blocks an immediate second shot")
	game.player.fire_ready=0
	var blocker=game.box(Vector3(0,1.65,2),Vector3(1,1,0.2),game.material(Color.BLACK))
	await physics_frame
	await physics_frame
	game.player.fire()
	verify(game.fly.hp==hp_after_first_shot,"Solid obstacle blocks the hitscan ray from reaching the drone")
	blocker.queue_free()
	await physics_frame
	await physics_frame
	game.fly.hp=game.player.weapon_damage
	game.player.fire_ready=0
	var win_signaled := [false]
	game.fly.defeated.connect(func(): win_signaled[0]=true,CONNECT_ONE_SHOT)
	game.player.fire()
	verify(game.fly.hp==0 and not game.fly.active,"Draining drone HP to zero deactivates it")
	verify(win_signaled[0],"Drone HP reaching zero emits defeated")
	game.fly.reset_body()
	game.fly.active=true
	game.player.active=true
	game.player.hp=game.player.max_hp
	game.director.connected=true
	game.director.neural={"output":[0.001,0,0,0]}
	game.director.last_neural_time=game.director.now()
	var lose_signaled := [false]
	game.player.defeated.connect(func(): lose_signaled[0]=true,CONNECT_ONE_SHOT)
	game.player.position=Vector3(0,0,0)
	game.fly.position=Vector3(0,1.25,0.2)
	await physics_frame
	game.fly._physics_process(0.001)
	verify(game.player.hp==0 and not game.player.active,"Drone contact drains player HP to zero")
	verify(lose_signaled[0],"Player HP reaching zero emits defeated")
	game.player.hp=game.player.max_hp
	game.player.active=false
	game.fly.active=false
	game.director.connected=false

	game.ambience.stop()
	game.fly.set_physics_process(false)
	game.player.position=Vector3.ZERO
	game.player.rotation=Vector3.ZERO
	game.player.camera.rotation=Vector3.ZERO
	var capture := AudioEffectCapture.new()
	# Isolate the 3D rotor; previous combat assertions may leave a result cue playing.
	game.combat_feedback.reset_feedback()
	capture.buffer_length=2.5
	AudioServer.add_bus_effect(0,capture)
	verify(not game.fly.buzz.playing,"Fly buzz is silent before play")
	game.fly.active=true
	game.fly.position=game.player.camera.global_position+Vector3(0,0,-1)
	var near := await sound_levels(capture)
	game.fly.position=game.player.camera.global_position+Vector3(0,0,-8)
	var far := await sound_levels(capture)
	print("ROTOR_MIX_ENERGY near=",near.x+near.y," far=",far.x+far.y)
	verify(near.x+near.y>0.00001 and near.x+near.y>4*(far.x+far.y),"Actual mixed fly buzz grows louder near the listener")
	game.fly.position=game.player.camera.global_position+Vector3(-2,0,0)
	var left := await sound_levels(capture)
	game.fly.position=game.player.camera.global_position+Vector3(2,0,0)
	var right := await sound_levels(capture)
	verify(left.x>left.y*1.5 and right.y>right.x*1.5,"Actual mixed fly buzz follows left and right position")
	game.fly.position=game.player.camera.global_position+Vector3(0,0,-13)
	var outside := await sound_levels(capture)
	verify(outside.length()<0.00000001,"Fly buzz is inaudible beyond its range")
	var held_key := InputEventKey.new()
	held_key.keycode=KEY_W
	held_key.physical_keycode=KEY_W
	held_key.pressed=true
	Input.parse_input_event(held_key)
	Input.flush_buffered_events()
	var key_was_held := Input.is_physical_key_pressed(KEY_W)
	game.pause_game()
	verify(not game.fly.buzz.playing,"Pause stops fly buzz immediately")
	game.resume_game()
	verify(game.fly.buzz.playing and game.fly.buzz.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"Resume restarts looping fly buzz")
	var stopped_at: Vector3=game.player.position
	await create_timer(0.2).timeout
	verify(key_was_held and not Input.is_physical_key_pressed(KEY_W) and Vector2(game.player.position.x-stopped_at.x,game.player.position.z-stopped_at.z).length()<0.001,"Pause releases a held movement key even when its key-up event never arrives")
	stopped_at=game.player.position
	Input.parse_input_event(held_key)
	await create_timer(0.2).timeout
	verify(game.player.position.distance_to(stopped_at)>0.25,"Fresh movement input still works after resuming")
	held_key.pressed=false
	Input.parse_input_event(held_key)
	game.set_volume(0)
	verify(AudioServer.is_bus_mute(0),"Zero volume mutes every game sound")
	game.set_volume(0.45)
	verify(not AudioServer.is_bus_mute(0) and AudioServer.get_bus_volume_db(0)<0,"Volume restores bounded game audio")
	game.win_game()
	verify(not game.fly.buzz.playing,"Round completion stops fly buzz")

	game.player.active=true
	game.events.clear()
	game.elapsed=100
	game.combat_feedback.reset_feedback() # Scare mixing below also uses an isolated bus capture.
	game.sound_rng.seed=42
	game.last_sound=-1
	var sequence: Array = []
	var heard := {}
	var bounded := true
	var behind := true
	var no_repeats := true
	var previous_sound := -1
	for _event in 12:
		game.elapsed+=16.1
		game.apply_action("steps",-1)
		no_repeats = no_repeats and game.last_sound!=previous_sound
		previous_sound=game.last_sound
		behind = behind and (game.footsteps.position-game.player.position).dot(game.player.global_basis.z)>2
		bounded = bounded and game.footsteps.max_db<=-6 and game.footsteps.volume_db<=-6 and game.footsteps.stream.get_length()/game.footsteps.pitch_scale<2
		sequence.append([game.last_sound,game.footsteps.position-game.player.position,game.footsteps.pitch_scale])
		if not heard.has(game.last_sound):
			heard[game.last_sound] = await sound_levels(capture,1.9)
	verify(heard.size()==4 and heard.values().all(func(level): return level.x+level.y>0.0000001),"Four scare clips produce actual mixed audio at the player")
	verify(no_repeats,"Sound variation never repeats the same clip back to back")
	verify(behind and bounded,"Scare audio stays behind the player, gain-limited and shorter than the reaction window")
	var rng_state: int=game.sound_rng.state
	var event_count: int=game.events.size()
	game.apply_action("steps",-1)
	verify(game.sound_rng.state==rng_state and game.events.size()==event_count,"Rejected sound consumes neither event budget nor random sequence")
	game.sound_rng.seed=42
	game.last_sound=-1
	var reproduced := true
	for event in sequence:
		game.elapsed+=16.1
		game.apply_action("steps",-1)
		reproduced = reproduced and event==[game.last_sound,game.footsteps.position-game.player.position,game.footsteps.pitch_scale]
	verify(reproduced,"Same seed reproduces sound, position and pitch")
	game.pause_game()
	verify(not game.footsteps.playing,"Pause immediately cancels scare audio")
	game.resume_game()
	verify(not game.footsteps.playing,"Resume does not replay a cancelled scare")
	game.fly.active=false
	game.intensity=0
	game.elapsed+=16.1
	game.apply_action("steps",-1)
	verify(not game.footsteps.playing,"Zero effect intensity disables all scare variants")
	game.intensity=0.65
	game.apply_action("wait",-1)
	verify(not game.footsteps.playing,"Wait never starts a scare sound")
	game.set_volume(0)
	game.apply_action("steps",-1)
	verify(AudioServer.is_bus_mute(AudioServer.get_bus_index(game.footsteps.bus)),"Master mute covers the scare player's output bus")
	game.set_volume(0.45)
	game.win_game()
	verify(not game.footsteps.playing,"Completing the round stops scare audio")
	game.player.active=false
	game.fly.set_physics_process(true)
	AudioServer.remove_bus_effect(0,0)

	game.player.position=Vector3(0,0,3.3)
	game.player.active=true
	game.player.camera.rotation=Vector3.ZERO
	game.player.rotation=Vector3.ZERO
	game.player.previous_yaw=0
	await physics_frame
	game.player.rotate_y(0.08)
	for _frame in 4: await physics_frame
	verify(absf(game.player.telemetry().turn_rate)>100,"Fast turn survives until 10 Hz telemetry sample")
	for _frame in 12: await physics_frame
	verify(absf(game.player.telemetry().turn_rate)<0.01,"Old turn expires instead of producing repeated reactions")
	game.player.active=false

	game.player.position=Vector3(8,0,0) # Occluded by the room wall even with the wider visual field.
	game.fly.position=Vector3(0,1.6,0)
	game.fly.gaze=Vector3.FORWARD
	game.fly.active=true
	game.director.connected=true
	game.director.neural={"output":[0,0.0266666667,0,0]}
	game.director.last_neural_time=game.director.now()
	var previous: Vector3=game.fly.gaze
	for _frame in 20: await physics_frame
	verify(not game.fly.visible_player and game.fly.gaze.angle_to(previous)>0.12,"Fly searches even when neural lateral drive cancels old search turn")
	game.director.connected=false
	game.fly.velocity=Vector3(1,0,0)
	var stopped: Vector3=game.fly.position
	for _frame in 3: await physics_frame
	verify(game.fly.position.distance_to(stopped)<0.00001,"Lost brain connection stops physical fly without stale drift")

	game.playing=true
	game.player.active=true
	game.fly.active=true
	game.menu.visible=false
	game.director.running=true
	game.director.mode="learn"
	game.director.feedback_id=77
	game.director.feedback_until=game.director.now()+8
	var rating_key := InputEventKey.new()
	rating_key.physical_keycode=KEY_2
	rating_key.pressed=true
	game._unhandled_input(rating_key)
	verify(game.director.feedback_status=="Sending…","Rating key reaches the learning feedback route")
	game.director.feedback_status=""
	game.director.feedback_until=game.director.now()-1
	game._unhandled_input(rating_key)
	verify(game.director.feedback_status.is_empty(),"Expired event cannot receive a rating")
	game.events.clear()
	game.apply_action("steps",-1)
	game.get_window().focus_exited.emit()
	verify(not game.player.active and not game.fly.active and not game.director.running and game.menu.visible,"Window focus loss pauses player, fly and event decisions")
	verify(not game.fly.buzz.playing,"Focus loss also stops fly buzz")
	verify(not game.footsteps.playing,"Focus loss also cancels scare audio")
	for menu_phase in ["new round","resume"]:
		game.win_game()
		if menu_phase=="resume":
			game.start_game()
			game.pause_game()
		held_key.pressed=true
		Input.parse_input_event(held_key.duplicate())
		Input.flush_buffered_events()
		key_was_held=Input.is_physical_key_pressed(KEY_W)
		game.start_game()
		stopped_at=game.player.position
		await create_timer(0.2).timeout
		verify(key_was_held and not Input.is_physical_key_pressed(KEY_W) and Vector2(game.player.position.x-stopped_at.x,game.player.position.z-stopped_at.z).length()<0.001,"Menu key without key-up cannot leak into "+menu_phase)
		stopped_at=game.player.position
		Input.parse_input_event(held_key.duplicate())
		await create_timer(0.2).timeout
		verify(game.player.position.distance_to(stopped_at)>0.25,"Fresh input works after menu entry: "+menu_phase)
		held_key.pressed=false
		Input.parse_input_event(held_key.duplicate())
		Input.flush_buffered_events()
	await game.quit_game(0 if failures.is_empty() else 1)
