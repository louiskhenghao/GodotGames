class_name RushArenaLayout
extends RefCounted
## Convex play boundaries and circular blockers shared by movement, spawning and previews.
const SCALE:=1.30
static func polygon(stage:int) -> PackedVector2Array:
	var points:=base_polygon(stage)
	for i in points.size():points[i]*=SCALE
	return points
static func blockers(stage:int) -> Array[Vector3]:
	var result:=base_blockers(stage)
	for i in result.size():result[i]*=SCALE
	return result
static func base_polygon(stage: int) -> PackedVector2Array:
	match stage:
		1:return PackedVector2Array([Vector2(-4.6,-8.7),Vector2(4.6,-8.7),Vector2(4.6,8.7),Vector2(-4.6,8.7)])
		6:return PackedVector2Array([Vector2(-8,-4),Vector2(-4,-8),Vector2(5,-7),Vector2(8,-2),Vector2(7,5),Vector2(1,8),Vector2(-6,6)])
		7:return PackedVector2Array([Vector2(-6,-9),Vector2(6,-9),Vector2(6,9),Vector2(-6,9)])
		8:return PackedVector2Array([Vector2(-10,-4),Vector2(-8,-6),Vector2(8,-6),Vector2(10,-4),Vector2(10,4),Vector2(8,6),Vector2(-8,6),Vector2(-10,4)])
		2,5:
			var points:=PackedVector2Array()
			for i in 8:points.append(Vector2.from_angle(i*TAU/8+PI/8)*(8.2 if stage==5 else 6.8))
			return points
		3:return PackedVector2Array([Vector2(-8.5,-4.5),Vector2(8.5,-4.5),Vector2(8.5,4.5),Vector2(-8.5,4.5)])
		4:return PackedVector2Array([Vector2(-5.5,-4.6),Vector2(0,-7),Vector2(5.5,-4.6),Vector2(6,3),Vector2(0,6.8),Vector2(-6,3)])
		_:return PackedVector2Array([Vector2(-6.05,-6.05),Vector2(6.05,-6.05),Vector2(6.05,6.05),Vector2(-6.05,6.05)])
static func base_blockers(stage: int) -> Array[Vector3]:
	match stage:
		1:return [Vector3(-2.6,-3.5,.72),Vector3(2.6,3.5,.72)]
		2:return [Vector3(-3.5,1.6,.8),Vector3(3.5,-1.6,.8)]
		3:return [Vector3(-4.0,-1.5,.9),Vector3(4.0,1.5,.9)]
		6:return [Vector3(-3.8,-2,.85),Vector3(3.4,2,1.0),Vector3(-1.2,4.6,.7)]
		7:return [Vector3(-3.2,-3,.8),Vector3(3.2,-3,.8),Vector3(-3.2,3.6,.8),Vector3(3.2,3.6,.8)]
		8:return [Vector3(-5,-2,.9),Vector3(5,2,.9),Vector3(0,-3.8,.85)]
		5:return [Vector3(-4,-2,.85),Vector3(4,-2,.85),Vector3(0,4,.9)]
		4:return [Vector3(-3.2,-1.6,.72),Vector3(3.2,-1.6,.72),Vector3(0,3.5,.75)]
		_:return []
static func constrain(at: Vector3, stage: int, radius: float=.34) -> Vector3:
	var p:=Vector2(at.x,at.z)
	var poly:=polygon(stage)
	for pass_index in 3:
		for i in poly.size():
			var a:=poly[i]
			var b:=poly[(i+1)%poly.size()]
			var inward:=Vector2(-(b-a).y,(b-a).x).normalized()
			if inward.dot(-(a+b)*.5)<0:inward=-inward
			var distance:float=(p-a).dot(inward)
			if distance<radius:p+=inward*(radius-distance)
		for obstacle in blockers(stage):
			var center:=Vector2(obstacle.x,obstacle.y)
			var away:=p-center
			if away.length()<obstacle.z+radius:
				p=center+(away.normalized() if away.length()>.001 else Vector2.RIGHT)*(obstacle.z+radius)
	return Vector3(p.x,at.y,p.y)
static func move(from: Vector3, displacement: Vector3, stage: int, radius: float=.34) -> Vector3:
	var steps:=maxi(1,ceili(displacement.length()/.22))
	var at:=from
	for i in steps:at=constrain(at+displacement/steps,stage,radius)
	return at
static func steer(from: Vector3, target: Vector3, stage: int) -> Vector3:
	var direction:=(target-from).normalized()
	for obstacle in blockers(stage):
		var center:=Vector3(obstacle.x,0,obstacle.y)
		var delta:=center-from
		if delta.length()>obstacle.z+1.4 or delta.dot(direction)<0:continue
		var closest:=Geometry3D.get_closest_point_to_segment(center,from,target)
		if closest.distance_to(center)>obstacle.z+.5:continue
		var outward:=(from-center).normalized()
		var tangent:=Vector3(-outward.z,0,outward.x)
		if tangent.dot(direction)<0:tangent=-tangent
		return (tangent+outward*.24+direction*.25).normalized()
	return direction
static func spawn_point(stage: int, angle: float) -> Vector3:
	var poly:=polygon(stage)
	var direction:=Vector2.from_angle(angle)
	var nearest:=direction*30
	for i in poly.size():
		var hit=Geometry2D.segment_intersects_segment(Vector2.ZERO,direction*30,poly[i],poly[(i+1)%poly.size()])
		if hit!=null and hit.length()<nearest.length():nearest=hit
	return constrain(Vector3(nearest.x,0,nearest.y),stage,.42)
