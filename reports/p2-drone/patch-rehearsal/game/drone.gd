extends CharacterBody3D

signal defeated

# Engineered body controller: visual tracking + measured neural modulation, not insect biomechanics.
var player: CharacterBody3D
var director: Node
var active := false:
	set(value):
		active = value
		if is_instance_valid(buzz):
			if value and not buzz.playing: buzz.play()
			elif not value: buzz.stop()
var buzz: AudioStreamPlayer3D
var max_hp := 100
var hp := 100
var visible_player := false
var sight := {}
var rotors: Array[MeshInstance3D] = []
var gaze := Vector3.FORWARD
var body: Node3D
var clock := 0.0
var avoided := Vector3.ZERO
var last_seen_target := Vector3.ZERO
var last_seen_until := -1.0
var dart := Vector3.ZERO
var dart_until := 0.0
var flight_rng := RandomNumberGenerator.new()
const CONTACT_DISTANCE := 0.6

func mesh(part: Mesh, pos: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = part
	node.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.3
	mat.roughness = 0.4
	node.material_override = mat
	parent.add_child(node)
	return node

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.1
	shape.shape = sphere
	add_child(shape)
	body = Node3D.new()
	body.scale = Vector3.ONE*0.5
	add_child(body)
	body.name = "DroneBody"
	# Code-native quadrotor; dimensions retain the existing gameplay envelope.
	var hull := BoxMesh.new()
	hull.size = Vector3(0.22,0.12,0.28)
	mesh(hull,Vector3.ZERO,Color(0.12,0.17,0.21),body).name = "Chassis"
	var sensor := BoxMesh.new()
	sensor.size = Vector3(0.12,0.045,0.025)
	var lens := mesh(sensor,Vector3(0,0,-0.15),Color(0.12,0.85,0.95),body)
	lens.name = "ForwardSensor"
	lens.material_override.emission_enabled = true
	lens.material_override.emission = Color(0.06,0.45,0.55)
	for side in [-1,1]:
		for fore in [-1,1]:
			var arm := BoxMesh.new()
			arm.size = Vector3(0.24,0.035,0.035)
			mesh(arm,Vector3(side*0.13,0,fore*0.13),Color(0.24,0.30,0.34),body)
			var motor := CylinderMesh.new()
			motor.top_radius = 0.035
			motor.bottom_radius = 0.035
			motor.height = 0.07
			mesh(motor,Vector3(side*0.23,0.025,fore*0.13),Color(0.09,0.12,0.15),body)
			var guard := TorusMesh.new()
			guard.inner_radius = 0.09
			guard.outer_radius = 0.105
			mesh(guard,Vector3(side*0.23,0.055,fore*0.13),Color(0.32,0.40,0.43),body)
			var blade := BoxMesh.new()
			blade.size = Vector3(0.17,0.012,0.026)
			var rotor := mesh(blade,Vector3(side*0.23,0.06,fore*0.13),Color(0.65,0.74,0.76),body)
			rotor.name = "Rotor"+str(rotors.size()+1)
			rotors.append(rotor)
	var light := OmniLight3D.new()
	light.light_color = Color(0.36,0.77,0.62)
	light.light_energy = 0.24
	light.omni_range = 0.45
	add_child(light)
	buzz = AudioStreamPlayer3D.new()
	var sound = load("res://audio/buzz.wav") as AudioStreamWAV
	sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sound.loop_end = int(sound.get_length() * sound.mix_rate)
	buzz.stream = sound
	buzz.unit_size = 2.5
	buzz.max_distance = 12
	buzz.max_db = -3
	buzz.volume_db = -3
	add_child(buzz)

func _exit_tree() -> void:
	if is_instance_valid(buzz):
		buzz.stop()
		buzz.stream = null

func reset_body() -> void:
	position = Vector3(0.7,1.75,0.4)
	gaze = (player.position+Vector3.UP*1.2-position).normalized()
	velocity = Vector3.ZERO
	avoided = Vector3.ZERO
	sight = {}
	visible_player = false
	clock = 0
	last_seen_target = Vector3.ZERO
	last_seen_until = -1
	dart = Vector3.ZERO
	dart_until = 0
	flight_rng.seed = int(director.seed_value)+1701
	hp = max_hp

func take_damage(amount: int) -> void:
	if not active or hp <= 0: return
	hp = maxi(0, hp-amount)
	if hp == 0:
		active = false
		defeated.emit()

func _physics_process(delta: float) -> void:
	if not active: return
	clock += delta
	buzz.pitch_scale = move_toward(buzz.pitch_scale,0.94 + minf(velocity.length(),8.0)*0.035,delta*2.5)
	# Rotor spin is cosmetic, never a neural activity measurement or force model.
	for i in rotors.size(): rotors[i].rotation.y=clock*85*(1.0 if i%2==0 else -1.0)
	var target: Vector3 = player.global_position+Vector3.UP*1.25
	var relative := target-global_position
	var ray := PhysicsRayQueryParameters3D.create(global_position,target,1)
	ray.exclude=[get_rid(),player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	visible_player=relative.length()<18 and gaze.dot(relative.normalized())>-0.8 and hit.is_empty()
	var output: Array = director.neural.get("output",[0,0,0,0])
	var fresh: bool = director.connected and director.last_neural_time>=0 and director.now()-director.last_neural_time<director.interval+1.5
	if not fresh or output.all(func(value): return absf(float(value))<0.000001):
		velocity = Vector3.ZERO
		avoided = Vector3.ZERO
		sight = {}
		return
	var lateral := clampf((float(output[0])-float(output[1]))*15,-1,1)
	var climb := clampf((float(output[2])+float(output[3]))*5,-0.75,0.75)
	var speed := clampf(absf(float(output[0]))*40,4.8,8.0)
	if clock>=dart_until:
		dart_until=clock+flight_rng.randf_range(0.18,0.42)
		dart=Vector3(flight_rng.randf_range(-2.8,2.8),flight_rng.randf_range(-1.6,1.6),flight_rng.randf_range(-0.8,0.8))
	if visible_player:
		last_seen_target=target
		last_seen_until=clock+3.0
		var telemetry: Dictionary = player.telemetry()
		telemetry.x=relative.x
		telemetry.z=relative.z-5 # Existing z normalization becomes relative distance / 11.
		sight=telemetry
	else:
		sight={}
	var tracking := visible_player or clock<last_seen_until
	if tracking:
		relative=last_seen_target-global_position
		gaze=gaze.lerp(relative.normalized(),1-exp(-10*delta)).normalized()
	else:
		# ponytail: local search and last-seen pursuit; add navigation only if doorway tests show trapping.
		gaze=gaze.rotated(Vector3.UP,delta*(1.8+absf(lateral))*(-1.0 if lateral<0 else 1.0))
	var desired := gaze*speed
	# Pursue contact rather than the horror controller's 2.3 m standoff.
	# Slow only at a remembered point; never reverse away from a visible target.
	if tracking: desired*=clampf(relative.length(),0.0,1.0)
	else: desired*=0.65
	desired += gaze.cross(Vector3.UP)*(lateral*0.65+dart.x)+Vector3.UP*(climb+dart.y)+gaze*dart.z+avoided
	if position.y<0.7: desired.y=maxf(desired.y,1.5)
	if position.y>2.7: desired.y=minf(desired.y,-1.5)
	velocity=velocity.move_toward(desired.limit_length(8.0),delta*24)
	move_and_slide()
	# Contact deals full HP for now; per-body-part graded damage is a later extension.
	if player.active and global_position.distance_to(player.global_position+Vector3.UP*1.25)<CONTACT_DISTANCE:
		# Recheck after movement: even a thin wall must block proximity damage.
		var contact_ray := PhysicsRayQueryParameters3D.create(global_position,player.global_position+Vector3.UP*1.25,1)
		contact_ray.exclude = [get_rid(),player.get_rid()]
		if get_world_3d().direct_space_state.intersect_ray(contact_ray).is_empty():
			player.take_damage(player.max_hp)
	avoided=avoided.move_toward(Vector3.ZERO,delta*4)
	for i in get_slide_collision_count(): avoided+=get_slide_collision(i).get_normal()*3
	avoided=avoided.limit_length(4)
	if gaze.length()>0.1: body.look_at(global_position+gaze,Vector3.UP)
