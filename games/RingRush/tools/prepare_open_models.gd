extends SceneTree
## Bake selected CC0 source animations to shared meshes. Run with native rendering.
const HEIGHTS={"drone":.7,"helper":.65,"wolf":1.1,"fox":.8,"shiba":.8,"spitter":1.15,"wisp":1.2,"bee":.7}
var report:Dictionary={}
func _initialize():call_deferred("run")
func run():
 if DisplayServer.get_name()=="headless":push_error("Native renderer required for skinned pose baking");quit(1);return
 var source:String=OS.get_cmdline_user_args()[0]
 for id in HEIGHTS:
  var doc:=GLTFDocument.new();var state:=GLTFState.new()
  var error:=doc.append_from_file(source.path_join(id+".gltf"),state)
  if error!=OK:push_error("Cannot load "+id);quit(1);return
  var scene:Node3D=doc.generate_scene(state);root.add_child(scene)
  var player:AnimationPlayer=scene.find_child("AnimationPlayer",true,false)
  var skeleton:Skeleton3D=scene.find_child("Skeleton3D",true,false)
  var idle:String="Flying_Idle" if id in ["wisp","bee"] else "Idle"
  var walk:String="Fast_Flying" if id in ["wisp","bee"] else ("Gallop" if id in ["wolf","fox","shiba"] else "Run" if id in ["drone","helper"] else "Walk")
  var attack:String="Punch" if id in ["wisp","bee"] else ("Bite_Front" if id=="spitter" else "Shoot" if id in ["drone","helper"] else "Attack")
  var hit:String="HitReact" if id in ["wisp","bee"] else ("HitRecieve" if id=="spitter" else "Idle_HitReact1" if id in ["wolf","fox","shiba"] else "Attack")
  var death:String="Dead" if id in ["drone","helper"] else "Death"
  player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  player.play(idle);player.seek(0,true);skeleton.force_update_all_bone_transforms();await process_frame
  var bounds:=AABB();var first:=true
  for node:MeshInstance3D in scene.find_children("*","MeshInstance3D",true,false):
   var mesh:=node.bake_mesh_from_current_skeleton_pose() if node.skin!=null else node.mesh
   var box:AABB=node.global_transform*mesh.get_aabb()
   bounds=box if first else bounds.merge(box);first=false
  var scale_factor:float=HEIGHTS[id]/bounds.size.y
  var center:=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
  var transform:=Transform3D(Basis.from_scale(Vector3.ONE*scale_factor),-center*scale_factor)
  var library:=RushCrowdLibrary.new()
  var clips:Dictionary={"Idle":idle,"Run":walk,"Attack":attack,"Hit":hit,"Death":death}
  for clip in clips:
   var animation:=player.get_animation(clips[clip]);var duration:float=animation.length
   var count:int=12 if clip in ["Idle","Run"] else 10
   library.clips[clip]=[];library.durations[clip]=duration
   for frame in count:
    player.play(clips[clip]);player.seek(frame*duration/count,true);skeleton.force_update_all_bone_transforms();await process_frame
    library.clips[clip].append(bake(scene,transform))
  report[id]={"source_bounds":str(bounds),"height":HEIGHTS[id],"triangles":library.clips.Idle[0].surface_get_array_index_len(0)/3,"poses":54}
  var code:=ResourceSaver.save(library,"res://assets/creatures/"+id+".res",ResourceSaver.FLAG_COMPRESS)
  if code!=OK:push_error("Cannot save "+id);quit(1);return
  print(id," ",report[id]);scene.free()
 var output:=FileAccess.open("res://assets/creatures/bake-report.json",FileAccess.WRITE);output.store_string(JSON.stringify(report,"  "));output.close();quit()
func bake(scene:Node3D,normalization:Transform3D) -> ArrayMesh:
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for node:MeshInstance3D in scene.find_children("*","MeshInstance3D",true,false):
  var mesh:Mesh=node.bake_mesh_from_current_skeleton_pose() if node.skin!=null else node.mesh
  var transform:Transform3D=normalization*node.global_transform
  for surface in mesh.get_surface_count():
   var arrays:=mesh.surface_get_arrays(surface)
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
   var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
   var mat:BaseMaterial3D=node.get_active_material(surface)
   var tint:Color=mat.albedo_color if mat!=null else Color.WHITE
   var image:Image=mat.albedo_texture.get_image() if mat!=null and mat.albedo_texture!=null else null
   if image!=null and image.is_compressed():image.decompress()
   if indices.is_empty():
    for i in vertices.size():indices.append(i)
   for index in indices:
    var color:=tint
    if arrays[Mesh.ARRAY_COLOR]!=null and arrays[Mesh.ARRAY_COLOR].size()>index:color*=arrays[Mesh.ARRAY_COLOR][index]
    if image!=null and arrays[Mesh.ARRAY_TEX_UV]!=null:
     var uv:Vector2=arrays[Mesh.ARRAY_TEX_UV][index]
     color*=image.get_pixel(clampi(int(uv.x*image.get_width()),0,image.get_width()-1),clampi(int(uv.y*image.get_height()),0,image.get_height()-1))
    tool.set_color(color);tool.set_normal((transform.basis*normals[index]).normalized());tool.add_vertex(transform*vertices[index])
 tool.index();return tool.commit()
