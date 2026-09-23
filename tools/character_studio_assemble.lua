-- Native pixel transforms and ordered assembly; source artwork is preserved.
local jobs=dofile(assert(app.params.jobs))
local function load(path)
 local s=app.open(path);local im=Image(s.width,s.height,ColorMode.RGB);im:drawSprite(s,1);s:close();return im
end
for _,job in ipairs(jobs) do
 local frames={}
 for n,entry in ipairs(job.frames) do
  local src=load(entry.path);local im=Image(job.width,job.height,ColorMode.RGB)
  for y=0,job.height-1 do for x=0,job.width-1 do
   local sx=x-(entry.dx or 0);local sy=y-(entry.dy or 0)
   if job.idle then
    local body=math.max(0,math.min(1,(60-y)/18))
    sy=math.floor(sy-math.sin((n-1)/#job.frames*2*math.pi)*body+0.5)
   end
   if job.mirror then sx=src.width-1-sx end
   if sx>=0 and sx<src.width and sy>=0 and sy<src.height then im:drawPixel(x,y,src:getPixel(sx,sy)) end
  end end
  frames[n]=im
  local s=Sprite(job.width,job.height,ColorMode.RGB);s:newCel(s.layers[1],s.frames[1],im,Point(0,0))
  s:saveCopyAs(job.out..'/'..string.format('%02d',n-1)..'.png');s:close()
 end
 local s=Sprite(job.width,job.height,ColorMode.RGB)
 for n,im in ipairs(frames) do local f=n==1 and s.frames[1] or s:newEmptyFrame();f.duration=1/job.fps;s:newCel(s.layers[1],f,im,Point(0,0)) end
 s:newTag(1,#frames).name=job.name;s:saveAs(job.out..'/'..job.name..'.aseprite')
 app.activeSprite=s;app.command.SpriteSize{width=job.width*4,height=job.height*4,method='nearest'}
 s:saveCopyAs(job.out..'/preview-4x.gif');s:close()
 local rows=math.ceil(#frames/4);local sh=Sprite(job.width*4,job.height*rows,ColorMode.RGB)
 local im=Image(sh.width,sh.height,ColorMode.RGB)
 for n,f in ipairs(frames) do im:drawImage(f,Point(((n-1)%4)*job.width,math.floor((n-1)/4)*job.height)) end
 sh:newCel(sh.layers[1],sh.frames[1],im,Point(0,0));app.command.SpriteSize{width=sh.width*2,height=sh.height*2,method='nearest'}
 sh:saveCopyAs(job.out..'/contact-sheet.png');sh:close()
 print('ASSEMBLED '..job.name..' '..#frames)
end
