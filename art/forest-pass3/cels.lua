local f=io.open('C:/Cravera/art/forest-pass3/cels.txt','w')
for _, action in ipairs({'Unarmed_Idle','Unarmed_Walk','Unarmed_Run','Unarmed_Hurt','Sword_Attack'}) do
 local name=action=='Sword_Attack' and 'Sword_attack' or action
 local s=app.open('C:/Cravera/assets_raw/Main Character/ASEPRITE/'..action..'/'..name..'_front.aseprite')
 f:write(action..'\n')
 for _,l in ipairs(s.layers) do
  f:write(l.name..': ')
  for _,c in ipairs(l.cels) do f:write(string.format('%d=%d,%d(%dx%d) ',c.frame.frameNumber,c.position.x,c.position.y,c.image.width,c.image.height)) end
  f:write('\n')
 end
 s:close()
end
f:close()
