-- Subtle native-pixel secondary motion; feet and shared canvas stay fixed.
local src = assert(app.params.source)
local out = assert(app.params.out)
local count = tonumber(app.params.count) or 8
local fps = tonumber(app.params.fps) or 10
local name = app.params.name or 'walk_right'
local run = name == 'run_right'
local function ramp(a,b,x)
  local t=math.max(0,math.min(1,(x-a)/(b-a)))
  return t*t*(3-2*t)
end
local frames={}
for n=0,count-1 do
  local s=app.open(src..'/'..string.format('%02d',n)..'.png')
  assert(s and s.width==96 and s.height==64)
  local base=Image(96,64,ColorMode.RGB)
  base:drawSprite(s,1)
  s:close()
  -- Optional approved head sequence preserves face and jaw timing when legs are reordered.
  if app.params.head_source then
    local headCount=tonumber(app.params.head_count) or count
    local h=app.open(app.params.head_source..'/'..string.format('%02d',math.floor(n*headCount/count))..'.png')
    local hi=Image(96,64,ColorMode.RGB)
    hi:drawSprite(h,1)
    h:close()
    for y=0,32 do for x=77,95 do base:drawPixel(x,y,hi:getPixel(x,y)) end end
  end
  local im=Image(96,64,ColorMode.RGB)
  local phase=n/count*2*math.pi
  for y=0,63 do for x=0,95 do
    local upper=1-ramp(31,45,y)
    local head=ramp(65,79,x)*upper
    local tail=(1-ramp(4,47,x))*(1-ramp(31,37,y))
    local arm=ramp(60,65,x)*(1-ramp(73,78,x))*ramp(30,36,y)*(1-ramp(41,46,y))
    local dx=1.2*math.sin(phase)*arm
    local dy=0.65*math.sin(2*phase)*upper+0.4*math.sin(2*phase)*head
      +1.55*math.sin(phase-0.5)*tail+0.8*math.cos(phase)*arm
    if run then
      -- Rock around the hips; taper through thighs to keep feet stable.
      local body=1-ramp(33,49,y)
      local swing=math.sin(phase)
      dx=1.0*swing*body*(1-ramp(74,88,x)) + 0.6*math.sin(phase-0.4)*arm
      dy=(1.15*math.sin(2*phase-0.5) + 0.025*(x-54)*swing)*body
        +0.65*math.sin(phase-0.55)*head + 1.1*math.sin(phase-0.8)*tail
    end
    local sx=math.floor(x-dx+0.5)
    local sy=math.floor(y-dy+0.5)
    if sx>=0 and sx<96 and sy>=0 and sy<64 then im:drawPixel(x,y,base:getPixel(sx,sy)) end
  end end
  frames[n+1]=im
  local one=Sprite(96,64,ColorMode.RGB)
  one:newCel(one.layers[1],one.frames[1],im,Point(0,0))
  one:saveCopyAs(out..'/'..string.format('%02d',n)..'.png')
  one:close()
end
local anim=Sprite(96,64,ColorMode.RGB)
anim.layers[1].name='Raptor secondary motion - '..name
for n,im in ipairs(frames) do
  local f=n==1 and anim.frames[1] or anim:newEmptyFrame()
  f.duration=1/fps
  anim:newCel(anim.layers[1],f,im,Point(0,0))
end
anim:newTag(1,count).name=name
anim:saveAs(out..'/'..name..'.aseprite')
anim:saveCopyAs(out..'/'..name..'.gif')
app.command.SpriteSize{width=384,height=256,method='nearest'}
anim:saveCopyAs(out..'/'..name..'-4x.gif')
anim:close()
local height=math.ceil(count/4)*64
local sheet=Sprite(384,height,ColorMode.RGB)
local pixels=Image(384,height,ColorMode.RGB)
for n,im in ipairs(frames) do pixels:drawImage(im,Point(((n-1)%4)*96,math.floor((n-1)/4)*64)) end
sheet:newCel(sheet.layers[1],sheet.frames[1],pixels,Point(0,0))
app.command.SpriteSize{width=1152,height=height*3,method='nearest'}
sheet:saveCopyAs(out..'/contact-sheet.png')
sheet:close()
print('SECONDARY_MOTION_OK frames='..count..' fps='..fps)
