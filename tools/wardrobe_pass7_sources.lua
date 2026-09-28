-- Layered source documents for each direction. PixelLab images stay editable;
-- the Godot compositor uses the registered PNG layers without a new clock.
local root='C:/Cravera/'
local out=root..'game/Forest/equipment/art/wardrobe/'
for _,dir in ipairs({'down','up','left','right'}) do
 local s=Sprite(64,64,ColorMode.RGB)
 s.layers[1].name='Base keeper - reference'
 local ref=app.open(root..'art/character-pass7/input/'..dir..'.png')
 local base=Image(ref.cels[1].image)
 s:newCel(s.layers[1],1,base,ref.cels[1].position)
 ref:close()
 local names={'cloth_chest_'..dir}
 for _,hair in ipairs({'braid','curly','ponytail'}) do names[#names+1]='hair_'..hair..'_'..dir end
 for _,family in ipairs({'leather','bone','crystal'}) do
  for _,slot in ipairs({'legs','chest','head'}) do names[#names+1]=family..'_'..slot..'_'..dir end
 end
 for _,name in ipairs(names) do
  local source=app.open(out..name..'.png')
  local layer=s:newLayer();layer.name=name
  local cel=source.cels[1]
  s:newCel(layer,1,Image(cel.image),cel.position)
  layer.isVisible=string.sub(name,1,7)=='crystal'
  source:close()
 end
 s:saveAs(out..'wardrobe_'..dir..'.aseprite')
 s:close()
end
print('Wardrobe layered Aseprite source files saved.')
