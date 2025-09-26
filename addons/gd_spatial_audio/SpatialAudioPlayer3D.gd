class_name SpatialAudioPlayer3D
extends AudioStreamPlayer3D

# set this to the max amount of raycasts you want processed by each audio player per
# physics frame.
static var __max_rays_per_frame : int = 3
# dont touch this
static var _total_turns_taken : int = 0
# dont touch this
static var _total_turns : int = 0
# set this to however many processing steps you want audio nodes to process on.
# higher = better frametime, lower = better audio effect syncing
static var _total_turns_max : int = 5
# dont touch this
static var _next_turn : int = 0
# dont touch this
static var _total_using_turns : Array
# dont touch this
static var _total_init_time : int = 0
# dont touch this
static var _finished_init : bool = false
# dont touch this
static var _begun_octree : bool = false

var creating_octree : bool = false

## maximum amount of cells for the audio pathing system to expand out to.
@export var sweep_max : int = 25;

## used for octree generation
@export var max_areas : int = 8;

@export var sweep_time : float = 0.03

@export var debug_show_free_areas : bool = false
@export var debug_show_filled_areas : bool = true
## 3 dimensional size of each grid cell to be used in the audio path sweep.
## larger = bigger grid size, less precision; smaller = smaller grid size, more precision.
@export var sweep_cell : float = 0.5;
@export var can_sweep : bool = false;
@export var octree_debug_material : Material;
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
var _debug_usec_mesh_avg : int = 0
var _debug_total_checks : int = 0
var _debug_use : bool = false

var _dist_to_player : float = 0.0
var _player_position : Vector3 = Vector3.ZERO
var _walls_in_way : bool = false
var _wall_distance : float = 0.0

var _sleep_update_frequency_seconds : float = 0.0
var _previous_position : Vector3 = Vector3.ZERO
var _has_moved : bool = true

var _total_effects : int = 0
var _current_effect_processed : int = 0
var _effect_functions : Array = []

var _audio_bus_idx = null
var _audio_bus_name = ""

var _stereo_effect : AudioEffectStereoEnhance
var _reverb_effect : AudioEffectReverb
var _lowpass_filter : AudioEffectLowPassFilter
var _eq_filter : AudioEffectEQ

var _target_lowpass_cutoff : float = 20000
var _target_lowpass_resonance : float = 0.0
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

var _shapecast_array: Dictionary = {}

@onready var box_mesh : BoxMesh = BoxMesh.new()
@onready var box_mesh_2 : BoxMesh = BoxMesh.new()
@onready var box_mesh_3 : BoxMesh = BoxMesh.new()
@onready var box_mesh_4 : BoxMesh = BoxMesh.new()
@onready var box_mesh_5 : BoxMesh = BoxMesh.new()
@onready var box_mesh_filled : BoxMesh = BoxMesh.new()
@onready var box_mesh_small_filled : BoxMesh = BoxMesh.new()
@onready var box_mat : StandardMaterial3D = StandardMaterial3D.new()
@onready var box_mat_filled : StandardMaterial3D = StandardMaterial3D.new()

@onready var _sp : ShapeCast3D = $space/hodl
@onready var _sp_mesh : MeshInstance3D = $space/hodl/MeshInstance3D

var bodies = []

var _FUCKYOU : Dictionary = {}

func _ready():
	if !is_active:
		return

	if _total_using_turns.size() == 0:
		_total_using_turns = [0]
		_total_turns = _total_using_turns.size()
		_total_init_time = Time.get_ticks_msec() + 100
	else:
		_total_init_time = _total_init_time + 100

	if _next_turn >= _total_turns: # reset turn loop
		if _total_turns < _total_turns_max: # we can fill up more turns
			_total_turns += 1
			_total_using_turns.resize(_total_turns) # expensive resizing of array, avoid doing every frame
			_total_using_turns[_total_turns-1] = 0
		else:
			_next_turn = 0

	_turn = _next_turn
	_next_turn += 1

	_total_using_turns[_turn] = _total_using_turns[_turn] + 1

	# print(_total_using_turns.size())
	# print(_total_turns)

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
	
	for i in max_areas:
		var __area : ShapeCast3D = ShapeCast3D.new()
		var __shape : BoxShape3D = BoxShape3D.new()
		__shape.size = Vector3.ONE
		__area.shape = __shape
		__area.collide_with_areas = raycast_collide_with_areas
		__area.collide_with_bodies = raycast_collide_with_bodies
		__area.exclude_parent = raycast_exclude_parent
		__area.margin = 0.01
		__area.target_position = Vector3.ZERO
		add_child(__area)
		_shapecast_array[i] = {"cast": __area, "active": false}

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
	_total_effects = AudioServer.get_bus_effect_count(_audio_bus_idx);
	
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

	if !_begun_octree:
		_begun_octree = true
		# for x in 20:
		# 	for z in 20:
		# 		var obj : RID = RenderingServer.instance_create()
		# 		RenderingServer.instance_set_scenario(obj, get_world_3d().scenario)
		# 		box_mesh.material = box_mat
		# 		RenderingServer.instance_set_base(obj, box_mesh)
		# 		var trns : Transform3D = Transform3D(Basis.IDENTITY, Vector3(float(x), 50.0, float(z)))
		# 		RenderingServer.instance_set_transform(obj, trns)
		# 		bodies.push_back(obj)

		await get_tree().create_timer(5.0).timeout
		call_deferred("create_octree")
		await get_tree().create_timer(0.5).timeout

		box_mesh.size = Vector3.ONE*8.0
		box_mesh_2.size = Vector3.ONE*4.0
		box_mesh_3.size = Vector3.ONE*2.0
		box_mesh_4.size = Vector3.ONE*1.0
		box_mesh_5.size = Vector3.ONE*0.5
		# box_mesh_small.size = Vector3.ONE*4.0
		box_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
		box_mat.albedo_color = Color.AQUA
		box_mat.albedo_color.a = 0.05

		box_mat_filled.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
		box_mat_filled.albedo_color = Color.RED
		box_mat_filled.albedo_color.a = 0.25
		var completed_keys : Array = []

		# var _doohicky : MultiMeshInstance3D = MultiMeshInstance3D.new()
		# var _other_doo : MultiMeshInstance3D = MultiMeshInstance3D.new()
		# _doohicky.multimesh.mesh = box_mesh
		# _other_doo.multimesh.mesh = box_mesh.duplicate()
		# _other_doo.multimesh.mesh.surface_set_material(0, box_mat_filled)


		while creating_octree:
			await get_tree().create_timer(5.0).timeout

			var _keys : Array = _FUCKYOU.keys()
			
			for i in range(completed_keys.size(), _keys.size()):
				var v : Vector3 = _keys[i]
				var k = _FUCKYOU[v]
				if _FUCKYOU[v]["drawn"]:
					continue
				if _FUCKYOU[v]["has_children"]:
					continue
				if !k["filled"]:
					# if !debug_show_free_areas:
					# 	continue
					var obj : RID = RenderingServer.instance_create()
					RenderingServer.instance_set_scenario(obj, get_world_3d().scenario)
					RenderingServer.instance_set_base(obj, box_mesh)
					RenderingServer.instance_set_surface_override_material(obj, 0, box_mat)

					var bs : Basis = Basis.IDENTITY
					bs = bs.scaled(Vector3.ONE / (8.0 / k["size"]))
					var trns : Transform3D = Transform3D(bs, v)
					RenderingServer.instance_set_transform(obj, trns)
					bodies.push_back(obj)
				else:
					pass
					# if !debug_show_filled_areas:
					# 	continue
					#var obj : RID = RenderingServer.instance_create()
					#RenderingServer.instance_set_scenario(obj, get_world_3d().scenario)
					#
					#RenderingServer.instance_set_surface_override_material(obj, 0, box_mat_filled)
					#var bs : Basis = Basis.IDENTITY
					#bs = bs.scaled(Vector3.ONE / (8.0 / k["size"]))
					#var trns : Transform3D = Transform3D(bs, v)
					#RenderingServer.instance_set_transform(obj, trns)
					#bodies.push_back(obj)
				_FUCKYOU[v]["drawn"] = true
			
			completed_keys = _keys

	# await get_tree().create_timer(randf_range(0.8, 1.5)).timeout
	# _connect_to_thing()

func _connect_to_thing():
	DebugCam.thing.connect("testicle", _testicle_receive)

func _testicle_receive():
	print("received testicle. name: ", name)

# Called when the node enters the scene tree for the first time.
# func _ready():
	# for i in num_threads:
	# 	var thread : Thread = Thread.new()
	# 	threads.push_back(thread)
	# var i : int = 0
	# var obj = RenderingServer.instance_create()
	# var scenario : RID = get_world_3d().scenario
	# RenderingServer.instance_set_scenario(obj, scenario)
	# var mat : Material = Material.new()
	# var box_mesh : BoxMesh = BoxMesh.new()
	# box_mesh.material = mat
	# var xform : Transform3D = Transform3D(Basis(), Vector3(float(1), 10.0, float(1)))
	# RenderingServer.instance_set_base(obj, box_mesh)
	# RenderingServer.instance_set_transform(obj, xform)

	# bodies.push_back(obj)

	# lowmesh.transform = xform

	# for x in num:
	# 	for z in num:
			
	# 		var scenario : RID = get_world_3d().scenario
	# 		var box_mesh : BoxMesh = BoxMesh.new()
	# 		var _mesh : RID = RenderingServer.instance_create2(box_mesh, scenario)
	# 		var xform : Transform3D = Transform3D(Basis(), Vector3(float(x), 10.0, float(z))) 
	# 		RenderingServer.instance_set_transform(_mesh, xform)
	# 		RenderingServer.instance_set_visible(_mesh, true)
	# 		# var bot = lowbot.instantiate()
	# 		# bot.going_up = i % 2 == 0
	# 		# bot.process_thread_group_order = i % num_threads + 1
	# 		# add_child(bot)
	# 		# bot.position.x = float(x)
	# 		# bot.position.z = float(z)
	# 		# bot.position.y = 2.0
	# 		bodies.push_back(_mesh)
			# i += 1

# func _exit_tree():
# 	for i in bodies.size():
# 		RenderingServer.free_rid(bodies[i])

var _size_stuff : Array = [
		Vector3(-1, -1, -1), Vector3(-1, -1, 1), Vector3(1, -1, 1),
		Vector3(1, -1, -1), Vector3(-1, 1, -1), Vector3(-1, 1, 1), 
		Vector3(1, 1, 1), Vector3(1, 1, -1)
	]

var perma_sound_stuff : Dictionary = {}

func create_octree():
	print("sup bruh")
	var chunk_size : Vector3 = Vector3.ONE*20
	var chunk_offset : Vector3 = Vector3.ZERO

	var _main_scene : Node3D = get_tree().current_scene as Node3D
	var _bx : AABB = SpatialAudioPlayer3D.get_node_aabb(get_tree().current_scene as Node3D, true, get_parent().global_transform)
	print(_main_scene.global_position)
	var _bx_origin : Vector3 = _bx.position + _main_scene.global_position
	var _bx_size : Vector3 = _bx.size

	perma_sound_stuff.bx = _bx

	var oct_settings : Dictionary = {}
	oct_settings._slice = 0
	oct_settings._max_slices = _size_stuff.size()
	oct_settings._oct_mult = 8.0
	oct_settings._max_sweep_size = Vector3.ONE*oct_settings._oct_mult
	oct_settings._deleg_size = 2.0 # how much to divide sweep size by each pass. this shouldnt ever change
	oct_settings._max_delegs = 4 # only go down 1 reduction, end on vector3(0.5, 0.5, 0.5)
	oct_settings.current_deleg = 0
	# oct_settings._starting_pos = _bx_origin
	oct_settings._x_bound = snappedf(_bx_origin.x+_bx_size.x+oct_settings._oct_mult, oct_settings._oct_mult)
	oct_settings._y_bound = snappedf(_bx_origin.y+_bx_size.y+oct_settings._oct_mult, oct_settings._oct_mult)
	oct_settings._z_bound = snappedf(_bx_origin.z+_bx_size.z+oct_settings._oct_mult, oct_settings._oct_mult)
	oct_settings._end_region = _bx_origin + _bx_size
	oct_settings._x_thing = snappedf(_bx_origin.x-oct_settings._oct_mult, oct_settings._oct_mult)
	oct_settings._y_thing = snappedf(_bx_origin.y-oct_settings._oct_mult, oct_settings._oct_mult)
	oct_settings._z_thing = snappedf(_bx_origin.z-oct_settings._oct_mult, oct_settings._oct_mult)
	oct_settings._starting_pos = snapped(_bx_origin - Vector3.ONE*oct_settings._oct_mult, oct_settings._max_sweep_size)
	oct_settings._oct_sweeping = true

	perma_sound_stuff.def_oct_settings = oct_settings.duplicate()
	perma_sound_stuff.start = snapped(_bx_origin, oct_settings._max_sweep_size)
	perma_sound_stuff.end = snapped(_bx_origin + _bx_size, oct_settings._max_sweep_size)
	
	var _in_creation := true
	# var _end_region : Vector3 = Vector3(_x_bound, _y_bound, _z_bound)
	_sp.visible = true
	# not using below
	# var _oct_tracker : Array[int] = []
	# _oct_tracker.resize(_max_delegs)

	_sp.global_position = oct_settings._starting_pos
	print(oct_settings._starting_pos, "   ", oct_settings._end_region)
	while _in_creation:
		creating_octree = true
		# chunk stuff...
		# enter chunk

		# go along x to max bound, then go up y, then after at max y bound, go z and repeat...
		
		# start z
		# go towards z bound at a rate of 2
		while oct_settings._z_thing <= oct_settings._z_bound:
			while oct_settings._y_thing <= oct_settings._y_bound:
				while oct_settings._x_thing <= oct_settings._x_bound:
					await get_tree().create_timer(sweep_time).timeout
					# do thing here...
					# check entire area. like, 1x1x1 space or smth
					# if no collision, move to next 1x1x1 area...
					# if collision, check 0.5x0.5x0.5 area in 1x1x1 area (8 areas)
					oct_settings._oct_sweeping = true
					oct_settings.current_deleg = 0
					oct_settings._slice = 0
					oct_sweep_test(oct_settings, 0)
					oct_settings._x_thing += oct_settings._oct_mult
				pass
				oct_settings._x_thing = snappedf(_bx_origin.x-oct_settings._oct_mult, oct_settings._oct_mult)
				oct_settings._y_thing += oct_settings._oct_mult
			pass
			oct_settings._y_thing = snappedf(_bx_origin.y-oct_settings._oct_mult, oct_settings._oct_mult)
			oct_settings._x_thing = snappedf(_bx_origin.x-oct_settings._oct_mult, oct_settings._oct_mult)
			oct_settings._z_thing += oct_settings._oct_mult
		break
	creating_octree = false
	pass

# need to know the up, down, and sides connected to EACH node
# how to do without breaking every-fucking-thing>
# a second pass perhamp?
# another loop perhapsth?

var print_first_time : bool = true

func oct_sweep_test(oct_settings : Dictionary, _shapecast : int = 0, _parent_oct : Vector3 = Vector3.ZERO):
	# for doing the testicles
	var _sweeping : bool = true
	while _shapecast_array[_shapecast].active:
		await get_tree().physics_frame
		_shapecast = _shapecast + 1 if _shapecast + 1 >= _shapecast_array.keys().size() else 0
	_shapecast_array[_shapecast].active = true
	var _cast : ShapeCast3D = _shapecast_array[_shapecast].cast
	# print("HERE YA GO BOSS ", oct_settings.current_deleg)
	while _sweeping:
		if !creating_octree:
			return
		oct_settings._starting_pos = Vector3(oct_settings._x_thing, oct_settings._y_thing, oct_settings._z_thing)
		if print_first_time:
			print(oct_settings._starting_pos)
			print_first_time = false
		var _i_start_pos : Vector3i = Vector3i(int(oct_settings._x_thing), int(oct_settings._y_thing), int(oct_settings._z_thing))
		if oct_settings.current_deleg == 0:
			# have not gone down. 1x1x1
			oct_settings._sweep_size = oct_settings._max_sweep_size
			_cast.shape.size = oct_settings._sweep_size
			_cast.global_position = oct_settings._starting_pos

			_cast.force_shapecast_update()
			# _FUCKYOU[oct_settings._starting_pos] = {"connecting": [], "filled": false, "drawn": false, "size": oct_settings._oct_mult, "has_children": false}
			if !_cast.is_colliding():
				# no collision hit. write nothing to this square
				_FUCKYOU[oct_settings._starting_pos] = {"connecting": [], "filled": false, "drawn": false, "size": oct_settings._oct_mult, "has_children": false}
				_FUCKYOU[oct_settings._starting_pos]["filled"] = false
				_sweeping = false
				_shapecast_array[_shapecast].active = false
				# print("nothing found. moving on")
			else:
				# _FUCKYOU[oct_settings._starting_pos]["filled"] = true
				_parent_oct = oct_settings._starting_pos
				var _next_oct_settings : Dictionary = oct_settings.duplicate()
				if _next_oct_settings.current_deleg < _next_oct_settings._max_delegs:
					_next_oct_settings.current_deleg = mini(oct_settings.current_deleg + 1, oct_settings._max_delegs)
					# _FUCKYOU[oct_settings._starting_pos]["has_children"] = true
					# print("bravo six going dark")
					var _next_shapecast = _shapecast + 1 if _shapecast + 1 >= _shapecast_array.keys().size() else 0
					_shapecast_array[_shapecast].active = false
					while _shapecast_array[_next_shapecast].active:
						await get_tree().physics_frame
						_next_shapecast = _next_shapecast + 1 if _next_shapecast + 1 >= _shapecast_array.keys().size() else 0
					oct_sweep_test(_next_oct_settings, _next_shapecast, _parent_oct)
					_sweeping = false
					
			# print("first return")
			_shapecast_array[_shapecast].active = false
			break
			
		else:
			var _deleg_mult : float = (oct_settings._deleg_size ** oct_settings.current_deleg)

			var _slice_seg : Vector3 = ((_size_stuff[oct_settings._slice]/2) * 
			(oct_settings._oct_mult/_deleg_mult))

			oct_settings._sweep_size = oct_settings._max_sweep_size / _deleg_mult
			_cast.shape.size = oct_settings._sweep_size
			_cast.global_position = _parent_oct + _slice_seg
			var _n_start_pos = _parent_oct + _slice_seg

			_cast.force_shapecast_update()
			# we will optimize by only creating the dict entry when we detect a non-collision.
			# that should cut the size down by at least a quarter
			# (the entry is out here for debugging purposes)
			# _FUCKYOU[_n_start_pos] = {"parent": _parent_oct, "connecting": [], "filled": false, "drawn": false, "size": (oct_settings._oct_mult/_deleg_mult), "has_children": false}
			if !_cast.is_colliding():
				# no collision hit. write nothing to this square.
				# move on to next square
				_FUCKYOU[_n_start_pos] = {
				"parent": _parent_oct, 
				"connecting": [], 
				"filled": false, 
				"drawn": false, 
				"level": oct_settings.current_deleg,
				"size": (oct_settings._oct_mult/_deleg_mult), 
				"has_children": false}

				_FUCKYOU[_n_start_pos]["filled"] = false
				var _next_shapecast = _shapecast + 1 if _shapecast + 1 >= _shapecast_array.keys().size() else 0
				_shapecast_array[_shapecast].active = false
				while _shapecast_array[_next_shapecast].active:
					await get_tree().physics_frame
					_next_shapecast = _next_shapecast + 1 if _next_shapecast + 1 >= _shapecast_array.keys().size() else 0
				oct_settings._slice = oct_settings._slice + 1 if oct_settings._slice + 1 < oct_settings._max_slices else 0
				# print("nothing found further down. moving on baws")
			else:
				# _FUCKYOU[_n_start_pos]["filled"] = true
				oct_settings._slice = oct_settings._slice + 1 if oct_settings._slice + 1 < oct_settings._max_slices else 0
				var _next_oct_settings : Dictionary = oct_settings.duplicate()
				_shapecast_array[_shapecast].active = false
				if oct_settings.current_deleg < oct_settings._max_delegs:
					var _next_shapecast = _shapecast + 1 if _shapecast + 1 >= _shapecast_array.keys().size() else 0
					while _shapecast_array[_next_shapecast].active:
						await get_tree().physics_frame
						_next_shapecast = _next_shapecast + 1 if _next_shapecast + 1 >= _shapecast_array.keys().size() else 0
					_next_oct_settings.current_deleg = mini(oct_settings.current_deleg + 1, oct_settings._max_delegs)
					_next_oct_settings._slice = 0 # RESET SLICES BEFORE GOING ON TO NEXT YOU FUCKING IDIOT
					# _FUCKYOU[_n_start_pos]["has_children"] = true
					# print("going further down, wish me luck")
					oct_sweep_test(_next_oct_settings, _next_shapecast, _n_start_pos)
			
			_shapecast_array[_shapecast].active = false
			if oct_settings._slice == 0: # we looped through all of em boss
				# print("we looped through em all boss")
				_sweeping = false
				break
	pass


func oct_connect_test():
	# how do dis?
	# start at top of dict list, get dirs of octree
	# while do thing
	# get next oct (always unfilled)
	# get surrounding octs (take _size_stuff and mult it by size again)
	# i guess... we just check boxes huh?
	var in_loop := true

	# var starting_pos : Vector3 = 

	# while in_loop:

	# 	pass

	pass


# determines if this spatial audio player should be pooled to a nearby audio bus.
# this can be called initially when you are creating multiple audio players in the same area
func optimize_audiobus():

	# if nearby audio players:
		# _assign_audiobus()
	# else if no nearby audio players:
		# _create_audiobus
	pass

# creates a new audio bus for this spatial audio player.
func _create_audiobus():
	
	pass

# finds an existing audio bus from nearby spatial audio players and routes audio through them.
func _assign_audiobus():
	
	pass

# takes the raycast and places it in a certain predefined orientation
# 5 cycles on x axis;
# 9 cycles on y axis.
# 45 total cycles.
var _cycle_x : int = 0
var _cycle_y : int = 0
var _full_cycle : bool = false
var _bounce_set : int = 0
var __time : int = 0
var rs = RenderingServer
var _scenario : RID
var __result : PackedInt64Array
var _first_mesh : MeshInstance3D = null
# print("TIME TO INTERSECT GEOMETRY ", Time.get_ticks_usec() - ___time)
# ___time = Time.get_ticks_usec()
# print(instance_from_id(__result[0]).name)
# print("TIME TO GET NODE FROM ID USING FUNCTION ", Time.get_ticks_usec() - ___time)

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
			if _debug_use:
				_debug_usec_avg += Time.get_ticks_usec() - __time
				_debug_total_checks += 1
		else:
			_bounce_set = 0
			raycast.position = Vector3.ZERO
			if _debug_use:
				_debug_usec_avg += Time.get_ticks_usec() - __time
				_debug_total_checks += 1
			if _debug_use:
				__time = Time.get_ticks_usec()
			# __result = rs.instances_cull_ray(raycast.global_position, to_global(raycast.target_position), _scenario)
			# if !__result.is_empty():
			# 	_first_mesh = instance_from_id(__result[0])
			if _debug_use:
				_debug_usec_mesh_avg += Time.get_ticks_usec() - __time
			return
		_bounce_set += 1
		if _debug_use:
			_debug_usec_avg += Time.get_ticks_usec() - __time
			_debug_total_checks += 1
		
		if _debug_use:
			__time = Time.get_ticks_usec()
		# __result = rs.instances_cull_ray(raycast.global_position, to_global(raycast.target_position), _scenario)
		# if !__result.is_empty():
		# 	_first_mesh = instance_from_id(__result[0])
		if _debug_use:
			_debug_usec_mesh_avg += Time.get_ticks_usec() - __time

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
	
	if _debug_use:
		__time = Time.get_ticks_usec()
	# __result = rs.instances_cull_ray(raycast.global_position, to_global(raycast.target_position), _scenario)
	# if !__result.is_empty():
	# 	_first_mesh = instance_from_id(__result[0])
	if _debug_use:
		_debug_usec_mesh_avg += Time.get_ticks_usec() - __time

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

var _raycast_keys : Dictionary = {"distance": -1.0, "material": null}

func _on_update_raycast_distance(raycast: RayCast3D, raycast_index: int):
	# randomise_raycast_direction(raycast)
	# print("Current Frame: ", Engine.get_process_frames(), " This: ", name)
	if raycast_index == 0:
		retrieve_raycast_hits(raycast)
		return
	var colliding : bool = raycast.is_colliding()
	# dictionaries are fine i suppose
	if colliding:
		_raycast_keys = {"distance": -1.0, "material": null} # i dont want to use dictionaries
		var _iterator : int = 0
		var collider : CollisionObject3D = raycast.get_collider()

		_raycast_keys["distance"] = self.global_position.distance_to(raycast.get_collision_point());
		if (collider is StaticBody3D and
			collider.physics_material_override and
			collider.physics_material_override is ExpandedPhysicsMaterial):
			_raycast_keys["material"] = collider.physics_material_override
		_total_distance_checks.append(_raycast_keys);
	else:
		_total_distance_checks.append({});
	
	if raycast_index > 0:
		cycle_raycast_direction(raycast)

func _on_check_spatial_camera(player: Node3D):
	if _effect_functions.is_empty():
		_effect_functions.append(Callable(_on_update_reverb));
		_effect_functions.append(Callable(_on_update_stereo));
		_effect_functions.append(Callable(_on_update_lowpass_filter));

		_total_effects = _effect_functions.size()
	
	_effect_functions[_current_effect_processed].call(player);

	# _on_update_reverb(player);
	# _on_update_stereo(player);
	# _on_update_lowpass_filter(player);

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
	if _effect_functions.is_empty():
		_effect_functions.append(Callable(_on_update_reverb));
		_effect_functions.append(Callable(_on_update_stereo));
		_effect_functions.append(Callable(_on_update_lowpass_filter));

		_total_effects = _effect_functions.size()
	
	_effect_functions[_current_effect_processed].call(player);

func _on_update_reverb(player: Node3D):
	if !_reverb_effect:
		return
	var room_size : float = 0.0
	var wetness : float = 0.0
	var damping : float = 0.0
	var resonance : float = 0.0
	var spread : float = 1.0
	var largest_ray_distance : float = 0.0
	var average_ray_distance : float = 0.0
	var reflectionTime : float = 0.0
	var reflectionFeedback : float = 0.4
	var _total_raycasts_allowed : int = 45 + (45 * max_raycast_bounces)
	for i in _total_raycasts_allowed:

		var dist : Dictionary
		if i < _total_distance_checks.size():
			dist = _total_distance_checks[i]
		if dist.is_empty():
		# 	reflectionTime += (max_raycast_distance * 343 * 0.001) # raycast result doesnt exist, nothing was hit, give the big echo.
		# 	# largest_ray_distance = max_raycast_distance
		# 	average_ray_distance += 1.0
			continue
		if dist["material"]:
			# damping += dist["material"].damping
			wetness += dist["material"].reflection
			resonance += dist["material"].transmission_loss
		else:
			# damping += 0.5
			wetness += 0.1
		# Getting how long for reflections.
		if dist["distance"] >= 0:
			if dist["distance"] > largest_ray_distance:
				largest_ray_distance = dist["distance"]
			average_ray_distance += dist["distance"]
			reflectionTime += ((dist["distance"] / 343.0) * 1000.0) * 2.0 # round-trip time
			room_size += (dist["distance"] / max_raycast_distance / 6.0) / float(_total_raycasts_allowed)
			# arbitrary value of 6.0 because of hall effect
			# no clue what the hall effect is lol that should tell you how qualified i am  
	average_ray_distance = average_ray_distance / _total_distance_checks.size()
	resonance = resonance / float(_total_distance_checks.size())
	room_size = (room_size / float(_total_distance_checks.size())) / largest_ray_distance
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
		_target_lowpass_resonance = resonance;
		_target_reverb_spread = spread;
		_target_reverb_room_size = room_size;
		_target_reverb_damping = room_size/_total_distance_checks.size()
		_target_reverb_reflection_time = reflectionTime/_total_distance_checks.size()
		_target_reverb_reflection_feedback = reflectionFeedback
	else:
		_target_reverb_wetness = 0.0;
		_target_reverb_spread = 0.0;
		_target_lowpass_resonance = 0.0;
		_target_reverb_room_size = 0.0;
		_target_reverb_damping = 0.5;
		_target_reverb_reflection_time = 0.0
		_target_reverb_reflection_feedback = 0.4
	
	_finished_ready = true

func _on_update_stereo(player: Node3D):
	if !_stereo_effect:
		return
	var _stereo_dist_player : float = _dist_to_player
	# if _debug_use:
	# 	print(_stereo_dist_player)
	if max_stereo_distance == 0:
		_target_stereo_pan_pullout = 0.3
	else:
		# if _debug_use:
		# 	if _target_reverb_room_size > _target_reverb_spread:
		# 		print("room size bigger ", _target_reverb_room_size, "  ", _target_reverb_spread)
		# 	else:
		# 		print("spread bigger ", _target_reverb_room_size, "  ", _target_reverb_spread)
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
	# if _debug_use:
	# 	print("bands ", bandReductions, "  ", total)
	# 	print("volume ", volume_db)

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
	_lowpass_filter.resonance = lerp(_lowpass_filter.resonance, _target_lowpass_resonance, delta*3.0);
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
var player_camera = null
var __rays_used_this_frame : int = 0

var max_sweep_size : Vector3 = Vector3(2, 2, 2)
var min_sweep_size : Vector3 = Vector3(0.5, 0.5, 0.5)
var max_cell_distance : float = 8.0

var created_aabb : bool = false

func _physics_process(delta):
	if !is_active:
		return
	if get_world_3d() != null && _scenario == null:
		_scenario = get_world_3d().scenario
	_last_update_time += delta
	_loop_rotation(delta)

	if _total_init_time < Time.get_ticks_msec() && !_finished_init:
		if (_total_turns < _total_turns_max):
			_next_turn = 0
		_finished_init = true
		# if !_begun_octree && name == "crook":
		# 	call_deferred("create_octree")
		# 	_begun_octree = true
		# _next_turn = 0
	# if name == "blop2" && _finished_init:
	# 	print(_next_turn, "   ", _turn)

	var _this_update_time : float = 0.0
	if _has_moved:
		_this_update_time = update_frequency_seconds
	else:
		_this_update_time = _sleep_update_frequency_seconds
	
	if _next_turn == _turn && _total_using_turns[_turn] == _total_turns_taken && !_update_distances:
		_total_turns_taken = 0
		_next_turn += 1
		if _next_turn >= _total_turns:
			_next_turn = 0
	
	# if name == "crook":
		# print("hoohoo ", _full_cycle, "  ", _update_distances, "  ", _total_distance_checks.size())
	if !_full_cycle || _update_distances:
		# if (_full_cycle) && _total_distance_checks.size() > 45 + (45 * max_raycast_bounces):
		# 	print(name, "  Total rays: ", raycast_count, ", Max bounces per ray: ", max_raycast_bounces, ", total avg time: ", max(1, _debug_usec_avg) / max(1, _debug_total_checks), " microseconds")
		# 	_debug_usec_avg = 0
		# 	_debug_total_checks = 0
		if _just_used_params:
			_do_sweeping = can_sweep
			_just_used_params = false
			_total_distance_checks = []
			if _debug_use:
				# if !created_aabb:
				# 	created_aabb = true
				# 	print(SpatialAudioPlayer3D.get_node_aabb(get_parent() as Node3D, true, get_parent().global_transform))
				print(name, 
				"  Total rays: ", raycast_count, ", Max bounces per ray: ", max_raycast_bounces, 
				", total physics ray avg time: ", max(1, _debug_usec_avg) / max(1, _debug_total_checks), " microseconds",
				", total mesh ray avg time: ", max(1, _debug_usec_mesh_avg) / max(1, _debug_total_checks), " microseconds"
				)
				# var _planes_thing : PackedVector3Array = _first_mesh.mesh.get_faces()
				# # print(_planes_thing)
				# var __planes : Array[Plane] = []
				# var __i : int = 0
				# var __v : Array = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
				# var __vert : int = 0
				# while __i < _planes_thing.size():
				# 	if __vert == 3:
				# 		__planes.append(Plane(__v[0], __v[1], __v[2]))
				# 		__vert = 0
				# 	__v[__vert] = _planes_thing[__i]
				# 	__vert += 1
					
				# 	__i += 1
				
				# print(__planes)
				# for i : Vector3 in _planes_thing:
				# 	__planes.append(Plane(i.x, i.y, i.z))
				_debug_usec_avg = 0
				_debug_usec_mesh_avg = 0
				_debug_total_checks = 0
		elif _update_distances:
			if _current_raycast_index >= _raycast_array.size():
				_current_raycast_index = 0
			while __rays_used_this_frame < __max_rays_per_frame:
				if _current_raycast_index >= _raycast_array.size():
					_current_raycast_index = 0
				_on_update_raycast_distance(_raycast_array[_current_raycast_index], _current_raycast_index);
				__rays_used_this_frame += 1
				if _current_raycast_index == 0:
					_current_raycast_index += 1
					continue
				if _bounce_set == 0:
					_current_raycast_index += 1
				if _full_cycle:
					_bounce_set = 0
					_update_distances = false
					break
			__rays_used_this_frame = 0
			
			
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

	if _last_update_time > _this_update_time && _next_turn == _turn:
		# if name == "crook":
		# 	var ___time : int = Time.get_ticks_usec()
		# 	var rs = RenderingServer
		# 	var _scenario = get_world_3d().scenario
		# 	var __result : PackedInt64Array = rs.instances_cull_ray(position, position + Vector3(20.0, 0.0, 0.0), _scenario)
		# 	print("TIME TO INTERSECT GEOMETRY ", Time.get_ticks_usec() - ___time)
		# 	___time = Time.get_ticks_usec()
		# 	print(instance_from_id(__result[0]).name)
		# 	print("TIME TO GET NODE FROM ID USING FUNCTION ", Time.get_ticks_usec() - ___time)

		
		if player_camera:
			_player_position = player_camera.global_position
			if !_just_used_params && _full_cycle:
				if player_camera is SpatialAudioCamera3D:
					_on_check_spatial_camera(player_camera);
				else:
					_on_update_spatial_audio(player_camera);
				
				_current_effect_processed += 1
				if _current_effect_processed >= _total_effects:
					_just_used_params = true
					_current_effect_processed = 0
					_update_distances = true
					_last_update_time = 0.0

					_total_turns_taken += 1
		else:
			player_camera = get_viewport().get_camera_3d()
		
		if _previous_position == global_position:
			_has_moved = false
		if _previous_position != global_position:
			_has_moved = true
		_previous_position = global_position
	
	_lerp_parameters(delta)
	
	if _do_sweeping:
		_fuckyou += delta
	if _do_sweeping && _waiter <= _fuckyou:
		_fuckyou = 0.0
		# print(_sweep_h_pos, "   ", _sweep_v_pos)
		if _sweep_v:
			_sweeper.position.y = (sweep_cell * _sweep_v_pos)
			_sweep_v_pos += 1
			if _sweep_v_pos >= sweep_max:
				_sweep_v_pos = -sweep_max
				_sweep_v = false
				_sweep_h = true
				if _sweep_h_pos >= sweep_max:
					_sweep_h_pos = -sweep_max
					_sweep_h = false
		elif _sweep_h:
			_sweeper.position.x = (sweep_cell * _sweep_h_pos)
			_sweep_h_pos += 1
			_sweep_v = true
			_sweep_h = false
			return
		elif !_sweep_h && !_sweep_v:
			$space.look_at(_player_position)
			_sweep_v_pos = -sweep_max
			_sweep_h_pos = -sweep_max
			_sweeper.position.x = (sweep_cell * _sweep_h_pos)
			_sweeper.position.y = (sweep_cell * _sweep_v_pos)
			_sweeper.position.z -= (sweep_cell)
			_sweep_v = true
		# if !_sweeper.has_overlapping_bodies() && !_sweeper.has_overlapping_areas():
		# 	var __d : Dictionary = {"position": _sweeper.position, "edges": {}}
		# 	_graph[_sweep_id] = __d
		# 	_sweep_id += 1
		# print(_sweeper.get_overlapping_bodies().size())
		var __d : Dictionary = {"bad": _sweeper.is_colliding(), "position": _sweeper.position, "edges": {}}
		_graph[_sweep_id] = __d
		_sweep_id += 1
		# print(_player_position.distance_squared_to(_sweeper.global_position))
		if _player_position.distance_squared_to(_sweeper.global_position) < sweep_cell:
			can_sweep = false
			# print(_graph.keys().size())
			# print(_graph)
			for i in $space/spots.get_child_count():
				if _graph.keys().size() <= i:
					break
				$space/spots.get_child(i).position = _graph[i].position
				$space/spots.get_child(i).set_surface_override_material(0, $space/spots.get_child(i).get_active_material(0).duplicate())
				# print(_graph[i].good)
				if _graph[i].bad:
					$space/spots.get_child(i).get_surface_override_material(0).albedo_color.r = 1.0
					$space/spots.get_child(i).get_surface_override_material(0).albedo_color.a = 1.0
				
			_sweeper.position.z = 0.0

@onready var _sweeper : ShapeCast3D = $space/hodl
var _waiter : float = 0.0
var _fuckyou : float = 0.0
var _do_sweeping : bool = false
var _sweep_v : bool = false
var _sweep_h : bool = false
var _sweep_v_pos : int = -3
var _sweep_h_pos : int = -3
var _sweep_id : int = 0

# graph implementation
# dictionary
# total number of nodes?
# node id, global position, edges : {node id, distance}
var _graph : Dictionary = {}

func _loop_rotation(delta):
	$cone.rotation.y += delta

	if $cone.rotation_degrees.y >= 360:
		$cone.rotation.y = 0.0


func _on_hodl_body_entered(body:Node3D):
	# if _graph.find_key(_sweep_id):
	# 	_graph[_sweep_id].bad = true
	print("howdy")
	pass # Replace with function body.


## static functions

# this is a boiled down version of Node3DEditorViewport::_calculate_spatial_bounds. Gets the total AABB of a node. Recursive.
static func get_node_aabb(thing : Node3D = null, ignore_top_level : bool = false, bounds_transform : Transform3D = Transform3D()) -> AABB:
	var box : AABB
	var transform : Transform3D
	var __thing
	#need to check if we are all the way up in the hierarchy
	
	# if thing.name == "Main":
	# 	print(bounds_transform.origin)
	# we are going down the child chain, need to get each transform as necessary
	if bounds_transform.is_equal_approx(Transform3D()):
		transform = thing.global_transform
	else:
		transform = bounds_transform
	
	# no more nodes. return default aabb
	if thing == null:
		return AABB(Vector3(-0.2, -0.2, -0.2), Vector3(0.4, 0.4, 0.4))
	
	var top_xform : Transform3D = transform.affine_inverse() * thing.global_transform

	# convert the node into visualinstance3D to have get_aabb() function. very sus
	var visual_result : VisualInstance3D = thing as VisualInstance3D
	if visual_result != null:
		box = visual_result.get_aabb()
	else:
		box = AABB()
	
	# xforms the transform with the box aabb
	box = top_xform * box
	
	for i : int in thing.get_child_count():
		var child : Node3D = thing.get_child(i) as Node3D
		if child && !(ignore_top_level && child.top_level):
			var child_box : AABB = SpatialAudioPlayer3D.get_node_aabb(child, ignore_top_level, transform)
			box = box.merge(child_box)
	
	return box

# 
static func build_scene_space():

	pass
