extends SceneTree
var checks:=0
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,text:String):
 checks+=1
 if not ok:failures+=1;push_error(text)
func run():
 var legacy:=CoreSaveStore.new("user://core-migration-test.json")
 legacy.data.coins=20;legacy.data.progress={"unlocks":{"character:hex":true},"selected_character":"hex","pending_run":{"state":{"character":"hex","run_mode":"hell","enemies":[{"role":"hexer"}]}}}
 check(RushBootstrap.migrate(legacy) and legacy.data.coins==640,"retired hero purchase is refunded")
 check(legacy.data.progress.selected_character=="atlas" and legacy.data.progress.unlocks.get("move:thunder",false),"migration keeps technique and selects human")
 check(legacy.data.progress.pending_run.state.character=="atlas" and legacy.data.progress.pending_run.state.enemies[0].role=="spark","existing fight migrates without creature actors")
 check(RushBootstrap.migrate(legacy) and legacy.data.coins==640,"migration refund is idempotent")
 for id in ["rattle","shade","hex"]:
  check(not RushRoster.owned(legacy,"character",id) and not RushRoster.equip(legacy,"character",id),"retired hero cannot be equipped: "+id)
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://core-migration-test.json"+suffix)
 print("HOST MIGRATION: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
