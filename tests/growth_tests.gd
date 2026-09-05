extends SceneTree
var checks:=0
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,description:String):
 checks+=1
 if not ok:failures+=1;push_error(description)
func settle():
 for i in 10:await process_frame
func run():
 var core:=root.get_node("MobileCore");var store:=CoreSaveStore.new("user://growth-suite.json");core.save=store
 store.data.coins=1000000
 var ids:Dictionary={}
 for badge in RushAchievements.catalog():ids[badge.id]=true
 check(ids.size()==36,"36 unique varied badges")
 for badge in RushAchievements.catalog():check(badge.icon in ["fist","bolt","crown","stairs","dumbbell","nova","shield","quake","cyclone","dash","flurry","timer","skull","flame"],"badge has an implemented icon: "+badge.id)
 check(RushAchievements.bonuses(store.data)=={"health":0.0,"power":0.0,"cooldown":0.0},"new player has no unearned badge bonuses")
 for stat in RushBalance.TRAINING:
  var paid:=0;var start:int=store.data.coins
  for level in 30:
   paid+=RushBalance.training_cost(level)
   if not RushTraining.buy(store,stat.id):check(false,"training purchase failed: "+stat.id)
  check(RushTraining.level(store,stat.id)==30 and store.data.coins==start-paid,"30 training levels have exact cumulative cost: "+stat.id)
  check(not RushTraining.buy(store,stat.id),"capped training cannot spend: "+stat.id)
 check(RushTraining.total(store)==240 and RushTraining.league(store)==5,"all training reaches Master with 240 levels")
 check(RushTraining.value(RushRoster.CHARACTERS[0],"mastery",30)>=60 and RushTraining.value(RushRoster.CHARACTERS[0],"charge",30)<=100,"training caps prevent negative cooldown and excess charge")
 var broken:=CoreSaveStore.new("user://missing-growth-directory/save.json");broken.data.coins=10000
 check(not RushTraining.buy(broken,"power") and broken.data.coins==10000 and not broken.data.progress.has("badges"),"failed training save cannot grant a badge or debit coins")
 check(not RushSkillGrowth.buy(broken,"quake") and not broken.data.progress.has("skill_levels"),"failed skill save is atomic")
 check(not RushSkillGrowth.buy(store,"invented"),"unknown technique cannot upgrade")
 check(not RushSkillGrowth.buy(store,"meteor"),"locked technique cannot upgrade")
 for id in ["aegis","ion","onyx"]:
  var before:int=store.data.coins
  check(RushRoster.unlock(store,"character",id),"premium mech unlocks: "+id)
  check(before-store.data.coins==RushRoster.character(id).price and RushRoster.unlock(store,"character",id) and store.data.coins==before-RushRoster.character(id).price,"premium unlock is charged once: "+id)
 for move in RushRoster.MOVES:
  RushRoster.unlock(store,"move",move.id)
  for i in 9:check(RushSkillGrowth.buy(store,move.id),"skill rank purchase: "+move.id)
  var before:int=store.data.coins
  check(RushSkillGrowth.level(store,move.id)==10 and not RushSkillGrowth.buy(store,move.id) and before==store.data.coins,"skill cap never spends: "+move.id)
 check(RushSkillGrowth.stats(10).damage>2 and RushSkillGrowth.stats(10).radius>1.3 and RushSkillGrowth.stats(10).cooldown>.8,"skill scaling is powerful but bounded")
 check(RushSkillGrowth.tint("quake",1)!=RushSkillGrowth.tint("quake",5) and RushSkillGrowth.tint("quake",5)!=RushSkillGrowth.tint("quake",10),"skill milestones have distinct color stages")
 var fresh:=CoreSaveStore.new("user://growth-suite.json");fresh.load_profile()
 check(RushTraining.total(fresh)==240 and RushSkillGrowth.level(fresh,"meteor")==10 and RushRoster.owned(fresh,"character","onyx"),"training, skill rank and mech ownership survive reload")
 var rookie:=CoreSaveStore.new("user://growth-rookie.json")
 var base:=RushGrowth.snapshot(rookie,RushRoster.CHARACTERS[0],"barrage")
 var advanced:=RushGrowth.snapshot(store,RushRoster.character("onyx"),"meteor")
 var contract:=RushGrowth.snapshot(store,RushRoster.character("onyx"),"meteor",true)
 check(base.enemy_hp==1 and advanced.enemy_hp>1 and advanced.enemy_hp<=1.65,"rivals scale with growth within a cap")
 check(is_equal_approx(contract.enemy_hp-advanced.enemy_hp,.3) and is_equal_approx(contract.coins-advanced.coins,.25),"optional contract trades more danger for a fixed bonus")
 # Clear explicit varied objectives in a separate record, then evaluate idempotently.
 var all:=store.data.duplicate(true)
 for entry in RushRoster.CHARACTERS:all.progress.get_or_add("unlocks",{})["character:"+entry.id]=true
 all.progress.total_kos=2000;all.progress.best_combo=50;all.progress.boss_kos=25;all.progress.ultimates=10;all.progress.dodges=50
 for mode in RushWaveDirector.MODES:all.progress["clears_"+mode.id]=1
 for i in 5:all.progress["wins_"+str(i)]=1
 for id in ["quake","cyclone","thunder"]:all.progress["casts_"+id]=20
 RushAchievements.evaluate(all)
 check(all.progress.badges.size()==36 and RushAchievements.evaluate(all).is_empty(),"all 36 badges reachable and never granted twice")
 var bonus:=RushAchievements.bonuses(all)
 check(bonus.health<=12 and bonus.power<=2.41 and bonus.cooldown<=.025,"badge stat rewards remain small at full completion")
 check(RushProgress.settle(rookie,"proof",100,0,10,true,"sprint",10,{"best_combo":10,"boss_kos":1,"casts_quake":20}),"fight metrics and achievements settle atomically")
 var same:=rookie.data.duplicate(true)
 check(RushProgress.settle(rookie,"proof",100,0,10,true,"sprint",10,{"best_combo":50,"boss_kos":100}) and rookie.data==same,"repeated settlement cannot farm badge metrics")
 check(not RushProgress.settle(broken,"failure",100,0,10,true,"sprint",10,{"boss_kos":1}) and broken.data.coins==10000,"failed result save grants no coins or badges")
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 for id in ["aegis","ion","onyx"]:
  game.preview_character(id)
  check(game.player.is_mech() and game.player.mech_arms.size()==2 and game.player.gloves.size()==2,"new mech has articulated boxing arms: "+id)
  check(game.player.animator.has_animation("Punch_Jab") and game.player.animator.has_animation("Jog_Fwd"),"mech has fight and movement animations: "+id)
  game.player.punch();game.player.animate(.1,true)
  check(game.player.mech_fists.any(func(f):return f.position.z>.3),"mech punch extends an actual fist: "+id)
 RushRoster.equip(store,"character","atlas");game.go_home();game.start_run()
 var snapshot:=RushRunSnapshot.capture(game);var frozen:Dictionary=game.growth.duplicate(true)
 check(RushRunSnapshot.valid(snapshot),"new fight stores valid frozen growth and metrics")
 store.data.progress.power=0;store.data.progress.skill_levels.barrage=1
 RushRunSnapshot.restore(game,snapshot)
 check(game.growth==frozen,"resuming does not recalculate growth from changed purchases")
 var bad:=snapshot.duplicate(true);bad.growth.skill_level=11
 check(not RushRunSnapshot.valid(bad),"out-of-range skill rank cannot resume")
 game.resume_run();game.records.clear();game.dash();game.technique_clock=0;game.technique();game.special_charge=100;game.special()
 check(game.records.dodges==1 and game.records.ultimates==1 and game.records.casts_barrage==2,"actual combat actions drive style achievements")
 game.finish_run(false);game.go_home()
 var recorded:Dictionary=game.records.duplicate(true)
 game.demo_move("quake");await settle()
 var header_back:Button=game.hud.buttons[0];header_back.pressed.emit();await settle()
 check(game.hud.current_page=="moves" and game.mode=="home" and not game.arena.showcase.visible,"Try Effect header back returns cleanly to Skills")
 check(game.records==recorded,"skill preview never advances achievements")
 var old:=snapshot.duplicate(true);old.erase("growth");old.erase("records")
 store.data.progress.mastery=30
 check(RushRunSnapshot.valid(old),"pre-growth snapshot remains accepted")
 RushRunSnapshot.restore(game,old)
 check(game.growth.enemy_hp==1 and is_equal_approx(game.growth.cooldown,.8) and game.growth.skill_level==1,"legacy fights retain original difficulty and capped old mastery")
 game.resume_run();game.finish_run(false);game.go_home()
 # Verify actual damage, coverage and effects at both ends, without kills or crit RNG.
 for move in RushRoster.MOVES:
  var results:Array=[]
  for rank in [1,10]:
   game._clear_combat();game.mode="playing";game.technique_id=move.id;game.growth={"skill_level":rank};game.damage=20;game.player.position=Vector3.ZERO;game.player.rotation.y=0
   var target=game._spawn(Vector3(0,0,-1),"rookie");target.health=100000
   game._cast_move(move.id,1)
   for frame in 24:game._update_technique(.05)
   results.append(100000-target.health)
  check(results[1]>results[0]*1.9 and results[0]>0,"level ten increases actual move damage: "+move.id)
  check(game.cast_radius>1.3,"level ten expands actual targeting radius: "+move.id)
 game._clear_combat();game.mode="playing";game.growth={"skill_level":1};game.damage=20
 var distant=game._spawn(Vector3(5.8,0,0),"rookie");distant.health=10000
 game._cast_move("quake",1);check(distant.health==10000,"base quake cannot hit outside its area")
 game.growth.skill_level=10;game._cast_move("quake",1);check(distant.health<10000,"upgraded quake reaches an opponent outside the old area")
 for resolution in [Vector2i(320,568),Vector2i(540,960),Vector2i(768,1024)]:
  root.size=resolution;game.mode="home";game.go_home();game.hud.training();await settle()
  var fight:Button=game.hud.screen.find_child("GymFight",true,false)
  check(game.hud.root.get_global_rect().encloses(fight.get_global_rect()),"training action stays visible: "+str(resolution))
  game.hud.moves();await settle()
  var upgrade:Button=game.hud.screen.find_child("UpgradeSkill",true,false)
  check(game.hud.root.get_global_rect().encloses(upgrade.get_global_rect()),"skill upgrade stays visible: "+str(resolution))
  game.hud.achievements();await settle()
  check(game.hud.page_body.find_children("Badge_*","PanelContainer",true,false).size()==36,"all badge cards build: "+str(resolution))
 var bank:=CoreSaveStore.new("user://growth-bank.json")
 RushProgress.checkpoint(bank,"contract-bank",100,0,10,{"growth":{"coins":1.25},"records":{"boss_kos":1},"run_mode":"sprint","completed_waves":2})
 check(RushProgress.recover(bank)==125 and bank.data.coins==125 and bank.data.progress.boss_kos==1,"banked contract applies multiplier and metrics once")
 check(RushProgress.recover(bank)==0 and bank.data.coins==125,"banked reward cannot replay")
 game.queue_free();await process_frame;await create_timer(.4).timeout
 for path in ["user://growth-suite.json","user://growth-rookie.json","user://growth-bank.json"]:
  for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(path+suffix)
 print("GROWTH: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
