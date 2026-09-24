extends Control

# Presentation only. Uses accepted fired/round signals, never changes combat state.
var game: Node
var shot: AudioStreamPlayer
var hit: AudioStreamPlayer
var result: AudioStreamPlayer
var hit_left := 0.0
const HIT_TIME := 0.14
const WON = preload("res://audio/won.wav")
const LOST = preload("res://audio/lost.wav")

func audio(stream: AudioStream, gain: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream=stream
	player.volume_db=gain
	player.bus="Master"
	add_child(player)
	return player

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	shot=audio(preload("res://audio/shot.wav"),-2)
	hit=audio(preload("res://audio/hit.wav"),-5)
	result=audio(WON,-3)
	game.player.fired.connect(on_shot)

func on_shot(hit_target: bool) -> void:
	# A lethal hit already emitted end_round. Do not paint a hitmarker over its menu.
	if not game.player.active: return
	shot.play()
	if hit_target:
		hit.play()
		hit_left=HIT_TIME
		queue_redraw()

func reset_feedback() -> void:
	hit_left=0
	for player in [shot,hit,result]:
		if is_instance_valid(player): player.stop()
	queue_redraw()

func finish(outcome: String) -> void:
	reset_feedback()
	result.stream=WON if outcome=="won" else LOST
	result.play()

func _process(delta: float) -> void:
	if hit_left>0:
		hit_left=maxf(0,hit_left-delta) if game.player.active else 0.0
		queue_redraw()

func _draw() -> void:
	if hit_left<=0 or not game.player.active: return
	var center := size/2
	var color := Color(0.4,1.0,0.9,hit_left/HIT_TIME)
	for x in [-1,1]:
		for y in [-1,1]:
			var direction := Vector2(x,y)
			draw_line(center+direction*8,center+direction*14,color,2,true)

func _exit_tree() -> void:
	for player in [shot,hit,result]:
		if is_instance_valid(player):
			player.stop()
			player.stream=null
