extends SceneTree
const FOLDER="res://docs/growth-preview/"
var game:Node3D
func _initialize():call_deferred("run")
func snap(name:String,delay:float=.25):
 await create_timer(delay).timeout;RenderingServer.force_draw();root.get_texture().get_image().save_png(FOLDER+name+".png")
func run():
 DirAccess.make_dir_recursive_absolute(FOLDER)
 var core:=root.get_node("MobileCore");core.save=CoreSaveStore.new("user://growth-capture.json");core.save.data.coins=20000;core.save.data.progress.unlocked_stage=4
 core.save.data.progress.skill_levels={"quake":10,"barrage":5,"thunder":5}
 core.save.data.progress.power=12;core.save.data.progress.health=18;core.save.data.progress.footwork=6
 for id in ["aegis","ion","onyx"]:RushRoster.unlock(core.save,"character",id)
 RushAchievements.evaluate(core.save.data)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
 for resolution in [Vector2i(540,960),Vector2i(320,568),Vector2i(768,1024)]:
  root.size=resolution
  var name:String="phone" if resolution.x==540 else ("small" if resolution.x==320 else "tablet")
  game.go_home();await snap(name+"-home")
  game.hud.training();await snap(name+"-gym")
  game.hud.gym_filter="TECH";game.hud.training();await snap(name+"-gym-tech");game.hud.gym_filter="ALL"
  game.hud.achievements();await snap(name+"-badges")
  game.hud.badge_filter="GROWTH";game.hud.achievements();await snap(name+"-badges-growth");game.hud.badge_filter="ALL"
  game.hud.move_index=1;game.hud.moves(true);await snap(name+"-skills")
  game.demo_move("quake");await snap(name+"-ascended-quake",.12)
  game.hud.moves(true)
 root.size=Vector2i(540,960)
 for i in range(6,9):
  game.hud.fighter_index=i;game.hud.fighters(true);await snap("fighter-"+game.player.character_id)
  game.player.punch();await snap("punch-"+game.player.character_id,.12)
  RushRoster.equip(core.save,"character",game.player.character_id);game.go_home();game.demo_move(game.selected_move());await snap("demo-"+game.player.character_id,.16)
  game.hud.moves(true)
 game.go_home();game.start_run();game._clear_combat()
 for i in 12:game._spawn(Vector3(cos(i*TAU/12)*3.5,0,sin(i*TAU/12)*3.5),["rookie","charger","guard"][i%3])
 game._cast_move("thunder",1);await snap("mech-fight",.1)
 game.queue_free();await process_frame;await create_timer(.4).timeout
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://growth-capture.json"+suffix)
 quit()
