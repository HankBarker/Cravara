-- Extract a regular generated sheet through Aseprite, with one shared canvas.
local source=assert(app.params.source)
local out=assert(app.params.out)
local name=assert(app.params.name)
local cols=tonumber(app.params.cols) or 4
local rows=tonumber(app.params.rows) or 4
local fps=tonumber(app.params.fps) or 20
local s=app.open(source)
local raw=Image(s.width,s.height,ColorMode.RGB);raw:drawSprite(s,1)
local cw,ch=s.width/cols,s.height/rows
assert(ch==math.floor(ch),'Rows must divide evenly')
s:close()
-- Label complete sprites before extraction: some generated poses cross a cell edge.
local W,H=raw.width,raw.height
local colors,labels={},{}
for y=0,H-1 do for x=0,W-1 do
 local c=raw:getPixel(x,y);local r,g,b=app.pixelColor.rgbaR(c),app.pixelColor.rgbaG(c),app.pixelColor.rgbaB(c)
 if app.pixelColor.rgbaA(c)>=128 and not (r>35 and b>35 and r>g*1.6 and b>g*1.6 and b>r*0.75 and r>b*0.65) then
  colors[y*W+x+1]=app.pixelColor.rgba(r,g,b,255)
 end
end end
for start,c in pairs(colors) do if not labels[start] then
 local q={start};labels[start]=-1;local at=1
 local minx,maxx,miny,maxy=W,0,H,0
 while at<=#q do
  local id=q[at];at=at+1;local x=(id-1)%W;local y=math.floor((id-1)/W)
  minx=math.min(minx,x);maxx=math.max(maxx,x);miny=math.min(miny,y);maxy=math.max(maxy,y)
  for dy=-1,1 do for dx=-1,1 do
   local xx,yy=x+dx,y+dy
   if xx>=0 and xx<W and yy>=0 and yy<H then
    local ni=yy*W+xx+1;if colors[ni] and not labels[ni] then labels[ni]=-1;q[#q+1]=ni end
   end
  end end
 end
 local col=math.min(cols-1,math.floor((minx+maxx)/2/cw))
 local row=math.min(rows-1,math.floor((miny+maxy)/2/ch))
 local frame=row*cols+col+1
 for _,id in ipairs(q) do labels[id]=frame end
end end
local frames={}
for n=0,cols*rows-1 do
 local im=Image(112,80,ColorMode.RGB)
 for y=0,79 do for x=0,111 do
  local sx=math.floor((n%cols)*cw+cw/2+(x-55.5)*ch/64)
  local sy=math.floor(math.floor(n/cols)*ch+(y-7.5)*ch/64)
  if sx>=0 and sx<W and sy>=0 and sy<H then
   local id=sy*W+sx+1
   if labels[id]==n+1 then im:drawPixel(x,y,colors[id]) end
  end
 end end
 frames[n+1]=im
end
local anim=Sprite(112,80,ColorMode.RGB)
for n,im in ipairs(frames) do
  local f=n==1 and anim.frames[1] or anim:newEmptyFrame();f.duration=1/fps
  anim:newCel(anim.layers[1],f,im,Point(0,0))
  local one=Sprite(112,80,ColorMode.RGB);one:newCel(one.layers[1],one.frames[1],im,Point(0,0))
  one:saveCopyAs(out..'/'..string.format('%02d',n-1)..'.png');one:close()
end
anim:newTag(1,#frames).name=name
anim:saveAs(out..'/'..name..'.aseprite')
app.activeSprite=anim;app.command.SpriteSize{width=448,height=320,method='nearest'}
anim:saveCopyAs(out..'/preview-4x.gif');anim:close()
local sheet=Sprite(112*cols,80*rows,ColorMode.RGB);local pixels=Image(sheet.width,sheet.height,ColorMode.RGB)
for n,im in ipairs(frames) do pixels:drawImage(im,Point(((n-1)%cols)*112,math.floor((n-1)/cols)*80)) end
sheet:newCel(sheet.layers[1],sheet.frames[1],pixels,Point(0,0))
app.command.SpriteSize{width=224*cols,height=160*rows,method='nearest'}
sheet:saveCopyAs(out..'/contact-sheet.png');sheet:close()
print('SHEET_PREPARED '..name..' '..#frames)
