extends SceneTree
var checks:=0
var failures:=0
var game:Node3D
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;push_error(message)
func fresh() -> RushBoxer:
 game._clear_combat();game.mode="playing";game.hp=1000;game.max_hp=1000
 game.player.position=Vector3.ZERO;game.player.rotation.y=0
 game.damage=20;game.ranks={};game.invulnerable=0;game.dash_clock=0
 game.technique_clock=0;game.technique_id="quake";game.special_charge=0
 game.growth={"skill_level":1};game.stage=0;game.wave=5
 var actor:RushBoxer=game._spawn(Vector3(0,0,-1.5),"boss")
 actor.max_health=10000;actor.health=10000;game.boss=actor
 return actor
func run():
 root.size=Vector2i(540,960)
 var core:=root.get_node("MobileCore");core.save=CoreSaveStore.new("user://boss-tests.json")
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 game.set_process(false);game.set_physics_process(false);game.start_run()
 await process_frame
 var b:=fresh();var ai:RushBossCombat=b.encounter
 b.health=5000;game._update_enemy(b,.01)
 check(ai.phase==2 and ai.roar>0 and ai.windup==0,"half health enters phase two and cancels current attack")
 check(b.health==5000,"phase transition does not refill health")
 game._update_enemy(b,1.0);check(ai.roar==0,"phase entrance has a finite safe pause")
 game._update_enemy(b,.4);check(ai.windup>0 and ai.followup,"phase two opens a two-strike combination")
 var first_target:Vector3=ai.target
 game.player.position=Vector3(5,0,4)
 game._update_enemy(b,.2);check(ai.target==first_target,"committed attack does not track a moving player")
 game._update_enemy(b,1.0);check(game.hp==1000 and ai.cooldown==.5,"leaving the telegraphed slam avoids damage")
 game._update_enemy(b,.51);check(ai.attack_kind=="bolt" and ai.windup>.9 and not ai.followup,"second strike has its own full telegraph and locked target")
 game._update_enemy(b,1.2);check(game.hp<1000 and ai.cooldown>1.5,"second strike resolves once then grants a recovery opening")
 var before:float=game.hp;game._update_enemy(b,.05)
 check(game.hp==before and ai.roar==0,"phase transition and strike are not repeated each frame")
 # All six moves can break, but only a correctly timed cast that actually hits can do so.
 for move in RushRoster.MOVES:
  b=fresh();ai=b.encounter;game.technique_id=move.id
  ai._begin(game,b,"slam");ai.windup=.35;b.windup=.35
  var hp:float=b.health;game.technique()
  for i in 12:game._update_technique(.025)
  check(ai.stagger>0 and ai.windup==0,"skill interrupts the gold window: "+move.id)
  check(b.health<hp and game.special_charge==12,"break grants damage and energy once: "+move.id)
  check(game.technique_clock<game.technique_cooldown(),"successful break refunds part of skill cooldown: "+move.id)
 b=fresh();ai=b.encounter;ai._begin(game,b,"slam")
 game.technique();check(ai.windup>0 and ai.stagger==0 and b.launch_time==0,"early quake hits but cannot freely cancel a boss telegraph")
 b=fresh();ai=b.encounter;ai._begin(game,b,"slam");ai.windup=.35
 game.player.position=Vector3(10,0,0);game.technique()
 check(ai.stagger==0 and game.special_charge==0,"out-of-range cast earns no break")
 b=fresh();ai=b.encounter;ai._begin(game,b,"slam");ai.windup=.35
 game._hit(b,20,true);check(ai.windup>0 and game.special_charge==0,"automatic basic punches do not break")
 ai.arm_break();game._hit(b,4,false)
 check(ai.stagger==0,"burn and passive hits cannot consume a skill break")
 b=fresh();ai=b.encounter;ai.phase=2;ai.followup=true;ai._begin(game,b,"slam");ai.windup=.35
 game.technique();check(not ai.followup and ai.stagger>1.5,"breaking opener cancels the whole combination")
 # Counter belongs to a late dodge inside the committed danger zone.
 b=fresh();ai=b.encounter;ai._begin(game,b,"slam");ai.windup=.24
 game.dash();check(ai.counter_open>2 and ai.dodge_rewarded,"late dodge in danger arms a counter")
 check(not ai.on_dodge(game,b),"same attack cannot reward repeated dodge calls")
 game._hit(b,4,false);check(ai.counter_open>0,"damage-over-time does not consume counter")
 before=b.health;game._hit(b,20,true)
 check(is_equal_approx(before-b.health,50) and ai.counter_open==0 and ai.stagger>0,"next direct hit deals 2.5x and staggers once")
 check(game.special_charge==8,"counter grants bounded energy")
 before=b.health;game._hit(b,20,true)
 check(is_equal_approx(before-b.health,20) and game.special_charge==8,"subsequent hit cannot repeat counter bonus")
 b=fresh();ai=b.encounter;ai._begin(game,b,"slam");game.dash()
 check(ai.counter_open==0,"early dodge gets normal evasion only")
 b=fresh();ai=b.encounter;ai._begin(game,b,"slam");ai.windup=.2;game.player.position=Vector3(8,0,8);game.dash()
 check(ai.counter_open==0,"safe-position dodge cannot farm counters")
 b=fresh();ai=b.encounter;ai._begin(game,b,"slam");ai.windup=.2;game.dash_clock=1;game.dash()
 check(ai.counter_open==0,"unavailable dodge cannot arm counter")
 game.dash_clock=0;game.dash();game.player.position=Vector3(8,0,8)
 game._update_enemy(b,2.3);check(ai.counter_open==0,"unused counter expires")
 b=fresh();ai=b.encounter;ai._begin(game,b,"slam");ai.windup=.24
 game.dash();before=b.health;game.technique()
 check(is_equal_approx(before-b.health,20*2.6*2.5) and game.special_charge==8,"skill after perfect dodge uses the stronger counter exactly once")
 b=fresh();ai=b.encounter;ai._begin(game,b,"slam");ai.windup=.24
 game.dash();game.player.position=Vector3(8,0,8);game._update_enemy(b,.25)
 check(game.hp==1000,"perfect dodge avoids the committed impact")
 # Charge locks direction and uses a swept collision; ranged impacts stay at the marked spot.
 b=fresh();ai=b.encounter;ai._begin(game,b,"charge");ai.windup=.01
 game._update_enemy(b,.02);check(ai.rush>0 and ai.rush_direction==Vector3.BACK,"charge commits to its marked direction")
 before=game.hp;game._update_enemy(b,.4)
 check(game.hp<before,"fast charge collision cannot tunnel through player")
 before=game.hp;game.invulnerable=0;game._update_enemy(b,.1)
 check(game.hp==before,"one charge damages at most once")
 b=fresh();ai=b.encounter;ai._begin(game,b,"bolt");game.player.position=Vector3(6,0,6)
 game._update_enemy(b,1.2);check(game.hp==1000,"ranged strike honors locked marker")
 # Essential warnings and UI remain legible when particles are disabled.
 b=fresh();ai=b.encounter;game.vfx.enabled=false;ai._begin(game,b,"slam");ai.windup=.35
 game._update_enemy(b,.01);game.hud.playing();game.hud.update_stats()
 check(b.warning.visible and b.warning.material_override.albedo_color==RushBossCombat.BREAK,"gold warning persists without decorative VFX")
 check(game.hud.technique_button.caption=="BREAK!","available skill button advertises break window")
 for size in [Vector2i(320,568),Vector2i(540,960),Vector2i(768,1024)]:
  root.size=size
  for i in 8:await process_frame
  game.hud.update_stats()
  check(game.hud.root.get_global_rect().encloses(game.hud.boss_cue.get_global_rect()),"boss cue stays in viewport: "+str(size))
 game.vfx.enabled=true
 # Resume phase and sequence without replaying partial attacks/rewards. Legacy states still load.
 ai.phase=2;ai.sequence=7
 var state:=RushRunSnapshot.capture(game)
 check(RushRunSnapshot.valid(state),"new boss snapshot validates")
 var encoded=JSON.parse_string(JSON.stringify(state))
 check(RushRunSnapshot.valid(encoded),"JSON round trip preserves boss schema")
 RushRunSnapshot.restore(game,encoded)
 check(game.boss.encounter.phase==2 and game.boss.encounter.sequence==7,"resume preserves phase and pattern position")
 check(game.boss.encounter.windup==0 and game.boss.encounter.counter_open==0 and game.boss.encounter.cooldown>=1,"resume gives a fresh attack warning without free counter")
 state.enemies[0].erase("boss_combat");state.enemies[0].health=4000
 check(RushRunSnapshot.valid(state),"older snapshots without boss state remain compatible")
 RushRunSnapshot.restore(game,state)
 check(game.boss.encounter.phase==2,"legacy half-health boss resumes in phase two")
 for bad in [{"phase":3,"sequence":1},{"phase":1,"sequence":-1},{"phase":2,"sequence":1.5},{"phase":2,"sequence":INF}]:
  state.enemies[0].boss_combat=bad
  check(not RushRunSnapshot.valid(state),"invalid boss state rejected: "+str(bad))
 game.boss.configure("rookie")
 check(game.boss.encounter==null,"pooled regular enemy cannot inherit boss state")
 game.go_home();check(game.enemies.is_empty(),"leaving combat removes all encounter actors")
 game.queue_free();await process_frame;await create_timer(.4).timeout
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://boss-tests.json"+suffix)
 print("BOSS COMBAT: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
