extends SceneTree
var checks:=0
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,text:String):
 checks+=1
 if not ok:failures+=1;push_error(text)
func settle():
 for i in 10:await process_frame
func run():
 var core:=root.get_node("MobileCore");core.save=CoreSaveStore.new("user://flow-test.json")
 core.save.data.coins=5000;core.save.data.progress.unlocked_stage=4
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 game.set_process(false);game.set_physics_process(false)
 for resolution in [Vector2i(320,568),Vector2i(540,960),Vector2i(768,1024)]:
  root.size=resolution;game.go_home();await settle()
  var nav:HBoxContainer=game.hud.screen.find_child("SideNavigation",true,false)
  var colors:Array=[]
  for b in nav.get_children():
   colors.append(b.get_theme_stylebox("normal").bg_color)
   check(absf(b.global_position.y-nav.get_child(0).global_position.y)<1,"home shortcuts share one row")
  check(colors.size()==4 and colors[0]!=colors[1] and colors[1]!=colors[2] and colors[2]!=colors[3],"destinations have distinct visual colors")
  var play:Button=game.hud.screen.find_child("HomePlay",true,false)
  for state in ["normal","hover","pressed","disabled"]:
   var skin:=play.get_theme_stylebox(state)
   check(skin.content_margin_left==skin.content_margin_right,"Play text has a symmetric center: "+state)
  check(game.hud.root.get_global_rect().encloses(play.get_global_rect()),"home action fits viewport")
  play.pressed.emit();await settle()
  check(game.hud.current_page=="circuits" and game.mode=="home","Play opens one combined fight picker")
  game.hud.select_challenge("blitz");await settle()
  var fight:Button=game.hud.screen.find_child("ConfirmFight",true,false)
  check(fight.text=="FIGHT","picker names its direct start action")
  fight.pressed.emit()
  check(game.mode=="playing" and game.run_mode=="blitz","picker starts the selected fight without another home screen")
  game.finish_run(false);game.go_home();game.hud.shop();await settle()
  var cards:GridContainer=game.hud.page_body.get_child(0)
  for row in 3:
   var a:Button=cards.get_child(row*2).get_child(0).get_child(3)
   var b:Button=cards.get_child(row*2+1).get_child(0).get_child(3)
   check(absf(a.global_position.y-b.global_position.y)<.1,"shop CTAs align across wrapped-copy row "+str(row))
 game.go_home()
 for fighter in RushRoster.CHARACTERS:
  game.preview_character(fighter.id)
  check(game.arena.showcase.current_fighter==fighter.id,"fighter uses its own background: "+fighter.id)
 check(game.arena.showcase.scenes.size()==9,"nine distinct background scenes are cached")
 game.stage=4
 for move in RushRoster.MOVES:
  game.demo_move(move.id);await settle()
  check(game.arena.current_stage==0 and not game.podium.visible and not game.arena.showcase.visible,"skill demo uses ring, no showroom: "+move.id)
  check(game.player.position.z<game.enemies[0].position.z and cos(game.player.rotation.y)<-.5,"preview faces player with targets in front: "+move.id)
  check(game.camera.size>=7.5 and game.player.scale.y<1.5,"preview has combat scale and full effect space")
  game.hud.moves(true)
  check(game.stage==4,"leaving demo restores chosen arena")
 var paths:Array=[]
 for mode in RushWaveDirector.MODES:
  game._play_music(mode.id)
  paths.append(game.music.stream.resource_path)
 check(paths.size()==9 and _unique(paths)==9,"every mode has a separate score resource")
 game.queue_free();await process_frame;await create_timer(.4).timeout
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://flow-test.json"+suffix)
 print("FLOW: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
func _unique(values:Array) -> int:
 var found:Dictionary={}
 for v in values:found[v]=true
 return found.size()
