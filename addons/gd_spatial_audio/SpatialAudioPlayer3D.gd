class_name SpatialAudioPlayer3D
extends AudioStreamPlayer3D


@export var max_raycast_distance: float = 100.0;
@export var update_frequency_seconds: float = 0.25 + randf()*0.2; # Don't want to do them all at the same time
@export var max_reverb_wetness: float = 0.5;
@export var wall_lowpass_cutoff_amount: int = 1000;
@export var max_stereo_distance : float = 16.0;
var horizontalCheck:float = 1.0;
var verticalCheck:float = 0.8;

var _raycast_array: Array = []
var _distance_array: Array = [{},{},{},{},{}, {},{},{},{},{}]
var _total_distance_checks : Array = []
var _last_update_time : float = 0.0
var _update_distances : bool = true
var _current_raycast_index : int = 0

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
var _target_reverb_wetness : float = 0.0
var _target_reverb_dryness : float = 1.0
var _target_volume_db : float = 0.0
var _target_reverb_dampening: float = 0.5
var _target_reverb_reflection_time: float = 0.0
var _target_stereo_pan_pullout : float = 0.5

var _target_32hz_reduction:float = 0.0
var _target_100hz_reduction:float = 0.0
var _target_320hz_reduction:float = 0.0
var _target_1000hz_reduction:float = 0.0
var _target_3200hz_reduction:float = 0.0
var _target_10000hz_reduction:float = 0.0

func _ready():
	_sleep_update_frequency_seconds = update_frequency_seconds + 1.0
	if max_distance > 0:
		max_raycast_distance = max_distance
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
	_raycast_array.append_array([
		$RayCastBackward, $RayCastBackwardLeft, $RayCastBackwardRight,
		$RayCastForward, $RayCastForwardLeft, $RayCastForwardRight,
		$RayCastLeft, $RayCastRight,
		$RayCastUp,
		$RayCastPlayer
		]);

	for raycast:RayCast3D in _raycast_array:
		raycast.target_position *= max_raycast_distance
	AudioServer.playback_speed_scale = 1.0

# takes the raycast and places it in a certain predefined orientation
# 4 cycles on x axis;
# 8 cycles on y axis.
var _cycle_x : int = 0
var _cycle_y : int = 0
var _full_cycle : bool = false

func cycle_raycast_direction(raycast: RayCast3D):
	if _full_cycle:
		_full_cycle = false
	
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
	if raycast.name != "RayCastPlayer":
		cycle_raycast_direction(raycast)
		# raycast.force_raycast_update()
	else:
		retrieve_raycast_hits(raycast)
		return
	var colliding : bool = raycast.is_colliding()
	var _raycast_keys : Dictionary = {"distance": -1.0, "material": null} # i dont want to use dictionaries
	# _distance_array[raycast_index]["distance"] = -1
	# _distance_array[raycast_index]["material"] = null
	if colliding:
		var collider : CollisionObject3D = raycast.get_collider()
		# _distance_array[raycast_index]["distance"] = self.global_position.distance_to(raycast.get_collision_point());
		_raycast_keys["distance"] = self.global_position.distance_to(raycast.get_collision_point());
		
		if (collider is StaticBody3D and
			collider.physics_material_override and
			collider.physics_material_override is ExpandedPhysicsMaterial):
			# _distance_array[raycast_index]["material"] = collider.physics_material_override
			_raycast_keys["material"] = collider.physics_material_override
	_total_distance_checks.push_back(_raycast_keys);
	# raycast.enabled = false;

func _on_check_spatial_camera(player: Node3D):
	_on_update_reverb(player);
	_on_update_stereo(player);
	_on_update_lowpass_filter(player);

	var _camera_room_size : float = player._target_reverb_room_size
	if _camera_room_size < _target_reverb_room_size:
		if !_walls_in_way:
			_target_reverb_room_size = _camera_room_size
			_target_reverb_dampening = player._target_reverb_dampening
			_target_reverb_reflection_time = player._target_reverb_reflection_time
			_target_reverb_dryness = lerp(_target_reverb_dryness, 1.0, get_physics_process_delta_time())
			return
		
		_target_reverb_room_size = _camera_room_size
		_target_reverb_dampening = player._target_reverb_dampening
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
	var wetness = 1.0
	var dampening = 0.5
	var reflectionTime = 0.0
	for dist in _total_distance_checks:
		if dist["material"]:
			dampening += dist["material"].dampening
			# wetness += min((dist["material"].reverberation * 0.5), 1.0)
		else:
			dampening += 0.5
		# Getting how long for reflections.
		# if dist["distance"] >= 0:
		# 	reflectionTime += (dist["distance"] * 343 * 0.001) # Speed of sound
		if dist["distance"] >= 0:
			reflectionTime += (dist["distance"] * 343 * 0.001) # Speed of sound
			# find average room size based on valid distances
			room_size += dist["distance"]
		else:
			room_size += max_raycast_distance
			wetness -= 1.0/float(_total_distance_checks.size());
			wetness = max(wetness, 0.0);
	
	room_size = (room_size / float(_total_distance_checks.size())) / max_raycast_distance
	# wetness = min(wetness, 1.0)

	if name == "crook":
		print(room_size)
		print(wetness)
	# wetness = (wetness / float(_total_distance_checks.size()))
	if _dist_to_player < 8.0:
		room_size = (room_size * min((_dist_to_player / 8.0), 1.0))
		wetness = (wetness * min((_dist_to_player / 8.0), 1.0))
	
	_target_reverb_dryness = 1.0;
	_target_reverb_wetness = wetness;
	_target_reverb_room_size = room_size;
	_target_reverb_dampening = dampening/_total_distance_checks.size()
	_target_reverb_reflection_time = reflectionTime/_total_distance_checks.size()

func _on_update_stereo(player: Node3D):
	if !_stereo_effect:
		return
	var _stereo_dist_player : float = _dist_to_player
	if max_stereo_distance == 0:
		_target_stereo_pan_pullout = 0.3
	else:
		_stereo_dist_player = clamp(_dist_to_player * _target_reverb_room_size, max_stereo_distance * 0.25, max_stereo_distance)
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
		$RayCastPlayer.target_position = (player.global_position - self.global_position + i)
		$RayCastPlayer.force_raycast_update()
		var collider = $RayCastPlayer.get_collider();
		var _lowpass_cutoff = 20000;
		_walls_in_way = $RayCastPlayer.is_colliding()
		if collider:
			var ray_distance : float = self.global_position.distance_to($RayCastPlayer.get_collision_point());
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

func _lerp_parameters(delta):
	# if max_distance > 0:
	# 	volume_db = lerp(volume_db, volume_db * (1.0-(_dist_to_player / max_distance)), delta);
	# else:
	AudioServer.lock()
	volume_db = lerp(volume_db, _target_volume_db, delta);
	_stereo_effect.pan_pullout = lerp(_stereo_effect.pan_pullout, _target_stereo_pan_pullout, delta*3.0);
	_lowpass_filter.cutoff_hz = lerp(_lowpass_filter.cutoff_hz, _target_lowpass_cutoff, delta*3.0);
	_reverb_effect.wet = lerp(_reverb_effect.wet, _target_reverb_wetness * max_reverb_wetness, delta * 5.0);
	_reverb_effect.dry = lerp(_reverb_effect.dry, _target_reverb_dryness, delta * 5.0);
	_reverb_effect.room_size = lerp(_reverb_effect.room_size, _target_reverb_room_size, delta* 5.0);
	_reverb_effect.damping = lerp(_reverb_effect.damping, _target_reverb_dampening, delta*5.0);
	_reverb_effect.predelay_msec = lerp(_reverb_effect.predelay_msec, _target_reverb_reflection_time, delta * 5.0);
	_eq_filter.set_band_gain_db(0, lerp(_eq_filter.get_band_gain_db(0), _target_32hz_reduction, delta*3.0))
	_eq_filter.set_band_gain_db(1, lerp(_eq_filter.get_band_gain_db(1), _target_100hz_reduction, delta*3.0))
	_eq_filter.set_band_gain_db(2, lerp(_eq_filter.get_band_gain_db(2), _target_320hz_reduction, delta*3.0))
	_eq_filter.set_band_gain_db(3, lerp(_eq_filter.get_band_gain_db(3), _target_1000hz_reduction, delta*3.0))
	_eq_filter.set_band_gain_db(4, lerp(_eq_filter.get_band_gain_db(4), _target_3200hz_reduction, delta*3.0))
	_eq_filter.set_band_gain_db(5, lerp(_eq_filter.get_band_gain_db(5), _target_10000hz_reduction, delta*3.0))
	AudioServer.unlock()
	#_reverb_effect.predelay_feedback = 0.8
	

func _physics_process(delta):
	_last_update_time += delta
	_loop_rotation(delta)
	if !_full_cycle || _update_distances:
		if (_full_cycle && _update_distances && _current_raycast_index == 0):
			_total_distance_checks = []
		_on_update_raycast_distance(_raycast_array[_current_raycast_index], _current_raycast_index);
		_current_raycast_index +=1
		if _current_raycast_index >= _distance_array.size():
			_current_raycast_index = 0

			_update_distances = false
	
	if _has_moved:
		if _last_update_time > update_frequency_seconds:
			var player_camera = get_viewport().get_camera_3d()
			if player_camera:
				_player_position = player_camera.global_position
				if _full_cycle:
					if player_camera is SpatialAudioCamera3D:
						_on_check_spatial_camera(player_camera);
					else:
						_on_update_spatial_audio(player_camera);
			_update_distances = true
			_last_update_time = 0.0

			if _previous_position == global_position:
				_has_moved = false
			if _previous_position != global_position:
				_has_moved = true
			_previous_position = global_position
	else:
		if _last_update_time > _sleep_update_frequency_seconds:
			var player_camera = get_viewport().get_camera_3d()
			if player_camera:
				_player_position = player_camera.global_position
				if _full_cycle:
					if player_camera is SpatialAudioCamera3D:
						_on_check_spatial_camera(player_camera);
					else:
						_on_update_spatial_audio(player_camera);
			_update_distances = true
			_last_update_time = 0.0

			if _previous_position == global_position:
				_has_moved = false
			if _previous_position != global_position:
				_has_moved = true
			_previous_position = global_position
	
	_lerp_parameters(delta)

func _loop_rotation(delta):
	$cone.rotation.y += delta

	if $cone.rotation_degrees.y >= 360:
		$cone.rotation.y = 0.0
