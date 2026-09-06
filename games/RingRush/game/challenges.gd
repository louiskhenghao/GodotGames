class_name RushChallenges
extends RefCounted
const SECRET_STAGE:=5
const SECRET_COST:=600
# Stable stage IDs: Rift stays at 5 for existing saves.
const ROUTE:=[0,1,2,3,4,6,7,8]
static func rift_open(store:CoreSaveStore) -> bool:return CoreWallet.owns(store,"mode:rift")
static func unlock_rift(store:CoreSaveStore) -> bool:return CoreWallet.unlock(store,"mode:rift",SECRET_COST)
static func available(store:CoreSaveStore,mode:String,stage:int) -> bool:
 if mode=="rift":return stage==SECRET_STAGE and rift_open(store)
 return stage in ROUTE and stage<=int(store.data.progress.get("unlocked_stage",0))
static func next_stage(stage:int) -> int:
 var index:=ROUTE.find(stage)
 return ROUTE[mini(index+1,ROUTE.size()-1)] if index>=0 else 0
static func cycle(stage:int,direction:int) -> int:return ROUTE[posmod(maxi(0,ROUTE.find(stage))+direction,ROUTE.size())]
static func ladder_stage(wave:int) -> int:return ROUTE[clampi((wave-1)/5,0,ROUTE.size()-1)]
static func previous_name(stage:int) -> String:return RushBalance.STAGES[ROUTE[maxi(0,ROUTE.find(stage)-1)]].name
