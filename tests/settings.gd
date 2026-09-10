extends SceneTree

var failures: Array[String] = []

func verify(condition: bool, description: String) -> void:
	print(("PASS: " if condition else "FAIL: ")+description)
	if not condition: failures.append(description)

func open_game(path: String) -> Node:
	var game = load("res://main.tscn").instantiate()
	game.settings_path = path
	game.research_modes = true # Exercise saved legacy research preferences in the isolated fixture.
	root.add_child(game)
	game.director.set_process(false)
	return game

func close_game(game: Node) -> void:
	game.pause_game()
	game.ambience.stop()
	game.ambience.stream = null
	await create_timer(0.1).timeout
	game.free()

func _initialize() -> void:
	run_checks.call_deferred()

func run_checks() -> void:
	var directory := OS.get_temp_dir().path_join("flyfear-settings-"+str(OS.get_process_id()))
	DirAccess.make_dir_absolute(directory)
	var path := directory.path_join("settings.cfg")
	var game := open_game(path)
	verify(is_equal_approx(game.volume,0.45) and not FileAccess.file_exists(path),"First launch uses defaults without writing a file")
	var sliders: Array[HSlider] = []
	for child in game.settings.get_children():
		if child is HSlider: sliders.append(child)
	sliders[0].value = 0
	sliders[1].value = 0.32
	sliders[2].value = 4.2
	sliders[3].value = 0.0016
	game.mode_choice.select(1)
	game.mode_choice.item_selected.emit(1)
	game.seed_box.value = 1234
	game.fullscreen = true
	verify(game.save_settings()==OK,"Menu changes save through the production path")
	verify(not FileAccess.file_exists(path+".tmp"),"Successful save replaces the file without leaving temporary data")
	await close_game(game)
	game = open_game(path)
	verify(game.volume==0 and AudioServer.is_bus_mute(0),"Reopening restores mute before playback")
	verify(is_equal_approx(game.intensity,0.32) and is_equal_approx(game.decision_interval,4.2) and is_equal_approx(game.player.sensitivity,0.0016),"Reopening restores effect intensity, interval and mouse sensitivity")
	verify(game.mode_choice.selected==1 and game.seed_box.value==1234 and game.fullscreen,"Reopening restores mode, seed and fullscreen preference")
	game.start_game()
	verify(game.director.mode=="fixed" and game.director.seed_value==1234 and is_equal_approx(game.director.interval,4.2),"Restored experiment settings reach the actual round")
	game.pause_game()
	var original := FileAccess.get_file_as_bytes(path)
	DirAccess.make_dir_absolute(path+".tmp")
	verify(game.save_settings()!=OK and FileAccess.get_file_as_bytes(path)==original and not game.settings_notice.is_empty(),"Failed write preserves the previous file and reports the failure")
	DirAccess.remove_absolute(path+".tmp")
	await close_game(game)

	game = open_game("")
	verify(is_equal_approx(game.volume,0.45) and game.mode_choice.selected==2 and game.save_settings()==ERR_UNAVAILABLE,"Isolated tests neither read nor write personal settings")
	await close_game(game)
	var config := ConfigFile.new()
	var invalid := {"volume":99,"intensity":-4,"interval":INF,"sensitivity":"invalid","seed":-12,"mode":{},"fullscreen":"true"}
	for key in invalid: config.set_value("settings",key,invalid[key])
	config.save(path)
	game = open_game(path)
	verify(is_equal_approx(game.volume,0.7) and game.intensity==0 and game.decision_interval==3 and game.seed_box.value==0,"Out-of-range and infinite values cannot escape safe limits")
	verify(is_equal_approx(game.player.sensitivity,0.002) and game.mode_choice.selected==2 and not game.fullscreen,"Wrong value types use safe defaults")
	game.preferences.set_value("settings","volume",NAN)
	verify(is_equal_approx(game.setting_number("volume",0.45,0,0.7),0.45),"NaN is rejected")
	await close_game(game)
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string("[settings\nvolume=")
	file.close()
	var broken := FileAccess.get_file_as_bytes(path)
	game = open_game(path)
	var backup_found := false
	for name in DirAccess.get_files_at(directory):
		if name.begins_with("settings.cfg.broken-"):
			backup_found = FileAccess.get_file_as_bytes(directory.path_join(name))==broken
	verify(backup_found and game.settings_writable and not game.settings_notice.is_empty() and FileAccess.get_file_as_bytes(path)==broken,"Corrupt settings are backed up byte for byte before replacement")
	verify(game.save_settings()==OK,"Settings remain usable after corrupt-file recovery")
	await close_game(game)
	game = open_game(directory)
	verify(not game.settings_writable and game.save_settings()==ERR_UNAVAILABLE,"Failed backup prevents overwriting unreadable settings")
	await close_game(game)
	config = ConfigFile.new()
	config.set_value("settings","mode","fixed")
	config.save(path)
	game = load("res://main.tscn").instantiate()
	game.settings_path = path
	root.add_child(game)
	game.director.set_process(false)
	verify(not game.mode_choice.visible and game.mode_choice.selected==2,"Normal play ignores old fixed/random preferences and hides control modes")
	game.start_game()
	verify(game.director.mode=="learn","Normal rounds always start reward learning")
	await close_game(game)
	for name in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	quit(0 if failures.is_empty() else 1)
