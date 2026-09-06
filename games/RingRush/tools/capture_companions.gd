extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(384,384)
 var world:=Node3D.new();root.add_child(world)
 var env:=WorldEnvironment.new();var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("162c45");environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color("bddcff");environment.ambient_light_energy=.65;env.environment=environment;world.add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-25,0);light.light_energy=1.4;world.add_child(light)
 var camera:=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.9;camera.position=Vector3(2,1.1,3);camera.look_at(Vector3(0,.45,0));camera.current=true
 var model:=RushCreatureModel.new();world.add_child(model)
 DirAccess.make_dir_recursive_absolute("res://assets/creatures/thumbs")
 for id in RushCreatureModel.MODELS:
  model.configure(id);model.position=Vector3.ZERO;model.rotation.y=.1
  var bounds:AABB=model.shell.mesh.get_aabb()
  camera.size=maxf(.8,bounds.size.length()*.85);camera.look_at(bounds.get_center())
  for i in 3:await process_frame
  RenderingServer.force_draw();root.get_texture().get_image().save_png("res://assets/creatures/thumbs/"+id+".png")
 world.queue_free();await process_frame;quit()
