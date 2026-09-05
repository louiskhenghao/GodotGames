class_name CoreWallet
extends RefCounted
## Idempotent currency unlock. The host must validate its product catalog first.
static func owns(store:CoreSaveStore,key:String) -> bool:
 return store.data.progress.get("unlocks",{}).get(key,false)
static func unlock(store:CoreSaveStore,key:String,cost:int) -> bool:
 if key.is_empty() or cost<0:return false
 if owns(store,key):return true
 if store.data.coins<cost:return false
 var next:=store.data.duplicate(true)
 next.coins-=cost
 if not next.progress.has("unlocks"):next.progress.unlocks={}
 next.progress.unlocks[key]=true
 return store.commit(next)
