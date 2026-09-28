-- Bake nearest-neighbor presentation scale without modifying approved sources.
local jobs=dofile(assert(app.params.jobs))
for _,job in ipairs(jobs) do
 for n,path in ipairs(job.frames) do
  local s=app.open(path)
  local im=Image(s.width,s.height,ColorMode.RGB);im:drawSprite(s,1);s:close()
  local scaled=Image(im,Rectangle(0,0,im.width,im.height))
  if job.scale~=1 then
   scaled:resize(math.floor(im.width*job.scale+0.5),math.floor(im.height*job.scale+0.5))
  end
  local dest=Sprite(112,80,ColorMode.RGB)
  local image=Image(112,80,ColorMode.RGB)
  image:drawImage(scaled,Point(math.floor((112-scaled.width)/2+0.5),job.dy))
  dest:newCel(dest.layers[1],dest.frames[1],image,Point(0,0))
  dest:saveCopyAs(job.out..'/'..string.format('%03d',n-1)..'.png');dest:close()
 end
 print('SCALE_BAKED '..job.name..' '..#job.frames)
end
