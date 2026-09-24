extends SceneTree
var failures: Array[String]=[]

func verify(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures.append(label)

func _initialize() -> void:
	run_test.call_deferred()

func run_test() -> void:
	var game=load("res://main.tscn").instantiate()
	game.settings_path=""
	root.add_child(game)
	game.director.set_process(false)
	game.fly.set_physics_process(false)
	game.player.set_physics_process(false)
	var feedback=game.get("combat_feedback")
	verify(feedback!=null,"Combat feedback is installed")
	if feedback==null:
		await game.quit_game(1)
		return
	feedback.set_process(false)
	game.start_game()
	verify(feedback.hit_left==0 and not feedback.result.playing,"Round starts without stale cue")
	verify(feedback.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Hitmarker never captures aiming input")
	game.player.position=Vector3(0,0,4)
	game.player.rotation=Vector3.ZERO
	game.player.camera.rotation=Vector3.ZERO
	game.fly.position=Vector3(0,1.65,0)
	await physics_frame
	await physics_frame
	game.player.fire()
	verify(game.fly.hp==85 and feedback.shot.playing and feedback.hit.playing,"Real accepted hit plays shot and confirmation")
	verify(feedback.hit_left==feedback.HIT_TIME,"Real hit opens a short marker")
	feedback._process(.05)
	var remaining: float=feedback.hit_left
	game.player.fire()
	verify(feedback.hit_left==remaining and game.fly.hp==85,"Cooldown produces no repeated feedback")
	feedback._process(.2)
	verify(feedback.hit_left==0,"Marker expires without input")
	feedback.reset_feedback()
	game.fly.position.x=3
	await physics_frame
	await physics_frame
	game.player.fire_ready=0
	game.player.fire()
	verify(feedback.shot.playing and not feedback.hit.playing and feedback.hit_left==0,"Miss has shot audio but no false hit feedback")
	game.pause_game()
	verify(not feedback.shot.playing and not feedback.hit.playing and feedback.hit_left==0,"Pause stops short combat cues")
	game.resume_game()
	game.fly.position=Vector3(0,1.65,0)
	game.fly.hp=15
	await physics_frame
	await physics_frame
	game.player.fire_ready=0
	game.player.fire()
	verify(game.completed and game.fly.hp==0 and feedback.hit_left==0 and not feedback.shot.playing,"Lethal hitscan settles before late fired signal without painting over menu")
	verify(feedback.result.playing and feedback.result.stream==feedback.WON,"Victory plays its own result cue")
	game.lose_game()
	verify(feedback.result.stream==feedback.WON,"Duplicate late outcome keeps original result cue")
	game.start_game()
	verify(not feedback.result.playing,"Restart clears previous result sound")
	game.lose_game()
	verify(feedback.result.playing and feedback.result.stream==feedback.LOST,"Defeat has a distinct result cue")
	game.set_volume(0)
	verify(AudioServer.is_bus_mute(0) and feedback.shot.bus=="Master" and feedback.hit.bus=="Master" and feedback.result.bus=="Master","Existing mute and volume control covers every new sound")
	verify(game.fly.buzz.stream.resource_path.ends_with("rotor.wav"),"Drone uses original mechanical rotor loop")
	verify(game.player.weapon_damage==15 and game.player.fire_cooldown==.35 and game.fly.flight_speed_scale==.8,"Presentation leaves approved difficulty unchanged")
	await game.quit_game(0 if failures.is_empty() else 1)
