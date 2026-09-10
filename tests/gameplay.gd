extends SceneTree

# Offline regression fixture; prescribed numbers below are not biological measurements.
var failures: Array[String] = []

func verify(condition: bool, text: String) -> void:
	print(("PASS: " if condition else "FAIL: ")+text)
	if not condition: failures.append(text)

func _initialize() -> void:
	run_checks.call_deferred()

func sound_levels(capture: AudioEffectCapture) -> Vector2:
	await create_timer(0.12).timeout # Let the audio mixer update the source position.
	capture.clear_buffer()
	await create_timer(0.18).timeout
	var frames := capture.get_buffer(capture.get_frames_available())
	var energy := Vector2.ZERO
	for frame in frames: energy += frame*frame
	return energy / maxf(frames.size(),1)

func run_checks() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.director.set_process(false)
	game.player.position=Vector3(-2.7,0,0.2)
	game.player.camera.look_at(game.key_object.global_position)
	await physics_frame
	await physics_frame
	verify(game.can_interact(game.key_object.global_position),"Unobstructed nearby key remains interactable")
	var midpoint: Vector3=(game.player.camera.global_position+game.key_object.global_position)*0.5
	var blocker=game.box(midpoint,Vector3(0.6,1,0.3),game.material(Color.BLACK))
	await physics_frame
	await physics_frame
	game.interact()
	verify(not game.has_key,"Solid obstacle prevents collecting key through it")
	blocker.queue_free()
	await physics_frame
	await physics_frame
	game.interact()
	verify(game.has_key,"Key can be collected after obstacle is removed")

	game.ambience.stop()
	game.fly.set_physics_process(false)
	game.player.position=Vector3.ZERO
	game.player.rotation=Vector3.ZERO
	game.player.camera.rotation=Vector3.ZERO
	var capture := AudioEffectCapture.new()
	capture.buffer_length=0.5
	AudioServer.add_bus_effect(0,capture)
	verify(not game.fly.buzz.playing,"Fly buzz is silent before play")
	game.fly.active=true
	game.fly.position=game.player.camera.global_position+Vector3(0,0,-1)
	var near := await sound_levels(capture)
	game.fly.position=game.player.camera.global_position+Vector3(0,0,-8)
	var far := await sound_levels(capture)
	verify(near.x+near.y>0.00001 and near.x+near.y>4*(far.x+far.y),"Actual mixed fly buzz grows louder near the listener")
	game.fly.position=game.player.camera.global_position+Vector3(-2,0,0)
	var left := await sound_levels(capture)
	game.fly.position=game.player.camera.global_position+Vector3(2,0,0)
	var right := await sound_levels(capture)
	verify(left.x>left.y*1.5 and right.y>right.x*1.5,"Actual mixed fly buzz follows left and right position")
	game.fly.position=game.player.camera.global_position+Vector3(0,0,-13)
	var outside := await sound_levels(capture)
	verify(outside.length()<0.00000001,"Fly buzz is inaudible beyond its range")
	game.pause_game()
	verify(not game.fly.buzz.playing,"Pause stops fly buzz immediately")
	game.resume_game()
	verify(game.fly.buzz.playing and game.fly.buzz.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"Resume restarts looping fly buzz")
	game.set_volume(0)
	verify(AudioServer.is_bus_mute(0),"Zero volume mutes every game sound")
	game.set_volume(0.45)
	verify(not AudioServer.is_bus_mute(0) and AudioServer.get_bus_volume_db(0)<0,"Volume restores bounded game audio")
	game.finish_game()
	verify(not game.fly.buzz.playing,"Round completion stops fly buzz")
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
	verify(game.director.feedback_status=="Gönderiliyor…","Rating key reaches the learning feedback route")
	game.director.feedback_status=""
	game.director.feedback_until=game.director.now()-1
	game._unhandled_input(rating_key)
	verify(game.director.feedback_status.is_empty(),"Expired event cannot receive a rating")
	game.get_window().focus_exited.emit()
	verify(not game.player.active and not game.fly.active and not game.director.running and game.menu.visible,"Window focus loss pauses player, fly and event decisions")
	verify(not game.fly.buzz.playing,"Focus loss also stops fly buzz")
	await game.quit_game(0 if failures.is_empty() else 1)
