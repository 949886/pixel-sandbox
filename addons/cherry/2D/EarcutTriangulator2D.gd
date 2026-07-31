class_name EarcutTriangulator2D
extends RefCounted

# Pure GDScript port of Mapbox Earcut (ISC license).
# Source algorithm: https://github.com/mapbox/earcut
# Stateless and safe to construct/use inside the collision worker thread.

class PolygonNode:
	var index: int
	var x: float
	var y: float
	var prev: PolygonNode = null
	var next: PolygonNode = null
	var z_order: int = 0
	var prev_z: PolygonNode = null
	var next_z: PolygonNode = null
	var steiner: bool = false

	func _init(p_index: int, p_x: float, p_y: float) -> void:
		reset(p_index, p_x, p_y)

	func reset(p_index: int, p_x: float, p_y: float) -> void:
		index = p_index
		x = p_x
		y = p_y
		prev = null
		next = null
		z_order = 0
		prev_z = null
		next_z = null
		steiner = false


var _coordinates := PackedFloat32Array()
var _node_pool: Array[PolygonNode] = []
var _node_pool_used: int = 0


func triangulate(vertices: PackedVector2Array, hole_indices: PackedInt32Array = PackedInt32Array()) -> PackedInt32Array:
	if vertices.size() < 3:
		return PackedInt32Array()

	_node_pool_used = 0
	_coordinates.resize(vertices.size() * 2)
	for i in range(vertices.size()):
		_coordinates[i * 2] = vertices[i].x
		_coordinates[i * 2 + 1] = vertices[i].y

	return _earcut(_coordinates, hole_indices, 2)


func _earcut(data: PackedFloat32Array, hole_indices: PackedInt32Array, dim: int) -> PackedInt32Array:
	var has_holes := not hole_indices.is_empty()
	var outer_len := hole_indices[0] * dim if has_holes else data.size()
	var outer_node: PolygonNode = _linked_list(data, 0, outer_len, dim, true)
	var triangles := PackedInt32Array()

	if outer_node == null or outer_node.next == outer_node.prev:
		return triangles

	var min_x := 0.0
	var min_y := 0.0
	var inv_size := 0.0

	if has_holes:
		outer_node = _eliminate_holes(data, hole_indices, outer_node, dim)
		if outer_node == null:
			return triangles

	if data.size() > 80 * dim:
		min_x = data[0]
		min_y = data[1]
		var max_x := min_x
		var max_y := min_y
		for i in range(dim, outer_len, dim):
			var x := data[i]
			var y := data[i + 1]
			min_x = minf(min_x, x)
			min_y = minf(min_y, y)
			max_x = maxf(max_x, x)
			max_y = maxf(max_y, y)
		inv_size = maxf(max_x - min_x, max_y - min_y)
		if inv_size != 0.0:
			inv_size = 32767.0 / inv_size

	_earcut_linked(outer_node, triangles, min_x, min_y, inv_size, 0)
	return triangles


func _linked_list(data: PackedFloat32Array, start: int, end: int, dim: int, clockwise: bool) -> PolygonNode:
	if dim < 2 or start < 0 or end <= start or end > data.size():
		return null

	var last: PolygonNode = null
	var area_positive: bool = _signed_area(data, start, end, dim) > 0.0
	if clockwise == area_positive:
		for i in range(start, end, dim):
			last = _insert_node(int(i / dim), data[i], data[i + 1], last)
	else:
		for i in range(end - dim, start - 1, -dim):
			last = _insert_node(int(i / dim), data[i], data[i + 1], last)

	if last != null and _equals(last, last.next):
		var next_node: PolygonNode = last.next
		_remove_node(last)
		last = next_node
	return last


func _filter_points(start: PolygonNode, end: PolygonNode = null) -> PolygonNode:
	if start == null:
		return start
	if end == null:
		end = start

	var p: PolygonNode = start
	while true:
		var again := false
		if not p.steiner and (_equals(p, p.next) or _area(p.prev, p, p.next) == 0.0):
			var previous: PolygonNode = p.prev
			_remove_node(p)
			p = previous
			end = previous
			if p == p.next:
				break
			again = true
		else:
			p = p.next
		if not again and p == end:
			break
	return end


func _earcut_linked(ear: PolygonNode, triangles: PackedInt32Array, min_x: float, min_y: float, inv_size: float, pass_value: int) -> void:
	if ear == null:
		return
	if pass_value == 0 and inv_size != 0.0:
		_index_curve(ear, min_x, min_y, inv_size)

	var stop: PolygonNode = ear
	while ear.prev != ear.next:
		var previous: PolygonNode = ear.prev
		var next_node: PolygonNode = ear.next
		var is_ear: bool = _is_ear_hashed(ear, min_x, min_y, inv_size) if inv_size != 0.0 else _is_ear(ear)
		if is_ear:
			triangles.append(previous.index)
			triangles.append(ear.index)
			triangles.append(next_node.index)
			_remove_node(ear)
			ear = next_node.next
			stop = next_node.next
			continue

		ear = next_node
		if ear == stop:
			if pass_value == 0:
				_earcut_linked(_filter_points(ear), triangles, min_x, min_y, inv_size, 1)
			elif pass_value == 1:
				ear = _cure_local_intersections(_filter_points(ear), triangles)
				_earcut_linked(ear, triangles, min_x, min_y, inv_size, 2)
			elif pass_value == 2:
				_split_earcut(ear, triangles, min_x, min_y, inv_size)
			break


func _is_ear(ear: PolygonNode) -> bool:
	var a: PolygonNode = ear.prev
	var b: PolygonNode = ear
	var c: PolygonNode = ear.next
	if _area(a, b, c) >= 0.0:
		return false

	var x0 := minf(a.x, minf(b.x, c.x))
	var y0 := minf(a.y, minf(b.y, c.y))
	var x1 := maxf(a.x, maxf(b.x, c.x))
	var y1 := maxf(a.y, maxf(b.y, c.y))
	var p: PolygonNode = c.next
	while p != a:
		if p.x >= x0 and p.x <= x1 and p.y >= y0 and p.y <= y1 \
		and _point_in_triangle_except_first(a.x, a.y, b.x, b.y, c.x, c.y, p.x, p.y) \
		and _area(p.prev, p, p.next) >= 0.0:
			return false
		p = p.next
	return true


func _is_ear_hashed(ear: PolygonNode, min_x: float, min_y: float, inv_size: float) -> bool:
	var a: PolygonNode = ear.prev
	var b: PolygonNode = ear
	var c: PolygonNode = ear.next
	if _area(a, b, c) >= 0.0:
		return false

	var x0 := minf(a.x, minf(b.x, c.x))
	var y0 := minf(a.y, minf(b.y, c.y))
	var x1 := maxf(a.x, maxf(b.x, c.x))
	var y1 := maxf(a.y, maxf(b.y, c.y))
	var min_z := _z_order(x0, y0, min_x, min_y, inv_size)
	var max_z := _z_order(x1, y1, min_x, min_y, inv_size)
	var p: PolygonNode = ear.prev_z
	var n: PolygonNode = ear.next_z

	while p != null and p.z_order >= min_z and n != null and n.z_order <= max_z:
		if _node_inside_ear_bbox(p, a, c, x0, y0, x1, y1):
			return false
		p = p.prev_z
		if _node_inside_ear_bbox(n, a, c, x0, y0, x1, y1):
			return false
		n = n.next_z

	while p != null and p.z_order >= min_z:
		if _node_inside_ear_bbox(p, a, c, x0, y0, x1, y1):
			return false
		p = p.prev_z

	while n != null and n.z_order <= max_z:
		if _node_inside_ear_bbox(n, a, c, x0, y0, x1, y1):
			return false
		n = n.next_z
	return true


func _node_inside_ear_bbox(p: PolygonNode, a: PolygonNode, c: PolygonNode, x0: float, y0: float, x1: float, y1: float) -> bool:
	return p.x >= x0 and p.x <= x1 and p.y >= y0 and p.y <= y1 \
		and p != a and p != c \
		and _point_in_triangle_except_first(a.x, a.y, a.next.x, a.next.y, c.x, c.y, p.x, p.y) \
		and _area(p.prev, p, p.next) >= 0.0


func _cure_local_intersections(start: PolygonNode, triangles: PackedInt32Array) -> PolygonNode:
	if start == null:
		return null
	var p: PolygonNode = start
	while true:
		var a: PolygonNode = p.prev
		var b: PolygonNode = p.next.next
		if not _equals(a, b) and _intersects(a, p, p.next, b) and _locally_inside(a, b) and _locally_inside(b, a):
			triangles.append(a.index)
			triangles.append(p.index)
			triangles.append(b.index)
			var p_next: PolygonNode = p.next
			_remove_node(p)
			_remove_node(p_next)
			p = b
			start = b
		p = p.next
		if p == start:
			break
	return _filter_points(p)


func _split_earcut(start: PolygonNode, triangles: PackedInt32Array, min_x: float, min_y: float, inv_size: float) -> void:
	var a: PolygonNode = start
	while true:
		var b: PolygonNode = a.next.next
		while b != a.prev:
			if a.index != b.index and _is_valid_diagonal(a, b):
				var c: PolygonNode = _split_polygon(a, b)
				a = _filter_points(a, a.next)
				c = _filter_points(c, c.next)
				_earcut_linked(a, triangles, min_x, min_y, inv_size, 0)
				_earcut_linked(c, triangles, min_x, min_y, inv_size, 0)
				return
			b = b.next
		a = a.next
		if a == start:
			break


func _eliminate_holes(data: PackedFloat32Array, hole_indices: PackedInt32Array, outer_node: PolygonNode, dim: int) -> PolygonNode:
	var queue: Array[PolygonNode] = []
	for i in range(hole_indices.size()):
		var start := hole_indices[i] * dim
		var end := hole_indices[i + 1] * dim if i < hole_indices.size() - 1 else data.size()
		var list: PolygonNode = _linked_list(data, start, end, dim, false)
		if list == null:
			continue
		if list == list.next:
			list.steiner = true
		queue.append(_get_leftmost(list))
	queue.sort_custom(_compare_x_y_slope)
	for hole: PolygonNode in queue:
		outer_node = _eliminate_hole(hole, outer_node)
	return outer_node


func _compare_x_y_slope(a: PolygonNode, b: PolygonNode) -> bool:
	var result := a.x - b.x
	if result == 0.0:
		result = a.y - b.y
		if result == 0.0:
			var a_slope: float = _slope(a.next.y - a.y, a.next.x - a.x)
			var b_slope: float = _slope(b.next.y - b.y, b.next.x - b.x)
			result = a_slope - b_slope
	return result < 0.0


func _slope(delta_y: float, delta_x: float) -> float:
	if delta_x != 0.0:
		return delta_y / delta_x
	if delta_y > 0.0:
		return INF
	if delta_y < 0.0:
		return -INF
	return 0.0


func _eliminate_hole(hole: PolygonNode, outer_node: PolygonNode) -> PolygonNode:
	var bridge: PolygonNode = _find_hole_bridge(hole, outer_node)
	if bridge == null:
		return outer_node
	var bridge_reverse: PolygonNode = _split_polygon(bridge, hole)
	_filter_points(bridge_reverse, bridge_reverse.next)
	return _filter_points(bridge, bridge.next)


func _find_hole_bridge(hole: PolygonNode, outer_node: PolygonNode) -> PolygonNode:
	var p: PolygonNode = outer_node
	var hx := hole.x
	var hy := hole.y
	var qx := -INF
	var m: PolygonNode = null

	if _equals(hole, p):
		return p
	while true:
		if _equals(hole, p.next):
			return p.next
		elif hy <= p.y and hy >= p.next.y and p.next.y != p.y:
			var x: float = p.x + (hy - p.y) * (p.next.x - p.x) / (p.next.y - p.y)
			if x <= hx and x > qx:
				qx = x
				m = p if p.x < p.next.x else p.next
				if x == hx:
					return m
		p = p.next
		if p == outer_node:
			break
	if m == null:
		return null

	var stop: PolygonNode = m
	var mx := m.x
	var my := m.y
	var tan_min := INF
	p = m
	while true:
		var ax := hx if hy < my else qx
		var bx := qx if hy < my else hx
		if hx >= p.x and p.x >= mx and hx != p.x \
		and _point_in_triangle(ax, hy, mx, my, bx, hy, p.x, p.y):
			var tangent := absf(hy - p.y) / (hx - p.x)
			if _locally_inside(p, hole) and (tangent < tan_min \
			or (tangent == tan_min and (p.x > m.x or (p.x == m.x and _sector_contains_sector(m, p))))):
				m = p
				tan_min = tangent
		p = p.next
		if p == stop:
			break
	return m


func _sector_contains_sector(m: PolygonNode, p: PolygonNode) -> bool:
	return _area(m.prev, m, p.prev) < 0.0 and _area(p.next, m, m.next) < 0.0


func _index_curve(start: PolygonNode, min_x: float, min_y: float, inv_size: float) -> void:
	var p: PolygonNode = start
	while true:
		if p.z_order == 0:
			p.z_order = _z_order(p.x, p.y, min_x, min_y, inv_size)
		p.prev_z = p.prev
		p.next_z = p.next
		p = p.next
		if p == start:
			break
	p.prev_z.next_z = null
	p.prev_z = null
	_sort_linked(p)


func _sort_linked(list: PolygonNode) -> PolygonNode:
	var in_size := 1
	while true:
		var p: PolygonNode = list
		var new_list: PolygonNode = null
		var tail: PolygonNode = null
		var num_merges := 0
		while p != null:
			num_merges += 1
			var q: PolygonNode = p
			var p_size := 0
			for _i in range(in_size):
				p_size += 1
				q = q.next_z
				if q == null:
					break
			var q_size := in_size
			while p_size > 0 or (q_size > 0 and q != null):
				var e: PolygonNode
				if p_size != 0 and (q_size == 0 or q == null or p.z_order <= q.z_order):
					e = p
					p = p.next_z
					p_size -= 1
				else:
					e = q
					q = q.next_z
					q_size -= 1
				if tail != null:
					tail.next_z = e
				else:
					new_list = e
				e.prev_z = tail
				tail = e
			p = q
		if tail != null:
			tail.next_z = null
		list = new_list
		in_size *= 2
		if num_merges <= 1:
			break
	return list


func _z_order(x: float, y: float, min_x: float, min_y: float, inv_size: float) -> int:
	var xi := int((x - min_x) * inv_size)
	var yi := int((y - min_y) * inv_size)
	xi = (xi | (xi << 8)) & 0x00FF00FF
	xi = (xi | (xi << 4)) & 0x0F0F0F0F
	xi = (xi | (xi << 2)) & 0x33333333
	xi = (xi | (xi << 1)) & 0x55555555
	yi = (yi | (yi << 8)) & 0x00FF00FF
	yi = (yi | (yi << 4)) & 0x0F0F0F0F
	yi = (yi | (yi << 2)) & 0x33333333
	yi = (yi | (yi << 1)) & 0x55555555
	return xi | (yi << 1)


func _get_leftmost(start: PolygonNode) -> PolygonNode:
	var p: PolygonNode = start
	var leftmost := start
	while true:
		if p.x < leftmost.x or (p.x == leftmost.x and p.y < leftmost.y):
			leftmost = p
		p = p.next
		if p == start:
			break
	return leftmost


func _point_in_triangle(ax: float, ay: float, bx: float, by: float, cx: float, cy: float, px: float, py: float) -> bool:
	return (cx - px) * (ay - py) >= (ax - px) * (cy - py) \
		and (ax - px) * (by - py) >= (bx - px) * (ay - py) \
		and (bx - px) * (cy - py) >= (cx - px) * (by - py)


func _point_in_triangle_except_first(ax: float, ay: float, bx: float, by: float, cx: float, cy: float, px: float, py: float) -> bool:
	return not (ax == px and ay == py) and _point_in_triangle(ax, ay, bx, by, cx, cy, px, py)


func _is_valid_diagonal(a: PolygonNode, b: PolygonNode) -> bool:
	return a.next.index != b.index and a.prev.index != b.index \
		and not _intersects_polygon(a, b) \
		and ((_locally_inside(a, b) and _locally_inside(b, a) and _middle_inside(a, b) \
		and (_area(a.prev, a, b.prev) != 0.0 or _area(a, b.prev, b) != 0.0)) \
		or (_equals(a, b) and _area(a.prev, a, a.next) > 0.0 and _area(b.prev, b, b.next) > 0.0))


func _area(a: PolygonNode, b: PolygonNode, c: PolygonNode) -> float:
	return (b.y - a.y) * (c.x - b.x) - (b.x - a.x) * (c.y - b.y)


func _equals(a: PolygonNode, b: PolygonNode) -> bool:
	return a.x == b.x and a.y == b.y


func _intersects(p1: PolygonNode, q1: PolygonNode, p2: PolygonNode, q2: PolygonNode) -> bool:
	var o1 := _sign(_area(p1, q1, p2))
	var o2 := _sign(_area(p1, q1, q2))
	var o3 := _sign(_area(p2, q2, p1))
	var o4 := _sign(_area(p2, q2, q1))
	if o1 != o2 and o3 != o4:
		return true
	if o1 == 0 and _on_segment(p1, p2, q1):
		return true
	if o2 == 0 and _on_segment(p1, q2, q1):
		return true
	if o3 == 0 and _on_segment(p2, p1, q2):
		return true
	if o4 == 0 and _on_segment(p2, q1, q2):
		return true
	return false


func _sign(value: float) -> int:
	if value > 0.0:
		return 1
	if value < 0.0:
		return -1
	return 0


func _on_segment(p: PolygonNode, q: PolygonNode, r: PolygonNode) -> bool:
	return q.x <= maxf(p.x, r.x) and q.x >= minf(p.x, r.x) \
		and q.y <= maxf(p.y, r.y) and q.y >= minf(p.y, r.y)


func _intersects_polygon(a: PolygonNode, b: PolygonNode) -> bool:
	var p: PolygonNode = a
	while true:
		if p.index != a.index and p.next.index != a.index and p.index != b.index and p.next.index != b.index \
		and _intersects(p, p.next, a, b):
			return true
		p = p.next
		if p == a:
			break
	return false


func _locally_inside(a: PolygonNode, b: PolygonNode) -> bool:
	if _area(a.prev, a, a.next) < 0.0:
		return _area(a, b, a.next) >= 0.0 and _area(a, a.prev, b) >= 0.0
	return _area(a, b, a.prev) < 0.0 or _area(a, a.next, b) < 0.0


func _middle_inside(a: PolygonNode, b: PolygonNode) -> bool:
	var px := (a.x + b.x) * 0.5
	var py := (a.y + b.y) * 0.5
	var inside := false
	var p: PolygonNode = a
	while true:
		if (p.y > py) != (p.next.y > py) and p.next.y != p.y:
			var x_cross: float = (p.next.x - p.x) * (py - p.y) / (p.next.y - p.y) + p.x
			if px < x_cross:
				inside = not inside
		p = p.next
		if p == a:
			break
	return inside


func _split_polygon(a: PolygonNode, b: PolygonNode) -> PolygonNode:
	var a2: PolygonNode = _create_node(a.index, a.x, a.y)
	var b2: PolygonNode = _create_node(b.index, b.x, b.y)
	var an: PolygonNode = a.next
	var bp: PolygonNode = b.prev
	a.next = b
	b.prev = a
	a2.next = an
	an.prev = a2
	b2.next = a2
	a2.prev = b2
	bp.next = b2
	b2.prev = bp
	return b2


func _insert_node(index: int, x: float, y: float, last: PolygonNode) -> PolygonNode:
	var p: PolygonNode = _create_node(index, x, y)
	if last == null:
		p.prev = p
		p.next = p
	else:
		p.next = last.next
		p.prev = last
		last.next.prev = p
		last.next = p
	return p


func _create_node(index: int, x: float, y: float) -> PolygonNode:
	var node: PolygonNode
	if _node_pool_used < _node_pool.size():
		node = _node_pool[_node_pool_used]
		node.reset(index, x, y)
	else:
		node = PolygonNode.new(index, x, y)
		_node_pool.append(node)
	_node_pool_used += 1
	return node


func _remove_node(p: PolygonNode) -> void:
	p.next.prev = p.prev
	p.prev.next = p.next
	if p.prev_z != null:
		p.prev_z.next_z = p.next_z
	if p.next_z != null:
		p.next_z.prev_z = p.prev_z


func _signed_area(data: PackedFloat32Array, start: int, end: int, dim: int) -> float:
	var sum := 0.0
	var j := end - dim
	for i in range(start, end, dim):
		sum += (data[j] - data[i]) * (data[i + 1] + data[j + 1])
		j = i
	return sum
