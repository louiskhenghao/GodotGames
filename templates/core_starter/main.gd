extends Control
## A standalone host proving that mobile_core does not import Ring Rush.
var status:Label
func _ready():
 MobileCore.configure_commerce({"demo_coins":{"coins":50}},{"demo_reward":10})
 var column:=VBoxContainer.new();column.position=Vector2(28,50);column.size=Vector2(484,750);column.add_theme_constant_override("separation",24);add_child(column)
 var heading:=Label.new();heading.text="YOUR NEXT GAME";heading.add_theme_font_size_override("font_size",34);column.add_child(heading)
 status=Label.new();column.add_child(status);_refresh()
 var note:=Label.new();note.text="Standalone core example. Test transactions only.";note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(note)
 for entry in [["TEST PURCHASE",func():MobileCore.commerce.buy("demo_coins")],["TEST REWARDED AD",func():MobileCore.commerce.reward("demo_reward")],["IN-GAME NOTICE",func():MobileCore.notices.post("Ready for your game.")]]:
  var button:=Button.new();button.text=entry[0];button.custom_minimum_size.y=64;button.pressed.connect(entry[1]);column.add_child(button)
 MobileCore.save.changed.connect(_refresh)
 MobileCore.notices.posted.connect(func(text):note.text=text)
 MobileCore.commerce.completed.connect(func(_ok,text):MobileCore.notices.post(text))
 var capabilities:=Label.new();capabilities.text="OS reminders: plug in a platform provider.";column.add_child(capabilities)
 print("CORE STARTER READY: ",MobileCore.save.path)
func _refresh():status.text="Coins: %d"%MobileCore.save.data.coins
