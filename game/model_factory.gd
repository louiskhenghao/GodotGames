class_name RushModelFactory
extends RefCounted
## Bake details into one surface per animated part. Meshes are shared across actors.
static var cache: Dictionary = {}
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
		else:
			primitive = SphereMesh.new()
			primitive.radius = 0.5
			primitive.height = 1
			primitive.radial_segments = detail
			primitive.rings = detail / 2
		var source: Array = primitive.get_mesh_arrays()
		var base := vertices.size()
		for i in source[Mesh.ARRAY_VERTEX].size():
			vertices.append(source[Mesh.ARRAY_VERTEX][i] * part.size + part.at)
			normals.append((source[Mesh.ARRAY_NORMAL][i] / part.size).normalized())
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

static func fighter(role: String, gold: bool = false) -> Dictionary:
	var key := role + str(gold)
	if cache.has(key): return cache[key]
	var skin := Color("d99b71") if role == "hero" else Color("b67a62")
	var suit: Color = {"hero": Color("26bdd3"), "rookie": Color("e95659"), "runner": Color("f39840"), "brute": Color("9c72d6"), "boss": Color("28364e")}.get(role, Color("e95659"))
	var dark := Color("172639")
	var white := Color("eee6d5")
	var glove := Color("ffc25b") if gold else suit
	var detail := 20 if role == "hero" else (12 if role == "boss" else 8)
	var parts := {}
	parts.torso = bake([
		piece("sphere", Vector3(0.76, 0.61, 0.43), Vector3(0, 1.0, 0), skin),
		piece("sphere", Vector3(0.60, 0.32, 0.38), Vector3(0, 0.76, 0), skin.darkened(0.04)),
		piece("box", Vector3(0.56, 0.27, 0.37), Vector3(0, 0.59, 0), suit),
		piece("box", Vector3(0.57, 0.08, 0.39), Vector3(0, 0.74, 0), white),
		piece("box", Vector3(0.13, 0.09, 0.025), Vector3(0, 0.735, -0.21), Color("e5ad4d")),
		piece("box", Vector3(0.025, 0.19, 0.014), Vector3(0, 0.94, -0.202), skin.darkened(0.13)),
		piece("sphere", Vector3(0.24, 0.21, 0.23), Vector3(0, 1.32, 0), skin)
	], detail)
	var head_parts := [
		piece("sphere", Vector3(0.45, 0.47, 0.42), Vector3.ZERO, skin),
		piece("sphere", Vector3(0.34, 0.22, 0.35), Vector3(0, -0.12, -0.035), skin),
		piece("sphere", Vector3(0.085, 0.14, 0.09), Vector3(-0.23, -0.02, 0), skin),
		piece("sphere", Vector3(0.085, 0.14, 0.09), Vector3(0.23, -0.02, 0), skin),
		piece("sphere", Vector3(0.08, 0.105, 0.10), Vector3(0, -0.035, -0.208), skin.lightened(0.07)),
		piece("box", Vector3(0.067, 0.055, 0.02), Vector3(-0.10, 0.035, -0.199), white),
		piece("box", Vector3(0.067, 0.055, 0.02), Vector3(0.10, 0.035, -0.199), white),
		piece("box", Vector3(0.027, 0.041, 0.025), Vector3(-0.092, 0.03, -0.212), dark),
		piece("box", Vector3(0.027, 0.041, 0.025), Vector3(0.092, 0.03, -0.212), dark),
		piece("box", Vector3(0.09, 0.025, 0.025), Vector3(-0.10, 0.09, -0.20), dark),
		piece("box", Vector3(0.09, 0.025, 0.025), Vector3(0.10, 0.09, -0.20), dark),
		piece("box", Vector3(0.095, 0.026, 0.014), Vector3(0, -0.135, -0.205), dark),
		piece("sphere", Vector3(0.46, 0.20, 0.40), Vector3(0, 0.185, 0.02), dark),
		piece("sphere", Vector3(0.27, 0.17, 0.32), Vector3(-0.05, 0.265, -0.05), dark)
	]
	if role == "brute" or role == "boss":
		head_parts.append(piece("box", Vector3(0.48, 0.1, 0.42), Vector3(0, 0.11, 0), suit))
		for x in [-0.24, 0.24]: head_parts.append(piece("sphere", Vector3(0.13, 0.36, 0.35), Vector3(x, 0, 0.03), suit))
	parts.head = bake(head_parts, detail)
	for side in [-1, 1]:
		parts["arm" + str(side)] = bake([
			piece("sphere", Vector3(0.30, 0.29, 0.31), Vector3.ZERO, skin),
			piece("sphere", Vector3(0.25, 0.37, 0.26), Vector3(side * 0.02, -0.20, 0.03), skin),
			piece("sphere", Vector3(0.23, 0.24, 0.38), Vector3(side * 0.02, -0.33, -0.10), skin),
			piece("box", Vector3(0.23, 0.16, 0.15), Vector3(side * 0.02, -0.26, -0.26), white),
			piece("box", Vector3(0.24, 0.025, 0.155), Vector3(side * 0.02, -0.24, -0.265), suit.darkened(0.25)),
			piece("sphere", Vector3(0.37, 0.33, 0.41), Vector3(side * 0.02, -0.21, -0.44), glove),
			piece("sphere", Vector3(0.15, 0.23, 0.19), Vector3(-side * 0.12, -0.30, -0.38), glove.darkened(0.08)),
			piece("sphere", Vector3(0.20, 0.09, 0.26), Vector3(side * 0.02, -0.066, -0.44), glove.lightened(0.22)),
			piece("box", Vector3(0.10, 0.024, 0.012), Vector3(side * 0.02, -0.18, -0.645), white)
		], detail)
		parts["leg" + str(side)] = bake([
			piece("box", Vector3(0.235, 0.20, 0.34), Vector3.ZERO, suit),
			piece("box", Vector3(0.038, 0.18, 0.35), Vector3(side * 0.09, 0, 0), white),
			piece("sphere", Vector3(0.20, 0.29, 0.22), Vector3(0, -0.17, 0), skin),
			piece("sphere", Vector3(0.18, 0.28, 0.20), Vector3(0, -0.33, 0.015), dark),
			piece("box", Vector3(0.23, 0.13, 0.36), Vector3(0, -0.46, -0.07), white),
			piece("box", Vector3(0.24, 0.035, 0.37), Vector3(0, -0.525, -0.07), dark),
			piece("box", Vector3(0.12, 0.012, 0.15), Vector3(0, -0.389, -0.10), suit)
		], detail)
	cache[key] = parts
	return parts
