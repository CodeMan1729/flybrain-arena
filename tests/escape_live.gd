extends SceneTree

# Live production WebSocket client + full MaleCNS backend, isolated by Python runner.
var failures: Array[String] = []
const Sensor = preload("res://threat_sensor.gd")

func verify(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures.append(label)

func _initialize() -> void:
	run_checks.call_deferred()

func run_checks() -> void:
	var game = load("res://main.tscn").instantiate()
	game.settings_path=""
	root.add_child(game)
	game.set_process(false)
	game.player.set_physics_process(false)
	game.fly.set_physics_process(false)
	var deadline := Time.get_ticks_msec()+15000
	while game.director.info.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	verify(game.director.info.get("neurons",0)==166700,"Live hello confirms full graph")
	if game.director.info.is_empty():
		await game.quit_game(1)
		return
	var results := []
	for x in [-.7,.7]:
		game.playing=false
		game.start_game()
		game.player.position=Vector3(0,0,4)
		game.player.rotation=Vector3.ZERO
		game.player.camera.rotation=Vector3.ZERO
		game.fly.position=Vector3(x,1.65,0)
		game.fly.gaze=Vector3.BACK
		await physics_frame
		var threat := Sensor.sample(game.fly,game.player)
		game.director.latest_telemetry={"vision":{},"threat":threat}
		deadline=Time.get_ticks_msec()+7000
		while game.director.escape_signal.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
		var escape: Dictionary=game.director.escape_signal.duplicate(true)
		verify(escape.get("source","")=="full_graph_dnp","Production client receives anatomical escape output")
		verify(float(escape.get("lateral",0))*float(threat.bearing)>0,"Live DN direction follows hemisphere, not fixed motor side")
		game.fly._physics_process(1.0/60)
		verify(game.fly.dodge_velocity.length()>.1,"Live reply drives an actual physics step")
		results.append({"threat":threat,"escape":escape,"dodge":str(game.fly.dodge_velocity),"rtt_ms":(game.director.escape_received_time-game.director.escape_request_time)*1000})
		game.director.pause_session()
		game.fly._physics_process(1.0/60)
		verify(game.fly.dodge_velocity==Vector3.ZERO,"Pause immediately removes live dodge force")
		await create_timer(.3).timeout
	verify(results.size()==2,"Both geometry directions measured")
	print("LIVE_ESCAPE_RESULTS "+JSON.stringify(results))
	game.director.finish_session("quit")
	await create_timer(.2).timeout
	await game.quit_game(0 if failures.is_empty() else 1)
