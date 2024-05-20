@tool
extends AudioStreamPlayer3D
class_name SpatialStreamPlayer3D

@export var moving = false
@export var persistent = true

# really, this should be calculated.
@export var outsideness : float = 1.0 : set = set_outsideness
func set_outsideness(value):
	# some logic goes here to filter
	outsideness = value

@export var max_buses = 4
var materials = []
@export_range(0.1,100,0.1) var loudness_factor = 10.0

# shape settings
@export_range(0.1,10000.0,0.1) var max_radius : float = 1.0 : set = set_radius
var area = Area3D.new()
var collision = CollisionShape3D.new()
var shape = SphereShape3D.new()

#debug settings
@export var show_debug_mesh = true
var debug_mesh = MeshInstance3D.new()
var debug_sphere = SphereMesh.new()
var debug_material = StandardMaterial3D.new()

func set_radius(value):
	shape.radius = value
	max_distance = value
	max_radius = value
	debug_sphere.radius = value
	debug_sphere.height = value*2
func _init():
	max_db = 0

func _enter_tree():
	collision.shape = shape
	area.add_child(collision)
	
	area.connect("body_entered", inspect_material)
	add_child(area)
	
	debug_material.albedo_color = Color.PINK - Color(0,0,0,0.8)

	debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	debug_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_sphere.material = debug_material
	debug_sphere.radius = max_radius
	debug_sphere.height = max_radius*2
	debug_mesh.mesh = debug_sphere
	debug_mesh.transparency = 0.8
	add_child(debug_mesh)
	
var source_audio = []
func  _ready():
	for player in max_buses:
		var new_player = AudioStreamPlayer3D.new()
		new_player.max_distance = max_radius
		new_player.stream = stream
		new_player.autoplay = false
		new_player.volume_db = linear_to_db( db_to_linear(0)/(max_buses*max_buses))
		new_player.max_db = -3
		new_player.unit_size = max_radius * loudness_factor
		new_player.pitch_scale = pitch_scale
		new_player.attenuation_filter_db = 0
		# var test = Mixer.buses.size()
		# Mixer.insert_bus(test)
		# Mixer.buses[test].spatial = true
		#AudioServer.add_bus_effect(test, AudioEffectDelay.new())
		source_audio.append(new_player)
		add_child(new_player,true)
		# AudioServer.set_bus_name(test, new_player.name)
		# Mixer.buses[test].rename_bus(new_player.name)
		# AudioServer.set_bus_send(test, "sfx")
		new_player.bus = new_player.name
	play_audio_in_buses()

func play_audio_in_buses():
	AudioServer.lock()
	for source in source_audio:
		source.play()
	AudioServer.unlock()
	
	
func inspect_material(body):
	if body is StaticBody3D:
		print(body)
		if body.physics_material_override is ExpandedPhysicsMaterial:
			var material = body.physics_material_override
			material.source_position = position
			materials.append(material)
			print(material)