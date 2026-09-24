extends Control

var game: Node
var move_finger := -1
var look_finger := -1
var origin := Vector2.ZERO
var stick := Vector2.ZERO
var buttons: Array[TouchScreenButton] = []
var ratings: Array[TouchScreenButton] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_button("PAUSE",game.pause_game,Vector2(88,48))
	add_button("TORCH",func(): game.player.torch.visible = not game.player.torch.visible,Vector2(88,48))
	add_button("BRAIN",game.toggle_brain_details,Vector2(68,48))
	for rating in 3:
		ratings.append(add_button(["No effect","Tense","Scared"][rating],func(): game.director.rate_event(rating),Vector2(92,48)))
	game.player.motion_reset.connect(reset)
	visibility_changed.connect(reset)
	resized.connect(layout)
	layout()
	visible = false

func add_button(text: String, callback: Callable, dimensions: Vector2) -> TouchScreenButton:
	var b := TouchScreenButton.new()
	var shape := RectangleShape2D.new()
	shape.size = dimensions
	b.shape = shape
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03,0.09,0.10,0.88)
	style.border_color = Color(0.38,0.63,0.56,0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	b.draw.connect(func(): b.draw_style_box(style,Rect2(-dimensions/2,dimensions)))
	b.pressed.connect(func():
		if game.player.active: callback.call()
	)
	var label := Label.new()
	label.text = text
	label.position = -dimensions/2
	label.size = dimensions
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",14)
	label.add_theme_color_override("font_color",Color(0.90,0.94,0.87))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(label)
	add_child(b)
	buttons.append(b)
	return b

func layout() -> void:
	if buttons.is_empty(): return
	buttons[0].position = Vector2(size.x-60,38)
	buttons[1].position = Vector2(size.x-64,size.y-48)
	buttons[2].position = Vector2(size.x-60,94)
	for i in ratings.size(): ratings[i].position = Vector2(size.x/2+(i-1)*100,164)
	reset()

func reset() -> void:
	move_finger = -1
	look_finger = -1
	stick = Vector2.ZERO
	origin = Vector2(90,size.y-110)
	game.player.touch_axis = Vector2.ZERO
	queue_redraw()

func _process(_delta: float) -> void:
	visible = game.player.active
	var can_rate: bool = game.director.feedback_id>=0 and game.director.now()<game.director.feedback_until and game.director.feedback_status.is_empty()
	for b in ratings: b.visible = can_rate

func _input(event: InputEvent) -> void:
	if not game.player.active or not is_visible_in_tree(): return
	if event is InputEventScreenTouch:
		if event.canceled:
			game.pause_game()
			return
		if not event.pressed:
			if event.index == move_finger:
				move_finger = -1
				stick = Vector2.ZERO
				game.player.touch_axis = Vector2.ZERO
			if event.index == look_finger: look_finger = -1
		elif event.position.y>100:
			for b in buttons:
				if b.visible and Rect2(b.position-b.shape.size/2,b.shape.size).has_point(event.position): return
			if event.position.x<size.x/2 and move_finger<0:
				move_finger = event.index
				origin = event.position
			elif event.position.x>=size.x/2 and look_finger<0:
				look_finger = event.index
		queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == move_finger:
			stick = (event.position-origin).limit_length(50)
			game.player.touch_axis = stick/50 if stick.length()>8 else Vector2.ZERO
			queue_redraw()
		elif event.index == look_finger:
			# The mobile viewport uses CSS pixels, so this drag stays independent of pixel density.
			game.player.look(event.relative*3)

func _draw() -> void:
	draw_circle(origin,58,Color(0.02,0.08,0.09,0.64))
	draw_arc(origin,58,0,TAU,48,Color(0.39,0.66,0.58,0.7),1.5,true)
	draw_circle(origin+stick,23,Color(0.42,0.72,0.61,0.55))
	draw_string(ThemeDB.fallback_font,Vector2(36,size.y-29),"MOVE",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(0.7,0.82,0.76))
	draw_string(ThemeDB.fallback_font,Vector2(size.x-124,size.y-150),"DRAG · LOOK",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(0.7,0.82,0.76))
