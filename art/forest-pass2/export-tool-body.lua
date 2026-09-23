local sources = {down='Sword_attack_front', up='Sword_attack_back', left='Sword_attack_side_left', right='Sword_attack_side_right'}
for facing, name in pairs(sources) do
 local sprite=app.open('C:/Cravera/assets_raw/Main Character/ASEPRITE/Sword_Attack/'..name..'.aseprite')
 for _,layer in ipairs(sprite.layers) do
  if layer.name=='sword' or layer.name=='swing' then layer.isVisible=false end
 end
 sprite:saveAs('C:/Cravera/game/Forest/equipment/art/tool_body_'..facing..'.aseprite')
 app.command.ExportSpriteSheet{ui=false,type=SpriteSheetType.HORIZONTAL,textureFilename='C:/Cravera/game/Forest/equipment/art/tool_body_'..facing..'.png'}
 sprite:close()
end
