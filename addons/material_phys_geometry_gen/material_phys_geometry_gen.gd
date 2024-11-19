@tool
extends Node

# gets all of the surfaces of a MeshInstance3D and generates a collision shape for each one.
# collision shapes get auto-attached to a generated StaticBody3D by default.

# place this node under a MeshInstance and press 'generate collisions'.

@export var generate_collisions : bool = false : 
	set(v):
		_generate_collisions()
		generate_collisions = false

@export var reset_collisions : bool = false : 
	set(v):
		_reset_collisions()
		reset_collisions = false

@export var collisions_generated : bool = false : 
	get():
		return collisions_generated

var gen_mesh : MeshInstance3D
@export var col : PhysicsBody3D

var arr_mesh : ArrayMesh
var new_mesh : MeshInstance3D

var mdt : MeshDataTool

var generate_single_trimesh : bool = false

func _generate_collisions():
	var _t : int = Time.get_ticks_msec()
	gen_mesh = get_parent() if get_parent() is MeshInstance3D else null

	if gen_mesh == null:
		print("Generation failed. Parent is not a MeshInstance3D.")
		return

	var _mesh : Mesh = gen_mesh.mesh
	var _sfc : int = _mesh.get_surface_count()

	if _sfc == 1:
		print("Only 1 surface on this mesh! Generating a normal trimesh.")
		generate_single_trimesh = true
	else:
		print(_sfc, " surfaces detected. Generating trimesh collisions...")
		generate_single_trimesh = false
	
	var _surface : PackedVector3Array
	var _sf_array : Array
	var _shapes : Array = []

	col = StaticBody3D.new()
	gen_mesh.add_child(col)
	col.set_owner(get_tree().get_edited_scene_root())

	# new_mesh = MeshInstance3D.new()
	# gen_mesh.add_child(new_mesh)
	# new_mesh.set_owner(get_tree().get_edited_scene_root())

	for i in _sfc:
		mdt = MeshDataTool.new()
		mdt.create_from_surface(_mesh, i)
		_surface.clear()
		for k in mdt.get_face_count():
			for x in 3:
				_surface.push_back(mdt.get_vertex(mdt.get_face_vertex(k, x)))
		mdt.clear()
		
		var _colshape : CollisionShape3D = CollisionShape3D.new()
		_colshape.shape = ConcavePolygonShape3D.new()
		_colshape.shape.set_faces(_surface)
		col.add_child(_colshape)
		_colshape.set_owner(get_tree().get_edited_scene_root())

	# new_mesh.mesh = arr_mesh

	


	collisions_generated = true
	print("wee")
	print("total time taken: ", Time.get_ticks_msec() - _t, " mSec")
	pass

func _reset_collisions():
	if col == null:
		print("No collisions detected. Please generate collisions first.")
		return
	
	col.queue_free()
	collisions_generated = false
	print("woo")
	pass