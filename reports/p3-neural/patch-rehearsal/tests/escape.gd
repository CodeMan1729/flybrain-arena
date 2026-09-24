extends SceneTree

# Offline motor/sensor fixture. Real anatomy and lesions: test_escape.py.
var failures: Array[String] = []
const Sensor = preload("res://threat_sensor.gd")

func verify(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures.append(label)

func _initialize() -> void:
	run_checks.call_deferred()

func run_checks() -> void:
	var game = load("res://main.tscn").instantiate()
	game.settings_path = ""
	root.add_child(game)
	game.set_process(false)
	game.director.set_process(false)
	game.fly.set_physics_process(false)
	game.player.set_physics_process(false)
	game.start_game()
	game.director.has_round = false
	game.player.position = Vector3(0,0,4)
	game.player.rotation = Vector3.ZERO
	game.player.camera.rotation = Vector3.ZERO
	game.fly.position = Vector3(0,1.65,0)
	game.fly.gaze = Vector3.BACK
	await physics_frame
	await physics_frame
	var aim := Sensor.sample(game.fly,game.player)
	verify(aim.level>0 and aim.level<1,"Aim anticipates hitscan without invented projectile travel")
	game.player.fire()
	verify(game.fly.hp==85,"Hitscan damage remains immediate before any neural reply")
	verify(Sensor.sample(game.fly,game.player).level>aim.level,"Accepted shot increases local threat")
	game.player.fire()
	verify(game.fly.hp==85,"Cooldown still prevents a second shot")
	game.player.reset_motion()
	verify(game.player.last_shot_time<0,"Restart clears shot history")
	game.fly.position.x = -.7
	var a := Sensor.sample(game.fly,game.player)
	game.fly.position.x = .7
	var b := Sensor.sample(game.fly,game.player)
	verify(a.bearing*b.bearing<0,"Near-ray offsets encode opposite hemispheres")
	game.fly.position.x = 3
	verify(Sensor.sample(game.fly,game.player).level==0,"Far miss is not a threat")
	game.fly.position = Vector3(0,1.65,6)
	verify(Sensor.sample(game.fly,game.player).level==0,"Target behind muzzle is not a threat")
	game.fly.position = Vector3(0,1.65,-30)
	verify(Sensor.sample(game.fly,game.player).level==0,"Out-of-range target is not a threat")
	game.fly.position = Vector3(0,1.65,0)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2,3,.1)
	shape.shape=box
	wall.add_child(shape)
	game.add_child(wall)
	wall.position=Vector3(0,1.5,2)
	await physics_frame
	await physics_frame
	verify(Sensor.sample(game.fly,game.player).level==0,"Thin wall occludes threat independent of pursuit sight")
	wall.queue_free()
	await physics_frame
	await physics_frame
	game.director.connected=true
	game.director.running=true
	game.director.neural={"output":[.16,.06,.08,.04]}
	game.director.last_neural_time=game.director.now()
	var vectors: Array[Vector3]=[]
	for sign_value in [-1,1]:
		game.fly.position=Vector3(0,1.65,0)
		game.fly.gaze=Vector3.BACK
		game.fly.velocity=Vector3.ZERO
		game.director.escape_signal={"source":"full_graph_dnp","strength":1,"lateral":sign_value,"vertical":0}
		game.director.escape_valid_until=game.director.now()+.5
		game.fly._physics_process(1.0/60)
		vectors.append(game.fly.dodge_velocity)
		verify(game.fly.velocity.length()<=6.40001,"Dodge retains speed cap")
		verify(game.fly.velocity.length()<=19.2/60+.0001,"Dodge retains acceleration cap")
	verify(vectors[0].dot(vectors[1])<0,"Opposite neural readouts produce opposite dodge forces")
	game.director.escape_valid_until=game.director.now()-1
	game.fly._physics_process(.016)
	verify(game.fly.dodge_velocity==Vector3.ZERO,"Expired escape signal contributes zero force")
	game.director.escape_valid_until=game.director.now()+1
	game.director.escape_signal.strength=0
	game.fly._physics_process(.016)
	verify(game.fly.dodge_velocity==Vector3.ZERO,"Zero DN strength has no random fallback")
	game.director.escape_signal.strength=1
	game.director.connected=false
	game.fly._physics_process(.016)
	verify(game.fly.dodge_velocity==Vector3.ZERO and game.fly.velocity==Vector3.ZERO,"Disconnection stops pursuit and dodge")
	game.director.pause_session()
	verify(game.director.escape_signal.is_empty() and game.director.escape_pending<0,"Pause invalidates pending escape and old signals")
	game.director.start_session()
	verify(game.director.escape_valid_until<0,"New round rejects previous escape validity")
	game.director.has_round=false
	await game.quit_game(0 if failures.is_empty() else 1)
