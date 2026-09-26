-- Original 24px item artwork. Aseprite source and PNG exports are both retained.
local out='C:/Cravera/game/Forest/art/v6/'
app.fs.makeAllDirectories(out)
local P={ink='302d32',wood='73503b',bark='ae8055',gold='dcc18c',bone='f5e7bc',jade='579c99',light='b6e9da',violet='8566a7',shine='dcc4ed',leaf='66864a',green='a2bf6c',berry='b45073',pink='f0a2b3',soil='705344',egg='e7d9ae'}
local function color(hex) return Color{r=tonumber(hex:sub(1,2),16),g=tonumber(hex:sub(3,4),16),b=tonumber(hex:sub(5,6),16),a=255} end
local function make(id,paint)
 local s=Sprite(24,24,ColorMode.RGB); local im=s.cels[1].image
 local function px(x,y,c) if x>=0 and y>=0 and x<24 and y<24 then im:drawPixel(x,y,color(P[c] or c)) end end
 local function rect(x,y,w,h,c) for yy=y,y+h-1 do for xx=x,x+w-1 do px(xx,yy,c) end end end
 local function line(x0,y0,x1,y1,c,width)
  local n=math.max(math.abs(x1-x0),math.abs(y1-y0))
  for i=0,n do local t=n==0 and 0 or i/n; local x=math.floor(x0+(x1-x0)*t+.5); local y=math.floor(y0+(y1-y0)*t+.5); rect(x,y,width or 1,width or 1,c) end
 end
 local function poly(points,c)
  for y=0,23 do for x=0,23 do
   local inside=false; local j=#points
   for i=1,#points do local a,b=points[i],points[j]; if (a[2]>y)~=(b[2]>y) and x<(b[1]-a[1])*(y-a[2])/(b[2]-a[2])+a[1] then inside=not inside end; j=i end
   if inside then px(x,y,c) end
  end end
 end
 paint(px,rect,line,poly)
 s:saveAs(out..'item-'..id..'.aseprite'); s:saveCopyAs(out..'item-'..id..'.png'); s:close()
end
make('reed_bow',function(p,r,l,f)
 l(6,3,13,4,'ink',3);l(13,4,18,10,'ink',3);l(18,10,17,16,'ink',3);l(17,16,10,21,'ink',3)
 l(7,3,14,6,'bark',2);l(14,6,18,12,'gold');l(18,12,17,16,'bark',2);l(17,16,11,21,'gold')
 l(7,4,10,21,'bone');l(7,13,19,13,'ink');l(7,12,19,12,'gold');f({{20,10},{23,12},{19,15}},'jade');p(21,12,'light')
 r(16,10,3,4,'wood');l(17,10,18,13,'jade');p(18,11,'light')
end)
make('bone_arrow',function(p,r,l,f)
 l(4,20,19,5,'ink',3);l(4,20,19,5,'bark');l(5,20,20,5,'gold');f({{18,2},{23,1},{22,7},{18,8}},'ink');f({{19,3},{22,2},{21,6},{18,7}},'bone');p(20,4,'light')
 f({{2,15},{7,17},{8,22},{5,20},{2,21}},'jade');l(3,17,6,20,'light')
end)
make('garden_hoe',function(p,r,l,f)
 l(5,20,16,6,'ink',3);l(6,20,17,6,'bark');l(7,19,17,6,'gold');f({{10,3},{20,2},{22,5},{21,9},{16,10},{15,6},{10,6}},'ink');f({{11,3},{19,3},{21,5},{20,8},{17,9},{16,5},{11,5}},'jade');l(11,3,19,3,'light');l(18,5,20,5,'gold');l(13,8,15,9,'bone')
end)
for _,id in ipairs({'berry_seed','mushroom_spore'}) do make(id,function(p,r,l,f)
 f({{7,7},{6,4},{17,4},{16,8},{20,15},{18,21},{6,21},{3,16}},'ink');f({{8,7},{7,5},{16,5},{15,8},{18,15},{17,20},{7,20},{5,16}},'bark');l(6,15,8,19,'gold');r(8,8,8,2,'wood');l(9,7,15,7,'bone');p(16,17,'wood')
 if id=='berry_seed' then r(10,12,5,4,'berry');p(11,12,'pink');l(12,11,14,10,'leaf');r(10,17,2,2,'gold')
 else r(11,14,2,3,'bone');f({{8,14},{10,11},{14,11},{16,14}},'violet');p(11,12,'shine') end
end) end
make('dodo_egg',function(p,r,l,f)
 f({{10,3},{14,3},{18,8},{20,15},{18,20},{14,22},{8,21},{4,17},{5,10}},'ink');f({{10,4},{14,4},{17,9},{19,15},{17,19},{14,21},{8,20},{5,16},{6,10}},'bark');f({{10,4},{14,4},{17,9},{17,16},{13,19},{8,18},{6,15},{7,9}},'egg');l(9,7,11,5,'bone',2);r(14,10,2,2,'wood');p(10,16,'bark');p(16,15,'wood');p(12,8,'bark')
end)
for _,id in ipairs({'forest_omelet','berry_compote'}) do make(id,function(p,r,l,f)
 f({{3,9},{7,6},{17,6},{22,10},{20,18},{15,21},{7,20},{3,16}},'ink');f({{4,10},{8,7},{17,7},{21,10},{19,17},{15,20},{7,19},{4,16}},'wood');f({{4,10},{8,7},{17,7},{21,10},{18,15},{7,15}},'gold')
 if id=='forest_omelet' then f({{6,11},{9,8},{16,8},{19,11},{16,14},{8,14}},'bone');r(10,10,4,3,'bark');p(8,12,'green');p(15,9,'leaf');p(16,12,'green')
 else f({{6,10},{9,8},{17,8},{19,11},{17,14},{7,14}},'berry');r(9,9,3,2,'pink');p(15,12,'pink');l(16,10,21,5,'bone') end
 l(7,17,16,18,'bark');p(6,16,'gold')
end) end
for _,id in ipairs({'crystal_pickaxe','crystal_axe'}) do make(id,function(p,r,l,f)
 l(4,21,17,5,'ink',3);l(5,21,18,5,'bark');l(6,20,18,5,'gold');l(9,16,11,17,'wood');l(11,14,13,15,'bone')
 if id=='crystal_pickaxe' then f({{7,4},{13,2},{20,5},{23,12},{18,9},{14,6},{7,7}},'ink');f({{8,4},{13,3},{19,6},{21,10},{17,8},{14,5},{8,6}},'jade');l(9,4,13,3,'light');l(14,4,19,7,'light')
 else f({{8,2},{17,3},{21,8},{20,14},{15,13},{11,9},{7,8}},'ink');f({{9,3},{16,4},{19,8},{19,12},{16,12},{12,8},{8,7}},'jade');f({{9,3},{16,4},{17,6},{12,5},{9,6}},'light');l(17,8,19,11,'light') end
 r(15,5,3,3,'wood');l(15,5,17,7,'gold')
end) end
make('prism_crystal',function(p,r,l,f)
 f({{5,11},{11,1},{15,5},{17,10},{21,7},{22,18},{14,23},{7,21},{2,16}},'ink');f({{6,11},{11,3},{14,6},{16,12},{20,9},{21,18},{14,22},{8,20},{3,16}},'violet');f({{7,12},{11,4},{11,18},{8,19}},'shine');f({{15,14},{19,10},{18,19},{14,21}},'shine');l(11,4,14,7,'bone');p(5,15,'light')
end)
make('shard_sword',function(p,r,l,f)
 f({{5,18},{18,2},{23,1},{22,7},{8,21}},'ink');f({{7,17},{19,3},{22,2},{21,6},{8,19}},'violet');l(8,17,21,3,'shine');l(9,17,20,6,'light');l(3,16,10,23,'ink',2);l(4,16,10,22,'gold');l(2,22,6,18,'wood',2);p(3,22,'jade');p(4,21,'light')
end)
