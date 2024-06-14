class_name SpatialAudioPlayer3D
extends AudioStreamPlayer3D

static var _total_turns_taken : int = 0
static var _total_turns : int = 4
static var _next_turn : int = 0
static var _total_using_turns : Array = []
static var _audio_server_locked : bool = false

@export var is_active : bool = true;
@export var max_raycast_distance: float = 100.0;
@export var update_frequency_seconds: float = 0.25 + randf()*0.5; # Don't want to do them all at the same time
@export var max_reverb_wetness: float = 0.5;
@export var wall_lowpass_cutoff_amount: int = 1000;
@export var max_stereo_distance : float = 16.0;
@export_range(0, 4) var max_raycast_bounces : int = 0;
@export_range(2, 16) var raycast_count : int = 4;
@export var raycast_exclude_parent : bool = true;
@export var raycast_collide_with_areas : bool = false;
@export var raycast_collide_with_bodies : bool = true;
@export var do_print_debug : bool = false;
@export_flags_3d_physics var raycast_collision_mask;
var horizontalCheck:float = 1.0;
var verticalCheck:float = 0.8;
var _turn : int = 0

var _raycast_array: Array = []
var _distance_array: Array = [{},{},{},{},{}, {},{},{},{},{}]
var _total_distance_checks : Array = []
var _last_update_time : float = 0.0
var _update_distances : bool = true
var _current_raycast_index : int = 0

var _debug_usec_avg : int = 0
var _debug_total_checks : int = 0
var _debug_use : bool = false

var _dist_to_player : float = 0.0
var _player_position : Vector3 = Vector3.ZERO
var _walls_in_way : bool = false
var _wall_distance : float = 0.0

var _sleep_update_frequency_seconds : float = 0.0
var _previous_position : Vector3 = Vector3.ZERO
var _has_moved : bool = true

var _audio_bus_idx = null
var _audio_bus_name = ""

var _stereo_effect : AudioEffectStereoEnhance
var _reverb_effect : AudioEffectReverb
var _lowpass_filter : AudioEffectLowPassFilter
var _eq_filter : AudioEffectEQ

var _target_lowpass_cutoff : float = 20000
var _target_reverb_room_size : float = 0.0
var _target_reverb_spread : float = 0.0
var _target_reverb_wetness : float = 0.0
var _target_reverb_dryness : float = 1.0
var _target_volume_db : float = 0.0
var _target_reverb_damping: float = 0.5
var _target_reverb_reflection_time: float = 0.0
var _target_reverb_reflection_feedback : float = 0.4
var _target_stereo_pan_pullout : float = 0.5

var _target_32hz_reduction:float = 0.0
var _target_100hz_reduction:float = 0.0
var _target_320hz_reduction:float = 0.0
var _target_1000hz_reduction:float = 0.0
var _target_3200hz_reduction:float = 0.0
var _target_10000hz_reduction:float = 0.0

var _finished_ready : bool = false

func _ready():
	if !is_active:
		return
	if _total_using_turns.size() == 0:
		_total_using_turns.resize(_total_turns+1)
	_turn = _next_turn
	_total_using_turns[_turn] = _total_using_turns[_turn] + 1 if _total_using_turns[_turn] != null else 0
	_next_turn += 1
	if _next_turn > _total_turns:
		_next_turn = 0

	_debug_use = do_print_debug
	_sleep_update_frequency_seconds = update_frequency_seconds + 1.0
	if max_distance > 0 && max_raycast_distance < max_distance:
		max_raycast_distance = max_distance
	for i in raycast_count:
		var __ray : RayCast3D = RayCast3D.new()
		__ray.collision_mask = raycast_collision_mask
		__ray.collide_with_areas = raycast_collide_with_areas
		__ray.collide_with_bodies = raycast_collide_with_bodies
		__ray.exclude_parent = raycast_exclude_parent
		add_child(__ray)
		_raycast_array.push_back(__ray)
	# Make new audio bus
	_audio_bus_idx = AudioServer.bus_count
	_audio_bus_name = "SpatialBus#"+str(_audio_bus_idx)
	AudioServer.add_bus(_audio_bus_idx)
	AudioServer.set_bus_name(_audio_bus_idx, _audio_bus_name);
	self.bus = _audio_bus_name
	
	AudioServer.add_bus_effect(_audio_bus_idx, AudioEffectStereoEnhance.new(), 0);
	AudioServer.add_bus_effect(_audio_bus_idx, AudioEffectReverb.new(), 1);
	AudioServer.add_bus_effect(_audio_bus_idx, AudioEffectLowPassFilter.new(), 2);
	AudioServer.add_bus_effect(_audio_bus_idx, AudioEffectEQ.new(), 3);
	_stereo_effect = AudioServer.get_bus_effect(_audio_bus_idx, 0);
	_reverb_effect = AudioServer.get_bus_effect(_audio_bus_idx, 1);
	_lowpass_filter = AudioServer.get_bus_effect(_audio_bus_idx, 2);
	_eq_filter = AudioServer.get_bus_effect(_audio_bus_idx, 3);
	
	_target_volume_db = volume_db;
	volume_db = -60.0;
	# _raycast_array.append_array([
	# 	$RayCastBackward, $RayCastBackwardLeft, $RayCastBackwardRight,
	# 	$RayCastForward, $RayCastForwardLeft, $RayCastForwardRight,
	# 	$RayCastLeft, $RayCastRight,
	# 	$RayCastUp,
	# 	$RayCastPlayer
	# 	]);

	for raycast:RayCast3D in _raycast_array:
		raycast.target_position *= max_raycast_distance
	AudioServer.playback_speed_scale = 1.0

# takes the raycast and places it in a certain predefined orientation
# 5 cycles on x axis;
# 9 cycles on y axis.
# 45 total cycles.
var _cycle_x : int = 0
var _cycle_y : int = 0
var _full_cycle : bool = false
var _bounce_set : int = 0
var __time : int = 0

func cycle_raycast_direction(raycast: RayCast3D):
	if _full_cycle:
		_full_cycle = false
	
	if _bounce_set > 0 && max_raycast_bounces > 0:
		if _debug_use:
			__time = Time.get_ticks_usec()
		if !raycast.is_colliding(): # reset this raycast if no more bounces to do
			_bounce_set = 0
			raycast.position = Vector3.ZERO
			if _debug_use:
				_debug_usec_avg += Time.get_ticks_usec() - __time
				_debug_total_checks += 1
			return

		var _touchy_touch = raycast.get_collision_point()
		var _touchy_bounce = raycast.get_collision_normal()

		raycast.global_position = _touchy_touch
		if _touchy_bounce.is_normalized():
			var _new_pos : Vector3 = raycast.target_position.normalized().bounce(_touchy_bounce)
			raycast.target_position = _new_pos.normalized() * max_raycast_distance
		else:
			_bounce_set = 0
			raycast.position = Vector3.ZERO
			if _debug_use:
				_debug_usec_avg += Time.get_ticks_usec() - __time
				_debug_total_checks += 1
			return
		_bounce_set += 1
		if _debug_use:
			_debug_usec_avg += Time.get_ticks_usec() - __time
			_debug_total_checks += 1
		if _bounce_set > max_raycast_bounces:
			_bounce_set = 0
		return
		# do bouncing here

	if _debug_use:
		__time = Time.get_ticks_usec()
	raycast.position = Vector3.ZERO

	var _x_axis_position : Vector3
	var _y_axis_position : Vector3
	var _total_position : Vector3
	match(_cycle_x):
		0:
			_x_axis_position = Vector3.UP
		1:
			_x_axis_position = Vector3.UP / 2.0
		2:
			_x_axis_position = Vector3.ZERO
		3:
			_x_axis_position = Vector3.DOWN / 2.0
		4:
			_x_axis_position = Vector3.DOWN
	
	match(_cycle_y):
		0:
			_y_axis_position = Vector3.FORWARD
		1:
			_y_axis_position = Vector3.FORWARD + Vector3.RIGHT
		2:
			_y_axis_position = Vector3.RIGHT
		3:
			_y_axis_position = Vector3.RIGHT + Vector3.BACK
		4:
			_y_axis_position = Vector3.BACK
		5:
			_y_axis_position = Vector3.BACK + Vector3.LEFT
		6:
			_y_axis_position = Vector3.LEFT
		7:
			_y_axis_position = Vector3.LEFT + Vector3.FORWARD
		8:
			_y_axis_position = Vector3.ZERO
	
	_total_position = _x_axis_position + _y_axis_position
	_total_position = _total_position.normalized()
	raycast.target_position = _total_position * max_raycast_distance

	if _debug_use:
		_debug_usec_avg += Time.get_ticks_usec() - __time
		_debug_total_checks += 1
	if max_raycast_bounces > 0:
		_bounce_set = 1

	if _cycle_y < 8:
		_cycle_y += 1
	else:
		_cycle_y = 0
		if _cycle_x < 4:
			_cycle_x += 1
		else:
			_cycle_x = 0
			if _cycle_x == 0 && _cycle_y == 0:
				_full_cycle = true

	
	# FRONT
	# RIGHT
	# BACK
	# LEFT
	# UP
	# DOWN
	# ...
	# TOP - TOP/2 - BOTTOM/2 - BOTTOM
	# FRONT
	# FRONT -RIGHT
	# RIGHT
	# RIGHT -BACK
	# BACK
	# BACK -LEFT
	# LEFT
	# LEFT -FRONT
	# TOP
	pass

func randomise_raycast_direction(raycast: RayCast3D):
	raycast.target_position = Vector3((randf()*2.0)-1.0, (randf()*2.0)-1.0, (randf()*2.0)-1.0)*max_raycast_distance

func retrieve_raycast_hits(raycast : RayCast3D):
	return
	raycast.target_position = to_local(_player_position)
	raycast.force_raycast_update()
	var _colliding : bool = raycast.is_colliding()
	var _total_distance : float = 0.0
	var _total_hits : int = 0
	if _colliding:
		var _col_point : Vector3 = raycast.get_collision_point()
		for i in 3:
			raycast.position = _col_point
			raycast.target_position = to_local(_player_position)
			raycast.force_raycast_update()
			_colliding = raycast.is_colliding()
			if _colliding:
				_total_hits += 1
				_col_point = raycast.get_collision_point()
				_total_distance += raycast.global_position.distance_squared_to(_col_point)
			else:
				break # if this hits a flat collision shape im cooked
	_wall_distance = _total_distance
	raycast.position = Vector3.ZERO

func _on_update_raycast_distance(raycast: RayCast3D, raycast_index: int):
	# randomise_raycast_direction(raycast)
	if raycast_index > 0:
		cycle_raycast_direction(raycast)
	else:
		retrieve_raycast_hits(raycast)
		return
	var colliding : bool = raycast.is_colliding()
	var _all_keys : Array = []
	# dictionaries are fine i suppose
	if colliding:
		var _raycast_keys : Dictionary = {"distance": -1.0, "material": null} # i dont want to use dictionaries
		var _iterator : int = 0
		var _looping : bool = max_raycast_bounces > 0
		var collider : CollisionObject3D = raycast.get_collider()

		_raycast_keys["distance"] = self.global_position.distance_to(raycast.get_collision_point());
		if (collider is StaticBody3D and
			collider.physics_material_override and
			collider.physics_material_override is ExpandedPhysicsMaterial):
			_raycast_keys["material"] = collider.physics_material_override
		_all_keys.push_back(_raycast_keys)
		
	_total_distance_checks.append_array(_all_keys);

func _on_check_spatial_camera(player: Node3D):
	_on_update_reverb(player);
	_on_update_stereo(player);
	_on_update_lowpass_filter(player);

	return
	var _camera_room_size : float = player._target_reverb_room_size
	if _camera_room_size < _target_reverb_room_size:
		if !_walls_in_way:
			_target_reverb_room_size = _camera_room_size
			_target_reverb_damping = player._target_reverb_damping
			_target_reverb_reflection_time = player._target_reverb_reflection_time
			_target_reverb_dryness = lerp(_target_reverb_dryness, 1.0, get_physics_process_delta_time())
			return
		
		_target_reverb_room_size = _camera_room_size
		_target_reverb_damping = player._target_reverb_damping
		_target_reverb_reflection_time = player._target_reverb_reflection_time
		_target_reverb_dryness = player._target_reverb_wetness
	else:
		_target_reverb_dryness = lerp(_target_reverb_dryness, 1.0, get_physics_process_delta_time())

func _on_update_spatial_audio(player: Node3D):
	_on_update_reverb(player);
	_on_update_stereo(player);
	_on_update_lowpass_filter(player);

func _on_update_reverb(player: Node3D):
	if !_reverb_effect:
		return
	var room_size = 0.0
	var wetness = 0.0
	var damping = 0.0
	var spread = 1.0
	var largest_ray_distance : float = 0.0
	var average_ray_distance : float = 0.0
	var reflectionTime = 0.0
	var reflectionFeedback = 0.4
	var _total_raycasts_allowed = 45 + (45 * max_raycast_bounces)
	for i in _total_raycasts_allowed:

		var dist : Dictionary
		if i < _total_distance_checks.size():
			dist = _total_distance_checks[i]
		if dist.is_empty():
			reflectionTime += (max_raycast_distance * 343 * 0.01) # raycast result doesnt exist, nothing was hit, give the big echo.
			# largest_ray_distance = max_raycast_distance
			average_ray_distance += 1.0
			continue
		if dist["material"]:
			damping += dist["material"].damping
			wetness += dist["material"].transmission
		else:
			damping += 0.5
			wetness += 0.1
		# Getting how long for reflections.
		if dist["distance"] >= 0:
			if dist["distance"] > largest_ray_distance:
				largest_ray_distance = dist["distance"]
			average_ray_distance += dist["distance"]
			reflectionTime += (dist["distance"] * 343 * 0.001) # Speed of sound
			room_size += dist["distance"]
	average_ray_distance = average_ray_distance / _total_distance_checks.size()
	room_size = (room_size / _total_distance_checks.size()) / largest_ray_distance
	wetness = (wetness / float(_total_distance_checks.size()))
	spread = min(1.0, average_ray_distance / largest_ray_distance)

	if _dist_to_player < 8.0:
		room_size = (room_size * min((_dist_to_player / 8.0), 1.0))
		wetness = (wetness * min((_dist_to_player / 8.0), 1.0))
	
	reflectionFeedback = (room_size + wetness) / 2.0

	if _debug_use:
		print("DAMPING:  ", _target_reverb_damping)
		print("SPREAD: ", _target_reverb_spread)
		print("TIME:  ", _target_reverb_reflection_time)
		print("FEEDBACK:  ", _target_reverb_reflection_feedback)
		print("WETNESS:  ", _target_reverb_wetness)
		print("ROOMSIZE:  ", _target_reverb_room_size)

	_target_reverb_dryness = 1.0;
	
	if _finished_ready:
		_target_reverb_wetness = wetness;
		_target_reverb_spread = spread;
		_target_reverb_room_size = room_size;
		_target_reverb_damping = damping/_total_distance_checks.size()
		_target_reverb_reflection_time = reflectionTime/_total_distance_checks.size()
		_target_reverb_reflection_feedback = reflectionFeedback
	else:
		_target_reverb_wetness = 0.0;
		_target_reverb_spread = 0.0;
		_target_reverb_room_size = 0.0;
		_target_reverb_damping = 0.5;
		_target_reverb_reflection_time = 0.0
		_target_reverb_reflection_feedback = 0.4
	
	_finished_ready = true

func _on_update_stereo(player: Node3D):
	if !_stereo_effect:
		return
	var _stereo_dist_player : float = _dist_to_player
	if _debug_use:
		print(_stereo_dist_player)
	if max_stereo_distance == 0:
		_target_stereo_pan_pullout = 0.3
	else:
		if _debug_use:
			if _target_reverb_room_size > _target_reverb_spread:
				print("room size bigger ", _target_reverb_room_size, "  ", _target_reverb_spread)
			else:
				print("spread bigger ", _target_reverb_room_size, "  ", _target_reverb_spread)
		_stereo_dist_player = clamp(
			_dist_to_player * max(_target_reverb_room_size, _target_reverb_spread), 
			max_stereo_distance * 0.25, 
			max_stereo_distance)
		_target_stereo_pan_pullout = clamp(_stereo_dist_player / max_stereo_distance, 0.3, 1.0)

func _on_update_lowpass_filter(player: Node3D):
	if !_lowpass_filter:
		return
	_dist_to_player = global_position.distance_to(player.global_position)
	var bandReductions = [0,0,0,0,0,0]
	var lowPassArray:Array = []
	for i in [
		Vector3(horizontalCheck,0,0), Vector3(-horizontalCheck,0,0),
		Vector3(0,0,horizontalCheck), Vector3(0,0,-horizontalCheck),
		Vector3(0,verticalCheck, horizontalCheck), Vector3(0,verticalCheck, -horizontalCheck),
		Vector3(horizontalCheck,verticalCheck, 0), Vector3(-horizontalCheck,verticalCheck, 0),
		Vector3(0,0,0)
	]:
		# $RayCastPlayer.target_position = (player.global_position - self.global_position + i).normalized() * max_raycast_distance
		var __ray : RayCast3D = _raycast_array[0]
		__ray.target_position = (player.global_position - self.global_position + i)
		__ray.force_raycast_update()
		var collider = __ray.get_collider();
		var _lowpass_cutoff = 20000;
		_walls_in_way = __ray.is_colliding()
		if collider:
			var ray_distance : float = self.global_position.distance_to(__ray.get_collision_point());
			var distance_to_player : float = _dist_to_player
			var wall_to_player_ratio : float = ray_distance / max(distance_to_player, 0.001)
			if ray_distance < distance_to_player:
				_lowpass_cutoff = wall_lowpass_cutoff_amount * wall_to_player_ratio
			if (collider is StaticBody3D and
				collider.physics_material_override and
				collider.physics_material_override is ExpandedPhysicsMaterial):
				bandReductions[0] -= -20*log(1-collider.physics_material_override.band_32_hz)/log(10)
				bandReductions[1] -= -20*log(1-collider.physics_material_override.band_100_hz)/log(10)
				bandReductions[2] -= -20*log(1-collider.physics_material_override.band_320_hz)/log(10)
				bandReductions[3] -= -20*log(1-collider.physics_material_override.band_1000_hz)/log(10)
				bandReductions[4] -= -20*log(1-collider.physics_material_override.band_3200_hz)/log(10)
				bandReductions[5] -= -20*log(1-collider.physics_material_override.band_10000_hz)/log(10)
		
		lowPassArray.append(_lowpass_cutoff)
	var total = 0;
	for i in range(bandReductions.size()):
		bandReductions[i]/=lowPassArray.size()
	for i in lowPassArray:
		total += i
	total /= lowPassArray.size()
	_target_lowpass_cutoff = total
	_target_32hz_reduction = bandReductions[0]*5.0
	_target_100hz_reduction = bandReductions[1]*5.0
	_target_320hz_reduction = bandReductions[2]*5.0
	_target_1000hz_reduction = bandReductions[3]*5.0
	_target_3200hz_reduction = bandReductions[4]*5.0
	_target_10000hz_reduction = bandReductions[5]*5.0
	if _debug_use:
		print("bands ", bandReductions, "  ", total)
		print("volume ", volume_db)

func _lerp_parameters(delta):
	# if max_distance > 0:
	# 	volume_db = lerp(volume_db, volume_db * (1.0-(_dist_to_player / max_distance)), delta);
	# else:
	# if _audio_server_locked:
	# 	return
	# AudioServer.call_deferred("lock")
	# AudioServer.lock()
	# _audio_server_locked = true
	volume_db = lerp(volume_db, _target_volume_db, delta);
	_stereo_effect.pan_pullout = lerp(_stereo_effect.pan_pullout, _target_stereo_pan_pullout, delta*3.0);
	_lowpass_filter.cutoff_hz = lerp(_lowpass_filter.cutoff_hz, _target_lowpass_cutoff, delta*3.0);
	_reverb_effect.wet = lerp(_reverb_effect.wet, _target_reverb_wetness * max_reverb_wetness, delta * 5.0);
	_reverb_effect.spread = lerp(_reverb_effect.spread, _target_reverb_spread, delta * 5.0);
	_reverb_effect.dry = lerp(_reverb_effect.dry, _target_reverb_dryness, delta * 5.0);
	_reverb_effect.room_size = lerp(_reverb_effect.room_size, _target_reverb_room_size, delta* 5.0);
	_reverb_effect.damping = lerp(_reverb_effect.damping, _target_reverb_damping, delta*5.0);
	_reverb_effect.predelay_msec = lerp(_reverb_effect.predelay_msec, _target_reverb_reflection_time, delta * 5.0);
	_reverb_effect.predelay_feedback = lerp(_reverb_effect.predelay_feedback, _target_reverb_reflection_feedback, delta * 5.0);
	_eq_filter.set_band_gain_db(0, lerp(_eq_filter.get_band_gain_db(0), _target_32hz_reduction, delta*3.0))
	_eq_filter.set_band_gain_db(1, lerp(_eq_filter.get_band_gain_db(1), _target_100hz_reduction, delta*3.0))
	_eq_filter.set_band_gain_db(2, lerp(_eq_filter.get_band_gain_db(2), _target_320hz_reduction, delta*3.0))
	_eq_filter.set_band_gain_db(3, lerp(_eq_filter.get_band_gain_db(3), _target_1000hz_reduction, delta*3.0))
	_eq_filter.set_band_gain_db(4, lerp(_eq_filter.get_band_gain_db(4), _target_3200hz_reduction, delta*3.0))
	_eq_filter.set_band_gain_db(5, lerp(_eq_filter.get_band_gain_db(5), _target_10000hz_reduction, delta*3.0))
	# AudioServer.call_deferred("unlock")
	# AudioServer.unlock()
	# _audio_server_locked = false
	#_reverb_effect.predelay_feedback = 0.8

var _just_used_params : bool = false

func _physics_process(delta):
	if !is_active:
		return
	_last_update_time += delta
	_loop_rotation(delta)
	
	var _this_update_time : int = 0
	if _has_moved:
		_this_update_time = update_frequency_seconds
	else:
		_this_update_time = _sleep_update_frequency_seconds
	
	if _last_update_time > _this_update_time && _next_turn == _turn:
		var player_camera = get_viewport().get_camera_3d()
		if player_camera:
			_player_position = player_camera.global_position
			if !_just_used_params && _full_cycle:
				if player_camera is SpatialAudioCamera3D:
					_on_check_spatial_camera(player_camera);
				else:
					_on_update_spatial_audio(player_camera);
				_just_used_params = true
		_update_distances = true
		_last_update_time = 0.0

		if _previous_position == global_position:
			_has_moved = false
		if _previous_position != global_position:
			_has_moved = true
		_previous_position = global_position

		_total_turns_taken += 1
		if _total_turns_taken > _total_using_turns[_turn]:
			_total_turns_taken = 0
			_next_turn += 1
			if _next_turn > _total_turns:
				_next_turn = 0
	
	# if name == "crook":
		# print("hoohoo ", _full_cycle, "  ", _update_distances, "  ", _total_distance_checks.size())
	if !_full_cycle || _update_distances:
		# if (_full_cycle) && _total_distance_checks.size() > 45 + (45 * max_raycast_bounces):
		# 	print(name, "  Total rays: ", raycast_count, ", Max bounces per ray: ", max_raycast_bounces, ", total avg time: ", max(1, _debug_usec_avg) / max(1, _debug_total_checks), " microseconds")
		# 	_debug_usec_avg = 0
		# 	_debug_total_checks = 0
		if _just_used_params:
			_just_used_params = false
			_total_distance_checks = []
			if _debug_use:
				print(name, "  Total rays: ", raycast_count, ", Max bounces per ray: ", max_raycast_bounces, ", total avg time: ", max(1, _debug_usec_avg) / max(1, _debug_total_checks), " microseconds")
				_debug_usec_avg = 0
				_debug_total_checks = 0
		elif _update_distances:
			while _current_raycast_index < _raycast_array.size():
				_on_update_raycast_distance(_raycast_array[_current_raycast_index], _current_raycast_index);
				if _current_raycast_index == 0:
					_current_raycast_index += 1
					continue
				if _bounce_set == 0:
					_current_raycast_index += 1
				if _full_cycle:
					_bounce_set = 0
					_update_distances = false
					break
			_current_raycast_index = 0
			
			# _update_distances = false
		# if _total_distance_checks.size() >= 45 + (45 * max_raycast_bounces):
		# 	_update_distances = false
		# if _current_raycast_index >= _distance_array.size():
		# if _current_raycast_index >= _raycast_array.size():
		# 	_current_raycast_index = 0
			# if !playing:
			# 	if !stream.is_class("AudioStreamWAV") && !stream.is_class("AudioStreamMP3"):
			# 		return
			# 	print("howdy howdy")
			# 	playing = true
			# 	_finished_ready = true
			# _update_distances = false

	_lerp_parameters(delta)

func _loop_rotation(delta):
	$cone.rotation.y += delta

	if $cone.rotation_degrees.y >= 360:
		$cone.rotation.y = 0.0
