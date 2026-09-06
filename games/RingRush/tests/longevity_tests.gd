extends SceneTree
var checks:=0
var failures:=0
var game:Node3D
var store:CoreSaveStore
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;push_error(message)
func fresh(character:String="atlas"):
 game._clear_combat();game.mode="playing";game.stage=0;game.arena.set_stage(0);game.player.set_character(character);game.player.position=Vector3.ZERO
 game.ranks={};game.hp=100;game.max_hp=100;game.damage=20;game.growth={"skill_level":1};game.records={};game.technique_clock=0;game.invulnerable=0;game.hit_stop=0
func target(at:Vector3=Vector3(0,0,-4)) -> RushBoxer:
 var actor:RushBoxer=game._spawn(at,"rookie");actor.health=1000;actor.max_health=1000;return actor
func shots() -> int:return game.ranged_combat.shots.filter(func(shot):return shot.active).size()
func travel():
 for i in 60:game.ranged_combat.update(game,.02)
func settle():
 for i in 5:await process_frame
func run():
 root.size=Vector2i(540,960)
 store=CoreSaveStore.new("user://longevity-tests.json");root.get_node("MobileCore").save=store
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 store.data.coins=20000
 check(not RushEquipment.equip(store,"air","sky_scout"),"locked companion cannot equip")
 var broken:=CoreSaveStore.new("user://missing-longevity-directory/save.json");broken.data.coins=20000
 check(not RushEquipment.buy(broken,"medic") and broken.data.coins==20000,"failed companion commit cannot charge or unlock")
 for entry in RushEquipment.ITEMS:
  var before:int=store.data.coins
  check(RushEquipment.buy(store,entry.id) and store.data.coins==before-entry.price,"companion exact unlock cost: "+entry.id)
  check(RushEquipment.buy(store,entry.id) and store.data.coins==before-entry.price,"duplicate companion purchase is free: "+entry.id)
  check(RushEquipment.equip(store,entry.slot,entry.id),"owned companion equips matching slot: "+entry.id)
  check(not RushEquipment.equip(store,"ground" if entry.slot=="air" else "air",entry.id),"wrong companion slot rejected: "+entry.id)
 var reloaded:=CoreSaveStore.new("user://longevity-tests.json");reloaded.load_profile()
 check(RushEquipment.selected(reloaded,"air")=="arc_bee" and RushEquipment.selected(reloaded,"ground")=="shiba","two independent equipment slots survive reload")
 check(not RushEquipment.buy(store,"unknown") and not RushEquipment.equip(store,"invented",""),"unknown equipment and slots rejected")
 fresh();RushEquipment.equip(store,"air","medic");RushEquipment.equip(store,"ground","shiba");game.support.begin(store)
 game.hp=50;game.support.update(game,4);check(game.hp==50,"medic cannot heal above trigger threshold")
 game.hp=20;game.support.update(game,.1)
 check(game.hp==24 and game.support.slots.air.charges==2 and game.support.shield_time==3,"low health triggers bounded heal and shield")
 game.invulnerable=0;game._take_damage(10);check(is_equal_approx(game.hp,16),"support shield reduces incoming damage by only 20 percent")
 for i in 5:game.hp=20;game.support.update(game,21)
 check(game.hp==20 and game.support.slots.air.charges==0 and game.support.slots.ground.charges==0,"healing and shield cannot exceed three activations per run")
 var frozen:Dictionary=game.support.snapshot();game.support.restore(frozen,Vector3.ZERO)
 game.hp=20;game.support.update(game,21);check(game.hp==20,"reloading cannot refill companion charges")
 var bad:Dictionary=frozen.duplicate(true);bad.slots.air.charges=3.5;check(not RushSupportCombat.valid(bad),"fractional companion charges rejected")
 bad=frozen.duplicate(true);bad.slots.air.cooldown=NAN;check(not RushSupportCombat.valid(bad),"invalid companion cooldown rejected")
 fresh();RushEquipment.equip(store,"air","sky_scout");RushEquipment.equip(store,"ground","husky");game.support.begin(store);game.support.update(game,4)
 var actor:=target(Vector3(0,0,-2))
 for i in 8:game._hit(actor,1,true)
 game.support.update(game,.1)
 check(shots()==2 and actor.health==979,"hit-count companions attack only after the threshold")
 travel();check(game.support.slots.air.hits==0 and game.support.slots.ground.hits==0,"companion attacks cannot recursively count as player hits")
 check(game.records.get("support_triggers",0)==2,"real support triggers are recorded")
 fresh();RushEquipment.equip(store,"ground","fox");RushEquipment.equip(store,"air","arc_bee");game.support.begin(store);game.support.update(game,4)
 actor=target();game.support.on_dodge(game);game.support.on_skill(game)
 check(game.support.speed_time==2.5 and actor.frost==1.4,"fox dodge boost and bee skill slow use distinct conditions")
 game.support.update(game,1);game.support.on_dodge(game);check(game.support.speed_time==1.5,"repeated dodge cannot refresh fox while on cooldown")
 game.support.update(game,3);check(game.support.speed_time==0,"temporary movement boost expires")
 for id in ["echo_bolt","frost_fan","seeker"]:
  fresh();actor=target();game.ranks[id]=1;game.arsenal.update(game,9);check(shots()>0,"new ranged passive actually launches: "+id);travel()
  check(actor.health<1000,"ranged passive reaches distant target: "+id)
  check(game.records.get("casts_"+id,0)==0,"automatic ranged passive is not a player technique cast")
  if id=="frost_fan":check(actor.frost>0,"ice volley applies slow on impact")
 fresh();actor=target(Vector3(0,0,-2));var other:=target(Vector3(2,0,-2));game.ranks={"ricochet":1};game._hit(actor,20,true);travel()
 check(actor.health==980 and other.health<1000,"ricochet skips its originating victim and hits another enemy")
 check(shots()==0 and game.arsenal.timers.ricochet>0,"ricochet cannot recursively spawn new bolts")
 fresh();actor=target();game.ranks={"longshot":3};game.ranged_combat.fire(Vector3.UP*.8,Vector3.FORWARD,20,"pulse");travel()
 check(is_equal_approx(actor.health,974),"longshot adds bounded bonus after sufficient projectile travel")
 for i in 50:
  var choices:=RushBalance.choices({},false)
  check(choices.any(func(entry):return entry.get("tag","")=="RANGED"),"level choices retain a ranged option")
 fresh();actor=target(Vector3(0,0,-2));game.technique_id="pulse";game.technique();var q_clock:float=game.technique_clock;game.special_charge=100;game.special()
 check(game.records.casts_pulse==1 and game.records.ultimates==1 and game.technique_clock==q_clock,"E neither recasts equipped Q nor resets its cooldown")
 check(game.ultimate.family=="rupture" and game.ultimate.damage_scale()==1.35 and actor.health<1000,"brawler E creates ground impact and temporary empowered punches")
 game.ultimate.update(game,4.1);check(game.ultimate.damage_scale()==1,"ultimate empowerment expires")
 fresh("zephyr");actor=target();game.special_charge=100;game.special()
 for i in 155:game.ultimate.update(game,.02)
 check(is_equal_approx(actor.health,886),"Skyfall delivers exactly three timed strikes")
 fresh("aegis");game.special_charge=100;game.special()
 check(game.ultimate.family=="siege" and game.ultimate.weapon_cooldown()==.65,"robot E enables temporary siege weapon tempo")
 game.support.begin(store);var snap:Dictionary=JSON.parse_string(JSON.stringify(RushRunSnapshot.capture(game)))
 check(RushRunSnapshot.valid(snap),"new companion arsenal and ultimate timers round-trip through JSON")
 RushRunSnapshot.restore(game,snap);check(game.ultimate.family=="siege" and game.ultimate.remaining==4,"resume preserves active ultimate rather than renewing its duration")
 for key in ["support","arsenal","ultimate"]:snap.erase(key)
 check(RushRunSnapshot.valid(snap),"older runs without new systems can still resume")
 var fighter:=RushRoster.character("atlas")
 for level in range(1,31):
  var current:=RushTraining.value(fighter,"footwork",level);var previous:=RushTraining.value(fighter,"footwork",level-1)
  check(current>previous and current-previous<=.022,"GYM speed increases stay small at every rank")
 check(is_equal_approx(RushTraining.value(fighter,"footwork",30)/fighter.speed,1.15),"max permanent speed gain capped at 15 percent")
 var data:=store.data.duplicate(true);data.progress={"badges":{"ko_0":true}}
 RushAchievements.evaluate(data);check(RushAchievements.rank(data,"ko_0")==1,"earned legacy badges retain Bronze")
 data.progress.total_kos=300;RushAchievements.evaluate(data);check(RushAchievements.rank(data,"ko_0")==1,"Silver objective alone cannot bypass match gates")
 data.progress.clears_sprint=5;data.progress.boss_kos=5;RushAchievements.evaluate(data);check(RushAchievements.rank(data,"ko_0")==2,"Silver requires objective plus five wins and five bosses")
 data.progress.total_kos=600;data.progress.clears_sprint=15;data.progress.boss_kos=30;RushAchievements.evaluate(data);check(RushAchievements.rank(data,"ko_0")==2,"Gold additionally requires hard-mode wins")
 data.progress.clears_hell=2;RushAchievements.evaluate(data);check(RushAchievements.rank(data,"ko_0")==3 and RushAchievements.evaluate(data).is_empty(),"Gold unlock is staged and idempotent")
 for entry in RushReleaseInfo.credits():
  check(entry.url.begins_with("https://") and not entry.author.is_empty(),"every credit has an author and primary source")
  if not entry.license.is_empty():check(FileAccess.file_exists(entry.license),"credit license is bundled: "+entry.title)
 check(RushReleaseInfo.config().support_email=="support@zxlabs.dev" and RushReleaseInfo.version().contains(RushReleaseInfo.config().version),"settings use actual supplied support and release version")
 for resolution in [Vector2i(320,568),Vector2i(540,960),Vector2i(768,1024)]:
  root.size=resolution;game.go_home();game.hud.equipment();await settle()
  check(game.hud.page_body.find_children("Equip_*","Button",true,false).size()==6,"six equipment cards remain reachable: "+str(resolution))
  for b in game.hud.page_body.find_children("Equip_*","Button",true,false):check(b.size.x<=game.hud.root.size.x*.5,"equipment card fits half-width column")
  game.hud.settings();await settle();game.hud.credits_page();await settle()
  check(game.hud.current_page=="credits","credits page builds at "+str(resolution))
 # Compare matched locomotion poses with and without an upper-body punch.
 fresh();var reference:=RushBoxer.new();root.add_child(reference);reference.build(true)
 game.player.animate(.01,false);reference.animate(.01,false)
 for i in 20:game.player.animate(.016,true);reference.animate(.016,true)
 var leg_before:Transform3D=game.player.skeleton.get_bone_pose(game.player.skeleton.find_bone("calf_l"))
 game.player.punch()
 for i in 8:game.player.animate(.016,true);reference.animate(.016,true)
 check(not leg_before.is_equal_approx(game.player.skeleton.get_bone_pose(game.player.skeleton.find_bone("calf_l"))),"locomotion continues advancing during punch")
 check(not game.player.skeleton.get_bone_pose(game.player.skeleton.find_bone("upperarm_l")).is_equal_approx(reference.skeleton.get_bone_pose(reference.skeleton.find_bone("upperarm_l"))),"upper-body attack overlays a real different pose")
 for bone in ["pelvis","thigh_l","calf_l","foot_l","thigh_r","foot_r"]:
  var a:int=game.player.skeleton.find_bone(bone);var b:=reference.skeleton.find_bone(bone)
  check(game.player.skeleton.get_bone_pose(a).is_equal_approx(reference.skeleton.get_bone_pose(b)),"walking punch preserves locomotion bone: "+bone)
 check(game.player.body.position.y==0,"ordinary walking punch never lifts actor body above floor")
 reference.queue_free();game.queue_free();await process_frame;await create_timer(.3).timeout
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://longevity-tests.json"+suffix)
 print("LONGEVITY: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
