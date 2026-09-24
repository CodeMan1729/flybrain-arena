extends CanvasLayer

# Isolated first-person view: cosmetic only, no colliders or gameplay rays.
var surface: SubViewportContainer
var viewport: SubViewport
var rig: Node3D
var flash: MeshInstance3D
var recoil := 0.0
var flash_left := 0.0
const REST := Vector3(0.22,-0.19,-0.48)

func part(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	node.mesh = shape
	node.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.5
	node.material_override = mat
	rig.add_child(node)
	return node

func _ready() -> void:
	layer = 0 # World < weapon < existing HUD (layer 1).
	surface = SubViewportContainer.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.stretch = true
	surface.stretch_shrink = 2
	add_child(surface)
	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	surface.add_child(viewport)
	var camera := Camera3D.new()
	camera.fov = 65
	camera.near = 0.02
	viewport.add_child(camera)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30,-25,0)
	light.light_energy = 1.7
	viewport.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.65,0.74,0.85)
	env.environment.ambient_light_energy = 0.7
	viewport.add_child(env)
	rig = Node3D.new()
	rig.position = REST
	# Barrel points slightly inward, leaving the center reticle unobstructed.
	rig.rotation.y = 0.12
	viewport.add_child(rig)
	part(Vector3(0.095,0.095,0.28),Vector3.ZERO,Color(0.13,0.18,0.23)).name = "Receiver"
	part(Vector3(0.065,0.045,0.32),Vector3(0,0.06,-0.025),Color(0.30,0.37,0.42))
	part(Vector3(0.042,0.042,0.16),Vector3(0,0.015,-0.21),Color(0.09,0.12,0.15)).name = "Barrel"
	var grip := part(Vector3(0.065,0.16,0.08),Vector3(0,-0.09,0.07),Color(0.08,0.10,0.12))
	grip.rotation.x = -0.2
	part(Vector3(0.068,0.11,0.085),Vector3(0,-0.085,-0.055),Color(0.20,0.25,0.29))
	part(Vector3(0.012,0.027,0.025),Vector3(0,0.095,-0.14),Color(0.2,0.85,0.95))
	part(Vector3(0.035,0.012,0.13),Vector3(0.049,0.015,0.005),Color(0.15,0.65,0.8))
	flash = MeshInstance3D.new()
	var flame := SphereMesh.new()
	flame.radius = 0.032
	flame.height = 0.064
	flash.mesh = flame
	flash.position = Vector3(0,0.015,-0.315)
	flash.scale = Vector3(0.7,0.7,2.0)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1,0.8,0.35)
	flash.material_override = glow
	rig.add_child(flash)
	reset_view()
	hide()

func reset_view() -> void:
	recoil = 0
	flash_left = 0
	if is_instance_valid(rig): rig.position = REST
	if is_instance_valid(flash): flash.hide()

func set_active(value: bool) -> void:
	visible = value
	if not value: reset_view()

func shoot() -> void:
	if not visible: return
	recoil = 1.0
	flash_left = 0.055
	flash.show()
	rig.position = REST+Vector3(0,0.012,0.035)

func _process(delta: float) -> void:
	if not visible: return
	recoil = move_toward(recoil,0,delta*9)
	flash_left = maxf(0,flash_left-delta)
	flash.visible = flash_left>0
	rig.position = REST+Vector3(0,0.012,0.035)*recoil
