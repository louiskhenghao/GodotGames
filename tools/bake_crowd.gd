extends SceneTree
## Offline LOD + pose baking. Crowd reuses real humanoid animation without 48 live rigs.
func _initialize(): call_deferred("run")
func reduce(mesh: Mesh, triangles: int) -> ArrayMesh:
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(0))
	im.generate_lods(60,25,[])
	var arrays := mesh.surface_get_arrays(0)
	for lod in im.get_surface_lod_count(0):
		var indices := im.get_surface_lod_indices(0,lod)
		if indices.size()/3 >= triangles: arrays[Mesh.ARRAY_INDEX]=indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result
func run():
	if DisplayServer.get_name()=="headless":
		push_error("Use the native renderer for skin baking.")
		quit(1)
		return
	var fighter := RushBoxer.new()
	root.add_child(fighter)
	fighter.build(true)
	fighter.outfit.mesh=RushBoxer.clothing(fighter.skin_mesh.mesh,true)
	fighter.skin_mesh.mesh=reduce(fighter.skin_mesh.mesh,1800)
	fighter.outfit.mesh=reduce(fighter.outfit.mesh,550)
	var library := RushCrowdLibrary.new()
	for clip in ["Idle","Jog_Fwd","Punch_Jab","Punch_Cross","Hit_Chest","Death01"]:
		var duration: float = fighter.animator.get_animation(clip).length
		var count := 18 if clip=="Death01" else (maxi(1,ceili(duration*24)) if clip != "Idle" else 1)
		library.durations[clip]=duration
		library.clips[clip]=[]
		for i in count:
			fighter.animator.play(clip)
			fighter.animator.seek(float(i)/count*duration,true)
			fighter.skeleton.force_update_all_bone_transforms()
			await process_frame
			var mesh := ArrayMesh.new()
			var skin := fighter.skin_mesh.bake_mesh_from_current_skeleton_pose()
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.append_from(skin,0,Transform3D.IDENTITY)
			surface.index()
			surface.commit(mesh)
			surface=SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.append_from(fighter.outfit.bake_mesh_from_current_skeleton_pose(),0,Transform3D.IDENTITY)
			for glove in fighter.gloves:
				var transform := fighter.skeleton.global_transform.affine_inverse()*glove.global_transform
				surface.append_from(glove.mesh,0,transform)
			surface.index()
			surface.commit(mesh)
			library.clips[clip].append(compact(mesh))
		print("Baked ",clip," ",count," frames, triangles ",library.clips[clip][0].surface_get_array_index_len(0)/3)
	ResourceSaver.save(library,"res://assets/fighters/crowd.res",ResourceSaver.FLAG_COMPRESS)
	fighter.queue_free()
	await process_frame
	quit()

func compact(mesh: ArrayMesh) -> ArrayMesh:
	var result := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		var source := mesh.surface_get_arrays(surface)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var uv := PackedVector2Array()
		var colors := PackedColorArray()
		var indices := PackedInt32Array()
		var mapping := {}
		for old in source[Mesh.ARRAY_INDEX]:
			if not mapping.has(old):
				mapping[old]=vertices.size()
				vertices.append(source[Mesh.ARRAY_VERTEX][old])
				normals.append(source[Mesh.ARRAY_NORMAL][old])
				uv.append(source[Mesh.ARRAY_TEX_UV][old])
				if surface==1: colors.append(source[Mesh.ARRAY_COLOR][old])
			indices.append(mapping[old])
		arrays[Mesh.ARRAY_VERTEX]=vertices
		arrays[Mesh.ARRAY_NORMAL]=normals
		arrays[Mesh.ARRAY_TEX_UV]=uv
		if surface==1: arrays[Mesh.ARRAY_COLOR]=colors
		arrays[Mesh.ARRAY_INDEX]=indices
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result
