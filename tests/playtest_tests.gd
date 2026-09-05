extends SceneTree
var checks:=0
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,title:String):
 checks+=1
 if not ok:failures+=1;push_error(title)
func settle():
 for i in 12:await process_frame
func run():
 var core:=root.get_node("MobileCore")
 core.save=CoreSaveStore.new("user://playtest-suite.json")
 core.save.data.coins=9999
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 game.set_physics_process(false);game.set_process(false)
 for resolution in [Vector2i(320,568),Vector2i(540,960),Vector2i(768,1024)]:
  root.size=resolution;game.go_home();await settle()
  for b in game.hud.buttons:
   if b.text.is_empty() and b.has_meta("glyph") and not b.get_meta("nav_tile",false):
    check((b.get_meta("glyph").get_global_rect().get_center()-b.get_global_rect().get_center()).length()<.1,"home glyph centered "+str(resolution))
  check(not game.camera.is_position_behind(Vector3(0,0,7)),"foreground floor is in front of showroom near plane")
  game.hud.training();await settle()
  var fight:Button=game.hud.screen.find_child("GymFight",true,false)
  check(game.hud.root.get_global_rect().encloses(fight.get_global_rect()),"gym always exposes fight action")
  var scroll:ScrollContainer=game.hud.page_body.get_parent()
  check(scroll.get_global_rect().end.y+16<=fight.get_global_rect().position.y,"gym actions separated from scrolling cards")
  check(game.hud.page_body.get_child(0).columns==2,"gym has two visual columns")
  var before:int=core.save.data.coins
  var upgrade:Button=game.hud.page_body.get_child(0).get_child(0).get_child(0).get_child(3)
  upgrade.pressed.emit();await settle()
  check(core.save.data.coins<before,"gym card directly purchases upgrade")
  game.hud.shop();await settle()
  check(game.hud.page_body.get_child(0).columns==2 and game.hud.page_body.get_child(0).get_child_count()==6,"shop shows six visual products")
  game.go_home();game.hud.circuits();await settle()
  var confirm:Button=game.hud.screen.find_child("ConfirmFight",true,false)
  var modes:Control=game.hud.screen.find_child("Mode_hell",true,false).get_parent()
  check(modes.get_child_count()==8,"eight challenges appear")
  var options:ScrollContainer=modes.get_parent().get_parent()
  check(options.get_global_rect().end.y+20<=confirm.get_global_rect().position.y,"fight footer has a clear gap")
  for b in modes.get_children():check(b.has_meta("glyph"),"mode has icon: "+b.name)
 for id in ["rattle","shade","hex"]:
  RushRoster.unlock(core.save,"character",id);RushRoster.equip(core.save,"character",id)
  game.go_home();game.run_mode="hell";game.start_run()
  check(game.music.stream.resource_path.ends_with("music_hell.ogg"),"hell starts its faster music")
  check(game.player.is_creature() and game.player.animator.has_animation("Punch_Jab"),"native animated creature: "+id)
  if id=="rattle":check(is_equal_approx(game.cooldown,RushRoster.character(id).tempo*.85),"quick combo starting rank changes punch tempo")
  game._clear_combat()
  for role in ["bone","revenant","hexer"]:
   var e=game._spawn(Vector3(2,0,0),role)
   check(e.crowd_poses!=RushBoxer.crowd_library,"creature enemy uses its own baked geometry: "+role)
  var state:=RushRunSnapshot.capture(game)
  check(RushRunSnapshot.valid(state),"hell snapshot accepts new creatures")
  RushRunSnapshot.restore(game,state)
  check(game.enemies.size()==3 and game.run_mode=="hell","hell snapshot restores creature crowd")
  game.resume_run();game.finish_run(false)
 var director:=RushWaveDirector.new();director.begin("hell")
 check(director.recovery()==0 and director.spawn_delay()<.2 and director.rest_duration()<1,"hell has dense spawns and no normal recovery")
 director.begin("bossrush")
 for wave in 5:
  check(director.boss_wave() and director.quota==1,"boss rush always spawns exactly one boss")
  director.advance()
 game.queue_free();await process_frame;await create_timer(.4).timeout
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://playtest-suite.json"+suffix)
 print("PLAYTEST: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
