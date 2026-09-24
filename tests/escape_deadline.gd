extends SceneTree

func _initialize() -> void:
	run_test.call_deferred()

func run_test() -> void:
	var director = load("res://director.gd").new()
	root.add_child(director)
	var deadline := Time.get_ticks_msec()+5000
	while director.info.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	if director.info.is_empty(): quit(1); return
	director.interval=5
	director.latest_telemetry={"threat":{"level":1,"bearing":1}}
	director.start_session()
	deadline=Time.get_ticks_msec()+3000
	while director.escape_pending<0 and Time.get_ticks_msec()<deadline: await process_frame
	if director.escape_pending<0: quit(2); return
	director.latest_telemetry={}
	var frames := 0
	deadline=Time.get_ticks_msec()+1250
	while Time.get_ticks_msec()<deadline:
		await process_frame
		frames+=1
		if not director.escape_signal.is_empty(): quit(3); return
	if frames<30: quit(4); return
	print("PASS: mismatched and late escape replies ignored; frames "+str(frames))
	director.latest_telemetry={"threat":{"level":1,"bearing":-1}}
	deadline=Time.get_ticks_msec()+2000
	while director.escape_pending<0 and Time.get_ticks_msec()<deadline: await process_frame
	if director.escape_pending<0: quit(5); return
	director.pause_session()
	await create_timer(.4).timeout
	if not director.escape_signal.is_empty() or director.escape_pending>=0: quit(6); return
	print("PASS: reply in flight at pause never becomes a dodge")
	director.socket.close()
	director.queue_free()
	await process_frame
	quit(0)
