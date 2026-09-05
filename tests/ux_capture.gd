extends SceneTree
## Actual renderer captures, using a disposable fully unlocked preview profile.
var game: Node3D
var folder:="res://docs/ux-preview/"
func _initialize():call_deferred("run")
func snap(title:String):
 await create_timer(.24).timeout
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder+title+".png")
func combat(stage:int):
 if game.mode in ["playing","paused","defeat"]:game.finish_run(false)
 game.go_home()
 if game.has_resume():game.bank_saved_run()
 game.stage=stage
 game.start_run()
 game.set_physics_process(false)
 game.special_charge=100
 game.wave=7;game.completed_waves=6;game.kills=42
 for i in 16:
  game._spawn(RushArenaLayout.spawn_point(stage,i*TAU/16)*.62,["rookie","runner","brute"][i%3])
 game.hud.update_stats()
func run():
 DirAccess.make_dir_recursive_absolute(folder)
 seed(13)
 var core:=root.get_node("MobileCore")
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://ux-capture-disposable.json"+suffix)
 core.save=CoreSaveStore.new("user://ux-capture-disposable.json")
 core.save.data.coins=3200
 core.save.data.progress.unlocked_stage=4
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 game.set_physics_process(false)
 root.size=Vector2i(540,960)
 game.go_home()
 await snap("phone-home")
 for i in RushRoster.CHARACTERS.size():
  game.hud.fighter_index=i
  game.hud.fighters(true)
  await snap("fighter-"+RushRoster.CHARACTERS[i].id)
 game.hud.moves()
 await snap("phone-skills")
 game.hud.move_index=1
 game.hud.moves(true)
 game.demo_move("quake")
 await snap("phone-skill-demo")
 game.go_home()
 game.hud.circuits()
 await snap("phone-modes")
 game.hud.shop()
 await snap("phone-shop")
 for stage in 5:
  combat(stage)
  await snap("venue-"+str(stage))
 game.hp=0
 game._simulate(.02)
 await snap("phone-revive")
 game.request_revive()
 core.commerce.provider.active.set_process(false)
 await snap("phone-ad")
 core.commerce.provider.active.advance(15)
 core.commerce.provider.active.request_close()
 game.finish_run(true)
 await snap("phone-result")
 for dimensions in [Vector2i(540,800),Vector2i(768,1024)]:
  var prefix:="compact" if dimensions.x==540 else "tablet"
  root.size=dimensions
  game.go_home()
  await snap(prefix+"-home")
  game.hud.fighter_index=2;game.hud.fighters(true)
  await snap(prefix+"-fighter")
  game.hud.moves()
  await snap(prefix+"-skills")
  combat(1)
  await snap(prefix+"-combat")
 game.queue_free()
 await process_frame
 await create_timer(.25).timeout
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://ux-capture-disposable.json"+suffix)
 quit()
