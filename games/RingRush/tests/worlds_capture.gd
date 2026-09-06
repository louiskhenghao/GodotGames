extends SceneTree
const FOLDER="res://docs/worlds-preview/"
var game:Node3D
func _initialize():call_deferred("run")
func settle(frames:int=8):
 for i in frames:await process_frame
func snap(id:String):
 RenderingServer.force_draw();root.get_texture().get_image().save_png(FOLDER+id+".png")
func run():
 DirAccess.make_dir_recursive_absolute(FOLDER);root.size=Vector2i(540,960)
 var store:=CoreSaveStore.new("user://worlds-capture.json");root.get_node("MobileCore").save=store
 store.data.coins=10000;store.data.progress.unlocked_stage=8
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 game.go_home();await settle();snap("home")
 RushEquipment.buy(store,"medic");RushEquipment.buy(store,"fox");RushEquipment.equip(store,"air","medic");RushEquipment.equip(store,"ground","fox")
 game.hud.equipment();await settle();snap("companions")
 game.hud.page_body.get_parent().scroll_vertical=1000;await settle();snap("companions-scrolled")
 RushEquipment.equip(store,"ground","");game.hud.equipment();await settle();snap("empty-slot")
 for stage_id in [6,7,8]:
  game.go_home();game.run_mode="sprint";game.stage=stage_id;game.hud.circuits();await settle();snap("venue-"+str(stage_id))
  game.start_run();game._clear_combat();game.mode="playing";game.wave=5;game.hp=game.max_hp;game.player.position=Vector3(0,0,1)
  for i in 6:
   var at:=Vector3(cos(i*TAU/6)*4.2,0,sin(i*TAU/6)*4.2)
   var actor=game._spawn(at,RushEncounterRoster.pick(stage_id,5,i));actor.animate(.18,false)
  var boss=game._spawn(Vector3(0,0,-4.3),"boss");game.boss=boss;game.boss_spawned=true;boss.animate(.2,false)
  game.player.face(Vector3.FORWARD);game.player.animate(.1,false);game.hud.playing();game.hud.update_stats()
  for i in 120:game.follow_camera.update(game.camera,game.player.position,root.get_visible_rect().size,.016)
  await settle();snap("fight-"+str(stage_id))
  game.mode="home";game.bank_saved_run()
 for size in [Vector2i(320,568),Vector2i(768,1024)]:
  root.size=size;game.go_home();await settle();snap("home-"+str(size.x));game.hud.equipment();await settle();snap("companions-"+str(size.x))
 game.queue_free();await process_frame;await create_timer(.3).timeout
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://worlds-capture.json"+suffix)
 quit()
