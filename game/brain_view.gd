extends Control

const CLASSES := ["ol_intrinsic", "cb_intrinsic", "visual_projection", "ol_sensory"]
const CLASS_NAMES := ["Optic lobe intrinsic", "Central brain intrinsic", "Visual projection", "Visual sensory"]
const CLASS_COLORS := [Color(0.32,0.78,0.98), Color(0.8,0.57,0.98), Color(0.98,0.73,0.35), Color(0.42,0.96,0.61)]
const GREEN := Color(0.3,0.91,0.72)
const AMBER := Color(1,0.58,0.31)
const MUTED := Color(0.53,0.68,0.66)
const OUTPUT_NAMES := ["L1", "L2", "L3", "Mi1"]

signal close_requested
var director: Node
var expanded := false
var mobile := false
var last_stamp := -1.0
var last_round := ""
var snapshot := {}
var measured_action := "wait"
var history: Array[Dictionary] = []
var points := PackedVector2Array()
var xyz := PackedVector3Array()
var edges: Array = []
var ids: Array = []
var metadata := {}
var view_error := ""
var selected := -1
var yaw := 0.18
var pitch := -0.12
var zoom := 1.0
var redraw_clock := 0.0
var dragging := false
var drag_position := Vector2.ZERO
var moved := 0.0
var toolbar: Container
var group_choice: OptionButton
var color_choice: OptionButton
var dots := MultiMesh.new()
var network := Control.new()
var was_fresh := false

func _ready() -> void:
	clip_contents = true
	network.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(network)
	network.draw.connect(draw_network)
	# One native instanced mesh keeps 4,096 soma markers out of the individual draw-call path.
	var vertices := PackedVector3Array()
	for i in 12:
		vertices.append_array([Vector3.ZERO,Vector3(cos(i*TAU/12),sin(i*TAU/12),0),Vector3(cos((i+1)*TAU/12),sin((i+1)*TAU/12),0)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	dots.transform_format=MultiMesh.TRANSFORM_2D
	dots.use_colors=true
	dots.mesh=mesh
	toolbar = HFlowContainer.new() if mobile else HBoxContainer.new()
	toolbar.position = Vector2(22,53)
	toolbar.add_theme_constant_override("separation",14)
	add_child(toolbar)
	group_choice = OptionButton.new()
	group_choice.add_item("All cell groups")
	for title in CLASS_NAMES: group_choice.add_item(title)
	group_choice.item_selected.connect(func(_i): selected=-1; redraw_network())
	toolbar.add_child(group_choice)
	color_choice = OptionButton.new()
	color_choice.add_item("Color: measured activity")
	color_choice.add_item("Color: cell group")
	color_choice.item_selected.connect(func(_i): redraw_network())
	toolbar.add_child(color_choice)
	for item in [["Most active" if mobile else "Most active neuron",select_peak],["Reset" if mobile else "Reset view",reset_view],["Back" if mobile else "Back [V]",func(): close_requested.emit()]]:
		var button := Button.new()
		button.text = item[0]
		button.pressed.connect(item[1])
		toolbar.add_child(button)
	for child in toolbar.get_children():
		child.custom_minimum_size.y=44 if mobile else 36
		child.add_theme_font_size_override("font_size",14 if mobile else 17)
	if mobile:
		for direction in [-1,1]:
			var zoom_button := Button.new()
			zoom_button.text = "−" if direction<0 else "+"
			zoom_button.custom_minimum_size = Vector2(44,44)
			zoom_button.pressed.connect(func(): zoom=clampf(zoom*pow(1.2,direction),0.55,2.5); project_points(); redraw_network())
			toolbar.add_child(zoom_button)
		toolbar.resized.connect(layout)
		toolbar.minimum_size_changed.connect(layout)
	get_viewport().size_changed.connect(layout)
	set_expanded(false)

func redraw_network() -> void:
	network.queue_redraw()
	queue_redraw()

func set_expanded(value: bool) -> void:
	expanded=value
	mouse_filter=Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
	focus_mode=Control.FOCUS_ALL if value else Control.FOCUS_NONE
	z_index=20 if value else 0
	toolbar.visible=value
	dragging=false
	layout()
	if value: grab_focus()

func layout() -> void:
	var screen := get_viewport_rect().size
	size=screen-Vector2(140,140) if expanded else Vector2(520,430)
	position=Vector2(70,70) if expanded else screen-Vector2(550,500)
	if mobile:
		size=screen-Vector2(24,24)
		position=Vector2(12,12)
		toolbar.position=Vector2(12,40)
		toolbar.size=Vector2(size.x-24,toolbar.get_minimum_size().y)
	dots.custom_aabb=AABB(Vector3.ZERO,Vector3(size.x,size.y,1))
	project_points()
	redraw_network()

func graph_rect() -> Rect2:
	if mobile:
		var top := toolbar.position.y+toolbar.size.y+8
		return Rect2(12,top,size.x-24,maxf(40,size.y-top-110))
	return Rect2(24,106,size.x-460,size.y-302) if expanded else Rect2(18,65,size.x-36,185)

func reset_view() -> void:
	yaw=0.18; pitch=-0.12; zoom=1.0
	project_points(); redraw_network()

func load_view(view: Dictionary) -> bool:
	# Local authenticated data still needs bounds before it becomes array indices and draw commands.
	var incoming: Variant=view.get("ids")
	var links: Variant=view.get("edges")
	var valid: bool=incoming is Array and incoming.size()>0 and incoming.size()<=4096 and links is Array and links.size()<=6000
	if valid:
		for key in ["xyz","source_xyz","types","classes","sides","degree_in","degree_out"]:
			var field: Variant=view.get(key)
			valid=valid and field is Array and field.size()==incoming.size()
	if valid:
		for i in incoming.size():
			valid=valid and incoming[i] is String and incoming[i].length()<=20 and incoming[i].is_valid_int() and int(incoming[i])>0
			for key in ["xyz","source_xyz"]:
				var p: Variant=view[key][i]
				if not (p is Array and p.size()==3): valid=false; break
				for n in p:
					if not ((n is float or n is int) and is_finite(float(n))): valid=false; break
					if key=="xyz" and absf(float(n))>1: valid=false; break
			for key in ["types","classes","sides"]: valid=valid and view[key][i] is String
			for key in ["degree_in","degree_out"]:
				var n: Variant=view[key][i]
				valid=valid and (n is float or n is int) and is_finite(float(n)) and float(n)>=0 and float(n)==floorf(float(n))
			if not valid: break
	if valid:
		for edge in links:
			if not (edge is Array and edge.size()==3): valid=false; break
			for n in edge:
				if not ((n is float or n is int) and is_finite(float(n))): valid=false; break
			if not valid: break
			valid=float(edge[0])==floorf(float(edge[0])) and float(edge[1])==floorf(float(edge[1])) and edge[0]>=0 and edge[1]>=0 and edge[0]<incoming.size() and edge[1]<incoming.size() and absf(float(edge[2]))<=1
			if not valid: break
	ids=[]; edges=[]; xyz.clear(); points.clear(); selected=-1
	if not valid:
		view_error="Invalid anatomy data; drawing stopped."
		redraw_network()
		return false
	view_error=""; ids=incoming; edges=links; metadata=view
	dots.instance_count=ids.size()
	for p in view.xyz: xyz.append(Vector3(float(p[0]),float(p[1]),float(p[2])))
	project_points()
	redraw_network()
	return true

func project_points() -> void:
	points.clear()
	if xyz.is_empty(): return
	var rotation := Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch)
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	for p in xyz:
		var q: Vector3=rotation*p
		var v := Vector2(q.x,-q.y)
		points.append(v); low=low.min(v); high=high.max(v)
	var rect := graph_rect()
	var span := high-low
	var scale_factor := minf(rect.size.x/maxf(span.x,0.01),rect.size.y/maxf(span.y,0.01))*0.9*(zoom if expanded else 1.0)
	for i in points.size(): points[i]=rect.get_center()+(points[i]-(low+high)/2)*scale_factor

func included(i: int) -> bool:
	return not expanded or group_choice.selected==0 or metadata.classes[i]==CLASSES[group_choice.selected-1]

func select_at(pos: Vector2) -> void:
	var distance := 11.0
	selected=-1
	for i in points.size():
		if included(i) and graph_rect().has_point(points[i]) and points[i].distance_to(pos)<distance:
			selected=i; distance=points[i].distance_to(pos)
	redraw_network()

func select_peak() -> void:
	var values: Array=snapshot.get("view_activity",[])
	var peak := -1.0
	for i in mini(values.size(),ids.size()):
		if included(i) and absf(float(values[i]))>peak: selected=i; peak=absf(float(values[i]))
	redraw_network()

func rotate_drag(pos: Vector2) -> void:
	var delta := pos-drag_position
	drag_position=pos; moved+=delta.length()
	yaw+=delta.x*0.008; pitch=clampf(pitch+delta.y*0.008,-1.4,1.4)
	project_points(); redraw_network()

func _gui_input(event: InputEvent) -> void:
	if not expanded: return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed and graph_rect().has_point(event.position):
				dragging=true; drag_position=event.position; moved=0; grab_focus()
			elif not event.pressed and dragging:
				rotate_drag(event.position)
				dragging=false
				if moved<5: select_at(event.position)
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and graph_rect().has_point(event.position):
			if event.button_index==MOUSE_BUTTON_WHEEL_UP: zoom=minf(2.5,zoom*1.12)
			if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: zoom=maxf(0.55,zoom/1.12)
			project_points(); redraw_network()
	elif event is InputEventMouseMotion and dragging:
		rotate_drag(event.position)
	elif event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_LEFT: yaw-=0.12
			KEY_RIGHT: yaw+=0.12
			KEY_UP: pitch=clampf(pitch-0.12,-1.4,1.4)
			KEY_DOWN: pitch=clampf(pitch+0.12,-1.4,1.4)
			KEY_HOME: reset_view()
			KEY_EQUAL, KEY_KP_ADD: zoom=minf(2.5,zoom*1.12)
			KEY_MINUS, KEY_KP_SUBTRACT: zoom=maxf(0.55,zoom/1.12)
			KEY_N: select_peak()
			_: return
		project_points(); redraw_network(); accept_event()

func _process(delta: float) -> void:
	if director==null: return
	if ids.is_empty() and view_error.is_empty() and director.info.has("view"): load_view(director.info.view)
	if director.round_id!=last_round:
		last_round=director.round_id; last_stamp=-1; snapshot={}; measured_action="wait"; history.clear()
		redraw_network()
	if director.last_neural_time>=0 and director.last_neural_time!=last_stamp:
		last_stamp=director.last_neural_time
		snapshot=director.neural
		measured_action=director.action
		history.append({"time":last_stamp,"sample":snapshot})
		if history.size()>32: history.pop_front()
		redraw_network()
	var fresh: bool=last_stamp>=0 and director.connected and director.running and director.now()-last_stamp<=director.interval+1.5
	if fresh!=was_fresh:
		was_fresh=fresh; redraw_network()
	redraw_clock+=delta
	if is_visible_in_tree() and redraw_clock>=0.1:
		redraw_clock=0; queue_redraw() # Text age changes; native network draw commands remain cached.

func status_text() -> String:
	if not view_error.is_empty(): return view_error
	if last_stamp<0: return "Waiting for measurement"
	var age: float=maxf(0,director.now()-last_stamp)
	var status := "LIVE"
	if not director.connected: status="NO CONNECTION / STALE"
	elif not director.running: status="PAUSED / LAST MEASUREMENT"
	elif age>director.interval+1.5: status="DELAYED MEASUREMENT"
	return "%s · %.1f sec ago" % [status,age]

func text_at(pos: Vector2, value: String, font_size := 16, color := Color(0.76,0.88,0.84), width := -1.0) -> void:
	draw_string(ThemeDB.fallback_font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,width,font_size,color)

func signed_bar(rect: Rect2, value: float, color: Color) -> void:
	draw_rect(rect,Color(0.09,0.17,0.19))
	draw_line(Vector2(rect.get_center().x,rect.position.y-2),Vector2(rect.get_center().x,rect.end.y+2),MUTED,1)
	var amount := clampf(value,-1,1)*rect.size.x*0.5
	draw_rect(Rect2(Vector2(rect.get_center().x+minf(0,amount),rect.position.y),Vector2(absf(amount),rect.size.y)),color)

func activity_chart(rect: Rect2) -> void:
	draw_rect(rect,Color(0.02,0.065,0.075))
	if history.is_empty(): return
	var peak := 0.001
	for item in history: peak=maxf(peak,float(item.sample.get("mean_abs",0)))
	var start: float=history[0].time
	var duration: float=maxf(1,last_stamp-start)
	var line := PackedVector2Array()
	for item in history:
		line.append(Vector2(rect.position.x+(item.time-start)/duration*rect.size.x,rect.end.y-float(item.sample.get("mean_abs",0))/peak*(rect.size.y-18)))
	if line.size()>1: draw_polyline(line,GREEN,1.7,true)
	text_at(rect.position+Vector2(6,14),"Full network avg |a| · peak %.4f · last %.0f sec" % [peak,last_stamp-start],12,MUTED)

func draw_network() -> void:
	if director==null or ids.is_empty(): return
	var values: Array=snapshot.get("view_activity",[])
	var valid := values.size()==ids.size() and last_stamp>=0
	var fresh: bool=valid and director.connected and director.running and director.now()-last_stamp<=director.interval+1.5
	var rect := graph_rect()
	network.draw_rect(rect,Color(0.015,0.052,0.064))
	var neighbors := {}
	var line_points := PackedVector2Array()
	var line_colors := PackedColorArray()
	var highlight_points := PackedVector2Array()
	var highlight_colors := PackedColorArray()
	for k in edges.size():
		var edge: Array=edges[k]
		var a := int(edge[0]); var b := int(edge[1])
		if not included(a) or not included(b) or not rect.has_point(points[a]) or not rect.has_point(points[b]): continue
		var connected := expanded and (a==selected or b==selected)
		if connected: neighbors[b if a==selected else a]=true
		if not expanded and k%6!=0: continue
		var color := AMBER if float(edge[2])<0 else GREEN
		color.a=0.045+(absf(float(values[a]))*0.24 if fresh else 0.0)
		if connected:
			color=AMBER if a==selected else Color(0.36,0.77,1)
			highlight_points.append_array([points[a],points[b]]); highlight_colors.append(color)
		else:
			line_points.append_array([points[a],points[b]]); line_colors.append(color)
		if connected and points[a].distance_to(points[b])>12:
			var direction := (points[b]-points[a]).normalized()
			var tip := points[b]-direction*4
			highlight_points.append_array([tip,tip-direction.rotated(0.5)*7,tip,tip-direction.rotated(-0.5)*7])
			highlight_colors.append_array([color,color])
	if not line_points.is_empty(): network.draw_multiline_colors(line_points,line_colors,0.7,false)
	if not highlight_points.is_empty(): network.draw_multiline_colors(highlight_points,highlight_colors,1.4,true)
	var instances := 0
	for i in points.size():
		if not included(i) or not rect.has_point(points[i]): continue
		var value: float=float(values[i]) if valid else 0.0
		var color := AMBER if value<0 else GREEN
		if expanded and color_choice.selected==1:
			var group: int=CLASSES.find(metadata.classes[i])
			color=CLASS_COLORS[group] if group>=0 else MUTED
		color.a=0.76 if expanded and color_choice.selected==1 else ((0.34+minf(absf(value)*2,0.66)) if valid else 0.28)
		if not fresh and (not expanded or color_choice.selected==0): color.a*=0.7
		var radius := (1.3 if expanded else 0.85)+minf(absf(value)*3,2)
		dots.set_instance_transform_2d(instances,Transform2D(Vector2(radius,0),Vector2(0,radius),points[i]))
		dots.set_instance_color(instances,color)
		instances+=1
	dots.visible_instance_count=instances
	if instances>0: network.draw_multimesh(dots,null)
	for i in points.size():
		if not included(i) or not rect.has_point(points[i]): continue
		if i==selected and expanded: network.draw_arc(points[i],7,0,TAU,24,Color.WHITE,2,true)
		elif neighbors.has(i): network.draw_arc(points[i],4,0,TAU,12,Color(0.65,0.88,0.91),1,true)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.012,0.032,0.041,1.0 if expanded else 0.95))
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.19,0.39,0.36),false,1)
	if mobile:
		text_at(Vector2(12,20),"FLY BRAIN · LAST MEASUREMENT",17)
		text_at(Vector2(12,36),status_text(),11,GREEN,size.x-24)
		var bottom := graph_rect().end.y+16
		text_at(Vector2(12,bottom),"%d somas · %d neurons" % [ids.size(),int(director.info.get("neurons",0))],12,MUTED,size.x-24)
		var output: Array = snapshot.get("output",[])
		for i in 4:
			text_at(Vector2(12+(i%2)*(size.x/2),bottom+20+(i/2)*20),OUTPUT_NAMES[i]+("  %+.5f" % float(output[i]) if output.size()==4 else "  —"),14)
		text_at(Vector2(12,bottom+66),"ID: "+str(ids[selected]) if selected>=0 else "Drag: rotate · Tap: select neuron",13,MUTED,size.x-24)
		text_at(Vector2(12,bottom+88),"Model activity; not a biological recording.",12,MUTED,size.x-24)
		return
	text_at(Vector2(20,28),"FLY BRAIN / " + ("DETAILED INSPECTION" if expanded else "MEASUREMENTS [B]"),21 if expanded else 17)
	if not expanded: text_at(Vector2(size.x-90,28),"V detail",15,GREEN)
	if director==null: return
	if ids.is_empty():
		text_at(Vector2(20,120),status_text(),16,AMBER)
		return
	if not expanded: text_at(Vector2(20,49),"%d somas · %d / %d sample connection lines" % [ids.size(),int(ceil(edges.size()/6.0)),edges.size()],13,MUTED)
	var values: Array=snapshot.get("view_activity",[])
	var valid := values.size()==ids.size() and last_stamp>=0
	var fresh: bool=valid and director.connected and director.running and director.now()-last_stamp<=director.interval+1.5
	var rect := graph_rect()
	var output: Array=snapshot.get("output",[0,0,0,0])
	if not expanded:
		text_at(Vector2(20,275),status_text(),14,GREEN if fresh else AMBER)
		for i in 4:
			var x := 20+i*125
			text_at(Vector2(x,299),"%s  %s" % [OUTPUT_NAMES[i],"%+.4f" % float(output[i]) if valid else "—"],13)
			signed_bar(Rect2(x,311,108,7),float(output[i])*5,GREEN if float(output[i])>=0 else AMBER)
		text_at(Vector2(20,336),"Bars: ±0.2 · numbers: raw group average",12,MUTED)
		activity_chart(Rect2(20,346,size.x-40,40))
		text_at(Vector2(20,410),"Soma sample; color is model activity, not a biological recording.",12,MUTED)
		return
	var right := size.x-410
	text_at(Vector2(right,124),status_text(),15,GREEN if fresh else AMBER,390)
	text_at(Vector2(right,155),"Showing %d / %d soma positions" % [ids.size(),int(metadata.get("candidate_count",0))],15)
	text_at(Vector2(right,181),"Full simulation: %d neurons" % int(director.info.get("neurons",0)),16)
	text_at(Vector2(right,205),"%d directed connections · %d sample connection lines" % [int(director.info.get("edges",0)),edges.size()],14,MUTED)
	text_at(Vector2(right,238),"Active: %d   Avg. |a| %.5f" % [int(snapshot.get("active_neurons",0)),float(snapshot.get("mean_abs",0))] if valid else "Active: —   Avg. |a| —",16)
	text_at(Vector2(right,260),"Active threshold |a| > 0.001 · dimensionless model",13,MUTED)
	draw_line(Vector2(right,278),Vector2(size.x-22,278),MUTED,1)
	text_at(Vector2(right,307),"SELECTED NEURON",18)
	if selected>=0:
		text_at(Vector2(right,336),"Biological ID: "+str(ids[selected]),16)
		text_at(Vector2(right,362),"Type: "+str(metadata.types[selected]),16,GREEN,380)
		var group: int=CLASSES.find(metadata.classes[selected])
		text_at(Vector2(right,386),CLASS_NAMES[group] if group>=0 else str(metadata.classes[selected]),15,MUTED,380)
		text_at(Vector2(right,411),"Soma side: "+str(metadata.sides[selected])+"  (source label)",14,MUTED)
		text_at(Vector2(right,440),"Last a: "+("%+.5f" % float(values[selected]) if valid else "—"),20,AMBER if valid and float(values[selected])<0 else GREEN)
		text_at(Vector2(right,468),"Full graph in-degree %d · out-degree %d" % [int(metadata.degree_in[selected]),int(metadata.degree_out[selected])],15)
		var source: Array=metadata.source_xyz[selected]
		text_at(Vector2(right,493),"Source xyz: %.0f / %.0f / %.0f" % [source[0],source[1],source[2]],13,MUTED)
		text_at(Vector2(right,518),"Blue arrow: in · orange arrow: out",13,MUTED)
	else:
		text_at(Vector2(right,342),"Click a neuron or press N to select the most active one.",15,MUTED,385)
	text_at(Vector2(right,553),"MEASURED OUTPUT GROUPS",17)
	for i in 4:
		text_at(Vector2(right,581+i*27),"%s  %s" % [OUTPUT_NAMES[i],"%+.5f" % float(output[i]) if valid else "—"],15)
		signed_bar(Rect2(right+163,570+i*27,198,8),float(output[i])*5,GREEN if float(output[i])>=0 else AMBER)
	text_at(Vector2(right,695),"±0.2 scale · event mapping is an engineering design",12,MUTED)
	text_at(Vector2(right,722),"Brain %.1f ms · RSS %.1f MiB" % [float(snapshot.get("latency_ms",0)),float(snapshot.get("rss_mb",0))] if valid else "Brain latency / RSS: —",15)
	var chart_y := size.y-172
	activity_chart(Rect2(24,chart_y,size.x-460,68))
	text_at(Vector2(24,size.y-83),"Drag / arrows: rotate   Wheel / +/-: zoom   Click: select   Home: reset   V: back   ESC: menu",15,MUTED)
	text_at(Vector2(24,size.y-54),"%d real somas and sample connections; neuron branches are not drawn. Full brain + VNC simulation is preserved." % ids.size(),14,MUTED)
	text_at(Vector2(24,size.y-29),"Colors show source cell groups; not a biological recording." if color_choice.selected==1 else "Green / orange: positive / negative model activity. Neural activity only changes with a new measurement.",14,MUTED)
	if color_choice.selected==1:
		for i in 4:
			text_at(Vector2(34+i*230,rect.end.y+24),CLASS_NAMES[i],14,CLASS_COLORS[i])
	else: text_at(Vector2(34,rect.end.y+24),"Measured action: "+str({"wait":"Wait","lights":"Light outage","steps":"Footsteps behind","silhouette":"Silhouette"}.get(measured_action,"Wait")),15,GREEN)
