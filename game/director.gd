extends Node

signal action_received(action: String, request_id: int)
signal status_changed

var socket := WebSocketPeer.new()
var connected := false
var session_ready := false
var running := false
var interval := 3.0
var mode := "fixed"
var seed_value := 42
var info := {}
var neural := {}
var reward := 0.0
var reward_source := "motion"
var action := "wait"
var reason := "Beyne bağlanılıyor"
var updates := 0
var budget_used := 0
var next_connect := 0.0
var last_request := 0.0
var last_sample := 0.0
var request_id := 0
var pending_id := -1
var rtt_ms := 0.0
var latest_telemetry := {}
var memory := {}
var last_neural_time := -1.0
var round_id := ""
var has_round := false
var ending := false
var feedback_id := -1
var feedback_until := 0.0
var feedback_action := ""
var feedback_status := ""

func rate_event(rating: int) -> void:
	if running and mode == "learn" and feedback_id >= 0 and now() < feedback_until and feedback_status.is_empty():
		feedback_status = "Gönderiliyor…"
		send({"type":"feedback","id":feedback_id,"rating":rating})

func now() -> float:
	return Time.get_ticks_msec() / 1000.0

func send(data: Dictionary) -> void:
	if connected:
		socket.send_text(JSON.stringify(data))

func start_session(new_round := true) -> void:
	feedback_id = -1
	if new_round:
		round_id = str(Time.get_unix_time_from_system()).replace(".","_") + "_" + str(Time.get_ticks_usec())
		running = true
		has_round = true
		neural = {}
		last_neural_time = -1
		reward = 0
		reward_source = "motion"
	session_ready = false
	pending_id = -1
	action = "wait"
	last_request = now()
	send({"type":"start", "mode":mode, "seed":seed_value, "interval":interval,"round_id":round_id,"paused":not running})

func finish_session(outcome: String) -> void:
	feedback_id = -1
	running = false
	pending_id = -1
	if has_round:
		ending = connected
		send({"type":"finish","outcome":outcome})
	has_round = false

func pause_session() -> void:
	feedback_id = -1
	running = false
	pending_id = -1
	action = "wait"
	send({"type":"pause"})

func resume_session() -> void:
	running = true
	last_request = now()
	send({"type":"resume"})

func _process(_delta: float) -> void:
	socket.poll()
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_CLOSED:
		if connected:
			feedback_id = -1
			connected = false
			session_ready = false
			pending_id = -1
			action = "wait"
			last_neural_time = -1
			reason = "Bağlantı kesildi · güvenli bekleme"
			status_changed.emit()
		if now() >= next_connect:
			next_connect = now() + 3
			socket = WebSocketPeer.new()
			var token := OS.get_environment("FLYFEAR_TOKEN")
			var port := OS.get_environment("FLYFEAR_PORT")
			if port.is_empty(): port = "8765"
			socket.connect_to_url("ws://127.0.0.1:%s/%s" % [port, token])
		return
	if state != WebSocketPeer.STATE_OPEN:
		return
	connected = true
	while socket.get_available_packet_count() > 0:
		var data = JSON.parse_string(socket.get_packet().get_string_from_utf8())
		if not data is Dictionary: continue
		if data.has("memory"): memory = data.memory
		if data.has("updates"): updates = int(data.updates)
		match data.get("type", ""):
			"feedback_open":
				if running:
					feedback_id = int(data.id)
					feedback_until = now() + minf(float(data.seconds),8)
					feedback_action = data.action
					feedback_status = ""
			"feedback":
				if int(data.id) == feedback_id: feedback_status = "Geri bildirimin alındı."
			"hello":
				info = data.get("info", {})
				reason = "Gerçek bağlantı verisi hazır"
				if has_round: start_session(false)
			"started":
				session_ready = true
				updates = data.get("updates", 0)
			"decision":
				if data.get("id", -2) != pending_id or pending_id < 0 or not running: continue
				rtt_ms = (now() - last_request) * 1000
				pending_id = -1
				if rtt_ms > 1500:
					action = "wait"
					reason = "Gecikmiş karar atlandı"
					continue
				action = data.get("action", "wait")
				if action not in ["wait", "lights", "steps", "silhouette"]: action = "wait"
				neural = data.get("neural", neural)
				if data.has("neural"): last_neural_time = now()
				budget_used = data.get("budget_used", budget_used)
				reason = {"selected":"Sinir çıktısından seçildi", "budget":"Olay bütçesi · bekleme", "cooldown":"Bekleme süresi"}.get(data.get("reason", "selected"),"Bekle")
				action_received.emit(action, int(data["id"]))
			"reward":
				reward = data.get("reward", 0)
				reward_source = data.get("source", "motion")
				updates = data.get("updates", 0)
			"parameters":
				updates = data.get("updates", 0)
				reason = "Karar katmanı " + ("sıfırlandı" if data.get("operation") == "reset" else "kaydedildi")
			"finished":
				ending = false
			"error":
				if feedback_status == "Gönderiliyor…": feedback_status = "Geri bildirim uygulanamadı."
				action = "wait"
				reason = data.get("message", "Beyin hatası")
		status_changed.emit()
	if pending_id >= 0 and now()-last_request > 1.5:
		pending_id = -1
		action = "wait"
		reason = "Simülasyon zaman aşımı · bekleme"
	if running and session_ready and not latest_telemetry.is_empty():
		if now()-last_sample >= 0.1:
			last_sample = now()
			send({"type":"telemetry", "telemetry":latest_telemetry})
		if now()-last_request >= interval and pending_id < 0:
			request_id += 1
			pending_id = request_id
			last_request = now()
			send({"type":"decision", "id":request_id, "telemetry":latest_telemetry})
