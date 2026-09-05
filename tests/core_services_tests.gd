extends SceneTree
var checks:=0
var failures:=0
class NotificationFake extends CoreNotificationProvider:
 var requests:=0
 var scheduled:Dictionary={}
 func _init():supported=true
 func request_permission():requests+=1
 func schedule(id:String,title:String,body:String,at:int,payload:Dictionary) -> Error:
  scheduled[id]={"title":title,"body":body,"at":at,"payload":payload};return OK
 func cancel(id:String) -> Error:scheduled.erase(id);return OK
func _initialize():call_deferred("run")
func check(ok:bool,text:String):
 checks+=1
 if not ok:failures+=1;push_error(text)
func run():
 var store:=CoreSaveStore.new("user://core-services-test.json");store.data.coins=700
 check(CoreWallet.unlock(store,"world:bonus",600),"shared wallet purchases a host key")
 check(CoreWallet.unlock(store,"world:bonus",600) and store.data.coins==100,"shared wallet cannot charge an unlock twice")
 check(not CoreWallet.unlock(store,"world:other",600),"wallet rejects insufficient currency")
 check(not CoreWallet.unlock(store,"",0) and not CoreWallet.unlock(store,"bad",-1),"wallet rejects malformed requests")
 var broken:=CoreSaveStore.new("user://no-core-services-directory/save.json");broken.data.coins=700
 check(not CoreWallet.unlock(broken,"world:bonus",600) and broken.data.coins==700,"failed save cannot grant or spend")
 var notices:=CoreNoticeBus.new();root.add_child(notices)
 var received:Array=[];notices.posted.connect(func(text):received.append(text))
 notices.post(" ");notices.post("Saved")
 check(received==["Saved"],"in-game notices are reusable and ignore empty messages")
 var service:=CoreNotifications.new();root.add_child(service);service.configure()
 var tomorrow:=int(Time.get_unix_time_from_system())+86400
 check(not service.request_permission(),"unsupported OS notification provider never prompts")
 check(service.schedule("daily","Come back","A new round",tomorrow)==ERR_UNAVAILABLE,"unsupported scheduling reports unavailable")
 var fake:=NotificationFake.new();service.configure(fake)
 check(fake.requests==0,"configuring notifications does not request permission")
 check(service.schedule("daily","Come back","",tomorrow)==ERR_UNAUTHORIZED,"OS schedule requires granted permission")
 check(service.request_permission() and fake.requests==1,"permission prompt needs explicit host request")
 fake.authorized=true
 check(service.schedule("daily","Come back","",tomorrow,{"screen":"home"})==OK,"provider receives validated schedule")
 check(service.schedule("daily","Updated","",tomorrow+30)==OK and fake.scheduled.size()==1,"stable notification IDs can be replaced")
 check(service.cancel("daily")==OK and fake.scheduled.is_empty(),"host can cancel a notification")
 check(service.schedule("bad","","",tomorrow-90000)==ERR_INVALID_PARAMETER,"invalid schedule rejected")
 var music:=CoreMusicPlayer.new();root.add_child(music)
 var tone:=AudioStreamGenerator.new();music.configure({"one":tone,"two":AudioStreamGenerator.new()})
 music.volume_db=-80
 check(music.play_cue("one") and music.current_cue=="one","shared player selects injected cue")
 check(not music.play_cue("missing") and music.current_cue=="one","unknown cue does not interrupt current music")
 check(music.play_cue("two") and music.volume_db==-80,"cue changes preserve mute setting")
 var legacy:=CoreSaveStore.new("user://core-migration-test.json")
 legacy.data.coins=20;legacy.data.progress={"unlocks":{"character:hex":true},"selected_character":"hex","pending_run":{"state":{"character":"hex","run_mode":"hell","enemies":[{"role":"hexer"}]}}}
 check(RushBootstrap.migrate(legacy) and legacy.data.coins==640,"retired hero purchase is refunded")
 check(legacy.data.progress.selected_character=="atlas" and legacy.data.progress.unlocks.get("move:thunder",false),"migration keeps technique and selects human")
 check(legacy.data.progress.pending_run.state.character=="atlas" and legacy.data.progress.pending_run.state.enemies[0].role=="spark","existing fight migrates without creature actors")
 check(RushBootstrap.migrate(legacy) and legacy.data.coins==640,"migration refund is idempotent")
 for id in ["rattle","shade","hex"]:
  check(not RushRoster.owned(legacy,"character",id) and not RushRoster.equip(legacy,"character",id),"retired hero cannot be equipped: "+id)
 music.stop();music.stream=null;music.cues.clear();tone=null;music.queue_free();notices.queue_free();service.queue_free()
 await process_frame;await create_timer(.25).timeout
 for path in ["user://core-services-test.json","user://core-migration-test.json"]:
  for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(path+suffix)
 print("CORE SERVICES: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
