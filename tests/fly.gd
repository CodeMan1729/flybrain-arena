extends SceneTree

# Scripted neural drive isolates flight tuning; it is not a biological measurement.
var failures: Array[String] = []

func verify(condition: bool, text: String) -> void:
	print(("PASS: " if condition else "FAIL: ")+text)
	if not condition: failures.append(text)

func _initialize() -> void:
	run_checks.call_deferred()

func run_checks() -> void:
	var game = load("res://main.tscn").instantiate()
	game.settings_path = ""
	root.add_child(game)
	game.set_process(false)
	game.director.set_process(false)
	game.set_volume(0)
	game.director.connected = true
	game.director.neural = {"output":[0.16,0.06,0.08,0.04]}
	game.fly.active = true
	verify(game.fly.body.scale.is_equal_approx(Vector3.ONE*0.5),"Fly mesh dimensions are halved")
	verify(is_equal_approx(game.fly.get_child(0).shape.radius,0.1),"Fly collision radius is halved")
	game.player.position = Vector3(-3,0,1)
	game.fly.position = Vector3(0,1.25,0)
	game.fly.gaze = Vector3.FORWARD
	for _frame in 2:
		game.director.last_neural_time = game.director.now()
		await physics_frame
	verify(game.fly.visible_player,"Wide vision acquires a player beside and slightly behind the fly")
	var last_seen: Vector3 = game.player.position+Vector3.UP*1.25
	var old_distance: float = game.fly.position.distance_to(last_seen)
	game.player.position = Vector3(8,0,0)
	for _frame in 30:
		game.director.last_neural_time = game.director.now()
		await physics_frame
	verify(not game.fly.visible_player and game.fly.sight.is_empty(),"Walls still hide the player's current telemetry")
	verify(game.fly.position.distance_to(last_seen)<old_distance-0.3,"Brief occlusion preserves pursuit of the last visible position")

	game.fly.reset_body()
	game.fly.position = Vector3(0,1.5,4)
	game.fly.gaze = Vector3.FORWARD
	game.player.position = Vector3(0,0,-2)
	game.player.active = true
	game.player.auto_walk = true
	game.player.auto_target = Vector3(0,0,-13)
	var peak_speed := 0.0
	var visible_frames := 0
	var contained := true
	for _frame in 240:
		game.director.last_neural_time = game.director.now()
		await physics_frame
		peak_speed = maxf(peak_speed,game.fly.velocity.length())
		if game.fly.visible_player: visible_frames += 1
		contained = contained and absf(game.fly.position.x)<5.9 and game.fly.position.z>-14.6
	var distance: float = game.fly.position.distance_to(game.player.position+Vector3.UP*1.25)
	verify(peak_speed>4.0 and peak_speed<=8.01,"Fly can overtake the 3.2-unit/s player within an 8-unit/s speed limit")
	verify(distance<3.0 and visible_frames>180,"Fly catches and follows a walking player through the corridor")
	verify(contained,"Fast flight stays inside the room and sealed exit")
	verify(game.fly.body.scale.is_equal_approx(Vector3.ONE*0.5),"Turning preserves the half-size body")
	game.player.active = false
	game.player.auto_walk = false
	var turns := 0
	var previous: Vector3 = game.fly.velocity
	for frame in 180:
		game.director.last_neural_time = game.director.now()
		await physics_frame
		if frame%6==0:
			if previous.length()>0.5 and game.fly.velocity.length()>0.5 and previous.angle_to(game.fly.velocity)>0.35: turns += 1
			previous = game.fly.velocity
	verify(turns>=4,"Hovering flight makes repeated short direction changes")
	print(JSON.stringify({"peak_speed":peak_speed,"following_distance":distance,"visible_frames":visible_frames,"frames":240,"short_turns":turns}))
	game.fly.active = false
	var stopped: Vector3 = game.fly.position
	var wing_angle: float = game.fly.wings[0].rotation.z
	for _frame in 6: await physics_frame
	verify(game.fly.position==stopped and game.fly.wings[0].rotation.z==wing_angle and not game.fly.buzz.playing,"Pause freezes flight, wings and buzz")
	game.fly.active = true
	game.director.neural = {"output":[0,0,0,0]}
	for _frame in 6:
		game.director.last_neural_time = game.director.now()
		await physics_frame
	verify(game.fly.position.distance_to(stopped)<0.00001,"Silent neural drive cannot power flight")
	stopped = game.fly.position
	game.director.neural = {"output":[0.16,0.06,0.08,0.04]}
	game.director.last_neural_time = game.director.now()-10
	for _frame in 6: await physics_frame
	verify(game.fly.position.distance_to(stopped)<0.00001,"Expired brain output stops flight without drifting")
	game.director.neural = {"output":[0.16,0.06,0.08,0.04]}
	for route_case in [[42,1],[3,1],[17,1],[42,-1],[3,-1],[17,-1]]:
		game.director.seed_value = route_case[0]
		game.player.position = Vector3(0,0,-9)
		game.player.reset_motion()
		game.fly.reset_body()
		game.fly.position = Vector3(0,1.5,-5)
		game.fly.gaze = Vector3.FORWARD
		game.fly.active = true
		game.player.active = true
		game.player.auto_walk = true
		var route := [Vector3(6,0,-9),Vector3(6,0,-18.5),Vector3(-6,0,-18.5),Vector3(-6,0,-9),Vector3(0,0,-9)]
		var missed_frames := 0
		var longest_miss := 0
		var route_reached := true
		var crossed_wall := false
		for point in route:
			point.x *= int(route_case[1])
			game.player.auto_target = point
			var route_frames := 0
			while game.player.position.distance_to(point)>0.23 and route_frames<600:
				var previous_position: Vector3 = game.fly.position
				game.director.last_neural_time = game.director.now()
				await physics_frame
				route_frames += 1
				missed_frames = 0 if game.fly.visible_player else missed_frames+1
				longest_miss = maxi(longest_miss,missed_frames)
				var crossing := PhysicsRayQueryParameters3D.create(previous_position,game.fly.position,1)
				crossing.exclude = [game.fly.get_rid(),game.player.get_rid()]
				crossed_wall = crossed_wall or not game.get_world_3d().direct_space_state.intersect_ray(crossing).is_empty()
			route_reached = route_reached and route_frames<600
		var route_distance: float = game.fly.position.distance_to(game.player.position+Vector3.UP*1.25)
		verify(route_reached and not crossed_wall,"Continuous room route respects collisions: "+str(route_case))
		verify(longest_miss<180 and game.fly.visible_player and route_distance<3,"Fly follows around side and rear doorway corners: "+str(route_case))
		print(JSON.stringify({"doorway_seed":route_case[0],"direction":route_case[1],"longest_unseen_frames":longest_miss,"end_distance":route_distance,"crossed_wall":crossed_wall}))
	await game.quit_game(0 if failures.is_empty() else 1)
