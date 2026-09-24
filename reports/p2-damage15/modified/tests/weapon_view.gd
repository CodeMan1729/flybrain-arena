extends SceneTree
var failures: Array[String] = []
func verify(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures.append(label)
func _initialize() -> void:
	run_checks.call_deferred()
func run_checks() -> void:
	var game = load("res://main.tscn").instantiate()
	game.settings_path = ""
	root.add_child(game)
	game.director.set_process(false)
	game.fly.set_physics_process(false)
	var view = game.player.get("weapon_view")
	verify(view != null,"First-person weapon exists")
	if view != null:
		view.set_process(false)
		verify(not view.visible,"Weapon hidden in initial menu")
		game.start_game()
		verify(view.visible and view.rig.has_node("Receiver") and view.rig.has_node("Barrel"),"Visible gun on round start")
		verify(view.viewport.own_world_3d and view.surface.mouse_filter == Control.MOUSE_FILTER_IGNORE,"Separate render world and non-intercepting input")
		verify(view.viewport.find_children("*","CollisionObject3D",true,false).is_empty(),"Cosmetic gun adds no collision objects")
		game.player.position = Vector3(0,0,4)
		game.player.rotation = Vector3.ZERO
		game.player.camera.rotation = Vector3.ZERO
		game.fly.position = Vector3(0,1.65,0)
		await physics_frame
		await physics_frame
		game.player.fire()
		verify(game.fly.hp == 85 and view.recoil == 1 and view.flash.visible,"Hitscan damage plus muzzle flash and recoil")
		view._process(0.02)
		var recoil: float = view.recoil
		game.player.fire()
		verify(game.fly.hp == 85 and view.recoil == recoil,"Cooldown blocks both damage and new animation")
		view._process(0.2)
		verify(view.recoil == 0 and not view.flash.visible and view.rig.position == view.REST,"Recoil and flash decay to rest")
		game.player.fire_ready = 0
		game.player.fire()
		game.pause_game()
		verify(not view.visible and not view.flash.visible and view.recoil == 0,"Pause hides weapon and clears flash")
		game.resume_game()
		verify(view.visible and view.recoil == 0,"Resume shows clean weapon")
		game.lose_game()
		verify(not view.visible,"Round end hides gun")
		game.start_game()
		verify(view.visible and view.recoil == 0 and not view.flash.visible,"Restart resets view model")
	await game.quit_game(0 if failures.is_empty() else 1)
