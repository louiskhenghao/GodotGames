extends SceneTree
var checks:=0
var failures:=0
func _initialize():call_deferred("run")
func check(value:bool,label:String):
 checks+=1
 if value:print("PASS: "+label)
 else:failures+=1;push_error(label)
func run():
 root.size=Vector2i(540,960)
 var core:=root.get_node("MobileCore")
 core.save=CoreSaveStore.new("user://quality-test.json")
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 game.set_process(false);game.set_physics_process(false)
 await process_frame
 check(game.arena.showcase.visible,"home has an actual boxing gym backdrop")
 game.hud.fighters()
 var fighter:String=game.player.character_id
 var yaw:float=game.player.rotation.y
 var touch:=InputEventScreenTouch.new()
 touch.index=2;touch.pressed=true;touch.position=game.hud._rotation_area().get_center()
 game.hud._input(touch)
 var drag:=InputEventScreenDrag.new()
 drag.index=2;drag.position=touch.position+Vector2(90,0);drag.relative=Vector2(90,0)
 game.hud._input(drag)
 check(game.player.rotation.y>yaw+.8 and game.player.character_id==fighter,"drag rotates the selected model without switching fighters")
 touch.pressed=false;game.hud._input(touch)
 check(game.hud.rotation_finger==-1,"release relinquishes model rotation touch")
 var mouse:=InputEventMouseButton.new()
 mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true;mouse.position=game.hud._rotation_area().get_center()
 game.hud._input(mouse)
 var motion:=InputEventMouseMotion.new();motion.relative=Vector2(-50,0)
 yaw=game.player.rotation.y;game.hud._input(motion)
 check(game.player.rotation.y<yaw,"mouse dragging also rotates the model")
 game.hud.cycle_fighter(1)
 check(game.player.character_id!=fighter,"arrows still change fighters independently")
 for page in ["shop","settings","moves","training"]:
  game.hud.call(page)
  check(not game.player.visible and not game.podium.visible,"no hidden actor leaks through "+page)
  check(game.hud.screen.modulate.a==1,"menu background stays opaque during "+page+" changes")
 game.hud.circuits()
 check(not game.player.visible and game.arena.venues[game.stage].visible,"fight picker displays the real venue above its controls")
 game.hud.cycle_venue(1)
 check(game.hud.venue_index==1 and game.stage==0,"locked venue can be previewed without changing saved fight selection")
 game.hud.select_challenge("survival30")
 check(game.run_mode=="survival30" and game.hud.current_page=="circuits","challenge selection refreshes without resetting venue preview")
 game.go_home();game.start_run()
 var base_camera:Vector3=game.camera.position
 check(game.camera.size<16,"portrait combat uses a closer camera")
 game.player.position=Vector3(3,0,3)
 for i in 60:game.follow_camera.update(game.camera,game.player.position,Vector2(540,960),.016)
 check(game.camera.position.distance_to(base_camera)>3,"camera follows travel beyond its dead zone")
 var screen_at:Vector2=game.camera.unproject_position(game.player.position+Vector3.UP)
 var viewport:Vector2=root.get_visible_rect().size
 check(screen_at.x>viewport.x*.3 and screen_at.x<viewport.x*.7 and screen_at.y>viewport.y*.30 and screen_at.y<viewport.y*.60,"fighter stays centered in the usable combat view")
 var steady:Vector3=game.follow_camera.focus
 game.follow_camera.update(game.camera,game.player.position+Vector3(.04,0,0),Vector2(540,960),.016)
 check(game.follow_camera.focus.distance_to(steady)<.04,"small movement does not jerk the camera")
 var enemy=game._spawn(game.player.position+Vector3(0,0,-1),"rookie")
 enemy.health=100
 game._hit(enemy,1)
 check(enemy.hit_time>0 and enemy.crowd_mesh.material_overlay!=null,"hit produces recoil and a short material flash")
 enemy.animate(.2,false)
 check(enemy.crowd_mesh.material_overlay==null,"hit flash clears instead of leaving permanent tint")
 game._hit(enemy,1000)
 var kos:int=game.kills
 check(not enemy.active and enemy.dying and enemy.visible and enemy not in game.enemies,"KO leaves a visible falling body outside combat targeting")
 game._hit(enemy,1000)
 check(game.kills==kos,"falling body cannot award a duplicate KO")
 var pose:Mesh=enemy.crowd_mesh.mesh
 game._update_knockouts(.36)
 check(enemy.visible and enemy.crowd_mesh.mesh!=pose,"fall animates through real shared skeletal poses")
 var fresh=game._spawn(Vector3.ZERO,"rookie")
 check(fresh!=enemy,"spawning preserves the current falling animation")
 game._update_knockouts(1.2)
 check(not enemy.dying and not enemy.visible and game.knockouts.is_empty(),"finished fall returns the actor to the pool")
 for i in 16:
  var target=game._spawn(Vector3.ZERO,"rookie")
  game._hit(target,1000)
 check(game.knockouts.size()<=10,"mass knockouts have a fixed visible-body budget")
 var children:int=game.get_child_count()
 game._update_knockouts(2)
 check(game.get_child_count()==children,"death presentation creates no new scene actors")
 game._clear_combat()
 game.xp=game.xp_needed
 var scene_camera:Transform3D=game.camera.transform
 var old_screen:Control=game.hud.screen
 var old_header:Label=game.hud.stats
 game._level_up()
 await process_frame
 check(game.mode=="upgrade" and game.hud.upgrade_overlay!=null,"upgrade opens an in-place popup")
 check(game.hud.screen==old_screen and game.hud.stats==old_header,"popup preserves the combat HUD beneath it")
 check(game.camera.transform==scene_camera and game.player.visible,"popup keeps the same scene and camera")
 check(not game.hud.stick.enabled,"popup stops held movement")
 var elapsed:float=game.elapsed
 game._simulate(2)
 check(game.elapsed==elapsed,"fight clock stays paused while choosing")
 var count:int=game.level
 game.reroll()
 check(game.hud.upgrade_overlay!=null and game.level==count,"reroll replaces popup choices without leaving the arena")
 if game.hud._motion_enabled():
  await process_frame
  check(game.hud.upgrade_panel.scale.x<1,"native popup has a short scale entrance")
  await create_timer(.26).timeout
  check(is_equal_approx(game.hud.upgrade_panel.scale.x,1),"native popup settles at full scale")
 var id:String=game.options[0].id
 var rank:int=game.rank_of(id)
 game.choose_ability(id);game.choose_ability(id)
 if game.hud._motion_enabled():
  check(game.mode=="upgrade" and game.hud.upgrade_closing,"native popup protects its short exit from duplicate taps")
  await create_timer(.18).timeout
 check(game.mode=="playing" and game.rank_of(id)==rank+1 and game.hud.upgrade_overlay==null,"choice resumes once and cannot double-grant")
 game.pause_run();game.hud.settings()
 check(not game.player.visible,"pause settings also hide the actor")
 game.resume_run()
 check(game.player.visible and not game.arena.showcase.visible,"resuming restores combat visibility without the gym")
 game.finish_run(false);game.go_home()
 check(game.arena.showcase.visible and game.player.visible,"returning home restores the showroom")
 game.queue_free();await process_frame
 await create_timer(.25).timeout
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://quality-test.json"+suffix)
 print("QUALITY: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
