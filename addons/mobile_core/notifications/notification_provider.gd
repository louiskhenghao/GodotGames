class_name CoreNotificationProvider
extends Node
## OS adapters own permission prompts, scheduling, deep links and cancellation.
## No automatic prompt; permission is requested only through an explicit host action.
signal permission_changed(granted:bool)
var supported:=false
var authorized:=false
func request_permission() -> void:permission_changed.emit(false)
func schedule(_id:String,_title:String,_body:String,_at_unix:int,_payload:Dictionary) -> Error:return ERR_UNAVAILABLE
func cancel(_id:String) -> Error:return ERR_UNAVAILABLE
