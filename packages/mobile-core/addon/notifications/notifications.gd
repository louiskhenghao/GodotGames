class_name CoreNotifications
extends Node
## Inject an Android/iOS/Web provider. Unsupported targets never report fake success.
signal permission_changed(granted:bool)
var provider:CoreNotificationProvider
func configure(adapter:CoreNotificationProvider=null) -> void:
 if provider!=null:
  remove_child(provider);provider.queue_free()
 provider=adapter if adapter!=null else CoreNotificationProvider.new()
 add_child(provider)
 provider.permission_changed.connect(func(granted):permission_changed.emit(granted))
func request_permission() -> bool:
 if provider==null or not provider.supported:return false
 provider.request_permission();return true
func schedule(id:String,title:String,body:String,at_unix:int,payload:Dictionary={}) -> Error:
 if id.is_empty() or title.is_empty() or at_unix<=int(Time.get_unix_time_from_system()):return ERR_INVALID_PARAMETER
 if provider==null or not provider.supported:return ERR_UNAVAILABLE
 if not provider.authorized:return ERR_UNAUTHORIZED
 return provider.schedule(id,title,body,at_unix,payload.duplicate(true))
func cancel(id:String) -> Error:
 return ERR_UNAVAILABLE if provider==null or not provider.supported else provider.cancel(id)
