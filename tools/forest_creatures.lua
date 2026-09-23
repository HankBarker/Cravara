-- Reproducible source-alpha extraction and restrained pixel animation.
-- No opaque backdrop is retained. Nearest sampling, fixed ground and canvas.
local vertical=app.params.vertical=='1'
local source=Sprite{fromFile='C:/Cravera/art/forest-creatures/'..(vertical and 'directions-source.png' or 'source.png')}
local full=Image(source.width,source.height,ColorMode.RGB);full:drawSprite(source,1)
local defs={
 {'raptor',0,0,480,470,42,32}, {'stego',480,0,1030,470,60,40},
 {'trike',1030,0,1536,470,54,42}, {'longneck',0,475,570,985,70,60},
 {'dodo',590,495,940,985,20,24}, {'rex',940,475,1536,985,76,56}}
local out='C:/Cravera/game/Forest/creatures/art/'
app.fs.makeAllDirectories(out)
local rgba=app.pixelColor.rgba
for _,d in ipairs(defs) do
 local name,x0,y0,x1,y1,w,h=table.unpack(d)
 if vertical then
  local col=({raptor=0,stego=1,trike=2,longneck=0,dodo=1,rex=2})[name]
  local row=({raptor=0,stego=0,trike=0,longneck=2,dodo=2,rex=2})[name]
  if app.params.facing=='up' then row=row+1 end
  x0=math.floor(source.width/3*col);x1=math.floor(source.width/3*(col+1))
  y0=math.floor(source.height/4*row);y1=math.floor(source.height/4*(row+1))
  if row==0 then y0=0;y1=350 end
  if row==1 then y0=350;y1=713 end
  if row==2 then y0=710;y1=1056 end
  if row==3 then y0=1057;y1=source.height end
  if name=='dodo' and row==2 then y0=760;y1=1068 end
  if name=='dodo' and row==3 then y0=1090;y1=source.height end
  name=name..'_'..app.params.facing
 end
 local bx,by,ex,ey=x1,y1,x0,y0
 for y=y0,y1-1 do for x=x0,x1-1 do
  if app.pixelColor.rgbaA(full:getPixel(x,y))>=180 then bx=math.min(bx,x);by=math.min(by,y);ex=math.max(ex,x);ey=math.max(ey,y) end
 end end
 local scale=math.min((w-4)/(ex-bx+1),(h-4)/(ey-by+1))
 local dw,dh=math.floor((ex-bx+1)*scale),math.floor((ey-by+1)*scale)
 local ox,oy=math.floor((w-dw)/2),h-dh-2
 local base=Image(w,h,ColorMode.RGB)
 for y=0,dh-1 do for x=0,dw-1 do
  local c=full:getPixel(bx+math.floor(x/scale),by+math.floor(y/scale))
  if app.pixelColor.rgbaA(c)>=140 then base:drawPixel(ox+x,oy+y,rgba(app.pixelColor.rgbaR(c),app.pixelColor.rgbaG(c),app.pixelColor.rgbaB(c),255)) end
 end end
 local spr=Sprite(w,h,ColorMode.RGB)
 local modes={{'idle',4,0.22},{'walk',8,0.10},{'attack',5,0.17}}
 local idx=0
 local sheet=Image(w*17,h,ColorMode.RGB)
 for _,mode in ipairs(modes) do
  local tagStart=idx+1
  for f=0,mode[2]-1 do
   idx=idx+1
   if idx>1 then spr:newEmptyFrame() end
   spr.frames[idx].duration=mode[3]
   local im=Image(w,h,ColorMode.RGB)
   local phase=f/mode[2]*math.pi*2
   local legY=math.floor(h*0.74)
   for y=0,h-1 do for x=0,w-1 do
    local dx,dy=0,0
    if mode[1]=='walk' then
     if vertical and y>=math.floor(h*0.52) then
      local sign=x<w*0.5 and 1 or -1
      if math.abs(x-w*0.5)>w*0.10 then
       dy=math.floor(math.sin(phase)*sign*1.5+0.5)
      elseif app.params.facing=='up' then dx=math.floor(math.sin(phase)*0.9+0.5) end
     elseif y>=legY then
      local sign=x<w*0.57 and 1 or -1
      dx=math.floor(math.sin(phase)*sign*1.6*(y-legY)/(h-legY)+0.5)
      dy=math.floor(math.max(0,math.cos(phase)*sign)*1.3+0.5)
     else
      dy=math.floor(math.cos(phase*2)*0.6+0.5)
      if x<w*0.3 then dy=dy+math.floor(math.sin(phase)*0.8+0.5) end
     end
    elseif mode[1]=='idle' then
     if y<legY and x>w*0.38 then dy=(f==2 and -1 or 0) end
    elseif mode[1]=='attack' then
     local lunge=({0,-1,2,3,0})[f+1]
     dx=y<legY and lunge or 0
     dy=(x>w*0.68 and y<h*0.55 and f==3) and 1 or 0
    end
    local c=base:getPixel(x,y)
    local xx,yy=x+dx,y+dy
    if xx>=0 and xx<w and yy>=0 and yy<h and app.pixelColor.rgbaA(c)>0 then im:drawPixel(xx,yy,c) end
   end end
   spr:newCel(spr.layers[1],spr.frames[idx],im,Point(0,0))
   sheet:drawImage(im,Point((idx-1)*w,0))
  end
  local tag=spr:newTag(tagStart,idx);tag.name=mode[1]
 end
 spr:saveAs(out..name..'.aseprite')
 local ss=Sprite(w*17,h,ColorMode.RGB);ss:newCel(ss.layers[1],ss.frames[1],sheet,Point(0,0));ss:saveCopyAs(out..name..'.png');ss:close();spr:close()
 print(name..' '..w..'x'..h..' source '..bx..','..by..'-'..ex..','..ey..' 17 frames')
end
source:close()
