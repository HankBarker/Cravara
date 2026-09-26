local f=io.open('C:/Cravera/art/forest-pass2/layers.txt','w')
for _, name in ipairs({'Sword_attack_front','Sword_attack_back','Sword_attack_side_left','Sword_attack_side_right'}) do
 local sprite=app.open('C:/Cravera/assets_raw/Main Character/ASEPRITE/Sword_Attack/'..name..'.aseprite')
 f:write(name..'\n')
 for _,layer in ipairs(sprite.layers) do f:write(layer.name..'\n') end
 sprite:close()
end
f:close()
