extends SceneTree
var checks:=0
var failures:=0
func _initialize():call_deferred("run")
func check(value:bool,label:String):
	checks+=1
	if value:print("PASS: "+label)
	else:failures+=1;push_error(label)
func run():
	var core:=root.get_node("MobileCore")
	core.save=CoreSaveStore.new("user://ux-ads-test.json")
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	var provider=core.commerce.provider
	check(provider.is_mock and provider.banner.visible,"home has an explicit development banner")
	game.hud.fighters()
	var first_mesh:Mesh=game.player.skin_mesh.mesh
	game.hud.cycle_fighter(1)
	check(game.player.character_id=="zephyr" and game.player.skin_mesh.mesh!=first_mesh,"carousel previews a genuinely different human mesh")
	check(game.selected_character().id=="atlas","browsing a locked fighter does not equip it")
	game.hud.cycle_fighter(-1)
	check(game.player.character_id=="atlas","carousel cycles back")
	var layouts:={}
	for c in RushRoster.CHARACTERS:
		game.preview_character(c.id)
		layouts[c.id]=game.player.skeleton.get_child_count()
		check(game.player.skin_mesh!=null and game.player.outfit.mesh.get_surface_count()>0,"body and fitted outfit load: "+c.id)
	check(layouts.titan>layouts.atlas,"heavyweight silhouette has extra bone-bound armor")
	game.go_home()
	game.hud.moves()
	check(not game.player.visible and game.hud.current_page=="moves","skill selection hides the background model for legibility")
	var colors:={}
	var icons:={}
	for m in RushRoster.MOVES:
		colors[RushRoster.visual(m.id).color]=true
		icons[RushRoster.visual(m.id).icon]=true
	check(colors.size()==6 and icons.size()==6,"all six skills have distinct icons and semantic colors")
	game.go_home()
	game.start_run()
	await process_frame
	await process_frame
	check(not provider.banner.visible,"no banner covers combat")
	for b in [game.hud.dash_button,game.hud.technique_button,game.hud.special_button]:
		check(b is RushActionButton and b.get_global_rect().get_center().x>game.hud.root.size.x*.52,"round action sits in the right thumb area")
	var touch:=InputEventScreenTouch.new()
	touch.index=0;touch.pressed=true;touch.position=Vector2(95,630)
	game.hud.stick._input(touch)
	var second:=InputEventScreenTouch.new()
	second.index=1;second.pressed=true;second.position=game.hud.technique_button.get_global_rect().get_center()
	game.hud._input(second)
	check(game.technique_clock>0 and game.hud.stick.finger==0,"second finger casts skill without taking the left stick")
	game.hud.stick.reset()
	game.hud.stick._input(second)
	check(game.hud.stick.finger==-1,"right-hand touches never start walking")
	for stage in range(1,5):
		var poly:=RushArenaLayout.polygon(stage)
		var constrained:=RushArenaLayout.move(Vector3.ZERO,Vector3(70,0,50),stage)
		check(Geometry2D.is_point_in_polygon(Vector2(constrained.x,constrained.z),poly),"movement stays within venue shape "+str(stage))
		for obstacle in RushArenaLayout.blockers(stage):
			var center:=Vector3(obstacle.x,0,obstacle.y)
			var at:=RushArenaLayout.move(center-Vector3.RIGHT*2,Vector3.RIGHT*4,stage)
			check(at.distance_to(center)>=obstacle.z+.33 and at.x<center.x,"dash cannot pass through blocker in venue "+str(stage))
			var walker:=center-Vector3.RIGHT*2
			var target:=RushArenaLayout.constrain(center+Vector3.RIGHT*2,stage)
			for step in 240:walker=RushArenaLayout.move(walker,RushArenaLayout.steer(walker,target,stage)*.06,stage)
			check(walker.distance_to(target)<.25,"enemy can navigate around blocker in venue "+str(stage))
		for i in 16:
			var point:=RushArenaLayout.spawn_point(stage,i*TAU/16)
			check(Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),poly),"spawn is inside venue "+str(stage))
	game.hp=0
	game._simulate(.1)
	check(game.mode=="defeat" and game.has_resume(),"knockout offers a resumable extra-life decision")
	game.request_revive()
	check(provider.active!=null,"revive presents an actual development ad screen")
	var id:String=core.commerce.pending.id
	provider.active.request_close()
	check(not core.commerce.pending.is_empty() and game.hp==0,"ad cannot close before the minimum watch time")
	provider.active.advance(5)
	provider.active.request_close()
	check(core.commerce.pending.is_empty() and game.hp==0 and not game.revive_used,"early close after five seconds grants no life")
	core.commerce._on_ad(id,true,"late replay")
	check(game.hp==0,"late earned callback after early close is ignored")
	provider.fail_next=true
	game.request_revive()
	check(game.mode=="defeat" and core.commerce.pending.is_empty(),"no-fill leaves revive available without consuming it")
	game.request_revive()
	id=core.commerce.pending.id
	provider.active.advance(15)
	provider.active.request_close()
	check(game.mode=="paused" and game.revive_used and is_equal_approx(game.hp,game.max_hp*.6),"completed ad grants one sixty-percent revive")
	var health:float=game.hp
	core.commerce._on_ad(id,true,"duplicate")
	check(game.hp==health and core.save.data.get("reward_receipts",{}).is_empty(),"duplicate revive callback cannot grant twice")
	game.resume_run()
	game.hp=0
	game._simulate(.1)
	check(game.mode=="result","second knockout ends the run without another revive")
	game.go_home();game.start_run()
	game.run_coins=100
	game.finish_run(true)
	var balance:int=core.save.data.coins
	game.request_victory_bonus()
	provider.active.advance(15)
	provider.active.request_close()
	check(game.result_bonus_claimed() and core.save.data.coins==balance+ceili(game.run_coins*.5),"victory ad adds exactly fifty percent of the saved result")
	game.request_victory_bonus()
	check(core.commerce.pending.is_empty(),"claimed victory bonus cannot request another ad")
	# Reward videos suppress another automatic ad on the same result.
	core.save.data.progress.runs=3
	game.leave_result()
	check(core.commerce.pending.is_empty(),"rewarded victory never stacks an interstitial")
	game.start_run();game.finish_run(false)
	core.save.data.progress.runs=6
	game.replay_result()
	check(provider.active!=null and not provider.active.rewarded and game.mode=="home","every third result offers an interstitial before replay")
	provider.active.request_close()
	check(game.mode=="home","interstitial close is locked during its minimum duration")
	provider.active.advance(5);provider.active.request_close()
	check(game.mode=="playing" and core.commerce.pending.is_empty(),"interstitial dismissal resumes queued play exactly once")
	game.finish_run(false);game.go_home()
	game.start_run();game.finish_run(false)
	core.save.data.progress.runs=9
	core.commerce.timeout_seconds=.05
	game.replay_result()
	await create_timer(.08).timeout
	check(provider.active==null and game.mode=="playing","ad timeout removes its overlay and resumes queued play")
	core.commerce.timeout_seconds=45
	game.finish_run(false);game.go_home()
	core.commerce.buy("remove_ads")
	await create_timer(.7).timeout
	check(game.ads_removed() and not provider.banner.visible,"permanent remove-ads purchase hides the banner")
	core.save.load_profile()
	check(game.ads_removed(),"remove-ads entitlement survives reload")
	game.start_run();game.hp=0;game._simulate(.1)
	game.request_revive()
	check(provider.active!=null,"ad-free players can still opt into reward videos")
	provider.active.advance(5);provider.active.request_close()
	game.finish_run(false)
	game.leave_result()
	check(core.commerce.pending.is_empty(),"ad-free players never receive automatic interstitials")
	# A durable earned receipt is recoverable even without its original UI callback.
	game.start_run();game.hp=0;game._simulate(.1)
	var next:Dictionary=core.save.data.duplicate(true)
	next.reward_receipts={"restart-receipt":{"placement":"revive","context":{"run_id":game.run_id}}}
	core.save.commit(next);core.save.load_profile()
	var saved_path:String=core.save.path
	core.save.path="user://nonexistent-ad-test-dir/profile.json"
	var failed_claim:=RushAdRewards.claim(core.save,"restart-receipt")
	check(failed_claim.get("retry",false) and core.save.data.reward_receipts.has("restart-receipt"),"failed benefit save retains its earned receipt for retry")
	core.save.path=saved_path
	var malformed:Dictionary=core.save.data.progress.pending_run.state.duplicate(true)
	malformed.knocked_out="yes"
	check(not RushRunSnapshot.valid(malformed),"invalid revive state is rejected on restore")
	var claimed:=RushAdRewards.claim(core.save,"restart-receipt")
	check(claimed.get("ok",false) and core.save.data.progress.pending_run.state.revive_used,"earned ad receipt survives restart and atomically updates the saved run")
	check(not RushAdRewards.claim(core.save,"restart-receipt").get("ok",false),"consumed durable receipt cannot be replayed")
	game.queue_free()
	await process_frame
	await create_timer(.25).timeout
	for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://ux-ads-test.json"+suffix)
	print("UX/ADS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
