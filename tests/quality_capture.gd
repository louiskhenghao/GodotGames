extends SceneTree
var game:Node3D
const FOLDER="res://docs/quality-preview/"
func _initialize():call_deferred("run")
func snap(title:String,delay:float=.28):
 await create_timer(delay).timeout
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(FOLDER+title+".png")
func fight(stage:int):
 if game.mode in ["playing","paused","defeat"]:game.finish_run(false)
 game.go_home()
 if game.has_resume():game.bank_saved_run()
 game.stage=stage
 game.start_run()
 game.set_physics_process(false)
 game.special_charge=100
 for i in 12:
  game._spawn(RushArenaLayout.spawn_point(stage,i*TAU/12)*.55,["rookie","runner","brute"][i%3])
 game.hud.update_stats()
func run():
 DirAccess.make_dir_recursive_absolute(FOLDER)
 seed(13)
 var core:=root.get_node("MobileCore")
 core.save=CoreSaveStore.new("user://quality-capture.json")
 core.save.data.coins=2400
 core.save.data.progress.unlocked_stage=4
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 game.set_physics_process(false)
 root.size=Vector2i(540,960)
 game.go_home()
 await snap("phone-home")
 game.hud.fighter_index=2;game.hud.fighters(true)
 await snap("phone-fighter")
 game.player.rotation.y+=1.1
 await snap("phone-fighter-turned")
 game.go_home();game.hud.circuits()
 await snap("phone-fight-ring")
 game.hud.cycle_venue(1)
 await snap("phone-fight-street")
 game.hud.select_challenge("ladder")
 await snap("phone-fight-ladder")
 game.hud.shop()
 await snap("phone-shop")
 game.hud.moves()
 await snap("phone-skills")
 game.run_mode="sprint"
 fight(1)
 await snap("phone-combat-center")
 game.player.position=Vector3(2.8,0,6.3)
 for i in 60:game.follow_camera.update(game.camera,game.player.position,Vector2(540,960),.016)
 await snap("phone-combat-edge")
 game._clear_combat()
 game.player.position=Vector3.ZERO;game._reset_combat_camera()
 var enemy=game._spawn(Vector3(0,0,-1.4),"rookie")
 enemy.health=500
 game._hit(enemy,5)
 await snap("phone-hit",.025)
 game._hit(enemy,999)
 game._update_knockouts(.35)
 await snap("phone-fall",.025)
 game._update_knockouts(.52)
 await snap("phone-floor",.025)
 game._update_knockouts(.40)
 await snap("phone-fade",.025)
 game.xp=game.xp_needed
 game._level_up()
 await snap("phone-upgrade")
 game.choose_ability(game.options[0].id)
 await create_timer(.22).timeout
 game.finish_run(false)
 for resolution in [Vector2i(320,568),Vector2i(768,1024)]:
  root.size=resolution
  var prefix:="small" if resolution.x==320 else "tablet"
  game.go_home()
  await snap(prefix+"-home")
  game.hud.circuits()
  await snap(prefix+"-fight")
  fight(4)
  await snap(prefix+"-combat")
  game.xp=game.xp_needed;game._level_up()
  await snap(prefix+"-upgrade")
  game.choose_ability(game.options[0].id)
  await create_timer(.2).timeout
  game.finish_run(false)
 game.queue_free();await process_frame
 await create_timer(.25).timeout
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://quality-capture.json"+suffix)
 quit()
