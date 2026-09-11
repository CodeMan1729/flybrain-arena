extends CharacterBody3D

var camera: Camera3D
var torch: SpotLight3D
var active := false
var sensitivity := 0.002
var pause_seconds := 0.0
var turn_rate := 0.0
var previous_yaw := 0.0
var auto_target := Vector3.ZERO
var auto_walk := false
var turn_samples: Array[Vector2] = []

func reset_motion() -> void:
	# Key-up can be lost outside the window, including while a menu is open.
	for key_code in [KEY_W,KEY_A,KEY_S,KEY_D]:
		var released := InputEventKey.new()
		released.keycode = key_code
		released.physical_keycode = key_code
		Input.parse_input_event(released)
	Input.flush_buffered_events()
	velocity = Vector3.ZERO
	pause_seconds = 0
	turn_rate = 0
	previous_yaw = rotation.y
	turn_samples.clear()

func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = 1.65
	camera.fov = 78
	camera.near = 0.05
	add_child(camera)
	torch = SpotLight3D.new()
	torch.position = Vector3(0.15, -0.12, -0.1)
	torch.light_color = Color(1.0, 0.85, 0.66)
	torch.light_energy = 3.2
	torch.spot_range = 17
	torch.spot_angle = 32
	torch.spot_attenuation = 1.25
	torch.shadow_enabled = true
	torch.shadow_reverse_cull_face = true # Closed meshes avoid flashlight shadow stripes on Metal.
	camera.add_child(torch)

func _unhandled_input(event: InputEvent) -> void:
	if active and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * sensitivity, -1.3, 1.3)
	if active and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		torch.visible = not torch.visible

func _physics_process(delta: float) -> void:
	var direction := Vector3.ZERO
	if active:
		if auto_walk:
			direction = auto_target - global_position
			direction.y = 0
			if direction.length() > 0.16:
				direction = direction.normalized()
			else:
				direction = Vector3.ZERO
		else:
			var axis := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
			direction = (basis * Vector3(axis.x, 0, axis.y)).normalized()
	velocity.x = direction.x * 3.2
	velocity.z = direction.z * 3.2
	if not is_on_floor():
		velocity.y -= 15 * delta
	else:
		velocity.y = 0
	move_and_slide()
	var speed := Vector2(velocity.x, velocity.z).length()
	pause_seconds = pause_seconds + delta if speed < 0.15 and active else 0.0
	turn_rate = rad_to_deg(angle_difference(previous_yaw, rotation.y)) / maxf(delta, 0.001)
	previous_yaw = rotation.y
	var now := Time.get_ticks_msec()/1000.0
	while not turn_samples.is_empty() and turn_samples[0].x <= now-0.12:
		turn_samples.pop_front()
	if active and absf(turn_rate)>0.01:
		turn_samples.append(Vector2(now,turn_rate))

func telemetry() -> Dictionary:
	var look := -camera.global_basis.z
	var speed := Vector2(velocity.x, velocity.z).length()
	# Retain brief turns across the 100 ms telemetry interval, then expire them.
	var sampled_turn := 0.0
	for sample in turn_samples:
		if absf(sample.y)>absf(sampled_turn): sampled_turn=sample.y
	return {"x":position.x, "z":position.z, "look_x":look.x, "look_z":look.z, "look_y":look.y,
		"speed":speed, "pause_seconds":pause_seconds, "retreat":maxf(0, -velocity.dot(look)), "turn_rate":sampled_turn}
