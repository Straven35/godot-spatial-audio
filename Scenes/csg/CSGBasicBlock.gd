@tool
extends StaticBody3D
class_name CSGBasicBlock

@export var size : Vector3 = Vector3.ONE
@export var material : Material
@export var physics_material : ExpandedPhysicsMaterial

@onready var collision = get_child(0)
@onready var mesh : MeshInstance3D = get_child(1)

var _collision : CollisionShape3D
var _mesh : MeshInstance3D
var _col_shape : BoxShape3D
var _mesh_shape : BoxMesh

var _update_time : float = 0.0
var _update_interval : float = 1.0
var _changes_detected : bool = true

func _ready():
	if Engine.is_editor_hint:
		if get_child_count() > 0:
			for i in get_children():
				i.queue_free()
	_col_shape = BoxShape3D.new()
	_mesh_shape = BoxMesh.new()
	_collision = CollisionShape3D.new()
	_mesh = MeshInstance3D.new()
	_collision.shape = _col_shape
	_mesh.mesh = _mesh_shape
	add_child(_collision)
	add_child(_mesh)

func _physics_process(_delta):
	if Engine.is_editor_hint:
		_update_time += _delta
		if _update_time >= _update_interval:
			if _update_interval > 16.0:
				_update_time = 0.0
				_update_interval = 1.0
				return
			_changes_detected = _collision.shape.size != size
			if _changes_detected:
				set_stuff()
				_changes_detected = false
				_update_interval = 1.0
			else:
				_update_interval += _update_interval
			_update_time = 0.0

# var _planes : Array[Plane] = []

func set_stuff():
	_collision.shape.size = size
	_mesh.mesh.size = size
	physics_material_override = physics_material
	_mesh.set_surface_override_material(0, material)
	# var _shape_data : Vector3 = PhysicsServer3D.shape_get_data(_collision.shape.get_rid())
	# _planes = Geometry3D.build_box_planes(_shape_data)

	# print(PhysicsServer3D.shape_get_data(_collision.shape.get_rid()))
