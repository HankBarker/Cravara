-- Native-pixel export from original generated sources. Run with Aseprite --batch.
-- Sources stay untouched; alpha, common palette and fixed animation anchors survive.
local root='C:/Cravera/'
local out=root..'game/Forest/art/v2/'
app.fs.makeAllDirectories(out)
local pc=app.pixelColor
local palette={}
for line in io.lines(root..'art/palettes/cravera_master.hex') do
 local hex=line:gsub('%s','')
 if #hex==6 then table.insert(palette,{tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16)}) end
end
local cache={}
local function mapped(c)
 if pc.rgbaA(c)<145 then return 0 end
 local r,g,b=pc.rgbaR(c),pc.rgbaG(c),pc.rgbaB(c)
 local k=r*65536+g*256+b
 if cache[k] then return cache[k] end
 local best,dist=palette[1],1e9
 for _,p in ipairs(palette) do
  local d=(r-p[1])^2*0.3+(g-p[2])^2*0.59+(b-p[3])^2*0.11
  if d<dist then best=p;dist=d end
 end
 local v=pc.rgba(best[1],best[2],best[3],255);cache[k]=v;return v
end
local function source(name)
 local spr=Sprite{fromFile=root..'art/forest-v2/'..name..'-source.png'}
 local img=Image(spr.width,spr.height,ColorMode.RGB);img:drawSprite(spr,1)
 return img
end
local function crop(img,x0,y0,x1,y1,w,h,pad,forced,stretch)
 local bx,by,ex,ey=x1,y1,x0,y0
 for y=y0,y1-1 do for x=x0,x1-1 do
  if pc.rgbaA(img:getPixel(x,y))>=145 then bx=math.min(bx,x);by=math.min(by,y);ex=math.max(ex,x);ey=math.max(ey,y) end
 end end
 if forced then bx,by,ex,ey=table.unpack(forced) end
 assert(ex>=bx and ey>=by,'Empty source cell')
 local scale=math.min((w-pad*2)/(ex-bx+1),(h-pad*2)/(ey-by+1))
 local dw,dh=math.max(1,math.floor((ex-bx+1)*scale+0.5)),math.max(1,math.floor((ey-by+1)*scale+0.5))
 if stretch then dw=w-pad*2;dh=h-pad*2 end
 local ox,oy=math.floor((w-dw)/2),h-dh-pad
 local result=Image(w,h,ColorMode.RGB)
 for y=0,dh-1 do for x=0,dw-1 do
  -- Box-sample the generated high-res texture before palette mapping. This
  -- removes isolated high-frequency speckles while retaining a hard pixel grid.
  local rr,gg,bb,aa,n=0,0,0,0,0
  for yy=0,3 do for xx=0,3 do
   local sx=math.min(ex,bx+math.floor((x+(xx+0.5)/4)/dw*(ex-bx+1)))
   local sy=math.min(ey,by+math.floor((y+(yy+0.5)/4)/dh*(ey-by+1)))
   local c=img:getPixel(sx,sy)
   local a=pc.rgbaA(c)
   rr=rr+pc.rgbaR(c)*a;gg=gg+pc.rgbaG(c)*a;bb=bb+pc.rgbaB(c)*a;aa=aa+a;n=n+1
  end end
  if aa>0 then result:drawPixel(ox+x,oy+y,mapped(pc.rgba(math.floor(rr/aa),math.floor(gg/aa),math.floor(bb/aa),math.floor(aa/n)))) end
 end end
 return result
end
local function save(img,name)
 img:saveAs(out..name..'.png')
 print(name..' '..img.width..'x'..img.height)
end
out=root..'game/Forest/art/v4/'
app.fs.makeAllDirectories(out)
local function loadpath(path)
 local spr=Sprite{fromFile=root..path}
 local img=Image(spr.width,spr.height,ColorMode.RGB);img:drawSprite(spr,1);return img
end
local img=loadpath('art/forest-pass4/terrain-source.png')
for row=0,1 do for col=0,2 do
 local x=({35,541,1047})[col+1];local y=({32,533})[row+1]
 save(crop(img,x,y,x+450,y+450,64,64,0,{x,y,x+449,y+449},true),(row==0 and 'grass' or 'soil')..col)
end end
local bed=loadpath('art/forest-pass4/bed-source.png')
save(crop(bed,0,0,bed.width,bed.height,30,40,1),'hide_bed')
save(crop(bed,0,0,bed.width,bed.height,32,32,2),'hide_bed_item')
