extends Node2D

# City parameters
@export var city_size := Vector2(800, 800)
@export var block_size := Vector2(40, 40)
@export var road_width := 6.0
@export var sidewalk_width := 2.0
@export var building_density := 0.9
@export var seed_value := 0

# Agent parameters
@export var num_agents := 50
@export var agent_speed := 5.0

# Camera2D node
var camera: Camera2D
var is_dragging := false
var drag_start_pos := Vector2.ZERO
var drag_start_camera_pos := Vector2.ZERO

# Colors
const COLORS = {
	"road": Color(0.3, 0.3, 0.3),
	"sidewalk": Color(0.5, 0.5, 0.5),
	"river": Color(0.2, 0.4, 0.7),
	"river_bank": Color(0.25, 0.5, 0.3),
	"bridge": Color(0.4, 0.35, 0.3),
	"park": Color(0.3, 0.6, 0.3),
	"park_path": Color(0.6, 0.5, 0.4),
	"residential": Color(0.7, 0.7, 0.8),
	"commercial": Color(0.9, 0.7, 0.4),
	"industrial": Color(0.5, 0.5, 0.6),
	"office": Color(0.6, 0.7, 0.9),
	"school": Color(0.95, 0.85, 0.5),
	"hospital": Color(0.9, 0.3, 0.3),
	"church": Color(0.85, 0.8, 0.9),
	"police": Color(0.2, 0.3, 0.6),
	"fire": Color(0.8, 0.2, 0.1),
	"little_italy": Color(0.8, 0.95, 0.8),
	"chinatown": Color(0.95, 0.85, 0.7),
	"downtown": Color(0.85, 0.85, 0.95)
}

# Building types
enum BuildingType { RESIDENTIAL, COMMERCIAL, INDUSTRIAL, OFFICE, SCHOOL, HOSPITAL, CHURCH, POLICE_STATION, FIRE_STATION }
enum NeighborhoodType { NONE, LITTLE_ITALY, CHINATOWN, DOWNTOWN }

# Data structures
class Building:
	var rect: Rect2
	var type: BuildingType
	var height: int
	var color: Color
	func _init(r: Rect2, t: BuildingType, h: int, c: Color):
		rect = r; type = t; height = h; color = c

class Agent:
	var position: Vector2
	var home: Building
	var work: Building
	var path: Array[Vector2] = []
	var path_index := 0
	var going_to_work := true
	var color: Color
	var wait_time := 0.0

	func _init(h: Building, w: Building, pos: Vector2, agent_color: Color = Color.WHITE):
		home = h; work = w; position = pos
		color = agent_color

	func get_target() -> Building:
		return work if going_to_work else home

	func switch_destination():
		going_to_work = !going_to_work
		path_index = 0
		path.clear()
		wait_time = randf_range(5.0, 15.0)

class Neighborhood:
	var center: Vector2
	var radius: float
	var type: NeighborhoodType
	var name: String
	func _init(c: Vector2, r: float, t: NeighborhoodType, n: String):
		center = c; radius = r; type = t; name = n
	func contains_point(p: Vector2) -> bool:
		return p.distance_to(center) < radius

# Collections
var buildings: Array[Building] = []
var agents: Array[Agent] = []
var neighborhoods: Array[Neighborhood] = []
var rivers: Array = []
var bridges: Array = []
var institutional_positions: Array[Vector2] = []
var parks: Array = []
var park_blocks: Dictionary = {}  # Using Dictionary for O(1) lookup instead of Array
var rng := RandomNumberGenerator.new()
var static_canvas: Node2D
var agent_canvas: Node2D

func _ready():
	print("=== City Generator Starting ===")

	# Create Camera2D
	camera = Camera2D.new()
	camera.position = city_size / 2
	camera.zoom = Vector2(0.6, 0.6)
	add_child(camera)
	camera.make_current()
	print("Camera created at position: ", camera.position)

	generate_city()
	print("=== City Generator Ready ===")

func _process(delta):
	# Camera panning with keyboard
	var pan_speed: float = 300.0 * delta / camera.zoom.x
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		camera.position.x -= pan_speed
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		camera.position.x += pan_speed
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		camera.position.y -= pan_speed
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		camera.position.y += pan_speed

	# Update agents
	update_agents(delta)

func _unhandled_input(event):
	if event is InputEventMouseButton:
		# Zoom with mouse wheel
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom = camera.zoom * 1.1
			camera.zoom.x = clamp(camera.zoom.x, 0.3, 3.0)
			camera.zoom.y = clamp(camera.zoom.y, 0.3, 3.0)
			print("Zoom in: ", camera.zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = camera.zoom * 0.9
			camera.zoom.x = clamp(camera.zoom.x, 0.3, 3.0)
			camera.zoom.y = clamp(camera.zoom.y, 0.3, 3.0)
			print("Zoom out: ", camera.zoom)
		# Pan with middle mouse button or right click
		elif event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_dragging = true
				drag_start_pos = event.position
				drag_start_camera_pos = camera.position
				print("Start dragging")
			else:
				is_dragging = false
				print("Stop dragging")

	if event is InputEventMouseMotion and is_dragging:
		var drag_delta: Vector2 = event.position - drag_start_pos
		camera.position = drag_start_camera_pos - drag_delta / camera.zoom.x

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			print("Regenerating city...")
			rng.randomize()
			generate_city()
		elif event.keycode == KEY_R and seed_value != 0:
			rng.seed = seed_value
			generate_city()
		elif event.keycode == KEY_C:
			camera.position = city_size / 2
			camera.zoom = Vector2(0.6, 0.6)
			print("Camera centered")

func generate_city():
	print("Generating city...")
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()

	buildings.clear()
	agents.clear()
	neighborhoods.clear()
	rivers.clear()
	bridges.clear()
	institutional_positions.clear()
	parks.clear()
	park_blocks.clear()

	if static_canvas:
		static_canvas.queue_free()
	if agent_canvas:
		agent_canvas.queue_free()

	generate_neighborhoods()
	gen_rivers()
	gen_bridges()
	gen_parks()
	gen_buildings()
	draw_static_city()

	# Create agent layer
	agent_canvas = Node2D.new()
	agent_canvas.name = "AgentLayer"
	agent_canvas.z_index = 1000
	add_child(agent_canvas)
	agent_canvas.draw.connect(_draw_agents)

	await get_tree().process_frame
	gen_agents()
	print("City generation complete!")

func generate_neighborhoods():
	var center := city_size / 2
	neighborhoods.append(Neighborhood.new(center, 120.0, NeighborhoodType.DOWNTOWN, "Downtown"))

	var li_pos := center + Vector2(rng.randf_range(-200, 200), rng.randf_range(-200, 200))
	neighborhoods.append(Neighborhood.new(li_pos, 90.0, NeighborhoodType.LITTLE_ITALY, "Little Italy"))

	var ct_pos := center + Vector2(rng.randf_range(-250, 250), rng.randf_range(-250, 250))
	while ct_pos.distance_to(li_pos) < 150:
		ct_pos = center + Vector2(rng.randf_range(-250, 250), rng.randf_range(-250, 250))
	neighborhoods.append(Neighborhood.new(ct_pos, 85.0, NeighborhoodType.CHINATOWN, "Chinatown"))

func gen_rivers():
	var is_horizontal := rng.randf() > 0.5
	var points: Array[Vector2] = []
	var num_seg := rng.randi_range(25, 40)
	var curve := rng.randf_range(30.0, 60.0)
	var wave_freq := rng.randf_range(2.0, 4.0)  # Calculate frequency once for smooth waves

	if is_horizontal:
		var start_y := rng.randf_range(city_size.y * 0.25, city_size.y * 0.75)
		for i in range(num_seg + 1):
			var t := float(i) / num_seg
			var x := t * city_size.x
			var y := start_y + sin(t * PI * wave_freq) * curve + rng.randf_range(-15, 15)
			points.append(Vector2(x, y))
	else:
		var start_x := rng.randf_range(city_size.x * 0.25, city_size.x * 0.75)
		for i in range(num_seg + 1):
			var t := float(i) / num_seg
			var y := t * city_size.y
			var x := start_x + sin(t * PI * wave_freq) * curve + rng.randf_range(-15, 15)
			points.append(Vector2(x, y))

	rivers.append(points)

func gen_bridges():
	var cols := int(city_size.x / block_size.x)
	var rows := int(city_size.y / block_size.y)
	var bridge_spacing := 5

	for i in range(0, cols + 1, bridge_spacing):
		check_bridge(Vector2(i * block_size.x, 0), Vector2(i * block_size.x, city_size.y), true)
	for j in range(0, rows + 1, bridge_spacing):
		check_bridge(Vector2(0, j * block_size.y), Vector2(city_size.x, j * block_size.y), false)

func check_bridge(start: Vector2, end: Vector2, is_vert: bool):
	for river in rivers:
		for i in range(river.size() - 1):
			var cross := line_cross(start, end, river[i], river[i + 1])
			if cross != Vector2.ZERO:
				var river_dir: Vector2 = (river[i + 1] - river[i]).normalized()
				var bridge_dir: Vector2 = Vector2(-river_dir.y, river_dir.x)
				var bridge_len := 35.0
				var b_start := cross - bridge_dir * bridge_len / 2
				var b_end := cross + bridge_dir * bridge_len / 2
				bridges.append([b_start, b_end])
				return

func line_cross(ls: Vector2, le: Vector2, ss: Vector2, se: Vector2) -> Vector2:
	var ld := le - ls
	var sd := se - ss
	var diff := ss - ls
	var cross := ld.x * sd.y - ld.y * sd.x

	if abs(cross) < 0.001:
		return Vector2.ZERO

	var t1 := (diff.x * sd.y - diff.y * sd.x) / cross
	var t2 := (diff.x * ld.y - diff.y * ld.x) / cross

	return ls + t1 * ld if (t1 >= 0 and t1 <= 1 and t2 >= 0 and t2 <= 1) else Vector2.ZERO

func gen_parks():
	var cols := int(city_size.x / block_size.x)
	var rows := int(city_size.y / block_size.y)
	var num_parks := rng.randi_range(3, 6)

	for p in range(num_parks):
		var park_width := rng.randi_range(2, 4)
		var park_height := rng.randi_range(2, 4)
		var start_col := rng.randi_range(1, cols - park_width - 1)
		var start_row := rng.randi_range(1, rows - park_height - 1)

		var valid := true
		for i in range(park_width):
			for j in range(park_height):
				var col := start_col + i
				var row := start_row + j
				var block_pos := Vector2(col * block_size.x, row * block_size.y)

				if is_in_river(col, row) or block_pos in park_blocks:
					valid = false
					break
			if not valid:
				break

		if valid:
			var park_region := []
			for i in range(park_width):
				for j in range(park_height):
					var col := start_col + i
					var row := start_row + j
					var block_pos := Vector2(col * block_size.x, row * block_size.y)
					park_blocks[block_pos] = true
					park_region.append(Vector2(col, row))
			parks.append(park_region)

func is_park_block(col: int, row: int) -> bool:
	var block_pos := Vector2(col * block_size.x, row * block_size.y)
	return block_pos in park_blocks

func gen_buildings():
	var cols := int(city_size.x / block_size.x)
	var rows := int(city_size.y / block_size.y)

	for i in range(cols):
		for j in range(rows):
			if is_in_river(i, j) or is_park_block(i, j):
				continue

			if rng.randf() < building_density:
				gen_block(i, j)

func gen_block(col: int, row: int):
	var pos := Vector2(col * block_size.x + road_width, row * block_size.y + road_width)
	var size := block_size - Vector2(road_width * 2, road_width * 2)
	var type := get_building_type(col, row)
	var hood := get_neighborhood(pos)

	if type in [BuildingType.SCHOOL, BuildingType.HOSPITAL, BuildingType.CHURCH, BuildingType.POLICE_STATION, BuildingType.FIRE_STATION]:
		institutional_positions.append(pos)
		var rect := Rect2(pos + Vector2(3, 3), size - Vector2(6, 6))
		buildings.append(Building.new(rect, type, get_height(type), get_color(type, hood)))
		return

	var num := rng.randi_range(1, 4)
	if num == 1:
		var rect := Rect2(pos + Vector2(2, 2), size - Vector2(4, 4))
		buildings.append(Building.new(rect, type, get_height(type), get_color(type, hood)))
	else:
		var grid := 2 if num <= 4 else 3
		var b_size := size / grid
		for i in range(grid):
			for j in range(grid):
				if rng.randf() < 0.75:
					var b_pos := pos + Vector2(i * b_size.x + 1, j * b_size.y + 1)
					var rect := Rect2(b_pos, b_size - Vector2(2, 2))
					buildings.append(Building.new(rect, type, get_height(type), get_color(type, hood)))

func get_building_type(col: int, row: int) -> BuildingType:
	var pos := Vector2(col * block_size.x, row * block_size.y)
	var hood := get_neighborhood(pos)
	var r := rng.randf()

	if hood:
		match hood.type:
			NeighborhoodType.DOWNTOWN:
				return BuildingType.OFFICE if r < 0.5 else (BuildingType.COMMERCIAL if r < 0.85 else BuildingType.RESIDENTIAL)
			NeighborhoodType.LITTLE_ITALY:
				return BuildingType.RESIDENTIAL if r < 0.65 else (BuildingType.COMMERCIAL if r < 0.9 else BuildingType.CHURCH)
			NeighborhoodType.CHINATOWN:
				return BuildingType.RESIDENTIAL if r < 0.55 else BuildingType.COMMERCIAL

	for ipos in institutional_positions:
		if pos.distance_to(ipos) < 80 and rng.randf() < 0.05:
			return [BuildingType.SCHOOL, BuildingType.CHURCH, BuildingType.HOSPITAL, BuildingType.POLICE_STATION, BuildingType.FIRE_STATION][rng.randi() % 5]

	var center := city_size / 2
	var dist := pos.distance_to(center) / (city_size.length() / 2)

	if dist < 0.3:
		return BuildingType.COMMERCIAL if r < 0.4 else (BuildingType.OFFICE if r < 0.8 else BuildingType.RESIDENTIAL)
	elif dist < 0.6:
		if r < 0.3: return BuildingType.COMMERCIAL
		elif r < 0.5: return BuildingType.OFFICE
		elif r < 0.8: return BuildingType.RESIDENTIAL
		else: return BuildingType.INDUSTRIAL
	else:
		return BuildingType.RESIDENTIAL if r < 0.5 else (BuildingType.INDUSTRIAL if r < 0.8 else BuildingType.COMMERCIAL)

func get_height(type: BuildingType) -> int:
	match type:
		BuildingType.RESIDENTIAL: return rng.randi_range(2, 6)
		BuildingType.COMMERCIAL: return rng.randi_range(1, 4)
		BuildingType.INDUSTRIAL: return rng.randi_range(1, 3)
		BuildingType.OFFICE: return rng.randi_range(5, 10)
		BuildingType.SCHOOL: return rng.randi_range(2, 3)
		BuildingType.HOSPITAL: return rng.randi_range(3, 5)
		BuildingType.CHURCH: return rng.randi_range(2, 4)
		_: return 2

func get_color(type: BuildingType, hood: Neighborhood = null) -> Color:
	var base: Color
	match type:
		BuildingType.RESIDENTIAL: base = COLORS.residential
		BuildingType.COMMERCIAL: base = COLORS.commercial
		BuildingType.INDUSTRIAL: base = COLORS.industrial
		BuildingType.OFFICE: base = COLORS.office
		BuildingType.SCHOOL: base = COLORS.school
		BuildingType.HOSPITAL: base = COLORS.hospital
		BuildingType.CHURCH: base = COLORS.church
		BuildingType.POLICE_STATION: base = COLORS.police
		BuildingType.FIRE_STATION: base = COLORS.fire
		_: base = Color.GRAY

	if hood:
		match hood.type:
			NeighborhoodType.LITTLE_ITALY:
				base = base.lerp(COLORS.little_italy, 0.3)
			NeighborhoodType.CHINATOWN:
				base = base.lerp(COLORS.chinatown, 0.3)
			NeighborhoodType.DOWNTOWN:
				base = base.lerp(COLORS.downtown, 0.2)

	return base

func get_neighborhood(pos: Vector2) -> Neighborhood:
	for hood in neighborhoods:
		if hood.contains_point(pos):
			return hood
	return null

func is_in_river(col: int, row: int) -> bool:
	var center := Vector2(col * block_size.x + block_size.x / 2, row * block_size.y + block_size.y / 2)
	for river in rivers:
		for i in range(river.size() - 1):
			if dist_to_seg(center, river[i], river[i + 1]) < 30:
				return true
	return false

func dist_to_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var ap: Vector2 = p - a
	var len: float = ab.length()
	if len == 0: return p.distance_to(a)
	var t: float = clamp(ap.dot(ab) / (len * len), 0.0, 1.0)
	return p.distance_to(a + t * ab)

func draw_static_city():
	static_canvas = Node2D.new()
	static_canvas.name = "CityLayer"
	static_canvas.z_index = 0
	add_child(static_canvas)
	static_canvas.draw.connect(_draw_static)
	static_canvas.queue_redraw()

func _draw_static():
	for hood in neighborhoods:
		var col: Color
		match hood.type:
			NeighborhoodType.LITTLE_ITALY:
				col = COLORS.little_italy
			NeighborhoodType.CHINATOWN:
				col = COLORS.chinatown
			NeighborhoodType.DOWNTOWN:
				col = COLORS.downtown
			_:
				continue
		static_canvas.draw_circle(hood.center, hood.radius, Color(col, 0.15))

	for river in rivers:
		for i in range(river.size() - 1):
			static_canvas.draw_line(river[i], river[i + 1], COLORS.river_bank, 24.0)
			static_canvas.draw_line(river[i], river[i + 1], COLORS.river, 20.0)

	for bridge in bridges:
		static_canvas.draw_line(bridge[0], bridge[1], COLORS.bridge, road_width + 2)
		static_canvas.draw_line(bridge[0], bridge[1], COLORS.road, road_width)

	var cols := int(city_size.x / block_size.x)
	var rows := int(city_size.y / block_size.y)

	for i in range(cols + 1):
		var x := i * block_size.x
		static_canvas.draw_line(Vector2(x, 0), Vector2(x, city_size.y), COLORS.sidewalk, road_width + sidewalk_width * 2)
		static_canvas.draw_line(Vector2(x, 0), Vector2(x, city_size.y), COLORS.road, road_width)

	for j in range(rows + 1):
		var y := j * block_size.y
		static_canvas.draw_line(Vector2(0, y), Vector2(city_size.x, y), COLORS.sidewalk, road_width + sidewalk_width * 2)
		static_canvas.draw_line(Vector2(0, y), Vector2(city_size.x, y), COLORS.road, road_width)

	for building in buildings:
		for i in range(building.height):
			var off := Vector2(-i * 0.5, -i * 0.5)
			static_canvas.draw_rect(Rect2(building.rect.position + off, building.rect.size), building.color.darkened(i * 0.05))

		static_canvas.draw_rect(building.rect, building.color)
		static_canvas.draw_rect(building.rect, Color.BLACK, false, 1.0)

		if building.height >= 3 and building.rect.size.x > 10:
			var spacing := 5.0
			var win_rows := int(building.rect.size.y / spacing) - 1
			var win_cols := int(building.rect.size.x / spacing) - 1
			for i in range(1, win_cols):
				for j in range(1, win_rows):
					if rng.randf() < 0.7:
						static_canvas.draw_rect(Rect2(building.rect.position + Vector2(i * spacing, j * spacing), Vector2(2.5, 2.5)), Color(0.8, 0.9, 1.0, 0.6))

	for park_region in parks:
		for block_grid in park_region:
			var col := int(block_grid.x)
			var row := int(block_grid.y)
			var park_pos := Vector2(col * block_size.x + road_width, row * block_size.y + road_width)
			var park_size := block_size - Vector2(road_width * 2, road_width * 2)

			static_canvas.draw_rect(Rect2(park_pos, park_size), COLORS.park)

			var center := park_pos + park_size / 2
			var path_width := 2.0
			static_canvas.draw_line(Vector2(park_pos.x, center.y), Vector2(park_pos.x + park_size.x, center.y), COLORS.park_path, path_width)
			static_canvas.draw_line(Vector2(center.x, park_pos.y), Vector2(center.x, park_pos.y + park_size.y), COLORS.park_path, path_width)

func gen_agents():
	agents.clear()
	var homes: Array[Building] = buildings.filter(func(b): return b.type == BuildingType.RESIDENTIAL)
	var works: Array[Building] = buildings.filter(func(b): return b.type in [BuildingType.COMMERCIAL, BuildingType.INDUSTRIAL, BuildingType.OFFICE, BuildingType.SCHOOL, BuildingType.HOSPITAL, BuildingType.POLICE_STATION, BuildingType.FIRE_STATION])

	if homes.is_empty() or works.is_empty():
		print("Not enough buildings for agents")
		return

	for i in range(num_agents):
		var home := homes[rng.randi() % homes.size()]
		var work := works[rng.randi() % works.size()]
		var agent_color := Color(rng.randf(), rng.randf(), rng.randf())
		agents.append(Agent.new(home, work, home.rect.get_center(), agent_color))

	print("Generated ", agents.size(), " agents")
	if agent_canvas:
		agent_canvas.queue_redraw()

func update_agents(delta: float):
	var moved := false
	for agent in agents:
		if agent.wait_time > 0:
			agent.wait_time -= delta
			continue

		if agent.path.is_empty():
			agent.path = find_path(agent.position, agent.get_target().rect.get_center())
			agent.path_index = 0

		if agent.path_index < agent.path.size():
			var target: Vector2 = agent.path[agent.path_index]
			var dir: Vector2 = (target - agent.position).normalized()
			var dist: float = agent.position.distance_to(target)
			var step: float = agent_speed * delta

			if dist <= step:
				agent.position = target
				agent.path_index += 1
			else:
				agent.position += dir * step
			moved = true

		if agent.position.distance_to(agent.get_target().rect.get_center()) < 5:
			agent.switch_destination()

	if moved and agent_canvas:
		agent_canvas.queue_redraw()

func find_path(start: Vector2, end: Vector2) -> Array[Vector2]:
	var path: Array[Vector2] = []
	var sg: Vector2 = (start / block_size).round()
	var eg: Vector2 = (end / block_size).round()
	var cur: Vector2 = sg
	var sidewalk_offset := (road_width / 2) + (sidewalk_width / 2)

	while cur.x != eg.x:
		cur.x += 1 if cur.x < eg.x else -1
		var pos := cur * block_size

		if is_park_block(int(cur.x), int(cur.y)):
			pos = cur * block_size + block_size / 2
		else:
			pos.y += sidewalk_offset if cur.y < eg.y else -sidewalk_offset
		path.append(pos)

	while cur.y != eg.y:
		cur.y += 1 if cur.y < eg.y else -1
		var pos := cur * block_size

		if is_park_block(int(cur.x), int(cur.y)):
			pos = cur * block_size + block_size / 2
		else:
			pos.x += sidewalk_offset if cur.x < eg.x else -sidewalk_offset
		path.append(pos)

	path.append(end)
	return path

func _draw_agents():
	if agent_canvas:
		for agent in agents:
			agent_canvas.draw_circle(agent.position, 3.5, agent.color)
			agent_canvas.draw_arc(agent.position, 3.5, 0, TAU, 16, Color.BLACK, 1.0)

func _draw():
	var y := 10
	draw_string(ThemeDB.fallback_font, Vector2(10, y), "Zoom: %.2f (Wheel) | Pan: WASD/Arrows or Right-Click Drag", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	y += 20
	draw_string(ThemeDB.fallback_font, Vector2(10, y), "SPACE: New City | C: Center | Buildings: %d | Agents: %d" % [buildings.size(), agents.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
