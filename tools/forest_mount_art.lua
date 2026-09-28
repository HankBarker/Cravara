-- Generated full saddled variants, assembled in Aseprite. Original dinosaur
-- and adventurer sheets are read-only. One scale/ground anchor per direction.
local out='C:/Cravera/game/Forest/creatures/mount_art/'
app.fs.makeAllDirectories(out)
local function loadImage(path)
 local s=Sprite{fromFile=path};local im=Image(s.width,s.height,ColorMode.RGB);im:drawSprite(s,1);s:close();return im
end
local function fit(src,r,w,h)
 local bx,by,ex,ey=r.x+r.width,r.y+r.height,r.x,r.y
 for y=r.y,r.y+r.height-1 do for x=r.x,r.x+r.width-1 do if app.pixelColor.rgbaA(src:getPixel(x,y))>180 then bx=math.min(x,bx);by=math.min(y,by);ex=math.max(x,ex);ey=math.max(y,ey) end end end
 local scale=math.min(w/(ex-bx+1),h/(ey-by+1));local dw=math.floor((ex-bx+1)*scale);local dh=math.floor((ey-by+1)*scale)
 local im=Image(w,h,ColorMode.RGB)
 for y=0,dh-1 do for x=0,dw-1 do local c=src:getPixel(bx+math.floor(x/scale),by+math.floor(y/scale));if app.pixelColor.rgbaA(c)>160 then im:putPixel(x+math.floor((w-dw)/2),y+h-dh,app.pixelColor.rgba(app.pixelColor.rgbaR(c),app.pixelColor.rgbaG(c),app.pixelColor.rgbaB(c),255)) end end end
 return im
end
local src=loadImage('C:/Cravera/art/forest-playtest/v4/saddled-generated.png')
for row,sp in ipairs({'stego','trike'}) do
 local w=sp=='stego' and 60 or 54;local h=sp=='stego' and 40 or 42
 for col,dir in ipairs({'side','down','up'}) do
  local crop=Rectangle(math.floor((col-1)*src.width/3),math.floor((row-1)*src.height/2),math.floor(src.width/3),math.floor(src.height/2))
  local body=fit(src,crop,w-4,h-4);local base=Image(w,h,ColorMode.RGB);base:drawImage(body,Point(2,2))
  local spr=Sprite(w,h,ColorMode.RGB);local sheet=Image(w*17,h,ColorMode.RGB)
  for f=0,16 do
   if f>0 then spr:newEmptyFrame() end
   local im=Image(w,h,ColorMode.RGB);local walk=f>=4 and f<12;local attack=f>=12;local phase=(f-4)/8*math.pi*2
   spr.frames[f+1].duration=walk and 0.1 or (attack and 0.14 or 0.22)
   for y=0,h-1 do for x=0,w-1 do
    local c=base:getPixel(x,y);local dx,dy=0,0
    if walk then
     if y>h*.73 then local sign=x<w*.5 and 1 or -1;dy=math.floor(math.sin(phase)*sign*1.2+.5);if dir=='side' then dx=math.floor(math.cos(phase)*sign*1.2+.5) end
     else dy=(f%4==1 or f%4==2) and 1 or 0 end
    elseif attack then
     local p=({0,-1,2,1,0})[f-11]
     if sp=='stego' then
      -- Tail fans across the intended strike while the saddle stays secured.
      if dir=='side' and x<w*.40 then dy=math.floor(p*(1-x/(w*.4))*2);elseif dir~='side' and y>h*.60 then dx=math.floor(p*1.4) end
     elseif y<h*.78 then
      if dir=='side' then dx=p elseif dir=='down' then dy=p else dy=-p end
     end
    end
    if x+dx>=0 and x+dx<w and y+dy>=0 and y+dy<h and app.pixelColor.rgbaA(c)>0 then im:putPixel(x+dx,y+dy,c) end
   end end
   spr:newCel(spr.layers[1],spr.frames[f+1],im,Point(0,0));sheet:drawImage(im,Point(f*w,0))
  end
  for _,t in ipairs({{'idle',1,4},{'walk',5,12},{'attack',13,17}}) do local tag=spr:newTag(t[2],t[3]);tag.name=t[1] end
  spr:saveAs(out..sp..'_'..dir..'.aseprite');spr:close()
  local png=Sprite(w*17,h,ColorMode.RGB);png:newCel(png.layers[1],png.frames[1],sheet,Point(0,0));png:saveCopyAs(out..sp..'_'..dir..'.png');png:close()
  print(sp..' '..dir..' full saddled 17-frame sheet')
 end
end
-- Hero identity is maintained by the source-first seated-pose recipe.
dofile('C:/Cravera/tools/forest_rider_source.lua')
