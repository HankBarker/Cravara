-- Front/rear run review: generated keys, controlled foot-depth exchange and secondary motion.
local src=assert(app.params.source)
local out=assert(app.params.out)
local dir=assert(app.params.direction)
local keys={}
for i=0,7 do
  local s=app.open(src..'/'..string.format('%02d',i)..'.png')
  local im=Image(96,64,ColorMode.RGB);im:drawSprite(s,1);s:close();keys[i+1]=im
end
local function ramp(a,b,v) local t=math.max(0,math.min(1,(v-a)/(b-a)));return t*t*(3-2*t) end
local function opaque(c) return app.pixelColor.rgbaA(c)>0 end
local function tail(x,y) return dir=='up' and y>=34 and x<50-(y-28)*0.48 end
local frames={}
for n=0,15 do
  local phase=n/16*2*math.pi
  local base=keys[math.floor(n/2)+1]:clone()
  local posed=base:clone()
  local regions=dir=='down' and {{39,47,43,57},{48,56,43,57}} or {{44,50,36,53},{51,58,34,53}}
  for side,r in ipairs(regions) do
    local bottom=r[3]
    for y=r[3],r[4] do for x=r[1],r[2] do
      if not tail(x,y) and opaque(base:getPixel(x,y)) then bottom=math.max(bottom,y) end
    end end
    local target=(dir=='down' and 52 or 48)+4*math.cos(phase+(side==1 and 0 or math.pi))
    local anchor=r[3]
    local foot=math.min(3,math.max(1,bottom-anchor-1))
    for y=anchor,60 do for x=r[1],r[2] do
      if not tail(x,y) then
        local sy
        if y>=target-foot then sy=y+bottom-target
        else sy=anchor+(y-anchor)*(bottom-foot-anchor)/math.max(1,target-foot-anchor) end
        sy=math.floor(sy+0.5)
        local c=0
        if sy>=anchor and sy<=bottom and not tail(x,sy) then c=base:getPixel(x,sy) end
        posed:drawPixel(x,y,c)
      end
    end end
  end
  local im=Image(96,64,ColorMode.RGB)
  for y=0,63 do for x=0,95 do
    local body=1-ramp(36,55,y)
    local tw=dir=='down' and (1-ramp(6,23,y)) or ramp(30,60,y)
    local dx=0.9*math.sin(phase)*body+1.2*math.sin(phase-0.5)*tw
    local dy=0.7*math.sin(phase*2)*body
    local sx=math.floor(x-dx+0.5);local sy=math.floor(y-dy+0.5)
    if sx>=0 and sx<96 and sy>=0 and sy<64 then im:drawPixel(x,y,posed:getPixel(sx,sy)) end
  end end
  frames[n+1]=im
  local s=Sprite(96,64,ColorMode.RGB);s:newCel(s.layers[1],s.frames[1],im,Point(0,0))
  s:saveCopyAs(out..'/'..string.format('%02d',n)..'.png');s:close()
end
local s=Sprite(96,64,ColorMode.RGB)
for n,im in ipairs(frames) do local f=n==1 and s.frames[1] or s:newEmptyFrame();f.duration=0.04;s:newCel(s.layers[1],f,im,Point(0,0)) end
s:newTag(1,16).name='run_'..dir
s:saveAs(out..'/run_'..dir..'.aseprite');s:saveCopyAs(out..'/run_'..dir..'.gif')
app.command.SpriteSize{width=384,height=256,method='nearest'};s:saveCopyAs(out..'/preview-4x.gif');s:close()
local sheet=Sprite(384,256,ColorMode.RGB);local im=Image(384,256,ColorMode.RGB)
for n,f in ipairs(frames) do im:drawImage(f,Point(((n-1)%4)*96,math.floor((n-1)/4)*64)) end
sheet:newCel(sheet.layers[1],sheet.frames[1],im,Point(0,0));app.command.SpriteSize{width=768,height=512,method='nearest'}
sheet:saveCopyAs(out..'/contact-sheet.png');sheet:close()
print('DIRECTIONAL_RUN_OK '..dir..' 16 frames at 25fps')
