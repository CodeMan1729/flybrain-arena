extends SceneTree

func _initialize() -> void:
	run_test.call_deferred()

func run_test() -> void:
	var game=load("res://main.tscn").instantiate()
	game.settings_path=""
	root.add_child(game)
	game.set_process(false)
	game.director.set_process(false)
	game.evidence_dir="user://report-test-"+str(OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(game.evidence_dir)
	var path: String=game.evidence_dir+"/game-smoke.json"
	game.frame_times.clear()
	game.write_report(true,"")
	var parser:=JSON.new()
	var code:=parser.parse(FileAccess.get_file_as_string(path))
	if code!=OK or parser.data.mean_fps!=null or parser.data.frames!=0:
		push_error("Empty frame samples must serialize as JSON null, never inf")
		await game.quit_game(1)
		return
	print("PASS: Empty timing sample is valid JSON with null FPS")
	game.frame_times.assign([10.0,20.0])
	game.write_report(true,"")
	code=parser.parse(FileAccess.get_file_as_string(path))
	if code!=OK or not is_equal_approx(float(parser.data.mean_fps),1000.0/15.0) or parser.data.frames!=2:
		push_error("Measured frame samples must retain actual FPS")
		await game.quit_game(1)
		return
	print("PASS: Nonempty sample preserves measured FPS")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(game.evidence_dir)
	await game.quit_game()
