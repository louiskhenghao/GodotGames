class_name RushWardrobe
extends RefCounted
## Bone-bound accessories define silhouettes; two independently modeled human bases.
static func female(id: String) -> bool:return id in ["zephyr","raven"]
static func attach(skeleton: Skeleton3D, bone: String, parts: Array) -> void:
	var socket:=BoneAttachment3D.new()
	skeleton.add_child(socket)
	socket.bone_name=bone
	var mesh:=MeshInstance3D.new()
	mesh.mesh=RushModelFactory.bake(parts,16)
	socket.add_child(mesh)
static func p(size: Vector3, at: Vector3, color: Color, shape: String="sphere") -> Dictionary:
	return RushModelFactory.piece(shape,size,at,color)
static func build(skeleton: Skeleton3D,id: String) -> void:
	var dark:=Color("182230")
	var cream:=Color("eee5c9")
	match id:
		"atlas":
			attach(skeleton,"Head",[p(Vector3(.13,.025,.015),Vector3(.025,.158,.090),Color("f2e5d0"),"box")])
		"zephyr":
			attach(skeleton,"Head",[p(Vector3(.24,.11,.22),Vector3(0,.16,-.02),dark),p(Vector3(.11,.16,.11),Vector3(0,.15,-.14),dark),p(Vector3(.075,.29,.075),Vector3(0,-.03,-.16),dark),p(Vector3(.20,.032,.20),Vector3(0,.13,0),Color("b9a2ef"))])
		"titan":
			attach(skeleton,"Head",[p(Vector3(.27,.13,.27),Vector3(0,.14,0),Color("5c6270")),p(Vector3(.06,.17,.16),Vector3(-.12,.04,0),Color("d4a565")),p(Vector3(.06,.17,.16),Vector3(.12,.04,0),Color("d4a565"))])
			for side in ["l","r"]:
				attach(skeleton,"upperarm_"+side,[p(Vector3(.27,.22,.29),Vector3(0,.015,0),Color("666e77")),p(Vector3(.30,.08,.30),Vector3(0,.035,0),Color("d4a565"))])
			attach(skeleton,"spine_03",[p(Vector3(.49,.34,.18),Vector3(0,.035,.11),Color("575f69")),p(Vector3(.42,.18,.16),Vector3(0,-.13,.10),Color("454e5b")),p(Vector3(.12,.11,.025),Vector3(0,.075,.205),Color("d4a565"))])
		"volt":
			attach(skeleton,"Head",[p(Vector3(.08,.20,.20),Vector3(0,.18,-.03),Color("d7eef1")),p(Vector3(.21,.032,.07),Vector3(0,.12,.086),Color("3d8eaf"),"box")])
			for side in ["l","r"]:attach(skeleton,"lowerarm_"+side,[p(Vector3(.15,.18,.15),Vector3(0,.19,0),Color("3b4c64")),p(Vector3(.17,.035,.17),Vector3(0,.20,0),Color("70dfff"))])
		"raven":
			attach(skeleton,"Head",[p(Vector3(.26,.18,.24),Vector3(0,.14,-.05),dark),p(Vector3(.19,.068,.08),Vector3(0,.063,.07),Color("692e41")),p(Vector3(.10,.29,.13),Vector3(-.10,.09,-.035),dark)])
			attach(skeleton,"spine_03",[p(Vector3(.16,.42,.06),Vector3(-.12,-.08,-.16),Color("9f435d"),"box"),p(Vector3(.16,.36,.06),Vector3(.10,-.11,-.16),Color("9f435d"),"box")])
		"sol":
			attach(skeleton,"Head",[p(Vector3(.20,.035,.21),Vector3(0,.12,0),Color("db8b40")),p(Vector3(.05,.20,.025),Vector3(.1,.02,-.07),Color("efcf84"),"box"),p(Vector3(.24,.045,.22),Vector3(0,.16,0),dark)])
			attach(skeleton,"pelvis",[p(Vector3(.19,.26,.05),Vector3(.04,-.12,.13),Color("f2db9a"),"box")])
