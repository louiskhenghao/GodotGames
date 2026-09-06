extends SceneTree
const FOLDER="res://docs/longevity-preview/"
var game:Node3D
func _initialize():call_deferred("run")
func settle(frames:int=8):
 for i in frames:await process_frame
func snap(name:String):
 RenderingServer.force_draw();root.get_texture().get_image().save_png(FOLDER+name+".png")
func run():
 DirAccess.make_dir_recursive_absolute(FOLDER);root.size=Vector2i(540,960)
 var store:=CoreSaveStore.new("user://longevity-capture.json");root.get_node("MobileCore").save=store;store.data.coins=10000
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 game.go_home();await settle();snap("home")
 for entry in RushEquipment.ITEMS:RushEquipment.buy(store,entry.id)
 RushEquipment.equip(store,"air","sky_scout");RushEquipment.equip(store,"ground","fox")
 game.hud.equipment();await settle();snap("companions")
 game.hud.achievements();await settle();snap("badges")
 game.hud.training();await settle();snap("gym")
 game.hud.settings();await settle();var scroll:ScrollContainer=game.hud.page_body.get_parent();scroll.scroll_vertical=10000;await settle();snap("settings")
 game.hud.credits_page();await settle();snap("credits")
 game.go_home();game.start_run();game._clear_combat();game.mode="playing";game.support.begin(store);game.growth={"skill_level":1}
 for i in 4:
  var actor=game._spawn(Vector3((i-1.5)*1.7,0,-2),RushCreatureModel.TYPES[i]);actor.health=10000;actor.animate(.12,false)
 game.player.face(Vector3(0,0,-1));game.player.animate(.1,false);game.support.update(game,.2);game.hud.playing()
 for i in 120:game.follow_camera.update(game.camera,game.player.position,root.get_visible_rect().size,.016)
 await settle();snap("open-enemies")
 game.ranks={"echo_bolt":1,"frost_fan":1,"seeker":1};game.arsenal.update(game,9)
 for i in 8:game.ranged_combat.update(game,.016);game.vfx._process(.016);await process_frame
 snap("ranged-build")
 game.special_charge=100;game.special()
 for i in 8:game.player.animate(.016,true);game.vfx._process(.016);game.vfx.spectacle._process(.016);await process_frame
 snap("faultbreaker")
 game.mode="upgrade";game.options=[RushBalance.ability("echo_bolt"),RushBalance.ability("frost_fan"),RushBalance.ability("ricochet")];game.hud.abilities(game.options);await settle(30);snap("ranged-choices")
 game.go_home();root.size=Vector2i(320,568);game.hud.equipment();await settle();snap("small-companions")
 game.queue_free();await process_frame;await create_timer(.3).timeout
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://longevity-capture.json"+suffix)
 quit()
