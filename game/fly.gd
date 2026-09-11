extends CharacterBody3D

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
var visible_player := false
var sight := {}
var wings: Array[MeshInstance3D] = []
var gaze := Vector3.FORWARD
var body: Node3D
var clock := 0.0
var avoided := Vector3.ZERO
var last_seen_target := Vector3.ZERO
var last_seen_until := -1.0
var dart := Vector3.ZERO
var dart_until := 0.0
var flight_rng := RandomNumberGenerator.new()

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
	var abdomen := SphereMesh.new()
	abdomen.radius = 0.12
	abdomen.height = 0.34
	mesh(abdomen,Vector3.ZERO,Color(0.07,0.15,0.13),body).rotation.x=PI/2
	var head := SphereMesh.new()
	head.radius = 0.105
	head.height = 0.21
	mesh(head,Vector3(0,0,-0.19),Color(0.11,0.16,0.14),body)
	for side in [-1,1]:
		var eye := SphereMesh.new()
		eye.radius = 0.06
		eye.height = 0.12
		mesh(eye,Vector3(side*0.075,0.025,-0.23),Color(0.66,0.19,0.08),body)
		var wing := SphereMesh.new()
		wing.radius = 0.16
		wing.height = 0.018
		var node := mesh(wing,Vector3(side*0.20,0.05,0),Color(0.42,0.66,0.62),body)
		node.scale.z=1.6
		wings.append(node)
		for i in 3:
			var leg := CylinderMesh.new()
			leg.top_radius=0.009
			leg.bottom_radius=0.007
			leg.height=0.18
			mesh(leg,Vector3(side*0.11,-0.1,-0.1+i*0.1),Color(0.17,0.24,0.2),body).rotation.z=side*0.7
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

func _physics_process(delta: float) -> void:
	if not active: return
	clock += delta
	buzz.pitch_scale = move_toward(buzz.pitch_scale,0.94 + minf(velocity.length(),8.0)*0.035,delta*2.5)
	# Wing flapping is a cosmetic animation, never a neural activity measurement.
	for i in wings.size(): wings[i].rotation.z=sin(clock*85)*(0.65 if i==0 else -0.65)
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
	if tracking: desired*=clampf(relative.length()-(2.3 if visible_player else 0.0),-0.75,1.0)
	else: desired*=0.65
	desired += gaze.cross(Vector3.UP)*(lateral*0.65+dart.x)+Vector3.UP*(climb+dart.y)+gaze*dart.z+avoided
	if position.y<0.7: desired.y=maxf(desired.y,1.5)
	if position.y>2.7: desired.y=minf(desired.y,-1.5)
	velocity=velocity.move_toward(desired.limit_length(8.0),delta*24)
	move_and_slide()
	avoided=avoided.move_toward(Vector3.ZERO,delta*4)
	for i in get_slide_collision_count(): avoided+=get_slide_collision(i).get_normal()*3
	avoided=avoided.limit_length(4)
	if gaze.length()>0.1: body.look_at(global_position+gaze,Vector3.UP)
