class_name CoreMusicPlayer
extends AudioStreamPlayer
## Cue catalog is injected by each game. Unknown cues never stop the current music.
var cues:Dictionary={}
var current_cue:=""
func configure(catalog:Dictionary) -> void:cues=catalog.duplicate()
func play_cue(id:String) -> bool:
 if not cues.has(id):return false
 if current_cue==id and playing:return true
 var next=load(cues[id]) if cues[id] is String else cues[id]
 if not next is AudioStream:return false
 if next is AudioStreamOggVorbis:next.loop=true
 stop();stream=next;current_cue=id;play()
 return true
