extends Node2D
## Finite sun shadows plus native, occluded point lights for fire and carried gear.
var world: Node2D
var player: Node2D
var nearby: Array[Node2D] = []
var _refresh := 0.0
var _pass: Node2D
## Sun shadows are drawn opaque into one group and faded together, so where two
## shadows overlap the ground is no darker than under one (as in daylight).
var _shade: CanvasGroup
const SHADOW_COLOR := Color(0.08,0.17,0.15)
## How dark a shadow is while the sun is up (it fades as the sun sets).
const SHADOW_STRENGTH := 0.34
var _gradient: GradientTexture2D
var _active_lights: Array[PointLight2D] = []
var _silhouettes: Dictionary = {}
var _sun_projections: Dictionary = {}
var _sun_phase := -1

func _ready():
	_gradient = GradientTexture2D.new()
	_gradient.width = 192
	_gradient.height = 192
	_gradient.fill = GradientTexture2D.FILL_RADIAL
	_gradient.fill_from = Vector2(0.5,0.5)
	_gradient.fill_to = Vector2(1,0.5)
	var gradient := Gradient.new()
	gradient.set_color(0,Color.WHITE)
	gradient.set_color(1,Color(1,1,1,0))
	_gradient.gradient = gradient
	_shade = CanvasGroup.new()
	_shade.name = "SunShadows"
	_shade.z_index = -17
	add_child(_shade)
	_pass = Node2D.new()
	_pass.draw.connect(_draw_shadows)
	_shade.add_child(_pass)
	_refresh_nearby()

func _process(delta):
	_refresh -= delta
	if _refresh<=0:
		_refresh=0.2
		_refresh_nearby()
	_update_light_energy()
	_pass.queue_redraw()

func _refresh_nearby():
	if not is_instance_valid(player) or not is_instance_valid(world): return
	for prop in nearby:
		if is_instance_valid(prop) and prop.has_node("LightOcclusion"): prop.get_node("LightOcclusion").visible=false
	nearby.clear()
	for prop in world.props.values():
		if not is_instance_valid(prop) or prop.global_position.distance_squared_to(player.global_position)>150000: continue
		nearby.append(prop)
		_set_prop_light_mask(prop)
		if prop.has_method("get_shadow_footprint"):
			var footprint: PackedVector2Array = _occlusion_shape(prop)
			# These emitters sit visually above their own hearth/stake/base. A 2D
			# footprint beneath them would incorrectly shadow half their own light.
			if footprint.size()>=3 and prop.kind not in ["campfire","torch","shrine"]:
				var occluder: LightOccluder2D = prop.get_node_or_null("LightOcclusion")
				if not occluder:
					occluder=LightOccluder2D.new()
					occluder.name="LightOcclusion"
					occluder.show_behind_parent=true
					occluder.occluder=OccluderPolygon2D.new()
					prop.add_child(occluder)
				occluder.occluder.polygon=footprint
				occluder.visible=GameSettings.shadows_enabled
		if prop.kind in ["campfire","shrine"] and not prop.has_node("EmberLight"):
			var light := PointLight2D.new()
			light.name="EmberLight"
			light.texture=_gradient
			light.position=Vector2(0,-8)
			light.color=Color("ffbc6d") if prop.kind=="campfire" else Color("79d9d5")
			light.energy=0.75
			light.texture_scale=1.05 if prop.kind=="campfire" else 0.65
			prop.add_child(light)
	var lights: Array[PointLight2D] = []
	for prop in world.props.values():
		if not is_instance_valid(prop): continue
		var light: PointLight2D = prop.get_node_or_null("EmberLight")
		if prop.kind=="torch": light=prop.get_node_or_null("PlacedObject/PointLight2D")
		if light:
			light.enabled=prop.global_position.distance_squared_to(player.global_position)<145000
			var surface: PointLight2D=light.get_node_or_null("PropSurfaceLight")
			if surface: surface.enabled=light.enabled and light.visible
			if light.enabled: lights.append(light)
	lights.sort_custom(func(a,b):return a.global_position.distance_squared_to(player.global_position)<b.global_position.distance_squared_to(player.global_position))
	for i in lights.size():
		lights[i].enabled=i<8
		_configure_light(lights[i])
	_active_lights=lights
	if player.get("_carried_light"):
		_configure_light(player._carried_light)
		_active_lights.append(player._carried_light)
	if player.get("_armor_glow"):
		_configure_light(player._armor_glow)
		_active_lights.append(player._armor_glow)

func _configure_light(light: PointLight2D):
	if not light.has_meta("forest_base_energy"):
		var holder:=light.get_parent()
		light.set_meta("forest_base_energy",holder.get("_base_energy") if holder.get("_base_energy")!=null else light.energy)
	light.shadow_enabled=GameSettings.shadows_enabled
	light.shadow_filter=Light2D.SHADOW_FILTER_PCF5
	light.shadow_filter_smooth=1.0
	light.shadow_color=Color(0.1,0.15,0.2,0.85)
	# Ground/actors receive occluded light. Raised prop artwork receives a
	# restrained companion light so its silhouette cannot black out its own face.
	light.range_item_cull_mask=1
	if not light.has_node("PropSurfaceLight"):
		var surface:=PointLight2D.new()
		surface.name="PropSurfaceLight"
		surface.range_item_cull_mask=2
		surface.shadow_enabled=false
		light.add_child(surface)

func _set_prop_light_mask(node: Node) -> void:
	if node is CanvasItem and not node is Light2D: node.light_mask=2
	for child in node.get_children():
		if not child is Light2D: _set_prop_light_mask(child)

func _update_light_energy() -> void:
	var daylight := maxf(0,sin((TimeCycle.time_of_day-0.25)*TAU))
	var intensity := lerpf(1.0,0.18,daylight)
	for light in _active_lights:
		if not is_instance_valid(light): continue
		var base: float=light.get_meta("forest_base_energy",1.0)
		var holder:=light.get_parent()
		# Torch.gd owns flicker; keep its true base separate to avoid compounding
		# the day/night factor on each refresh and to preserve the flicker loop.
		if holder.get("_base_energy")!=null:
			holder._base_energy=base*intensity
			light.energy=holder._base_energy*(1.0+sin(holder._flicker_phase)*0.045)
		else:
			light.energy=base*intensity
		var surface: PointLight2D=light.get_node_or_null("PropSurfaceLight")
		if surface:
			surface.texture=light.texture
			surface.texture_scale=light.texture_scale
			surface.color=light.color
			surface.energy=light.energy*0.72
			surface.enabled=light.enabled and light.visible

func sun_offset(height: float, time: float) -> Vector2:
	var elevation := maxf(0,sin((time-0.25)*TAU))
	return Vector2(cos((time-0.25)*TAU),0.48).normalized()*height*(0.3+(1-elevation)*0.9)

func _draw_shadows():
	var daylight := maxf(0,sin((TimeCycle.time_of_day-0.25)*TAU))
	# Full strength once the sun is up (a low sun throws long, dark shadows);
	# they fade only as it rises and sets.
	_shade.self_modulate=Color(1,1,1,SHADOW_STRENGTH*clampf(daylight/0.3,0.0,1.0))
	if not GameSettings.shadows_enabled or daylight<0.03: return
	for prop in nearby:
		if not is_instance_valid(prop) or not prop.has_method("get_shadow_footprint"): continue
		var shape: PackedVector2Array=_corners(prop.get_shadow_footprint())
		if shape.size()<3: continue
		_pass.draw_set_transform(prop.global_position)
		for polygon in _get_local_sun_shadow_polygons(prop,TimeCycle.time_of_day):
			_pass.draw_colored_polygon(polygon,SHADOW_COLOR)
	_pass.draw_set_transform(Vector2.ZERO)

func get_sun_shadow_polygons(prop: Node2D, time: float) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]=[]
	for polygon in _get_local_sun_shadow_polygons(prop,time):
		var translated: PackedVector2Array=polygon.duplicate()
		for i in translated.size(): translated[i]+=prop.global_position
		result.append(translated)
	return result

func _get_local_sun_shadow_polygons(prop: Node2D, time: float) -> Array[PackedVector2Array]:
	# Static sprites share local geometry. Rebuild only as the sun advances,
	# rather than unioning/triangulating every nearby prop on every frame.
	var phase:=floori(time*512)
	if phase!=_sun_phase:
		_sun_phase=phase
		_sun_projections.clear()
	var key: String=prop.kind+":"+str(prop.variant%5)+":"+str(prop.opened)
	if _sun_projections.has(key): return _sun_projections[key]
	var result: Array[PackedVector2Array]=[]
	# Landmarks in parts: every stone, column and heap casts its own shadow from
	# its own foot, as tall as it stands (each outline of a part on its own).
	if prop.has_method("get_shadow_parts"):
		var parts: Array=prop.get_shadow_parts()
		if not parts.is_empty():
			for part in parts:
				for shape in _texture_shapes("part:"+str(part.key),part.texture):
					var bounds: Rect2=shape.bounds
					result.append_array(_project(shape.outline,bounds,part.origin,bounds.size.y,PackedVector2Array(),time))
			_sun_projections[key]=result
			return result
	var silhouette: Dictionary=_sun_silhouette(prop)
	var contact: PackedVector2Array=_corners(prop.get_shadow_footprint())
	if contact.size()<3: return result
	if silhouette.is_empty():
		var offset:=sun_offset(3 if prop.kind=="campfire" else prop.get_shadow_height(),time)
		var points:=contact.duplicate()
		for p in contact: points.append(p+offset)
		result.append(Geometry2D.convex_hull(points))
	else:
		var origin: Vector2=silhouette.origin
		var bounds: Rect2i=silhouette.bounds
		var base_y: float=origin.y+bounds.end.y
		var offset:=sun_offset(prop.get_shadow_height(),time)
		var projected:=PackedVector2Array()
		for p in silhouette.outline:
			# Use the opaque artwork's bottom, not the transparent canvas. A pixel
			# touching the ground must project to that exact ground contact.
			var elevation: float=(bounds.end.y-p.y)/maxf(bounds.size.y,1)
			projected.append(Vector2(origin.x+p.x,base_y)+offset*elevation)
		if Geometry2D.triangulate_polygon(projected).is_empty(): return result
		# Bridge the contact footprint into the sprite projection. Thin/transparent
		# legs and root tips can otherwise leave a 1-3px floating shadow gap.
		var root_x: float=origin.x+(bounds.position.x+bounds.size.x*0.5)
		var bridge:=PackedVector2Array([Vector2(root_x-2,base_y-2),Vector2(root_x+2,base_y-2),Vector2(root_x+2,base_y+2),Vector2(root_x-2,base_y+2)])
		var grounded:=Geometry2D.merge_polygons(projected,bridge)
		for poly in grounded:
			var joined:=Geometry2D.merge_polygons(poly,contact)
			for segment in joined:
				if not Geometry2D.triangulate_polygon(segment).is_empty(): result.append(segment)
	_sun_projections[key]=result
	return result

## One silhouette projected on the ground by the sun: the drawing's outline
## laid flat from its foot and pushed away from the sun by its height, joined to
## the ground it covers.
func _project(outline: PackedVector2Array, bounds: Rect2, origin: Vector2, height: float, contact: PackedVector2Array, time: float) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]=[]
	var base_y: float=origin.y+bounds.end.y
	var offset:=sun_offset(height,time)
	var projected:=PackedVector2Array()
	for p in outline:
		var elevation: float=(bounds.end.y-p.y)/maxf(bounds.size.y,1)
		projected.append(Vector2(origin.x+p.x,base_y)+offset*elevation)
	if Geometry2D.triangulate_polygon(projected).is_empty(): return result
	var root_x: float=origin.x+(bounds.position.x+bounds.size.x*0.5)
	var bridge:=PackedVector2Array([Vector2(root_x-2,base_y-2),Vector2(root_x+2,base_y-2),Vector2(root_x+2,base_y+2),Vector2(root_x-2,base_y+2)])
	for poly in Geometry2D.merge_polygons(projected,bridge):
		var joined: Array=Geometry2D.merge_polygons(poly,contact) if contact.size()>=3 else [poly]
		for segment in joined:
			if not Geometry2D.triangulate_polygon(segment).is_empty(): result.append(segment)
	return result

## Every opaque outline of a texture with its own bounds (cached by key):
## outer contours only (the winding of the largest), specks under 10px left out.
func _texture_shapes(key: String, texture: Texture2D) -> Array:
	if _silhouettes.has(key): return _silhouettes[key]
	var source: Image=texture.get_image()
	var bitmap:=BitMap.new()
	bitmap.create_from_image_alpha(source,0.5)
	var found: Array=[]
	var largest:=0.0
	var winding:=1.0
	for polygon in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO,source.get_size()),1.0):
		if polygon.size()<3 or Geometry2D.triangulate_polygon(polygon).is_empty(): continue
		var area:=0.0
		for i in polygon.size(): area+=polygon[i].cross(polygon[(i+1)%polygon.size()])
		if absf(area)>largest:
			largest=absf(area)
			winding=signf(area)
		found.append([polygon,area])
	var shapes: Array=[]
	for entry in found:
		var polygon: PackedVector2Array=entry[0]
		if signf(entry[1])!=winding or absf(entry[1])*0.5<10.0: continue
		var lo:=polygon[0]
		var hi:=polygon[0]
		for point in polygon:
			lo=lo.min(point)
			hi=hi.max(point)
		shapes.append({"outline":polygon,"bounds":Rect2(lo,hi-lo)})
	_silhouettes[key]=shapes
	return shapes

func _occlusion_shape(prop: Node2D) -> PackedVector2Array:
	if not prop.get_shadow_footprint().has_area(): return PackedVector2Array()
	var silhouette: Dictionary=_sun_silhouette(prop)
	if silhouette.is_empty(): return _corners(prop.get_shadow_footprint())
	var polygon: PackedVector2Array=silhouette.outline.duplicate()
	for i in polygon.size(): polygon[i]+=silhouette.origin
	return polygon

func _sun_silhouette(prop: Node2D) -> Dictionary:
	var key: String=prop.kind+str(prop.variant%5 if prop.kind=="tree" else 0)
	if _silhouettes.has(key): return _silhouettes[key]
	var source: Image
	if prop.kind=="tree":
		# Same untouched source regions used by ForestProp's tree rendering.
		var regions: Array[Rect2i]=[Rect2i(366,0,66,80),Rect2i(436,0,63,79),Rect2i(502,0,82,82),Rect2i(586,9,77,73),Rect2i(305,0,61,79)]
		source=prop.atlas.get_image().get_region(regions[prop.variant%5])
	else:
		var constants: Dictionary=prop.get_script().get_script_constant_map()
		var art: Dictionary=constants.get("ART",{})
		var texture: Texture2D=art.get(prop.kind)
		if prop.kind=="wood_door": texture=constants.get("DOOR")
		if prop.kind=="stone_door": texture=constants.get("STONE_DOOR")
		if texture: source=texture.get_image()
	if source==null:
		_silhouettes[key]={}
		return {}
	var bitmap:=BitMap.new()
	bitmap.create_from_image_alpha(source,0.5)
	var polygons: Array[PackedVector2Array]=bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO,source.get_size()),1.0)
	var outline:=PackedVector2Array()
	var largest:=0.0
	for polygon in polygons:
		if Geometry2D.triangulate_polygon(polygon).is_empty(): continue
		var area:=0.0
		for i in polygon.size(): area+=polygon[i].cross(polygon[(i+1)%polygon.size()])
		if absf(area)>largest:
			largest=absf(area)
			outline=polygon
	if outline.is_empty():
		_silhouettes[key]={}
		return {}
	var bottom:=8 if prop.kind in ["wall","ore","wood_wall","stone_wall"] else 7
	var result: Dictionary={"size":Vector2(source.get_size()),"polygons":polygons,"outline":outline,"bounds":source.get_used_rect(),"origin":Vector2(-source.get_width()/2.0,bottom-source.get_height())}
	_silhouettes[key]=result
	return result

func _corners(rect: Rect2) -> PackedVector2Array:
	if not rect.has_area(): return PackedVector2Array()
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
