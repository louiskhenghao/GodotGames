class_name RushFrontierVenues
extends RefCounted
## Original batched scenery. Visible obstacles share the movement/projectile layout.
static func part(parts:Array,shape:String,size:Vector3,at:Vector3,color:String,rotation:Vector3=Vector3.ZERO):
 var piece:=RushModelFactory.piece(shape,size,at,Color(color));piece.rotation=rotation;parts.append(piece)
static func build(arena:RushArena,index:int) -> Node3D:
 var venue:=Node3D.new();venue.name=["Wildwood","HollowGraveyard","OrbitalStation"][index-6];arena.add_child(venue)
 arena._floor(venue,index,[Color("708451"),Color("3a5557"),Color("344a63")][index-6])
 var parts:Array=[]
 match index:
  6:forest(parts)
  7:graveyard(parts)
  8:station(parts)
 for obstacle in RushArenaLayout.base_blockers(index):
  var at:=Vector3(obstacle.x,0,obstacle.y)
  if index==6:
   part(parts,"sphere",Vector3(obstacle.z*1.8,1.2,obstacle.z*1.8),at+Vector3.UP*.4,"778677")
   part(parts,"sphere",Vector3(obstacle.z*1.3,.25,obstacle.z*1.1),at+Vector3.UP*.96,"8ba368")
  elif index==7:
   part(parts,"cylinder",Vector3(obstacle.z*1.7,.18,obstacle.z*1.7),at+Vector3.UP*.09,"516d70")
   part(parts,"box",Vector3(1,.8,.5),at+Vector3.UP*.48,"92b3ab")
   part(parts,"sphere",Vector3(1,.4,.5),at+Vector3.UP*.87,"92b3ab")
   part(parts,"box",Vector3(.06,.33,.035),at+Vector3(0,.56,.27),"344b54")
   part(parts,"box",Vector3(.28,.06,.035),at+Vector3(0,.61,.27),"344b54")
  else:
   part(parts,"box",Vector3(obstacle.z*1.5,1.2,obstacle.z*1.5),at+Vector3.UP*.6,"5b7792")
   part(parts,"box",Vector3(obstacle.z*1.55,.09,obstacle.z*1.55),at+Vector3.UP*1.21,"abc7d7")
   part(parts,"box",Vector3(.18,.65,.04),at+Vector3(.32,.6,obstacle.z*.76),"ffd477")
 arena._batch(venue,parts,8)
 if index==8:
  arena._sign(venue,"ORBITAL / 09",Vector3(0,3,-8.6),Color("81dfff"))
  arena._sign(venue,"CARGO   //   KEEP CLEAR",Vector3(0,.025,3.2),Color("7087a1"),true)
 elif index==7:arena._sign(venue,"HOLLOW",Vector3(0,2.7,-10.1),Color("a5c5bb"))
 venue.scale=Vector3(RushArenaLayout.SCALE,1,RushArenaLayout.SCALE)
 venue.visible=false
 return venue
static func forest(parts:Array):
 part(parts,"cylinder",Vector3(40,.22,40),Vector3(0,-.38,0),"344e3d")
 # Stepping stones lead through the clearing, leaving the centre legible for VFX.
 for i in 13:
  part(parts,"sphere",Vector3(1.4,.08,.9),Vector3(sin(i*.75)*1.6,.015,-7.3+i*1.16),"9a9c71")
 for i in 32:
  var angle:=i*TAU/32
  var radius:=10.0+(i%3)*1.4
  var at:=Vector3(cos(angle)*radius,0,sin(angle)*radius)
  var tall:=at.z<1 and at.x<5
  var height:=4.8+(i%3)*.5 if tall else 2.2+(i%2)*.4
  part(parts,"cylinder",Vector3(.46,height,.46),at+Vector3.UP*height*.5,"644c39")
  for tier in 3:
   var width:=3.1-tier*.65
   part(parts,"cone",Vector3(width,height*.57,width),at+Vector3.UP*(height*.53+tier*height*.19),["315f49","407655","548861"][tier])
  part(parts,"sphere",Vector3(1.5,.5,1.4),at+Vector3(.4,.1,.6),"527948")
 for i in 65:
  var angle:=i*2.399
  var at:=Vector3(cos(angle)*(8.6+i%5*.6),.10,sin(angle)*(8.6+i%5*.6))
  part(parts,"cone",Vector3(.3,.55,.3),at,"abc277" if i%4==0 else "6b9956")
  if i%5==0:
   part(parts,"cylinder",Vector3(.09,.35,.09),at+Vector3.UP*.1,"bfaa81")
   part(parts,"sphere",Vector3(.4,.15,.4),at+Vector3.UP*.3,"dfaa70")
 # A fallen trunk and low boulders outside the traversable edge.
 part(parts,"cylinder",Vector3(.8,4.4,.8),Vector3(8.7,.25,4),"6d5037",Vector3(0,0,PI/2))
 part(parts,"cylinder",Vector3(.67,.025,.67),Vector3(6.49,.25,4),"c9aa79",Vector3(0,0,PI/2))
 for i in 7:part(parts,"sphere",Vector3(2+i%2,.9,1.4),Vector3(-7+i*2.2,-.05,9.8),"5b7767")
static func graveyard(parts:Array):
 part(parts,"box",Vector3(28,.18,32),Vector3(0,-.33,0),"253c41")
 for i in 20:
  part(parts,"box",Vector3(2,.03,.73),Vector3(.07*sin(i),.01,-8.4+i*.88),"53686a")
 for side in [-1,1]:
  for i in 7:
   var at:=Vector3(side*7.8,0,-7.6+i*2.5)
   part(parts,"box",Vector3(1.2,.12,1.85),at+Vector3(0,0,.4),"526561")
   part(parts,"box",Vector3(.9,.72,.25),at+Vector3(0,.37,-.3),"81978f")
   part(parts,"sphere",Vector3(.9,.36,.26),at+Vector3(0,.74,-.3),"81978f")
   part(parts,"box",Vector3(.55,.035,.03),at+Vector3(0,.46,-.16),"435955")
  for i in 9:
   var height:=.35+(i%3)*.17
   part(parts,"box",Vector3(.4,height,1.6),Vector3(side*6.65,height*.5,-8+i*2),"526b69")
  # Lanterns and the cemetery gate.
  for z in [-9.6,9.6]:
   part(parts,"box",Vector3(.55,1.9,.55),Vector3(side*3, .95,z),"506d70")
   part(parts,"box",Vector3(.33,.44,.33),Vector3(side*3,2.05,z),"a1e5cf")
  for i in 4:
   var at:=Vector3(side*(10.2+i%2),0,-8+i*5)
   part(parts,"cylinder",Vector3(.28,3.4,.28),at+Vector3.UP*1.7,"49534e")
   for branch in [-1,1]:
    part(parts,"cylinder",Vector3(.16,1.7,.16),at+Vector3(branch*.52,2.4,0),"49534e",Vector3(.2,0,branch*-.7))
 part(parts,"box",Vector3(4.5,2.6,2.5),Vector3(0,1.2,-11.3),"536a6b")
 part(parts,"box",Vector3(5,.28,2.9),Vector3(0,2.62,-11.3),"8ca59c")
 part(parts,"box",Vector3(1.55,2.1,.05),Vector3(0,.98,-10.02),"142e38")
 for side in [-1,1]:
  part(parts,"cylinder",Vector3(.32,2.4,.32),Vector3(side*1.65,1.2,-9.98),"9cb1a4")
static func station(parts:Array):
 # Deck cutout / void makes the silhouette different from ground venues.
 part(parts,"box",Vector3(70,.2,70),Vector3(0,-2.2,0),"080f21")
 for x in range(-8,9,2):
  part(parts,"box",Vector3(.035,.025,10),Vector3(x,.01,0),"24374e")
 for z in [-4,-2,0,2,4]:part(parts,"box",Vector3(18,.025,.035),Vector3(0,.01,z),"24374e")
 for side in [-1,1]:
  part(parts,"box",Vector3(17,.3,1.1),Vector3(0,-.02,side*6.5),"607b95")
  part(parts,"box",Vector3(16,.035,.1),Vector3(0,.15,side*6.02),"73d9f3")
  for i in 6:
   part(parts,"box",Vector3(.35,.028,.75),Vector3(-7.5+i*3,.02,side*5.25),"d7ba7a",Vector3(0,-.5,0))
 for side in [-1,1]:
  for z in [-4.5,4.5]:
   part(parts,"box",Vector3(1.1,1.3,1.1),Vector3(side*11,.3,z),"405973")
   part(parts,"box",Vector3(.09,1.4,.1),Vector3(side*10.42,.4,z+.3),"76e6f0")
 # Back bulkhead frames a view into space; no tall front wall hides combat.
 for x in [-8,-4,4,8]:
  part(parts,"box",Vector3(.5,3.6,.6),Vector3(x,1.4,-8.7),"55718c")
  part(parts,"box",Vector3(.09,2.6,.08),Vector3(x-.26,1.4,-8.36),"87d9ee")
 part(parts,"box",Vector3(18,.5,.8),Vector3(0,3.5,-8.7),"7192b0")
 part(parts,"sphere",Vector3(7,7,7),Vector3(-9,1,-21),"346c91")
 part(parts,"sphere",Vector3(6.7,6.7,6.7),Vector3(-9.7,1.1,-21.5),"122c50")
 for i in 90:
  var x:=sin(i*2.399)*30;var z:=-14.0-fmod(i*3.17,20)
  part(parts,"sphere",Vector3.ONE*(.055+float(i%3)*.026),Vector3(x,1+i%9*.65,z),"b4d2f1")
