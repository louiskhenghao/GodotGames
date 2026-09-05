class_name CoreNoticeBus
extends Node
## In-game notices. Presentation and localization belong to the host UI.
signal posted(text:String)
func post(text:String) -> void:
 if not text.strip_edges().is_empty():posted.emit(text)
