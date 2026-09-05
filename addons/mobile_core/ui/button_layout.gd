class_name CoreButtonLayout
extends RefCounted
## Geometry only; the host owns text, icons, colors and actions.
static func install(button:Button,glyph:Control) -> void:
 for state in ["normal","hover","pressed","disabled"]:
  var surface:=button.get_theme_stylebox(state).duplicate()
  var inset:=18 if button.text.is_empty() else 53
  surface.content_margin_left=inset;surface.content_margin_right=inset
  button.add_theme_stylebox_override(state,surface)
 button.resized.connect(func():place(button,glyph))
 button.tree_entered.connect(func():place.call_deferred(button,glyph))
static func place(button,glyph) -> void:
 if not is_instance_valid(button) or not is_instance_valid(glyph):return
 if button.get_meta("nav_tile",false):glyph.position=Vector2((button.size.x-glyph.size.x)*.5,12)
 elif button.text.is_empty():glyph.position=(button.size-glyph.size)*.5
 else:glyph.position=Vector2(18,(button.size.y-glyph.size.y)*.5)
