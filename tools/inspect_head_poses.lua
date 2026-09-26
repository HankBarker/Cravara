local root='C:/Cravera/assets_raw/Main Character/ASEPRITE/Unarmed_Idle/'
local names={'front','back','side_left','side_right'}
local sheet=Image(24*12,24*4,ColorMode.RGB)
local log=io.open('C:/Cravera/art/forest-pass4/head-cels.txt','w')
for row,dir in ipairs(names) do
 local s=app.open(root..'Unarmed_Idle_'..dir..'.aseprite')
 for _,layer in ipairs(s.layers) do
  log:write(dir..' layer '..layer.name..'\n')
  if layer.name=='head' then
   for i=1,#s.frames do
    local cel=layer:cel(i)
    if cel then
     sheet:drawImage(cel.image,Point((i-1)*24+5,(row-1)*24+5))
     log:write(string.format('%s f%d pos%d,%d size%d,%d\n',dir,i,cel.position.x,cel.position.y,cel.image.width,cel.image.height))
    end
   end
  end
 end
 s:close()
end
sheet:resize(sheet.width*4,sheet.height*4)
sheet:saveAs('C:/Cravera/art/forest-pass4/head-cels.png')
log:close()
