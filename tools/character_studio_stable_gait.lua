-- Stable native artwork with complete lower legs and rigid-size feet.
local root=assert(app.params.root)
local out=assert(app.params.out)
local dir=assert(app.params.direction)
local mode=assert(app.params.mode)
local energy=tonumber(app.params.energy) or 1
local s=app.open(root..'/swipe_'..dir..'/00.png')
local base=Image(112,80,ColorMode.RGB);base:drawSprite(s,1);s:close()
local function ramp(a,b,t) return math.max(0,math.min(1,(t-a)/(b-a))) end
local anchor=dir=='down' and 50 or 43
-- Rear thighs overlap the pelvis instead of meeting it at a moving cut edge.
local legAnchor=dir=='up' and anchor-4 or anchor
local bottom=dir=='down' and 64 or 66
local function tail(x,y) return dir=='up' and y>=anchor and math.abs(x-(57-(y-43)*0.30))<=4 end
local body=base:clone()
for y=anchor,79 do for x=0,111 do if not tail(x,y) then body:drawPixel(x,y,0) end end end
for n=0,19 do
 local phase=n/20*2*math.pi
 local bob=(mode=='run' and 0.75*energy or 0.4)*math.sin(phase*2)
 local im=Image(112,80,ColorMode.RGB)
 for side=1,2 do
  local sign=side==1 and -1 or 1
  local p=phase+(side==1 and 0 or math.pi)
  local reach=(mode=='run' and 2.5*energy or 1.5)
  local target=bottom+reach*math.cos(p)-reach*math.max(0,math.sin(p))
  local origin=legAnchor+bob
  local footHeight=6
  for y=legAnchor-2,73 do for x=37,75 do
   local sy
   if y>=target-footHeight then sy=y+bottom-target
   else sy=legAnchor+(y-origin)*(bottom-footHeight-legAnchor)/(target-footHeight-origin) end
   local lateral=(mode=='run' and 1.1*energy or 0.6)*math.sin(p)*ramp(anchor,bottom,y)
   local sx=math.floor(x-lateral+0.5);sy=math.floor(sy+0.5)
   if dir=='up' and side==1 then sx=112-sx end
   local lo,hi
   if dir=='up' then lo,hi=60,72 else lo,hi=side==1 and 44 or 58,side==1 and 55 or 70 end
   if sx>=lo and sx<=hi and sy>=legAnchor and sy<=bottom then
    local c=base:getPixel(sx,sy)
    if app.pixelColor.rgbaA(c)>0 then im:drawPixel(x,y,c) end
   end
  end end
 end
 -- Fixed torso source prevents generated texture and width flicker.
 for y=0,79 do for x=0,111 do
  local upper=1-ramp(anchor-5,anchor+2,y)
  local tw=dir=='up' and ramp(43,69,y) or 1-ramp(13,28,y)
  local dx=0.45*math.sin(phase)*upper+1.0*math.sin(phase-0.6)*tw
  local dy=bob*upper
  if mode=='run' and energy>1 and dir=='down' then
   local arm=ramp(39,43,y)*(1-ramp(47,50,y))
   dy=dy+0.8*math.sin(phase+(x<56 and 0 or math.pi))*arm
  end
  if dir=='down' and mode=='run' then dy=dy+1.2*energy*ramp(22,32,y)*(1-ramp(40,49,y)) end
  local sx,sy=math.floor(x-dx+0.5),math.floor(y-dy+0.5)
  if sx>=0 and sx<112 and sy>=0 and sy<80 then
   local c=body:getPixel(sx,sy);if app.pixelColor.rgbaA(c)>0 then im:drawPixel(x,y,c) end
  end
 end end
 local frame=Sprite(112,80,ColorMode.RGB);frame:newCel(frame.layers[1],frame.frames[1],im,Point(0,0))
 frame:saveCopyAs(out..'/'..string.format('%02d',n)..'.png');frame:close()
end
print('STABLE_GAIT '..mode..'_'..dir..' 20 frames')
