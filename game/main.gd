extends Node3D

const PlayerScript = preload("res://player.gd")
const DirectorScript = preload("res://director.gd")
const BrainViewScript = preload("res://brain_view.gd")
const FlyScript = preload("res://fly.gd")
const ACTION_NAMES := {"lights":"Işık kesintisi", "steps":"Arkadan gelen ses", "silhouette":"Görüş kenarı silueti", "wait":"Bekle"}
const SCARE_SOUNDS := ["steps", "breath", "creak", "knock"]
const MODE_NAMES := ["Rastgele seçim · kontrol", "Sabit bağlantı modeli", "Beyin + öğrenen karar katmanı"]
const MODES := ["random", "fixed", "learn"]
# ponytail: three hand-checked surfaces; add validated spots when the map grows.
const KEY_SPOTS := [Vector3(-7.4,1.04,-9.35), Vector3(-2.8,1.04,-1.65), Vector3(8.3,1.59,-9.7)]

var player: CharacterBody3D
var director: Node
var fly: CharacterBody3D
var brain_view: Control
var memory_text: Label
var key_object: Node3D
var key_rng := RandomNumberGenerator.new()
var key_seed := -1
var key_slot := -1
var door: StaticBody3D
var silhouette: Node3D
var footsteps: AudioStreamPlayer3D
var scare_streams: Array[AudioStreamWAV] = []
var sound_rng := RandomNumberGenerator.new()
var last_sound := -1
var ambience: AudioStreamPlayer
var room_lights: Array[OmniLight3D] = []
var has_key := false
var door_open := false
var playing := false
var completed := false
var intensity := 0.65
var volume := 0.45
var decision_interval := 3.0
var dark_until := 0.0
var silhouette_until := 0.0
var events: Array[Dictionary] = []
var elapsed := 0.0
var frame_times: Array[float] = []
var brain_view_frame_times: Array[float] = []
var last_frame_usec := 0
var ui_clock := 0.1
var hud: Control
var menu: Control
var settings: VBoxContainer
var menu_title: Label
var start_button: Button
var mode_choice: OptionButton
var seed_box: SpinBox
var objective: Label
var prompt: Label
var badge: Label
var debug_panel: PanelContainer
var debug_text: Label
var notice: Label
var science_note: Label
var feedback_text: Label
var smoke := false
var benchmark := false
var evidence_dir := ""
var smoke_checks: Array[String] = []
var settings_path := "user://settings.cfg"
var preferences := ConfigFile.new()
var settings_notice := ""
var settings_writable := true
var fullscreen := false
var brain_was_running := false
var brain_was_visible := true
var research_modes := false
var web_pause_callback: JavaScriptObject

func _exit_tree() -> void:
	if is_instance_valid(ambience):
		ambience.stop()
		ambience.stream = null
	if is_instance_valid(footsteps):
		footsteps.stop()
		footsteps.stream = null
	if is_instance_valid(director):
		director.socket.close()

func _ready() -> void:
	get_tree().auto_accept_quit = false
	get_window().close_requested.connect(quit_game)
	var args := OS.get_cmdline_user_args()
	smoke = "--smoke" in args
	benchmark = "--benchmark" in args
	research_modes = (research_modes or smoke or benchmark) and not OS.has_feature("web")
	if smoke or benchmark: settings_path = ""
	load_settings()
	set_volume(volume)
	evidence_dir = ProjectSettings.globalize_path("res://../reports")
	build_world()
	player = CharacterBody3D.new()
	player.set_script(PlayerScript)
	player.name = "Player"
	add_child(player)
	player.sensitivity = setting_number("sensitivity",0.002,0.0007,0.004)
	player.position = Vector3(2.0, 0.08, 3.3)
	player.rotation.y = 0.15
	director = Node.new()
	director.set_script(DirectorScript)
	add_child(director)
	director.action_received.connect(apply_action)
	fly = CharacterBody3D.new()
	fly.set_script(FlyScript)
	fly.player = player
	fly.director = director
	add_child(fly)
	fly.reset_body()
	build_ui()
	if OS.has_feature("web"):
		web_pause_callback = JavaScriptBridge.create_callback(func(_args):
			if player.active: pause_game()
		)
		JavaScriptBridge.get_interface("window").flyfearPause = web_pause_callback
	if not smoke and not benchmark:
		get_window().focus_exited.connect(func():
			if player.active: pause_game()
		)
	for arg in args:
		if research_modes and arg.begins_with("--mode="):
			var selected := MODES.find(arg.trim_prefix("--mode="))
			if selected >= 0: mode_choice.select(selected)
	if fullscreen and not OS.has_feature("web"): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if smoke or benchmark:
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		get_window().content_scale_size = Vector2i(1920, 1080)
		call_deferred("automated_run")

func setting_number(key: String, fallback: float, low: float, high: float) -> float:
	var value: Variant = preferences.get_value("settings",key,fallback)
	if not (value is float or value is int) or not is_finite(float(value)): return fallback
	return clampf(float(value),low,high)

func load_settings() -> void:
	if settings_path.is_empty(): return
	var error := preferences.load(settings_path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		preferences.clear()
		var backup := settings_path + ".broken-" + str(Time.get_unix_time_from_system())
		settings_writable = DirAccess.copy_absolute(settings_path,backup) == OK
		settings_notice = "Ayarlar açılamadı; yedek alındı, varsayılanlar kullanılıyor." if settings_writable else "Ayarlar açılamadı ve yedeklenemedi; önceki dosya korunuyor, değişiklikler bu oturum için geçerli."
	volume = setting_number("volume",0.45,0,0.7)
	intensity = setting_number("intensity",0.65,0,1)
	decision_interval = setting_number("interval",3,2,5)
	var saved_fullscreen: Variant = preferences.get_value("settings","fullscreen",false)
	fullscreen = saved_fullscreen is bool and saved_fullscreen

func save_settings() -> Error:
	if settings_path.is_empty() or not settings_writable: return ERR_UNAVAILABLE
	var values := {"volume":volume,"intensity":intensity,"sensitivity":player.sensitivity,
		"interval":decision_interval,"mode":MODES[mode_choice.selected],"seed":int(seed_box.value),"fullscreen":fullscreen}
	for key in values: preferences.set_value("settings",key,values[key])
	var temporary := settings_path + ".tmp"
	var error := preferences.save(temporary)
	if error == OK: error = DirAccess.rename_absolute(temporary,settings_path)
	settings_notice = "" if error == OK else "Ayarlar kaydedilemedi; önceki kayıt korundu. Değişiklikler bu oturum için geçerli."
	return error

func toggle_fullscreen() -> void:
	fullscreen = DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	save_settings()

func material(color: Color, emission := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.88
	if emission > 0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat

func box(pos: Vector3, size: Vector3, mat: Material, solid := true, parent: Node = self) -> Node3D:
	var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
	body.position = pos
	parent.add_child(body)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	mesh.material_override = mat
	body.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	return body

func label3(text: String, pos: Vector3, size := 44, color := Color(0.58, 0.7, 0.67)) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = size
	label.pixel_size = 0.007
	label.modulate = color
	label.no_depth_test = false
	add_child(label)
	return label

func lamp(pos: Vector3, color: Color, energy: float, distance: float, part_of_room := true) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = distance
	light.set_meta("base_energy", energy)
	add_child(light)
	if part_of_room: room_lights.append(light)
	return light

func build_world() -> void:
	var env := WorldEnvironment.new()
	var atmosphere := Environment.new()
	atmosphere.background_mode = Environment.BG_COLOR
	atmosphere.background_color = Color(0.006, 0.012, 0.02)
	atmosphere.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	atmosphere.ambient_light_color = Color(0.22, 0.32, 0.42)
	atmosphere.ambient_light_energy = 0.23
	atmosphere.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	atmosphere.fog_enabled = true
	atmosphere.fog_light_color = Color(0.025, 0.042, 0.054)
	atmosphere.fog_density = 0.016
	env.environment = atmosphere
	add_child(env)
	var concrete := material(Color(0.21, 0.245, 0.25))
	var noise := FastNoiseLite.new()
	noise.seed = 42
	noise.frequency = 0.06
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	var gradient := Gradient.new()
	gradient.set_color(0,Color(0.48,0.50,0.51))
	gradient.set_color(1,Color(0.86,0.88,0.89))
	texture.color_ramp = gradient
	concrete.albedo_texture = texture
	concrete.uv1_triplanar = true
	concrete.uv1_scale = Vector3(0.35, 0.35, 0.35)
	var floor_mat := material(Color(0.12, 0.16, 0.17))
	var metal := material(Color(0.10, 0.14, 0.15))
	var dark := material(Color(0.025, 0.037, 0.043))
	var brass := material(Color(0.59, 0.34, 0.12))
	var amber := material(Color(1.0, 0.43, 0.15), 2.0)
	var teal := material(Color(0.22, 0.78, 0.66), 1.6)
	box(Vector3(0,-0.2,0),Vector3(12,0.4,12),floor_mat)
	box(Vector3(0,3.6,0),Vector3(12,0.3,12),dark)
	box(Vector3(-6,1.8,0),Vector3(0.3,3.6,12),concrete)
	box(Vector3(6,1.8,0),Vector3(0.3,3.6,12),concrete)
	box(Vector3(0,1.8,6),Vector3(12,3.6,0.3),concrete)
	for x in [-3.75,3.75]:
		box(Vector3(x,1.8,-6),Vector3(4.5,3.6,0.3),concrete)
	box(Vector3(0,3.2,-6),Vector3(3,0.8,0.3),concrete)
	box(Vector3(0,-0.2,-11),Vector3(3,0.4,10),floor_mat)
	box(Vector3(0,3.2,-11),Vector3(3,0.3,10),dark)
	for x in [-1.65,1.65]:
		# Side doorways are 2.4 m wide with a continuous floor underneath.
		box(Vector3(x,1.6,-6.9),Vector3(0.3,3.2,1.8),concrete)
		box(Vector3(x,1.6,-13.1),Vector3(0.3,3.2,5.8),concrete)
		box(Vector3(x,2.95,-9),Vector3(0.3,0.5,2.4),concrete)
	box(Vector3(0,1.6,-16),Vector3(3,3.2,0.3),concrete)
	# Two furnished side rooms share a rear service passage; the exit stays sealed.
	for side in [-1,1]:
		box(Vector3(side*5.65,-0.2,-11),Vector3(8.3,0.4,8),floor_mat)
		box(Vector3(side*5.65,3.2,-11),Vector3(8.3,0.3,8),dark)
		box(Vector3(side*9.65,1.6,-11),Vector3(0.3,3.2,8),concrete)
		box(Vector3(side*5.65,1.6,-7),Vector3(8,3.2,0.3),concrete)
		for segment in [Vector2(3.225,3.15),Vector2(8.425,2.45)]:
			box(Vector3(side*segment.x,1.6,-15),Vector3(segment.y,3.2,0.3),concrete)
		box(Vector3(side*6,2.95,-15),Vector3(2.4,0.5,0.3),concrete)
		box(Vector3(side*6,-0.2,-16),Vector3(2.4,0.4,2),floor_mat)
		box(Vector3(side*6,3.2,-16),Vector3(2.4,0.3,2),dark)
		for edge in [4.65,7.35]:
			box(Vector3(side*edge,1.6,-16),Vector3(0.3,3.2,2),concrete)
		box(Vector3(side*5.8,2.94,-10),Vector3(2.0,0.06,0.22),amber if side<0 else teal,false)
		lamp(Vector3(side*5.8,2.65,-10),Color(0.98,0.56,0.28) if side<0 else Color(0.35,0.68,0.66),1.25,6.5)
		box(Vector3(side*1.65,0.015,-9),Vector3(0.45,0.02,2.3),brass,false)
		label3("SERVİS GEÇİDİ",Vector3(side*6,2.85,-14.78),24,Color(0.36,0.79,0.69))
	box(Vector3(0,-0.2,-18.5),Vector3(14.4,0.4,3),floor_mat)
	box(Vector3(0,3.2,-18.5),Vector3(14.4,0.3,3),dark)
	box(Vector3(0,1.6,-20),Vector3(14.7,3.2,0.3),concrete)
	box(Vector3(0,1.6,-17),Vector3(9.6,3.2,0.3),concrete)
	for x in [-7.35,7.35]:
		box(Vector3(x,1.6,-18.5),Vector3(0.3,3.2,3),concrete)
	for x in [-6,0,6]:
		box(Vector3(x,0.04,-19.8),Vector3(1.2,0.04,0.08),teal,false)
		lamp(Vector3(x,1.8,-19.65),Color(0.23,0.56,0.49),0.6,4.2,false)
		box(Vector3(x,2.95,-18.5),Vector3(0.1,0.12,2.8),metal,false)
	box(Vector3(0,2.65,-19.7),Vector3(14.2,0.14,0.14),brass,false)
	label3("← ARŞİV       SERVİS / 03       MAKİNE →",Vector3(0,1.8,-19.8),28)
	# Archive shelving and folders leave the central aisle and both doors clear.
	for z in [-11.8,-13.7]:
		box(Vector3(-9.12,1.05,z),Vector3(0.6,2.1,1.65),metal)
		for y in [0.4,1.0,1.6]:
			box(Vector3(-8.77,y,z),Vector3(0.05,0.045,1.55),brass,false)
			for offset in [-0.5,0.0,0.5]:
				box(Vector3(-8.79,y+0.21,z+offset),Vector3(0.12,0.37,0.28),brass if offset==0 else floor_mat,false)
	box(Vector3(-7.4,0.88,-9.5),Vector3(2.2,0.15,1.1),metal)
	for x in [-8.3,-6.5]:
		for z in [-9.9,-9.1]: box(Vector3(x,0.42,z),Vector3(0.1,0.85,0.1),metal)
	box(Vector3(-8,1.02,-9.65),Vector3(0.42,0.1,0.35),floor_mat,false)
	box(Vector3(-7.4,1.12,-9.82),Vector3(1,0.32,0.05),metal,false)
	label3("TESLİM MASASI",Vector3(-7.4,1.13,-9.78),14,Color(0.86,0.65,0.37))
	label3("ARŞİV / 01",Vector3(-8.4,2.45,-14.79),36,Color(0.86,0.65,0.37))
	# Original generator cabinets, vents and a cable tray in the machine room.
	for z in [-10,-12.5]:
		box(Vector3(8.55,0.75,z),Vector3(1.25,1.5,1.5),metal)
		for y in [0.5,0.7,0.9,1.1]:
			box(Vector3(7.91,y,z),Vector3(0.025,0.06,1.15),dark,false)
		box(Vector3(7.89,1.3,z),Vector3(0.025,0.08,0.12),teal,false)
	box(Vector3(9.43,2.1,-11.3),Vector3(0.06,0.6,2.1),dark,false)
	label3("MAKİNE / 02",Vector3(9.36,2.12,-11.3),30).rotation.y=-PI/2
	box(Vector3(8.8,2.75,-11),Vector3(0.3,0.15,7.5),metal,false)
	label3("← ARŞİV     ÇIKIŞ ↑     MAKİNE →",Vector3(0,2.68,-7.6),22,Color(0.53,0.84,0.74))
	for x in range(-5,6,2):
		box(Vector3(x,0.006,0),Vector3(0.018,0.008,11.7),dark,false)
	for z in range(-5,6,2):
		box(Vector3(0,0.006,z),Vector3(11.7,0.008,0.018),dark,false)
	for x in [-5.77,5.77]:
		box(Vector3(x,0.18,0),Vector3(0.06,0.36,11.8),metal,false)
		box(Vector3(x,2.55,0),Vector3(0.06,0.12,11.8),metal,false)
		for z in [-4,-1,2,5]:
			box(Vector3(x,1.3,z),Vector3(0.1,2.1,0.07),metal,false)
	for z in [-3,3]:
		box(Vector3(0,3.37,z),Vector3(2.6,0.1,0.28),metal,false)
		box(Vector3(0,3.30,z),Vector3(2.3,0.025,0.17),amber,false)
		lamp(Vector3(0,2.9,z),Color(1.0,0.57,0.29),1.6,7.3)
	for z in [-11,-13]:
		box(Vector3(-1.47,2.55,z),Vector3(0.08,0.12,0.7),teal,false)
		lamp(Vector3(-1.25,2.3,z),Color(0.25,0.66,0.60),0.9,4.0,false)
		for x in [-1.43,1.43]:
			box(Vector3(x,0.06,z),Vector3(0.06,0.025,1.5),teal,false)
	# Original primitive furniture leaves a wide navigable route.
	box(Vector3(-3,0.88,-1.8),Vector3(2.4,0.15,1.2),metal)
	for x in [-4,-2]:
		for z in [-2.2,-1.4]:
			box(Vector3(x,0.42,z),Vector3(0.1,0.85,0.1),metal)
	box(Vector3(-3.7,1.04,-2),Vector3(0.65,0.18,0.5),dark)
	box(Vector3(-5.3,0.55,2.8),Vector3(0.85,1.1,2.4),metal)
	for z in [2.0,2.8,3.6]:
		box(Vector3(-5.25,1.5,z),Vector3(0.65,0.75,0.65),brass)
	box(Vector3(4.4,0.55,-3.9),Vector3(1.8,1.1,0.8),metal)
	for x in [3.8,4.4,5.0]:
		box(Vector3(x,0.6,-3.47),Vector3(0.52,0.85,0.025),dark,false)
		box(Vector3(x,0.85,-3.44),Vector3(0.25,0.035,0.03),brass,false)
	box(Vector3(3.7,1.85,-5.78),Vector3(2.9,1.1,0.06),dark,false)
	label3("KARANTİNA / 09\nGÖZLEM ODASI",Vector3(3.7,1.88,-5.72),47)
	label3("Ç I K I Ş",Vector3(0,2.77,-14.57),48,Color(0.35,1,0.76))
	label3("01",Vector3(-3,2.65,-5.8),76,Color(0.61,0.42,0.23))
	label3("ANAHTAR KAYIP\nODALARI ARA",Vector3(-3,1.85,-5.78),27,Color(0.73,0.60,0.35))
	key_object = Node3D.new()
	key_object.position = KEY_SPOTS[0]
	add_child(key_object)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.08
	torus.outer_radius = 0.13
	ring.mesh = torus
	ring.material_override = material(Color(0.94,0.65,0.21),0.6)
	key_object.add_child(ring)
	box(Vector3(0.17,0,0),Vector3(0.28,0.035,0.055),ring.material_override,false,key_object)
	box(Vector3(0.28,0,-0.05),Vector3(0.05,0.035,0.1),ring.material_override,false,key_object)
	lamp(Vector3(0,0.46,0),Color(0.95,0.61,0.25),0.35,2.0,false).reparent(key_object,false)
	door = box(Vector3(0,1.35,-14.8),Vector3(2.98,2.7,0.18),metal) as StaticBody3D
	box(Vector3(0,0.1,0.11),Vector3(0.42,0.2,0.035),brass,false,door)
	box(Vector3(0.85,-0.1,0.12),Vector3(0.28,0.07,0.07),brass,false,door)
	for y in [-0.8,0.7]:
		box(Vector3(0,y,0.11),Vector3(2.4,0.07,0.025),dark,false,door)
	silhouette = Node3D.new()
	add_child(silhouette)
	var body_mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.height = 1.3
	capsule.radius = 0.24
	body_mesh.mesh = capsule
	body_mesh.position.y = 0.9
	body_mesh.material_override = material(Color(0.008,0.012,0.014))
	silhouette.add_child(body_mesh)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.17
	sphere.height = 0.34
	head.mesh = sphere
	head.position.y = 1.7
	head.material_override = body_mesh.material_override
	silhouette.add_child(head)
	silhouette.visible = false
	footsteps = AudioStreamPlayer3D.new()
	for sound in SCARE_SOUNDS: scare_streams.append(load("res://audio/"+sound+".wav"))
	footsteps.stream = scare_streams[0]
	footsteps.max_db = -6
	footsteps.volume_db = -6
	footsteps.unit_size = 2.5
	footsteps.max_distance = 9
	add_child(footsteps)
	ambience = AudioStreamPlayer.new()
	var hum = load("res://audio/hum.wav") as AudioStreamWAV
	hum.loop_mode = AudioStreamWAV.LOOP_FORWARD
	hum.loop_end = int(hum.get_length() * hum.mix_rate)
	ambience.stream = hum
	ambience.volume_db = -8
	add_child(ambience)
	ambience.play()

func ui_label(text: String, size: int, color := Color(0.77,0.84,0.82)) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	return label

func button(text: String, callback: Callable, parent: Node) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(470,58)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 22
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065,0.10,0.11,0.96)
	style.border_color = Color(0.22,0.36,0.35)
	style.set_border_width_all(1)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	theme.set_stylebox("normal","Button",style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.13,0.24,0.23)
	theme.set_stylebox("hover","Button",hover)
	theme.set_stylebox("pressed","Button",hover)
	var focus := style.duplicate()
	focus.bg_color = Color(0,0,0,0)
	focus.border_color = Color(0.48,0.86,0.71)
	focus.set_border_width_all(2)
	theme.set_stylebox("focus","Button",focus)
	root.theme = theme
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){vec2 p=UV*2.0-1.0;float v=smoothstep(0.3,1.5,length(p));COLOR=vec4(0.0,0.008,0.012,v*0.46);}"
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = shader
	vignette.material = shader_mat
	root.add_child(vignette)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	objective = ui_label("01 / ANAHTARI BUL",26,Color(0.88,0.76,0.54))
	objective.position = Vector2(52,42)
	hud.add_child(objective)
	badge = ui_label("",18)
	badge.position = Vector2(52,84)
	hud.add_child(badge)
	var controls := ui_label("W A S D  Hareket     F  El feneri     E  Etkileşim     B  Beyin     V  Beyni incele     TAB  Ölçümler     ESC  Duraklat",18)
	controls.position = Vector2(52,1016)
	hud.add_child(controls)
	var cross := ui_label("·",32,Color(0.8,0.86,0.83,0.7))
	cross.position = Vector2(954,514)
	hud.add_child(cross)
	prompt = ui_label("",23,Color(0.98,0.82,0.5))
	prompt.position = Vector2(560,872)
	prompt.size.x = 800
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(prompt)
	feedback_text = ui_label("",19,Color(0.74,0.83,0.77))
	feedback_text.position = Vector2(220,932)
	feedback_text.size.x = 1100
	feedback_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(feedback_text)
	debug_panel = PanelContainer.new()
	debug_panel.position = Vector2(1360,38)
	debug_panel.custom_minimum_size = Vector2(510,370)
	debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := style.duplicate()
	panel_style.bg_color = Color(0.015,0.032,0.04,0.94)
	debug_panel.add_theme_stylebox_override("panel",panel_style)
	debug_text = ui_label("",19)
	debug_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	debug_panel.add_child(debug_text)
	hud.add_child(debug_panel)
	debug_panel.visible = false
	brain_view = Control.new()
	brain_view.set_script(BrainViewScript)
	brain_view.director = director
	hud.add_child(brain_view)
	brain_view.close_requested.connect(toggle_brain_details)
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	var shade := ColorRect.new()
	shade.color = Color(0.007,0.018,0.026,0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(shade)
	var strip := ColorRect.new()
	strip.position = Vector2(78,108)
	strip.size = Vector2(4,94)
	strip.color = Color(0.70,0.37,0.18)
	menu.add_child(strip)
	var eyebrow := ui_label("B A Ğ L A N T I   /   D E N E Y   0 1",18,Color(0.45,0.71,0.65))
	eyebrow.position = Vector2(110,106)
	menu.add_child(eyebrow)
	var title := ui_label("FLYFEAR",90,Color(0.90,0.91,0.85))
	title.position = Vector2(105,131)
	menu.add_child(title)
	var subtitle := ui_label("Oda seni izlemiyor. Ama hareketlerini okuyor.",24)
	subtitle.position = Vector2(110,255)
	menu.add_child(subtitle)
	var column := VBoxContainer.new()
	column.position = Vector2(110,335)
	column.add_theme_constant_override("separation",12)
	menu.add_child(column)
	menu_title = ui_label("Üç odada anahtarı ara. Çıkışa ulaş.",22,Color(0.88,0.69,0.42))
	column.add_child(menu_title)
	column.add_child(ui_label("DENEY MODU" if research_modes else "ÖĞRENME HER TURDA AÇIK",15))
	mode_choice = OptionButton.new()
	mode_choice.custom_minimum_size = Vector2(530,48)
	for text in MODE_NAMES: mode_choice.add_item(text)
	var saved_mode: Variant = preferences.get_value("settings","mode","learn")
	mode_choice.select(MODES.find(saved_mode) if research_modes and saved_mode in MODES else 2)
	mode_choice.visible = research_modes
	mode_choice.item_selected.connect(func(_index): save_settings())
	column.add_child(mode_choice)
	start_button = button("BAŞLAT", start_game,column)
	button("AYARLAR",func(): settings.visible = not settings.visible; science_note.visible = not settings.visible; memory_text.visible = not settings.visible,column)
	button("ANA SAYFA" if OS.has_feature("web") else "ÇIKIŞ",quit_game,column)
	column.add_child(ui_label("WASD / Fare · E etkileşim · F el feneri",17))
	settings = VBoxContainer.new()
	settings.position = Vector2(850,340)
	settings.custom_minimum_size.x = 560
	settings.add_theme_constant_override("separation",12)
	menu.add_child(settings)
	settings.add_child(ui_label("AYARLAR / OTOMATİK KAYIT",26,Color(0.88,0.76,0.54)))
	add_slider("Ses · 0 = tamamen sessiz",0,0.7,volume,set_volume)
	add_slider("Efekt yoğunluğu · 0 = olaylar kapalı",0,1,intensity,func(v): intensity=v)
	add_slider("Karar aralığı · saniye (yeni turda)",2,5,decision_interval,func(v): decision_interval=v)
	add_slider("Fare hassasiyeti",0.0007,0.004,player.sensitivity,func(v): player.sensitivity=v)
	settings.add_child(ui_label("Tohum · yeni turda uygulanır",18))
	seed_box = SpinBox.new()
	seed_box.max_value = 4294967295
	seed_box.value = setting_number("seed",42,0,4294967295)
	seed_box.value_changed.connect(func(_value): save_settings())
	settings.add_child(seed_box)
	if not OS.has_feature("web"):
		button("Öğrenilen karar katmanını kaydet",func(): director.send({"type":"save"}),settings)
		button("Öğrenilen karar katmanını sıfırla",func(): director.send({"type":"reset"}),settings)
	button("Tam ekran / pencere",toggle_fullscreen,settings)
	settings.visible = false
	memory_text = ui_label("",20)
	memory_text.position = Vector2(850,345)
	menu.add_child(memory_text)
	var science := ui_label("GERÇEK VERİ. TASARLANMIŞ EŞLEME.\n\nMaleCNS v1.0 bağlantıları üzerinde sayısal sinir etkinliği.\nSinek oyuncuyu yönetmez; odadaki olayları seçer.\nÖğrenme, beyin üzerine eklenen karar katmanındadır.\nTepki puanı korkunun kesin ölçüsü değildir.\n\nTamamen yerel · Kamera ve mikrofon kullanılmaz.",21)
	if OS.has_feature("web"):
		science.text = "HER OYUN ORTAK ÖĞRENMEYE KATILIR.\n\nOyun içi hareketlerin ve 1 / 2 / 3 değerlendirmelerin\nkimlik bilgisi olmadan öğrenme için kaydedilir.\nBaşlat'a basarak bu katkıyla oynamayı seçersin.\nKamera, mikrofon ve gerçek konum kullanılmaz.\n\nSinir ağı gerçek bağlantı verisinden hesaplanır.\nÖğrenme dış karar katmanındadır; korku garantisi yoktur."
	science_note = science
	science.position = Vector2(850,720 if OS.has_feature("web") else 800)
	menu.add_child(science)
	notice = ui_label("Beyin verisi yükleniyor…",17,Color(0.49,0.72,0.66))
	notice.position = Vector2(110,974)
	menu.add_child(notice)
	hud.visible = false
	start_button.grab_focus()

func set_volume(value: float) -> void:
	volume = clampf(value,0,0.7)
	AudioServer.set_bus_mute(0,volume == 0)
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(volume*0.6,0.0001)))

func add_slider(text: String, low: float, high: float, value: float, callback: Callable) -> void:
	var format := "%s  %.4f" if high < 0.01 else "%s  %.2f"
	var label := ui_label(format % [text,value],18)
	settings.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.0001 if high < 0.01 else 0.01
	slider.value = value
	slider.custom_minimum_size = Vector2(530,24)
	slider.value_changed.connect(func(v): label.text=format % [text,v]; callback.call(v); save_settings())
	settings.add_child(slider)

func place_key() -> void:
	# A separate stream keeps layout choices from changing scare-sound randomness.
	if key_seed != int(seed_box.value):
		key_seed = int(seed_box.value)
		key_rng.seed = key_seed
		key_slot = -1
	var next := key_rng.randi_range(0,KEY_SPOTS.size()-1 if key_slot<0 else KEY_SPOTS.size()-2)
	if key_slot>=0 and next>=key_slot: next+=1
	key_slot = next
	key_object.position = KEY_SPOTS[key_slot]
	key_object.visible = true

func start_game() -> void:
	if OS.has_feature("web") and not director.connected:
		director.connect_requested = true
		menu_title.text = "Beyne bağlanılıyor… Hazır olunca Başlat'a bas."
		return
	if playing and not completed:
		resume_game()
		return
	has_key = false
	door_open = false
	completed = false
	playing = true
	elapsed = 0
	events.clear()
	frame_times.clear()
	brain_view_frame_times.clear()
	place_key()
	door.position.x = 0
	player.position = Vector3(2,0.05,3.3)
	player.rotation = Vector3(0,0.15,0)
	player.camera.rotation = Vector3.ZERO
	player.torch.visible = true
	player.reset_motion()
	player.active = true
	fly.reset_body()
	fly.active = true
	director.mode = MODES[mode_choice.selected] if research_modes else "learn"
	director.interval = decision_interval
	director.seed_value = int(seed_box.value)
	sound_rng.seed = director.seed_value
	last_sound = -1
	director.start_session()
	menu.visible = false
	hud.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func pause_game() -> void:
	player.active = false
	player.reset_motion()
	fly.active = false
	director.pause_session()
	clear_effects()
	menu.visible = true
	menu_title.text = "DURAKLATILDI · Odada zaman bekler."
	start_button.text = "DEVAM ET"
	mode_choice.disabled = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	start_button.grab_focus()

func resume_game() -> void:
	if OS.has_feature("web") and not director.connected:
		director.connect_requested = true
		menu_title.text = "Beyne yeniden bağlanılıyor…"
		return
	player.active = true
	fly.active = true
	director.resume_session()
	menu.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle_brain_details() -> void:
	if brain_view.expanded:
		close_brain_details(brain_was_running)
	elif playing and not completed:
		brain_was_running=player.active
		brain_was_visible=brain_view.visible
		if player.active: pause_game()
		menu.visible=false
		brain_view.visible=true
		brain_view.set_expanded(true)

func close_brain_details(resume_play := false) -> void:
	brain_view.set_expanded(false)
	brain_view.visible=brain_was_visible
	if resume_play: resume_game()
	else:
		menu.visible=true
		start_button.grab_focus()

func clear_effects() -> void:
	dark_until = 0
	silhouette_until = 0
	silhouette.visible = false
	footsteps.stop()
	for light in room_lights: light.light_energy = light.get_meta("base_energy")

func quit_game(exit_code := 0) -> void:
	player.active = false
	fly.active = false
	director.finish_session("quit")
	ambience.stop()
	footsteps.stop()
	ambience.stream = null
	footsteps.stream = null
	var deadline := Time.get_ticks_msec()+1500
	while director.ending and director.connected and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.assign('/')")
	else: get_tree().quit(exit_code)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				if brain_view.expanded: close_brain_details()
				elif playing and not completed:
					if menu.visible: resume_game()
					else: pause_game()
			KEY_TAB:
				debug_panel.visible = not debug_panel.visible
			KEY_B:
				if brain_view.expanded: close_brain_details()
				else: brain_view.visible = not brain_view.visible
			KEY_V:
				toggle_brain_details()
			KEY_E:
				if player.active: interact()
			KEY_1, KEY_2, KEY_3:
				if player.active: director.rate_event(event.physical_keycode-KEY_1)

func can_interact(target: Vector3) -> bool:
	var ray: Vector3 = target-player.camera.global_position
	if ray.length() >= 2.5 or ray.normalized().dot(-player.camera.global_basis.z) <= 0.65: return false
	var query := PhysicsRayQueryParameters3D.create(player.camera.global_position,target,1)
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func interact() -> void:
	if not has_key and can_interact(key_object.global_position):
		has_key = true
		key_object.visible = false
	elif can_interact(Vector3(0,1.35,-14.68)) and has_key:
		door_open = true
		door.position.x = 3.2

func event_allowed(action_name: String) -> bool:
	if action_name not in ACTION_NAMES: return false
	if action_name == "wait": return true
	if intensity <= 0 or not player.active: return false
	while not events.is_empty() and events[0].time <= elapsed-60:
		events.pop_front()
	if events.size() >= 5: return false
	if not events.is_empty() and elapsed-float(events[-1].time) < 8: return false
	for e in events:
		if e.action == action_name and elapsed-float(e.time) < 16: return false
	return true

func apply_action(action_name: String, id: int) -> void:
	var accepted := event_allowed(action_name)
	if accepted and action_name != "wait":
		events.append({"action":action_name,"time":elapsed})
		match action_name:
			"lights":
				dark_until = elapsed + 2.2 * intensity + 0.5
			"steps":
				last_sound = sound_rng.randi_range(0,3) if last_sound < 0 else (last_sound+sound_rng.randi_range(1,3)) % 4
				footsteps.stream = scare_streams[last_sound]
				footsteps.position = player.position + player.global_basis.z * 2.3 + player.global_basis.x * sound_rng.randf_range(-0.7,0.7)
				footsteps.position.y = player.position.y + (0.15 if last_sound == 0 else 1.4)
				footsteps.pitch_scale = sound_rng.randf_range(0.97,1.03)
				footsteps.volume_db = -6 + linear_to_db(maxf(intensity,0.01))
				footsteps.play()
			"silhouette":
				var viewport_size := get_viewport().get_visible_rect().size
				var target: Vector3 = player.camera.project_position(Vector2(viewport_size.x*0.88,viewport_size.y*0.53),3.0)
				var query := PhysicsRayQueryParameters3D.create(player.camera.global_position,target)
				query.exclude = [player.get_rid()]
				var hit := get_world_3d().direct_space_state.intersect_ray(query)
				if not hit.is_empty(): target = hit.position + hit.normal * 0.35
				target.y = player.position.y
				silhouette.position = target
				silhouette.scale = Vector3.ONE * (0.65 + 0.35 * intensity)
				silhouette.visible = true
				silhouette_until = elapsed + 0.7 + intensity
	director.send({"type":"applied", "id":id, "accepted":accepted, "telemetry":player.telemetry(),
		"sound_variant":SCARE_SOUNDS[last_sound] if accepted and action_name == "steps" else null})
	if not accepted:
		director.action = "wait"
		director.reason = "Yerel olay bütçesi / yoğunluk sınırı"

func finish_game() -> void:
	completed = true
	player.active = false
	fly.active = false
	director.finish_session("won")
	clear_effects()
	menu.visible = true
	menu_title.text = "ÇIKIŞ AÇILDI · Odadan çıktın.  %d sn" % int(elapsed)
	start_button.text = "YENİ TUR"
	mode_choice.disabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	start_button.grab_focus()

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	if OS.has_feature("web") and player.active and not director.connected:
		pause_game()
		menu_title.text = "Bağlantı kesildi. Beyin hazır olunca devam edebilirsin."
	var tick := Time.get_ticks_usec()
	if player.active and elapsed > 2 and last_frame_usec > 0 and (smoke or benchmark):
		frame_times.append((tick-last_frame_usec)/1000.0)
	if brain_view.expanded and last_frame_usec>0 and benchmark:
		brain_view_frame_times.append((tick-last_frame_usec)/1000.0)
	last_frame_usec = tick
	if player.active:
		elapsed += delta
		director.latest_telemetry = player.telemetry()
		director.latest_telemetry["vision"] = fly.sight
		director.latest_telemetry["fly"] = {"position":[fly.position.x,fly.position.y,fly.position.z],"sees_player":fly.visible_player}
		for light in room_lights:
			var base: float = light.get_meta("base_energy")
			var target := base * (1.0-intensity) * 0.12 if elapsed < dark_until else base
			light.light_energy = move_toward(light.light_energy,target,delta*3)
		if elapsed >= silhouette_until: silhouette.visible = false
		if has_key and door_open and absf(player.position.x)<1.3 and player.position.z < -15.2 and player.position.z > -16: finish_game()
	ui_clock+=delta
	if ui_clock<0.1: return
	ui_clock=0
	objective.text = "03 / ÇIKIŞA İLERLE" if door_open else ("02 / KORİDORDAKİ ÇIKIŞI AÇ" if has_key else "01 / ODALARDAKİ ANAHTARI BUL")
	prompt.text = ""
	if not has_key and can_interact(key_object.global_position): prompt.text = "[ E ]   ANAHTARI AL"
	elif can_interact(Vector3(0,1.35,-14.68)):
		prompt.text = "[ E ]   ÇIKIŞI AÇ" if has_key else "KİLİTLİ · Odalarda anahtarı ara"
	var scope := "TAM GRAF" if not director.info.get("subnetwork",false) else "KÜÇÜLTÜLMÜŞ ALT AĞ"
	var data_ready: bool = not director.info.is_empty()
	badge.text = "%s  /  %s  /  %s" % [MODE_NAMES[mode_choice.selected],scope if data_ready else "VERİ BAĞLI DEĞİL","BAĞLI" if director.connected else "GÜVENLİ BEKLEME"]
	notice.text = "MaleCNS v1.0  ·  %s  ·  %s nöron  ·  %s" % [scope,str(director.info.get("neurons","—")),director.reason]
	if not settings_notice.is_empty(): notice.text = settings_notice
	feedback_text.text = ""
	if player.active and director.feedback_id >= 0 and director.now() < director.feedback_until:
		feedback_text.text = director.feedback_status if not director.feedback_status.is_empty() else "%s · İstersen değerlendir:  1 Etkilemedi   2 Gerildim   3 Korktum" % ACTION_NAMES.get(director.feedback_action,"")
	if memory_text.is_visible_in_tree():
		var saved: Dictionary = director.memory
		memory_text.text = ("ORTAK ÖĞRENME / TÜM OYUNCULAR\n\n%d oyun bölümü · %d öğrenme örneği\n" if OS.has_feature("web") else "KALICI ÖĞRENME / BU MAC\n\n%d kayıtlı tur · %d kişisel öğrenme örneği\n") % [int(saved.get("rounds",0)),int(saved.get("updates",0))]
		var feedback_counts: Dictionary = saved.get("feedback_counts",{})
		memory_text.text += "%d doğrudan değerlendirme · %d hareket tepkisi\n%d yapay eğitim olayıyla başlangıç\n\n" % [int(feedback_counts.get("rating",0)),int(feedback_counts.get("motion",0)),int(saved.get("prior_events",0))]
		if not OS.has_feature("web"): memory_text.text += "SON TURLAR\n"
		for item in saved.get("recent",[]).slice(-3):
			var mean_score: float = float(item.get("reward_sum",0))/maxi(1,int(item.get("rewards",0)))
			memory_text.text += "%s · %d sn · %d olay · tepki %.2f\n" % [{"won":"Çıkış","quit":"Çıkıldı","connection_lost":"Kesinti","restarted":"Yeniden"}.get(item.get("outcome",""),"Tur"),int(item.get("seconds",0)),int(item.get("events",0)),mean_score]
		if saved.get("recent",[]).is_empty() and not OS.has_feature("web"): memory_text.text += "Henüz tamamlanmış tur yok.\n"
		var reaction_means: Array = saved.get("mean_reaction",[0,0,0])
		var reaction_counts: Array = saved.get("counts",[0,0,0])
		memory_text.text += "\nGözlenen tepki / örnek sayısı\nIşık %.2f / %d · Ses %.2f / %d · Siluet %.2f / %d" % [reaction_means[0],int(reaction_counts[0]),reaction_means[1],int(reaction_counts[1]),reaction_means[2],int(reaction_counts[2])]
	if not debug_panel.is_visible_in_tree(): return
	var output: Array = director.neural.get("output",[0,0,0,0])
	debug_text.text = "ÖLÇÜMLER / TAB\n%s · biyolojik doğrulama yok\n\nEtkinlik: boyutsuz sayısal model\nL1 %.4f   L2 %.4f\nL3 %.4f   Mi1 %.4f\nEtkin nöron: %s  |  Ort. |a|: %.4f\n\nEylem: %s\n%s: %.3f / 1\nOlay: %d / 5 (60 sn)  ·  Kalıcı bellek: %d\nFPS: %d  |  Beyin: %.1f ms\nİstek/yanıt: %.1f ms\nBeyin RSS: %.1f MiB  |  Oyun heap: %.1f MiB\n%s" % [scope,output[0],output[1],output[2],output[3],str(director.neural.get("active_neurons","—")),director.neural.get("mean_abs",0),ACTION_NAMES.get(director.action,"Bekle"),"Oyuncu değerlendirmesi" if director.reward_source == "rating" else "Hareket tepkisi",director.reward,events.size(),director.updates,Engine.get_frames_per_second(),director.neural.get("latency_ms",0),director.rtt_ms,director.neural.get("rss_mb",0),OS.get_static_memory_usage()/1048576.0,director.reason]
	if director.neural.is_empty():
		debug_text.text = "ÖLÇÜMLER / TAB\nHenüz sinir etkinliği ölçülmedi.\nFPS: %d\n%s\n\nTepki puanı, korkunun kesin ölçüsü değildir." % [Engine.get_frames_per_second(),director.reason]
	elif OS.has_feature("web"):
		debug_text.text = debug_text.text.replace("Oyun heap: 0.0 MiB", "Web: ölçülmüyor")
	debug_text.text += "\nSinek görüşü: " + ("OYUNCUYU GÖRÜYOR" if fly.visible_player else "ARAMA / GÖRÜŞ KAPALI")

func check(condition: bool, description: String) -> bool:
	if not condition:
		push_error("SMOKE FAILED: " + description)
		write_report(false,description)
		quit_game(1)
		return false
	smoke_checks.append(description)
	print("CHECK: " + description)
	return true

func walk_to(target: Vector3) -> bool:
	player.auto_walk = true
	player.auto_target = target
	var start := Time.get_ticks_msec()
	while Vector2(player.position.x-target.x,player.position.z-target.z).length() > 0.22:
		await get_tree().physics_frame
		if completed and target.z < -15.2:
			player.auto_walk = false
			return true
		if Time.get_ticks_msec()-start > 15000: return false
	player.auto_walk = false
	return true

func aim_at(target: Vector3) -> void:
	player.camera.look_at(target)
	await get_tree().physics_frame

func automated_run() -> void:
	var start := Time.get_ticks_msec()
	while director.info.is_empty() and Time.get_ticks_msec()-start < 15000:
		await get_tree().process_frame
	if not check(not director.info.is_empty(),"Godot received real connectome manifest"): return
	start_game()
	debug_panel.visible = true
	await get_tree().create_timer(1).timeout
	var fly_start := fly.position
	await get_tree().create_timer(4).timeout
	if not check(brain_view.points.size()==4096 and director.neural.get("view_activity",[]).size()==4096,"Live panel receives 4096 measured biological neuron samples"): return
	if not check(fly.position.distance_to(fly_start)>0.05,"Physical fly moves with fresh measured neural output"): return
	toggle_brain_details()
	if not check(brain_view.expanded and not player.active and not director.running,"Detailed brain inspection pauses gameplay and decisions"): return
	var original_points: PackedVector2Array=brain_view.points.duplicate()
	brain_view.yaw+=0.65
	brain_view.project_points()
	brain_view.select_peak()
	if not check(brain_view.points!=original_points and brain_view.selected>=0,"Real soma cloud rotates and a measured neuron can be selected"): return
	if benchmark: await get_tree().create_timer(2).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(evidence_dir+"/brain-detail-1080p.png")
		brain_view.color_choice.select(1)
		brain_view.redraw_network()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(evidence_dir+"/brain-groups-1080p.png")
	brain_view.color_choice.select(0)
	brain_view.reset_view()
	toggle_brain_details()
	if not check(not brain_view.expanded and player.active and director.running,"Closing brain inspection restores previous gameplay state"): return
	if DisplayServer.get_name() != "headless":
		await aim_at(fly.position)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(evidence_dir+"/fly-1080p.png")
		player.camera.rotation=Vector3.ZERO
	fly.position=Vector3(0,1.6,0)
	fly.gaze=(player.position+Vector3.UP*1.25-fly.position).normalized()
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not check(fly.visible_player,"Fly sees unobstructed player inside visual field"): return
	fly.position=Vector3(8,1.6,0)
	fly.gaze=(player.position+Vector3.UP*1.25-fly.position).normalized()
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not check(not fly.visible_player and fly.sight.is_empty(),"Wall blocks fly vision and player telemetry to brain"): return
	fly.active=false
	fly.position=Vector3(0,1.6,0)
	var fly_hit = fly.move_and_collide(Vector3(10,0,0))
	if not check(fly_hit!=null and fly.position.x<5.9,"Physical fly collides with room wall"): return
	fly.reset_body()
	fly.active=true
	for key_code in [KEY_W, KEY_A, KEY_S, KEY_D]:
		var before := player.position
		var key_event := InputEventKey.new()
		key_event.physical_keycode = key_code
		key_event.keycode = key_code
		key_event.pressed = true
		Input.parse_input_event(key_event)
		# Count physics frames: synchronous screenshot readback can consume a wall-clock timer.
		for _frame in 12: await get_tree().physics_frame
		key_event = InputEventKey.new()
		key_event.physical_keycode = key_code
		key_event.keycode = key_code
		key_event.pressed = false
		Input.parse_input_event(key_event)
		if not check(player.position.distance_to(before) > 0.25,"Physical keyboard movement: " + OS.get_keycode_string(key_code)): return
	# Wall test uses the actual CharacterBody collision path.
	player.auto_walk = true
	player.auto_target = Vector3(9,0,3.3)
	await get_tree().create_timer(2).timeout
	player.auto_walk = false
	if not check(player.position.x < 5.7,"Room wall prevents walking through collision"): return
	if not check(await walk_to(Vector3(0,0,0)),"Walk to room center"): return
	if key_slot==1:
		if not check(await walk_to(Vector3(-2.8,0,-0.2)),"Search observation-room table"): return
		await aim_at(key_object.global_position)
		interact()
		if not check(await walk_to(Vector3(0,0,0)),"Return from observation table"): return
	if not check(await walk_to(Vector3(0,0,-12.7)),"Navigate corridor with collisions"): return
	await aim_at(Vector3(0,1.35,-14.68))
	if not has_key:
		interact()
		if not check(not door_open,"Exit stays locked without key"): return
	if not check(await walk_to(Vector3(0,0,-9)),"Return to side-room junction"): return
	if not check(await walk_to(Vector3(6,0,-9)),"Enter machine room through side doorway"): return
	if key_slot==2:
		if not check(await walk_to(Vector3(7,0,-9.7)),"Search machine-room cabinet"): return
		await aim_at(key_object.global_position)
		interact()
		if not check(await walk_to(Vector3(6,0,-9)),"Return from machine cabinet"): return
	if DisplayServer.get_name() != "headless":
		await aim_at(Vector3(9,1.4,-11.5))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(evidence_dir+"/machine-room-1080p.png")
	if not check(await walk_to(Vector3(6,0,-18.5)),"Walk from machine room into rear service corridor"): return
	if not check(await walk_to(Vector3(0,0,-18.5)),"Reach rear passage behind sealed exit"): return
	if DisplayServer.get_name() != "headless":
		await aim_at(Vector3(-6,1.5,-18.5))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(evidence_dir+"/service-corridor-1080p.png")
	if not check(await walk_to(Vector3(-6,0,-18.5)),"Cross rear corridor with collisions"): return
	if not check(await walk_to(Vector3(-6,0,-12)),"Enter archive through rear doorway"): return
	if not check(await walk_to(Vector3(-5.5,0,-7.9)),"Navigate archive aisle around furniture"): return
	if not check(await walk_to(Vector3(-7.4,0,-7.9)) and player.is_on_floor(),"Reach archive key table on continuous floor"): return
	if key_slot==0:
		await aim_at(key_object.global_position)
		interact()
	if not check(has_key and not key_object.visible,"E interaction collects key"): return
	# Exercise every original effect through the production dispatch and local gate.
	for effect in ["lights","steps","silhouette"]:
		events.clear()
		apply_action(effect,-1)
		if not check(events.size()==1,"Effect dispatch: "+effect): return
		if effect == "steps":
			if not check((footsteps.position-player.position).dot(player.global_basis.z)>0,"Footstep source is behind player"): return
		if effect == "silhouette":
			if not check(silhouette.visible,"Silhouette is visible"): return
		await get_tree().create_timer(0.35).timeout
	clear_effects()
	events.clear()
	apply_action("lights",-1)
	apply_action("steps",-1)
	if not check(events.size()==1,"Local cooldown rejects event spam"): return
	pause_game()
	if not check(not player.active and not director.running and not silhouette.visible,"ESC pause cancels effects and decisions"): return
	var paused_fly := fly.position
	await get_tree().create_timer(0.2).timeout
	if not check(fly.position==paused_fly,"Pause freezes physical fly"): return
	resume_game()
	# Socket loss must keep physics running and clear stale actions.
	director.socket.close()
	start = Time.get_ticks_msec()
	while director.connected and Time.get_ticks_msec()-start<4000: await get_tree().process_frame
	if not check(not director.connected and director.action=="wait" and player.active,"WebSocket disconnect safely waits; game remains active"): return
	await get_tree().create_timer(4).timeout
	if not check(director.connected,"Automatic localhost reconnect"): return
	var same_round: String = director.round_id
	pause_game()
	director.socket.close()
	await get_tree().create_timer(4).timeout
	if not check(director.connected and director.session_ready and not director.running and not fly.active and director.round_id==same_round,"Reconnect during pause preserves round and stays paused"): return
	resume_game()
	if benchmark:
		await get_tree().create_timer(25).timeout
	await aim_at(Vector3(-7.5,1.4,-11.8))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(evidence_dir+"/game-1080p.png")
	if not check(await walk_to(Vector3(-3.3,0,-7.9)),"Leave archive key table"): return
	if not check(await walk_to(Vector3(-3.3,0,-9)),"Reach archive side doorway"): return
	if not check(await walk_to(Vector3(0,0,-9)),"Return from archive to exit corridor"): return
	if not check(await walk_to(Vector3(0,0,-12.7)),"Reach exit with key"): return
	await aim_at(Vector3(0,1.35,-14.68))
	interact()
	if not check(door_open,"E interaction opens exit with key"): return
	if not check(await walk_to(Vector3(0,0,-15.6)),"Walk through open exit"): return
	await get_tree().process_frame
	if not check(completed,"Playable route reaches victory"): return
	start=Time.get_ticks_msec()
	while director.ending and Time.get_ticks_msec()-start<2000: await get_tree().process_frame
	if not check(not director.ending and not director.memory.get("recent",[]).is_empty(),"Victory persists round history and acknowledges save"): return
	if not check(not director.neural.is_empty(),"Input to actual neural output to game decision"): return
	write_report(true,"")
	await quit_game()

func write_report(passed: bool, failure: String) -> void:
	var sorted := frame_times.duplicate()
	sorted.sort()
	var sum := 0.0
	for v in sorted: sum+=v
	var result := {"passed":passed,"failure":failure,"checks":smoke_checks,"renderer":RenderingServer.get_video_adapter_name(),"display":DisplayServer.get_name(),"viewport":str(get_viewport().get_visible_rect().size),"frames":sorted.size(),"elapsed_seconds":elapsed,"mean_fps":1000.0/(sum/maxi(1,sorted.size())),"godot_version":Engine.get_version_info(),"last_neural":director.neural,"mode":director.mode,"headless":DisplayServer.get_name()=="headless"}
	result["key_slot"] = key_slot
	if not sorted.is_empty():
		result["frame_ms_p50"] = sorted[int(sorted.size()*0.5)]
		result["frame_ms_p95"] = sorted[int(sorted.size()*0.95)]
		result["frame_ms_p99"] = sorted[int(sorted.size()*0.99)]
	if not brain_view_frame_times.is_empty():
		var total := 0.0
		for ms in brain_view_frame_times: total+=ms
		result["brain_view_mean_fps"]=1000.0/(total/brain_view_frame_times.size())
		result["brain_view_frames"]=brain_view_frame_times.size()
	var file := FileAccess.open(evidence_dir+("/game-benchmark.json" if benchmark else "/game-smoke.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	if benchmark:
		var mode_file := FileAccess.open(evidence_dir+"/game-%s-benchmark.json" % director.mode,FileAccess.WRITE)
		mode_file.store_string(JSON.stringify(result,"  "))
