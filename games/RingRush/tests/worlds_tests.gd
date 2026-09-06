extends SceneTree
var checks:=0
var failures:=0
var game:Node3D
var store:CoreSaveStore
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;push_error(message)
func settle():
 for i in 6:await process_frame
func fresh(stage_id:int,mode_id:String="sprint"):
 game._clear_combat();game.mode="playing";game.stage=stage_id;game.run_mode=mode_id;game.wave=1;game.director.begin(mode_id)
 game.player.position=Vector3.ZERO;game.hp=1000;game.max_hp=1000;game.damage=1;game.ranks={};game.growth={"skill_level":1}
 game.remaining=90;game.elapsed=0;game.boss_spawned=false;game.boss_defeated=false;game.spawn_clock=0;game.attack_clock=100;game.checkpoint_clock=1000;game.invulnerable=100
 game.arena.showroom(false);game.arena.set_stage(stage_id)
func run():
 root.size=Vector2i(540,960)
 store=CoreSaveStore.new("user://worlds-tests.json");root.get_node("MobileCore").save=store
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 check(RushChallenges.ROUTE==[0,1,2,3,4,6,7,8] and RushChallenges.SECRET_STAGE==5,"normal progression preserves old stage IDs and skips secret Rift")
 check(game.arena.venues.size()==9,"all nine venues are constructed")
 check(RushChallenges.cycle(4,1)==6 and RushChallenges.cycle(8,1)==0 and RushChallenges.cycle(0,-1)==8,"venue carousel visits all eight ordinary maps")
 for stage_id in RushChallenges.ROUTE:
  check(RushChallenges.available(store,"sprint",stage_id)==(stage_id==0),"new profile venue gate: "+str(stage_id))
 store.data.progress.unlocked_stage=8
 check(not RushChallenges.available(store,"sprint",5) and not RushChallenges.available(store,"rift",8),"secret and ordinary venues cannot cross modes")
 for stage_id in range(9):
  var family:=RushEncounterRoster.allowed(stage_id)
  var seen:Dictionary={}
  for wave in [1,3,10,30,50]:
   for i in 30:seen[RushEncounterRoster.pick(stage_id,wave,i)]=true
  check(seen.keys().all(func(role):return role in family) and seen.size()==family.size(),"encounter rotation covers precisely the venue family: "+str(stage_id))
  if stage_id==0:check(seen.keys().all(func(role):return role not in RushCreatureModel.TYPES),"boxing arena has no wild or mechanical monsters")
  if stage_id!=5:check(not seen.has("bone") and not seen.has("revenant") and not seen.has("hexer"),"skeleton enemies remain exclusive to Rift: "+str(stage_id))
  for mode_id in ["sprint","classic","hell","blitz"] if stage_id!=5 else ["rift"]:
   fresh(stage_id,mode_id)
   for wave in [1,5,15]:
    game.wave=wave;game.director.number=wave;game.director.spawned=1;game.director.quota=40;game.director.clearing=false
    for i in 10:game.spawn_clock=0;game._simulate(.001)
   check(not game.enemies.is_empty() and game.enemies.all(func(actor):return actor.role in family),"actual spawn loop respects biome: %s / %d"%[mode_id,stage_id])
  game.arena.set_stage(stage_id)
  for i in range(1,9):check(game.arena.venues[i].visible==(i==stage_id),"only chosen scenery is visible: %d/%d"%[stage_id,i])
  for angle in [0,PI/3,PI,PI*1.7]:
   var point:=RushArenaLayout.spawn_point(stage_id,angle)
   check(Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),RushArenaLayout.polygon(stage_id)),"spawn sits inside venue: "+str(stage_id))
  for obstacle in RushArenaLayout.blockers(stage_id):
   var center:=Vector3(obstacle.x,0,obstacle.y)
   var point:=RushArenaLayout.constrain(center,stage_id)
   check(point.distance_to(center)>=obstacle.z+.339,"movement respects visible blocker: "+str(stage_id))
   check(RushRangedCombat._wall_fraction(center+Vector3.LEFT*2,center+Vector3.RIGHT*2,stage_id,0)<1,"projectile cannot pass through visible blocker: "+str(stage_id))
 for stage_id in [6,7,8]:
  fresh(stage_id);game.wave=5
  var boss:RushBoxer=game._spawn(Vector3(0,0,-3),"boss");game.boss=boss
  check(boss.role=="boss" and boss.is_nonhuman() and boss.boss_appearance==RushEncounterRoster.boss_model(stage_id),"biome boss keeps mechanics with a matching creature silhouette: "+str(stage_id))
  boss.max_health=10000;boss.health=4900;game._update_enemy(boss,.01)
  check(boss.encounter.phase==2,"biome boss enters phase two: "+str(stage_id))
  boss.encounter.roar=0;boss.encounter._begin(game,boss,"slam");boss.encounter.windup=.32
  game.technique_id="quake";game.technique_clock=0;game.technique()
  check(boss.encounter.stagger>0,"biome boss preserves the skill guard-break window: "+str(stage_id))
  var state:Dictionary=JSON.parse_string(JSON.stringify(RushRunSnapshot.capture(game)))
  check(RushRunSnapshot.valid(state),"new-stage save is valid: "+str(stage_id))
  RushRunSnapshot.restore(game,state)
  check(game.boss!=null and game.boss.is_nonhuman() and game.stage==stage_id,"biome boss appearance survives resume: "+str(stage_id))
  game.boss.begin_defeat(Vector3.FORWARD);game.boss.animate_defeat(.5,0)
  game.boss.configure("rookie")
  check(not game.boss.is_nonhuman() and game.boss.boss_appearance.is_empty() and game.boss.crowd_mesh.visible,"pooled biome boss resets to ordinary human")
 fresh(0);game.wave=4
 for role in ["hound","spitter","wisp","drone"]:game._spawn(Vector3(1,0,-3),role)
 var legacy:=RushRunSnapshot.capture(game)
 check(RushRunSnapshot.valid(legacy),"old cross-biome save stays resumable")
 RushRunSnapshot.restore(game,legacy)
 check(game.enemies.all(func(actor):return actor.role in RushEncounterRoster.allowed(0)),"restoring 0.7 wolves in gym substitutes appropriate opponents")
 check(game.enemies.size()==4 and game.wave==4,"legacy adaptation keeps combat progress and enemy count")
 fresh(8);game._spawn(Vector3(0,0,-3),"sentry")
 var current:=RushRunSnapshot.capture(game);RushRunSnapshot.restore(game,current)
 check(game.enemies[0].role=="sentry","new sentry survives JSON-safe restore")
 var progress_store:=CoreSaveStore.new("user://worlds-progress.json")
 for stage_id in RushChallenges.ROUTE:
  check(RushProgress.settle(progress_store,"world-"+str(stage_id),0,stage_id,0,true),"venue settlement saves")
  check(int(progress_store.data.progress.unlocked_stage)==RushChallenges.next_stage(stage_id),"win unlocks next ordinary venue")
 var old_store:=CoreSaveStore.new("user://worlds-migration.json");old_store.data.progress={"unlocked_stage":4,"wins_4":1}
 check(RushBootstrap.prepare(old_store) and old_store.data.progress.unlocked_stage==6,"previous temple winners receive earned forest access")
 check(RushBootstrap.prepare(old_store) and old_store.data.progress.unlocked_stage==6,"world migration is idempotent")
 fresh(0,"ladder")
 check(game.director.target==40,"new world ladder has forty waves")
 for wave in [6,11,16,21,26,31,36]:
  game._clear_combat();game.wave=wave-1;game.director.number=wave-1;game.director.clearing=true;game.director.rest=0;game.xp=0;game.xp_needed=10
  game._advance_waves(.01)
  check(game.stage==RushChallenges.ladder_stage(wave) and game.stage!=5,"ladder transition follows ordinary route: "+str(wave))
 fresh(4,"ladder");game.wave=22;game.director.number=22;game.director.target=25
 var old_ladder:=RushRunSnapshot.capture(game);RushRunSnapshot.restore(game,old_ladder)
 check(game.director.target==25 and game.stage==4,"existing twenty-five-wave ladder is not extended mid-run")
 store.data.coins=10000;RushEquipment.buy(store,"medic");RushEquipment.buy(store,"fox");RushEquipment.equip(store,"air","medic");RushEquipment.equip(store,"ground","fox")
 for size in [Vector2i(320,568),Vector2i(540,960),Vector2i(768,1024)]:
  root.size=size;game.go_home();await settle()
  var nav:Control=game.hud.screen.find_child("SideNavigation",true,false)
  var growth:Control=game.hud.screen.find_child("HomeGrowthNavigation",true,false)
  var play:Control=game.hud.screen.find_child("HomePlay",true,false)
  check(growth.get_global_rect().position.y>=nav.get_global_rect().end.y+8 and play.get_global_rect().position.y>=growth.get_global_rect().end.y+8,"growth controls sit below main navigation and above Play: "+str(size))
  check(growth.find_child("HomeEquipment",true,false)!=null and growth.find_child("HomeBadges",true,false)!=null,"companion and badge entries belong to growth row")
  check(play.get_global_rect().end.y<=game.hud.root.size.y,"home actions stay inside viewport")
  game.hud.equipment_filter="ALL";game.hud.equipment();await settle()
  var fixed:Control=game.hud.screen.find_child("EquippedLoadout",true,false)
  var catalog:ScrollContainer=game.hud.page_body.get_parent()
  check(fixed.get_global_rect().end.y+8<=catalog.get_global_rect().position.y,"pinned preview does not overlap catalog: "+str(size))
  check(catalog.size.y>=game.hud.root.size.y*.35,"catalog leaves enough browsing space: "+str(size))
  var air:Control=fixed.find_child("EquippedCard_air",true,false)
  var image:TextureRect=air.find_child("EquippedPreview",true,false)
  check(image.texture.resource_path.ends_with("helper.png") and image.size.y>=80,"equipped medic image is visible immediately")
  var original:=fixed.global_position;catalog.scroll_vertical=500;await settle()
  check(fixed.global_position==original and image.is_visible_in_tree(),"scrolling catalog never hides equipped companion")
  check(game.hud.page_body.find_children("Equip_*","",true,false).size()==6,"all six companions remain browseable")
  var choose:Button=air.find_child("Choose_air",true,false);choose.pressed.emit();await settle()
  check(game.hud.page_body.find_children("Equip_*","",true,false).size()==3 and game.hud.equipment_filter=="AIR","Change filters catalog to the corresponding slot")
  game.hud.screen.find_child("Remove_ground",true,false).pressed.emit();await settle()
  check(RushEquipment.selected(store,"ground").is_empty() and game.hud.screen.find_child("Remove_ground",true,false)==null,"empty slot shows Choose instead of a redundant Remove")
  RushEquipment.equip(store,"ground","fox")
 game.queue_free();await process_frame;await create_timer(.3).timeout
 for path in ["worlds-tests","worlds-progress","worlds-migration"]:
  for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://"+path+".json"+suffix)
 print("WORLDS & LOADOUT: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
