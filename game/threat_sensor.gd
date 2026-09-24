extends RefCounted

# Engineered pre-looming detector. No claims of retinal or bullet-flight simulation.
# Hitscan damage happens immediately; this supports anticipation and follow-up evasion.
static func sample(drone: CharacterBody3D, player: CharacterBody3D) -> Dictionary:
	var quiet := {"level":0.0,"bearing":0.0}
	if not drone.active or not player.active: return quiet
	var origin: Vector3 = player.camera.global_position
	var relative := drone.global_position-origin
	var aim: Vector3 = -player.camera.global_basis.z
	var along := relative.dot(aim)
	if along <= 0 or along > player.weapon_range: return quiet
	var ray := PhysicsRayQueryParameters3D.create(origin,drone.global_position,1)
	ray.exclude = [player.get_rid(),drone.get_rid()]
	if not drone.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return quiet
	var offset := relative-aim*along
	var proximity := clampf(1.0-offset.length()/1.5,0,1)
	if proximity <= 0: return quiet
	var shot: bool = Time.get_ticks_msec()/1000.0-player.last_shot_time < 0.55
	var right: Vector3 = drone.gaze.cross(Vector3.UP).normalized()
	return {"level":proximity*(1.0 if shot else 0.55),
		"bearing":clampf(offset.dot(right)/0.65,-1,1)}
