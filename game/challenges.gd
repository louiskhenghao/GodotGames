class_name RushChallenges
extends RefCounted
const SECRET_STAGE:=5
const SECRET_COST:=600
static func rift_open(store:CoreSaveStore) -> bool:return CoreWallet.owns(store,"mode:rift")
static func unlock_rift(store:CoreSaveStore) -> bool:return CoreWallet.unlock(store,"mode:rift",SECRET_COST)
static func available(store:CoreSaveStore,mode:String,stage:int) -> bool:
 if mode=="rift":return stage==SECRET_STAGE and rift_open(store)
 return stage>=0 and stage<=mini(4,int(store.data.progress.get("unlocked_stage",0)))
