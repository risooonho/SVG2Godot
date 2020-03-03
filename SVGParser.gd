tool
extends EditorScript
"""
SVG PARSER
"""
var file_path = "res://files/map01.svg"

var xml_data = XMLParser.new()
var root_node : Node
var current_node : Node
const MAX_WIDTH = 7.0

func _run() -> void:
	if xml_data.open(file_path) != OK:
		print("Error opening file: ", file_path)
		return
	root_node = self.get_scene()
	current_node = root_node
	
	#clear tree
	for c in root_node.get_children():
		c.queue_free()
	
	parse()

"""
Loop through all nodes and create the respective element.
"""
func parse() -> void:
	print("start parsing ...")
	while xml_data.read() == OK:
		if not xml_data.get_node_type() in [XMLParser.NODE_ELEMENT, XMLParser.NODE_ELEMENT_END]:
			continue
		elif xml_data.get_node_name() == "g":
			if xml_data.get_node_type() == XMLParser.NODE_ELEMENT:
				process_group(xml_data)
			elif xml_data.get_node_type() == XMLParser.NODE_ELEMENT_END:
#				post_process_group(current_node)
				current_node = current_node.get_parent()
		elif xml_data.get_node_name() == "rect":
			process_rectangle(xml_data)
		elif xml_data.get_node_name() == "polygon":
			process_polygon(xml_data)
		elif xml_data.get_node_name() == "path":
			process_path(xml_data)
	print("... end parsing")


func process_group(element:XMLParser) -> void:
	var new_group = Node2D.new()
	new_group.name = element.get_named_attribute_value("id")
	new_group.transform = get_svg_transform(element)
	current_node.add_child(new_group)
	new_group.set_owner(root_node)
	new_group.set_meta("_edit_group_", true)
	current_node = new_group
	print("group " + new_group.name + " created")


func post_process_group(group) -> void:
	#move all to limiter center
	var limiter_offset = Vector2.ZERO
	if group.has_node("Limiter"):
		limiter_offset = group.get_node("Limiter").rect_position + group.get_node("Limiter").rect_size/2
	for c in group.get_children():
		if c is ColorRect:
			c.rect_position -= limiter_offset
			if c.name.begins_with("Exit"):
				c.rect_size = Vector2(4, 5)
		elif c is Line2D:
			c.position -= limiter_offset
	group.position += limiter_offset


func process_rectangle(element:XMLParser) -> void:
	var new_rect = ColorRect.new()
	new_rect.name = element.get_named_attribute_value("id")
	current_node.add_child(new_rect)
	new_rect.set_owner(root_node)
	
	#transform
	var x = float(element.get_named_attribute_value("x"))
	var y = float(element.get_named_attribute_value("y"))
	var width = float(element.get_named_attribute_value("width"))
	var height = float(element.get_named_attribute_value("height"))
	var transform = get_svg_transform(element)
	new_rect.rect_position = Vector2((x), (y))
	new_rect.rect_size = Vector2(width, height)
	new_rect.rect_position = transform.xform(new_rect.rect_position)
	new_rect.rect_size.x *= transform[0][0] 
	new_rect.rect_size.y *= transform[1][1]
	
	#style
	var style = get_svg_style(element)
	if style.has("fill"):
		new_rect.color = Color(style["fill"])
	if style.has("fill-opacity"):
		new_rect.color.a = float(style["fill-opacity"])
		
	print("-rect ", new_rect.name, " created")


func process_polygon(element:XMLParser) -> void:
	var points : PoolVector2Array
	var points_split = element.get_named_attribute_value("points").split(" ", false)
	for i in points_split:
		var values = i.split_floats(",", false)
		points.append(Vector2(values[0], values[1]))
	points.append(points[0])

	#create closed line
	var new_line = Line2D.new()
	new_line.name = element.get_named_attribute_value("id")
	new_line.transform = get_svg_transform(element)
	current_node.add_child(new_line)
	new_line.set_owner(root_node)
	new_line.points = points
	
	#style
	var style = get_svg_style(element)
	if style.has("fill"):
		new_line.default_color = Color(style["fill"])
	if style.has("stroke-width"):
		new_line.width = float(style["stroke-width"])

	print("-line ", new_line.name, " created")


func process_path(element:XMLParser) -> void:
	#prepare element string
	var element_string = element.get_named_attribute_value("d")
	for symbol in ["m", "M", "v", "V", "h", "H", "l", "L", "c", "C", "s", "S"]:
		element_string = element_string.replacen(symbol, " " + symbol + " ")
	element_string = element_string.replacen(",", " ")
	
	#split element string into multiple arrays
	var element_string_array = element_string.split(" ", false)
	var string_arrays = []
	var string_array : PoolStringArray
	for a in element_string_array:
		if a == "m" or a == "M":
			if string_array.size() > 0:
				string_arrays.append(string_array)
				string_array.resize(0)
		string_array.append(a)
	string_arrays.append(string_array)
	
	#convert into Line2Ds
	for string_array in string_arrays:
		var cur_point = Vector2.ZERO
		var points : PoolVector2Array
		
		for i in string_array.size()-1:
			match string_array[i]:
				"m":
					cur_point += Vector2(float(string_array[i+1]), float(string_array[i+2]))
					points.append(cur_point)
				"M":
					cur_point = Vector2(float(string_array[i+1]), float(string_array[i+2]))
					points.append(cur_point)
				"v":
					cur_point.y += float(string_array[i+1])
					points.append(cur_point)
				"V":
					cur_point.y = float(string_array[i+1])
					points.append(cur_point)
				"h":
					cur_point.x += float(string_array[i+1])
					points.append(cur_point)
				"H":
					cur_point.x = float(string_array[i+1])
					points.append(cur_point)
				"l":
					cur_point += Vector2(float(string_array[i+1]), float(string_array[i+2]))
					points.append(cur_point)
				"L":
					cur_point = Vector2(float(
					string_array[i+1]), float(string_array[i+2]))
					points.append(cur_point)
				#simpify Bezier curves with straight line
				"c": 
					cur_point += Vector2(float(string_array[i+5]), float(string_array[i+6]))
					points.append(cur_point)
				"C":
					cur_point = Vector2(float(string_array[i+5]), float(string_array[i+6]))
					points.append(cur_point)
				"s":
					cur_point += Vector2(float(string_array[i+3]), float(string_array[i+4]))
					points.append(cur_point)
				"S":
					cur_point = Vector2(float(string_array[i+3]), float(string_array[i+4]))
					points.append(cur_point)
		
		if string_array[string_array.size()-1].to_upper() == "Z": #closed polygon
			create_polygon2d(	element.get_named_attribute_value("id"), 
								current_node, 
								points, 
								get_svg_transform(element), 
								get_svg_style(element))
		else:
			create_line2d(	element.get_named_attribute_value("id"), 
							current_node, 
							points, 
							get_svg_transform(element), 
							get_svg_style(element))


func create_line2d(	name:String, 
					parent:Node, 
					points:PoolVector2Array, 
					transform:Transform2D, 
					style:Dictionary) -> void:
	var new_line = Line2D.new()
	new_line.name = name
	new_line.transform = transform
	parent.add_child(new_line)
	new_line.set_owner(root_node)
	new_line.points = points
	
	#style
	if style.has("stroke"):
		new_line.default_color = Color(style["stroke"])
	if style.has("stroke-width"):
		new_line.width = float(style["stroke-width"])


func create_polygon2d(	name:String, 
						parent:Node, 
						points:PoolVector2Array, 
						transform:Transform2D, 
						style:Dictionary) -> void:

	var new_poly
	#style
	if style.has("fill") and style["fill"] != "none":
		#create base
		new_poly = Polygon2D.new()
		new_poly.name = name
		parent.add_child(new_poly)
		new_poly.set_owner(root_node)
		new_poly.transform = transform
		new_poly.polygon = points
		new_poly.color = Color(style["fill"])
	
	if style.has("stroke") and style["stroke"] != "none":
		#create outline
		var new_outline = Line2D.new()
		new_outline.name = name + "_stroke"
		if new_poly:
			new_poly.add_child(new_outline)
		else:
			parent.add_child(new_outline)
			new_outline.transform = transform
		new_outline.set_owner(root_node)
		points.append(points[0])
		new_outline.points = points
		
		new_outline.default_color = Color(style["stroke"])
		if style.has("stroke-width"):
			new_outline.width = float(style["stroke-width"])


static func get_svg_transform(element:XMLParser) -> Transform2D:
	var transform = Transform2D.IDENTITY
	if element.has_attribute("transform"):
		var svg_transform = element.get_named_attribute_value("transform")
		#check transform method
		if svg_transform.begins_with("translate"):
			svg_transform = svg_transform.replace("translate", "").replacen("(", "").replacen(")", "")
			var transform_split = svg_transform.split_floats(",")
			transform[2] = Vector2(transform_split[0], transform_split[1])
		elif svg_transform.begins_with("matrix"):
			svg_transform = svg_transform.replace("matrix", "").replacen("(", "").replacen(")", "")
			var matrix = svg_transform.split_floats(",")
			for i in 3:
				transform[i] = Vector2(matrix[i*2], matrix[i*2+1])
	return transform


static func get_svg_style(element:XMLParser) -> Dictionary:
	var style = {}
	if element.has_attribute("style"):
		var svg_style = element.get_named_attribute_value("style")
		svg_style = svg_style.replacen(":", "\":\"")
		svg_style = svg_style.replacen(";", "\",\"")
		svg_style = "{\"" + svg_style + "\"}"
		style = parse_json(svg_style)
	return style



