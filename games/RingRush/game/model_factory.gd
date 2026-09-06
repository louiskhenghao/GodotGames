class_name RushModelFactory
extends RefCounted
## Batch procedural environment pieces and accessories into one colored surface.
static var shared_material: StandardMaterial3D

static func piece(shape: String, size: Vector3, at: Vector3, color: Color) -> Dictionary:
	return {"shape": shape, "size": size, "at": at, "color": color}

static func bake(parts: Array, detail: int = 12) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for part in parts:
		var primitive: PrimitiveMesh
		if part.shape == "box":
			primitive = BoxMesh.new()
			primitive.size = Vector3.ONE
		elif part.shape in ["cylinder","cone"]:
			primitive=CylinderMesh.new()
			primitive.top_radius=0 if part.shape=="cone" else .5
			primitive.bottom_radius=.5
			primitive.height=1
			primitive.radial_segments=detail
		else:
			primitive = SphereMesh.new()
			primitive.radius = 0.5
			primitive.height = 1
			primitive.radial_segments = detail
			primitive.rings = detail / 2
		var source: Array = primitive.get_mesh_arrays()
		var base := vertices.size()
		var rotation:=Basis.from_euler(part.get("rotation",Vector3.ZERO))
		for i in source[Mesh.ARRAY_VERTEX].size():
			vertices.append(rotation*(source[Mesh.ARRAY_VERTEX][i] * part.size) + part.at)
			normals.append(rotation*(source[Mesh.ARRAY_NORMAL][i] / part.size).normalized())
			colors.append(part.color)
		for index in source[Mesh.ARRAY_INDEX]: indices.append(base + index)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if shared_material == null:
		shared_material = StandardMaterial3D.new()
		shared_material.vertex_color_use_as_albedo = true
		shared_material.roughness = 0.72
	mesh.surface_set_material(0, shared_material)
	return mesh
