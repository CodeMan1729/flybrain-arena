extends SceneTree

var director: Node
var received_actions := 0

func _initialize() -> void:
	director = Node.new()
	director.set_script(load("res://director.gd"))
	root.add_child(director)
	director.action_received.connect(func(_action,_id): received_actions += 1)
	run_test.call_deferred()

func run_test() -> void:
	var start := Time.get_ticks_msec()
	while director.info.is_empty() and Time.get_ticks_msec()-start<5000: await process_frame
	if director.info.is_empty(): quit(1); return
	director.interval = 2
	director.latest_telemetry = {"x":0}
	director.start_session()
	while director.pending_id<0 and Time.get_ticks_msec()-start<7000: await process_frame
	if director.pending_id<0: quit(2); return
	var frames := 0
	var until := Time.get_ticks_msec()+2300
	while Time.get_ticks_msec()<until:
		await process_frame
		frames += 1
	if received_actions != 0 or director.action != "wait" or frames < 30:
		push_error("Delayed reply was applied, or game loop stalled")
		quit(3)
		return
	director.pause_session()
	director.socket.close()
	print("PASS: delayed response discarded; %d frames continued; safe wait" % frames)
	quit(0)
