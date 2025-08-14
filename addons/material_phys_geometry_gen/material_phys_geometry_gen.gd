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


@export var default_material_mapper : String = 'res://addons/gd_spatial_audio/ExpandedPhysicsMaterials/ExpandedPhysicsMaterialMapper.tres'
@export var default_material_res : String = "res://Materials/"
@export var default_phys_material : String = 'res://addons/gd_spatial_audio/ExpandedPhysicsMaterials/Materials/Concrete.tres'

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

	var _materials : Dictionary = {}

	# build list of materials from file
	# (file_name: Material)
	# check list against material map (map.file_name coincides with material.file_name)
	
	if !default_material_res.is_empty():
		var _da : DirAccess = DirAccess.open(default_material_res)
		if _da == null:
			print("fuck")
		else:
			var _mat_res : Array = _da.get_files()
			
			if !_mat_res.is_empty():
				for i in _mat_res:
					if i.ends_with(".tres"):
						var _mat : Material = load(default_material_res + i)
						_materials[i.trim_suffix(".tres")] = _mat
	
	for i in _sfc:
		mdt = MeshDataTool.new()
		var _mesh_mat : Material = gen_mesh.get_surface_override_material(i)
		if _mesh_mat == null:
			_mesh_mat = _mesh.surface_get_material(i)
		var _mat_found : bool = false
		var _mat_key : String
		for m in _materials:
			print(_materials[m])
			print(_mesh_mat)
			if _materials[m] != _mesh_mat:
				continue
			_mat_found = true
			_mat_key = m
			break
		
		var _phys_material : ExpandedPhysicsMaterial = load(default_phys_material)
		var _map : ExpandedPhysicsMaterialMapper = load(default_material_mapper)
		if _mat_found:
			print("hi ", _mat_key)
			for m in _map.ExpandedPhysicsMaterialDictionary:
				if m != _mat_key:
					continue
				print(_map.ExpandedPhysicsMaterialDictionary[m])
				_phys_material = _map.ExpandedPhysicsMaterialDictionary[m]
				break
		
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
		_colshape.set_meta("ext_phys_material", _phys_material)
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
