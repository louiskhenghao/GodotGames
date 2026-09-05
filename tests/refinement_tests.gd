extends SceneTree
var checks:=0
var failures:=0
func _initialize():call_deferred("run")
func check(value:bool,title:String):
 checks+=1
 if not value:failures+=1;push_error(title)
 else:print("PASS: "+title)
func settle():
 for i in 8:await process_frame
func run():
 var core:=root.get_node("MobileCore")
 core.save=CoreSaveStore.new("user://refinement-test.json")
 core.save.data.coins=10000
 core.save.data.settings.effects=false
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 game.set_process(false);game.set_physics_process(false)
 var store:CoreSaveStore=core.save
 for stat in RushBalance.TRAINING:
  var before:int=store.data.coins
  check(RushTraining.buy(store,stat.id),"coin training succeeds: "+stat.id)
  check(store.data.coins==before-80 and RushTraining.level(store,stat.id)==1,"training cost and rank commit together: "+stat.id)
  for i in 4:RushTraining.buy(store,stat.id)
  before=store.data.coins
  store.data.progress[stat.id]=30
  check(not RushTraining.buy(store,stat.id) and store.data.coins==before,"maximum stat cannot spend coins: "+stat.id)
  store.data.progress[stat.id]=5
 check(not RushTraining.buy(store,"unknown"),"unknown stat cannot be purchased")
 var broken:=CoreSaveStore.new("user://missing-directory-refinement/profile.json");broken.data.coins=100
 check(not RushTraining.buy(broken,"power") and broken.data.coins==100 and RushTraining.level(broken,"power")==0,"failed save never grants or charges training")
 var fresh:=CoreSaveStore.new("user://refinement-test.json");fresh.load_profile()
 check(RushTraining.level(fresh,"footwork")==5,"permanent boosts survive reload")
 game.start_run()
 check(is_equal_approx(game.damage,35+RushAchievements.bonuses(store.data).power) and is_equal_approx(game.max_hp,160+RushAchievements.bonuses(store.data).health) and is_equal_approx(game.move_speed,5.16),"training changes actual combat stats")
 game.technique_id="barrage";game.technique()
 check(is_equal_approx(game.technique_clock,4.8*(1-RushAchievements.bonuses(store.data).cooldown)),"mastery reduces actual technique cooldown")
 for move in RushRoster.MOVES:
  game._clear_combat()
  game.player.position=Vector3.ZERO
  game._cast_move(move.id,1)
  game._update_technique(.05)
  game.vfx._process(.03)
  var visible:bool=game.vfx.cracks.visible
  for effect in game.vfx.rings+game.vfx.strokes:visible=visible or effect.node.visible
  check(visible,"essential VFX render with particles off and no targets: "+move.id)
 game.vfx.burst(Vector3.ZERO,Color.WHITE)
 check(game.vfx.particles.all(func(p):return p.life<=0),"optional particles respect the saved off setting")
 game._clear_combat()
 game.player.position=Vector3.ZERO
 var spark=game._spawn(Vector3(0,0,-4),"spark")
 spark.attack_timer=0
 game._update_enemy(spark,.01)
 var agile_poses:RushCrowdLibrary=spark.crowd_poses
 var target:Vector3=spark.attack_target
 game.player.position=Vector3(3,0,0)
 var hp:float=game.hp
 game._update_enemy(spark,1.2)
 check(game.hp==hp and spark.attack_target==target,"sidestep escapes the locked lightning warning")
 game._clear_combat();game.player.position=Vector3.ZERO
 var charger=game._spawn(Vector3(0,0,-3),"charger")
 charger.attack_timer=0;game._update_enemy(charger,.01);game._update_enemy(charger,.9)
 check(charger.rush_time>0,"charger telegraph releases a timed rush")
 game.invulnerable=0;hp=game.hp
 for i in 10:game._update_enemy(charger,.05)
 check(is_equal_approx(game.hp,hp-14*(1-game.rank_of("armor")*.1)*game.growth.enemy_damage*(1-game.growth.grit)),"charger swept collision hits once per rush")
 var guard=game._spawn(Vector3(2,0,0),"guard")
 guard.health=100;game._hit(guard,20,true)
 check(is_equal_approx(guard.health,88),"guard armor mitigates normal punches")
 game._hit(guard,20,false)
 check(is_equal_approx(guard.health,68),"techniques bypass guard armor")
 check(guard.crowd_poses!=agile_poses and guard.crowd_poses!=RushBoxer.crowd_library,"enemy families use different silhouette meshes")
 var state:=RushRunSnapshot.capture(game)
 check(RushRunSnapshot.valid(state),"new enemy roles survive checkpoint validation")
 RushRunSnapshot.restore(game,state)
 check(game.enemies.all(func(e):return e.windup==0 and e.attack_timer>=.8),"restored enemy attacks give a fresh readable grace period")
 game.resume_run()
 for resolution in [Vector2i(320,568),Vector2i(540,960),Vector2i(768,1024)]:
  root.size=resolution
  for start in range(0,RushBalance.ABILITIES.size(),3):
   game.mode="upgrade";game.options=RushBalance.ABILITIES.slice(start,start+3)
   game.hud.abilities(game.options)
   await settle()
   var panel:Rect2=game.hud.upgrade_panel.get_global_rect()
   check(game.hud.root.get_global_rect().encloses(panel),"popup fits viewport "+str(resolution)+" batch "+str(start))
   for card in game.hud.upgrade_choices.get_children():
    var rank:Control=card.find_child("Rank",true,false)
    check(rank.get_global_rect().end.y<=card.get_global_rect().end.y-12,"wrapped description keeps rank inside "+card.name+str(resolution))
  game.hud.toast("WAVE 3 CLEAR  /  RECOVERY +7 HP")
  check(game.hud.message.vertical_alignment==VERTICAL_ALIGNMENT_CENTER,"toast text is vertically centered")
 game.mode="playing";game.finish_run(false);game.go_home()
 await settle()
 var nav:Control=game.hud.screen.find_child("SideNavigation",true,false)
 check(nav.get_child_count()==4,"home groups all four icon destinations")
 var before:int=store.data.coins
 core.commerce._on_purchase("late-callback","coins_500","refinement-pack-1",true,"")
 core.commerce._on_purchase("late-callback","coins_500","refinement-pack-1",true,"")
 check(store.data.coins==before+500,"coin purchase callbacks cannot double-grant")
 core.commerce._on_purchase("late-callback","coins_500","refinement-pack-2",true,"")
 check(store.data.coins==before+1000,"consumable can be bought again with a new receipt")
 check(not store.data.entitlements.has("coins_500"),"consumable creates no permanent entitlement")
 before=store.data.coins
 var restore_id:String=core.commerce._begin("restore","")
 core.commerce._on_restore(restore_id,["coins_500","remove_ads"],true,"")
 check(store.data.coins==before and store.data.entitlements.get("remove_ads",false),"restore grants only permanent products, never more coins")
 game.queue_free();await process_frame
 await create_timer(.3).timeout
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://refinement-test.json"+suffix)
 print("REFINEMENT: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
