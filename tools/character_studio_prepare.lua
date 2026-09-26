-- Aseprite batch preparation. Source images must share exactly 1536x1024.
-- Fixed 16:1 sampling for every frame; never crop/center each pose independently.
local src = assert(app.params['source'], 'source folder required')
local out = assert(app.params['out'], 'output folder required')
local count = tonumber(app.params['count']) or 6
local fps = tonumber(app.params['fps']) or 8
local name = app.params['name'] or 'walk_right'
local frames = {}
for n = 0, count - 1 do
  local s = app.open(src .. '/' .. string.format('%02d', n) .. '.png')
  assert(s and s.width == 1536 and s.height == 1024, 'All sources must be 1536x1024')
  if s.layers[1].isBackground then app.command.LayerFromBackground() end
  for _, cel in ipairs(s.cels) do
    local im = cel.image:clone()
    for px in im:pixels() do
      local c = px()
      local r,g,b = app.pixelColor.rgbaR(c),app.pixelColor.rgbaG(c),app.pixelColor.rgbaB(c)
      if r > 100 and b > 100 and r > g * 1.65 and b > g * 1.65 then
        px(app.pixelColor.rgba(0,0,0,0))
      end
    end
    cel.image = im
  end
  s:saveCopyAs(out .. '/full-' .. string.format('%02d',n) .. '.png')
  app.command.SpriteSize{width=96,height=64,method='nearest'}
  s:saveCopyAs(out .. '/' .. string.format('%02d',n) .. '.png')
  local im = Image(96,64,ColorMode.RGB)
  im:drawSprite(s,1)
  frames[n+1] = im
  s:close()
end
local animation = Sprite(96,64,ColorMode.RGB)
animation.layers[1].name = 'Raptor - generated walk test'
for n,im in ipairs(frames) do
  local f = n == 1 and animation.frames[1] or animation:newEmptyFrame()
  f.duration = 1/fps
  animation:newCel(animation.layers[1], f, im, Point(0,0))
end
local tag = animation:newTag(1,count)
tag.name = name
animation:saveAs(out .. '/walk-right.aseprite')
animation:saveCopyAs(out .. '/walk-right.gif')
local sheet = Sprite(96*count,64,ColorMode.RGB)
local pixels = Image(96*count,64,ColorMode.RGB)
for n,im in ipairs(frames) do pixels:drawImage(im,Point((n-1)*96,0)) end
sheet:newCel(sheet.layers[1],sheet.frames[1],pixels,Point(0,0))
sheet:saveCopyAs(out .. '/contact-sheet.png')
sheet:close()
app.activeSprite = animation
app.command.SpriteSize{width=384,height=256,method='nearest'}
animation:saveCopyAs(out .. '/preview-4x.gif')
animation:close()
print('STUDIO_PREPARED frames=' .. count .. ' canvas=96x64 fps=' .. fps .. ' name=' .. name)
