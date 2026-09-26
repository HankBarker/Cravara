-- Source-first seated hero: all pixels come from the existing hero atlas.
-- No generated character anatomy, palette substitution or frame resizing.
local root='C:/Cravera/'
local src=Sprite{fromFile=root..'game/Sprites/Base Character/Unarmed_Idle_full.png'}
local atlas=Image(src.width,src.height,ColorMode.RGB);atlas:drawSprite(src,1)
local out=root..'game/Forest/creatures/mount_art/'
local board=Image(256,128,ColorMode.RGB)
for row,dir in ipairs({'down','right','left','up'}) do
 local frame=(dir=='left' or dir=='right') and 5 or 0
 local atlas_row=({down=0,right=2,left=1,up=3})[dir]
 local base=Image(atlas,Rectangle(frame*64,atlas_row*64,64,64))
 local seated=Image(64,64,ColorMode.RGB)
 for y=0,63 do for x=0,63 do
  local c=base:getPixel(x,y)
  if app.pixelColor.rgbaA(c)>0 then
   local xx,yy=x,y
   if y>=40 then
    if dir=='down' or dir=='up' then
     -- Spread the two existing thighs and shorten the shin drop into stirrups.
     xx=x+(x<32 and -2 or 2)
     yy=y-(y>=44 and 2 or 0)
    else
     -- Existing thigh and calf clusters hinge at the hip; head/torso/arms stay
     -- byte-identical to the current idle cel.
     local sign=dir=='right' and 1 or -1
     xx=x+sign*(y>=43 and 3 or 1)
     yy=y-(y>=43 and 2 or 0)
    end
   end
   if xx>=0 and xx<64 and yy>=0 and yy<64 then seated:putPixel(xx,yy,c) end
  end
 end end
 local spr=Sprite(64,64,ColorMode.RGB);spr:newCel(spr.layers[1],spr.frames[1],seated,Point(0,0))
 spr:saveAs(out..'rider_'..dir..'.aseprite');spr:saveCopyAs(out..'rider_'..dir..'.png');spr:close()
 board:drawImage(base,Point((row-1)*64,0));board:drawImage(seated,Point((row-1)*64,64))
 print(dir..' seated from exact idle source frame '..frame..'; upper40rows unchanged')
end
app.fs.makeAllDirectories(root..'art/forest-playtest/v5')
local spr=Sprite(256,128,ColorMode.RGB);spr:newCel(spr.layers[1],spr.frames[1],board,Point(0,0));spr:saveCopyAs(root..'art/forest-playtest/v5/rider-source-native.png');app.activeSprite=spr;app.command.SpriteSize{width=1536,height=768,method='nearest'};spr:saveCopyAs(root..'art/forest-playtest/v5/rider-source-review.png')
print('Source-first four-direction seated hero exported.')
