extends Control

var director: Node
var last_stamp := -1.0
var history: Array[float] = []
var points := PackedVector2Array()
var edges: Array = []
var ids: Array = []
var redraw_clock := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if director == null: return
	if points.is_empty() and director.info.has("view"):
		var view: Dictionary = director.info.view
		ids = view.ids
		edges = view.edges
		for p in view.xyz:
			points.append(Vector2(24+float(p[0])*438,55+float(p[1])*175))
	if director.last_neural_time != last_stamp:
		last_stamp = director.last_neural_time
		if last_stamp >= 0:
			history.append(float(director.neural.get("mean_abs",0)))
			if history.size()>32: history.pop_front()
	redraw_clock += delta
	if visible and redraw_clock>=0.1:
		redraw_clock = 0
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.012,0.032,0.041,0.93))
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.15,0.31,0.29),false,1)
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(18,25),"SİNEK BEYNİ / CANLI ÖLÇÜMLER  [B]",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(0.74,0.9,0.84))
	draw_string(font,Vector2(18,45),"GÖRÜŞ  →  GERÇEK BAĞLANTILAR  →  EYLEM",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(0.51,0.64,0.62))
	if director == null: return
	var age: float = director.now()-director.last_neural_time
	var fresh: bool = director.last_neural_time>=0 and director.connected and director.running and age<=director.interval+1.5
	var values: Array = director.neural.get("view_activity",[])
	for edge in edges:
		var active := 0.0
		if fresh and values.size()==points.size(): active=absf(float(values[int(edge[0])]))
		draw_line(points[int(edge[0])],points[int(edge[1])],Color(0.2,0.61,0.52,0.06+active*0.28),1)
	for i in points.size():
		var value: float = float(values[i]) if fresh and i<values.size() else 0.0
		var color := Color(1,0.57,0.29) if value<0 else Color(0.24,0.91,0.70)
		color.a = 0.22+minf(absf(value)*2,0.78) if fresh else 0.18
		draw_circle(points[i],1.7+minf(absf(value)*3,2),color)
	var status := "Ölçüm bekleniyor"
	if director.last_neural_time>=0: status=("Son ölçüm %.1f sn önce" if fresh else "ESKİ ÖLÇÜM / %.1f sn") % age
	draw_string(font,Vector2(18,256),status,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color(0.7,0.8,0.77))
	draw_string(font,Vector2(18,281),"512 gerçek soma · 2B izdüşüm · tam ağ çalışır",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(0.51,0.64,0.62))
	draw_string(font,Vector2(18,302),"Renk: işaretli model etkinliği; biyolojik kayıt değil",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(0.51,0.64,0.62))
	for i in range(1,history.size()):
		draw_line(Vector2(20+(i-1)*14,333-history[i-1]*500),Vector2(20+i*14,333-history[i]*500),Color(0.36,0.72,0.62),1.5)
