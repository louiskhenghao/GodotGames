extends SceneTree
## Non-destructive evaluation: retain bones, UVs and weights while testing mesh LODs.
func _initialize():call_deferred("run")
func run():
 for file in ["candidate","candidate_b"]:
  var scene:PackedScene=load("res://assets/fighters/custom/"+file+".fbx")
  var model:=scene.instantiate()
  root.add_child(model)
  for instance:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
   var source:=instance.mesh
   var result:=ArrayMesh.new()
   for i in source.get_surface_count():
    var arrays:=source.surface_get_arrays(i)
    var importer:=ImporterMesh.new()
    importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays)
    importer.generate_lods(60,25,[])
    var best:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
    var counts:=[]
    for lod in importer.get_surface_lod_count(0):
     var indices:=importer.get_surface_lod_indices(0,lod)
     counts.append(indices.size()/3)
     if indices.size()/3>=10000 and indices.size()<best.size():best=indices
    print(file," generated LODs ",counts," selected ",best.size()/3)
    arrays[Mesh.ARRAY_INDEX]=best
    # Compact unused vertices while preserving all supported skin and UV channels.
    var mapping:={}
    var order:=PackedInt32Array()
    for old in best:
     if not mapping.has(old):mapping[old]=order.size();order.append(old)
    var vertex_count:int=arrays[Mesh.ARRAY_VERTEX].size()
    for slot in Mesh.ARRAY_MAX:
     if slot==Mesh.ARRAY_INDEX or arrays[slot]==null:continue
     var source_array=arrays[slot]
     var stride:int=source_array.size()/vertex_count
     if stride<1:continue
     var packed=source_array.duplicate();packed.resize(order.size()*stride)
     for index in order.size():
      for component in stride:packed[index*stride+component]=source_array[order[index]*stride+component]
     arrays[slot]=packed
    for index in best.size():best[index]=mapping[best[index]]
    arrays[Mesh.ARRAY_INDEX]=best
    result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    result.surface_set_material(i,instance.get_active_material(i))
   instance.mesh=result
  var packed:=PackedScene.new()
  packed.pack(model)
  ResourceSaver.save(packed,"res://assets/fighters/custom/"+file+"_preview.scn",ResourceSaver.FLAG_COMPRESS)
  model.queue_free();await process_frame
 quit()
