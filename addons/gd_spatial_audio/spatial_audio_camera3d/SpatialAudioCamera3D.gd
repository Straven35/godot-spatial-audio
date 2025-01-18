extends Camera3D
class_name SpatialAudioCamera3D

@onready var _raycast_holder : Node3D = $Raycasts

@export var raycast_count : int = 3
@export var max_sounds : int = 16 
@export var raycast_update_time : float = 0.3
var _nearby_sounds : Array = []

var _sleep_update_frequency_seconds : float = 0.0
var _previous_position : Vector3 = Vector3.ZERO
var _has_moved : bool = true

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

var _target_lowpass_cutoff : float = 20000
var _target_reverb_room_size : float = 0.0
var _target_reverb_wetness : float = 0.0
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

func _ready():
	_raycast_array = _raycast_holder.get_children();
	_distance_array = []
	for i in _raycast_array.size():
		_distance_array.push_back({})

	for raycast:RayCast3D in _raycast_array:
		raycast.target_position *= max_raycast_distance

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

func _on_update_raycast_distance(raycast: RayCast3D, raycast_index: int):
	cycle_raycast_direction(raycast)
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

func _on_update_spatial_audio(player: Node3D):
	_on_update_reverb(player);

func _on_update_reverb(player: Node3D):
	var room_size = 0.0
	var wetness = 1.0
	var damping = 0.5
	var reflectionTime = 0.0
	var reflectionFeedback = 0.4
	for dist in _total_distance_checks:
		if dist["material"]:
			wetness += dist["material"].reflection
			# wetness += min((dist["material"].reverberation * 0.5), 1.0)
		else:
			damping += 0.5
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
	# if name == "blop":
	# 	print("FULL SIZE:  ", room_size, "  OUT OF:  ", max_raycast_distance * float(_total_distance_checks.size()))
	room_size = (room_size / float(_total_distance_checks.size())) / max_raycast_distance
	# wetness = min(wetness, 1.0)

	# wetness = (wetness / float(_total_distance_checks.size()))
	if _dist_to_player < 8.0:
		room_size = (room_size * min((_dist_to_player / 8.0), 1.0))
		wetness = (wetness * min((_dist_to_player / 8.0), 1.0))
	
	reflectionFeedback = (room_size + wetness) / 2.0

	# if name == "blop":
	# 	print("DAMPENING:  ", dampening/_total_distance_checks.size())
	# 	print("TIME:  ", reflectionTime/_total_distance_checks.size())
	# 	print("FEEDBACK:  ", reflectionFeedback)
	# 	print("WETNESS:  ", wetness)
	# 	print("ROOMSIZE:  ", room_size)

	_target_reverb_wetness = wetness;
	_target_reverb_room_size = room_size;
	_target_reverb_damping = damping/_total_distance_checks.size()
	_target_reverb_reflection_time = reflectionTime/_total_distance_checks.size()
	_target_reverb_reflection_feedback = reflectionFeedback

func _physics_process(delta):
	_last_update_time += delta
	if !_full_cycle || _update_distances:
		if (_full_cycle && _update_distances && _current_raycast_index == 0):
			_total_distance_checks = []
		_on_update_raycast_distance(_raycast_array[_current_raycast_index], _current_raycast_index);
		_current_raycast_index +=1
		if _current_raycast_index >= _distance_array.size():
			_current_raycast_index = 0

			_update_distances = false
	
	if _last_update_time > update_frequency_seconds:
		var player_camera = self
		if player_camera && _full_cycle:
			_on_update_spatial_audio(player_camera);
		_update_distances = true
		_last_update_time = 0.0
	if _has_moved:
		if _last_update_time > update_frequency_seconds:
			var player_camera = self
			if player_camera:
				if _full_cycle:
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
			var player_camera = self
			if player_camera:
				if _full_cycle:
					_on_update_spatial_audio(player_camera);
			_update_distances = true
			_last_update_time = 0.0

			if _previous_position == global_position:
				_has_moved = false
			if _previous_position != global_position:
				_has_moved = true
			_previous_position = global_position




