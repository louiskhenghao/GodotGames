extends SceneTree
func _initialize():call_deferred("run")
func run():
 var core:=root.get_node("MobileCore");core.save=CoreSaveStore.new("user://shutdown-test.json")
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 await create_timer(.4).timeout
 game.start_run();game.set_physics_process(false)
 var actual:String=core.save.path
 core.save.path="user://missing-shutdown-directory/save.json"
 game.request_quit()
 assert(not game.shutdown_started,"failed checkpoint must keep the game open")
 core.save.path=actual
 game.request_quit()
 assert(game.shutdown_started,"valid checkpoint starts shutdown")
 var fresh:=CoreSaveStore.new(actual);fresh.load_profile()
 assert(fresh.data.progress.pending_run.id==game.run_id,"normal close persisted the active run")
 print("SHUTDOWN: 3 checks, 0 failures")
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(actual+suffix)
