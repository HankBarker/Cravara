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
if app.params.mode=='items' then
 local img=source('items')
 local names={'basic_axe','basic_pickaxe','berry','bone_dagger','bucket','campfire','chest','cooked_meat','crystal_shard','leather_chestplate','leather_helmet','leather_leggings','log','net','plank','plant_fiber','raptor_fang','stone','torch','trex_meat','trex_scale','water_bucket','wood_floor','wood_wall','workbench','crystal_pendant','hunter_charm','river_totem','lantern','dodo_egg'}
 local atlas=Image(6*32,5*32,ColorMode.RGB)
 local xs={0,226,429,632,842,1046,1254}
 local ys={0,300,522,735,978,1254}
 for i,name in ipairs(names) do
  local col,row=(i-1)%6,math.floor((i-1)/6)
  local icon=crop(img,xs[col+1],ys[row+1],xs[col+2],ys[row+2],32,32,2)
  atlas:drawImage(icon,Point(col*32,row*32));save(icon,'item-'..name)
 end
 save(atlas,'items')
 local spr=Sprite(192,160,ColorMode.RGB);spr.cels[1].image=atlas;spr:saveAs(out..'items.aseprite')
elseif app.params.mode=='build' then
 local spr=Sprite{fromFile=root..'art/forest-v3/build-source.png'}
 local img=Image(spr.width,spr.height,ColorMode.RGB);img:drawSprite(spr,1)
 out=root..'game/Forest/art/v3/'
 app.fs.makeAllDirectories(out)
 for i,name in ipairs({'door','door_open','roof'}) do
  local x0=math.floor((i-1)*img.width/3)
  local x1=math.floor(i*img.width/3)
  local result=crop(img,x0,0,x1,img.height,16,24,0,nil,true)
  if name~='roof' then result=crop(img,x0,0,x1,img.height,16,28,0,nil,true) end
  save(result,name)
  if name~='door_open' then save(crop(img,x0,0,x1,img.height,32,32,2),name..'_item') end
 end
elseif app.params.mode=='props' then
 local img=source('props')
 local defs={{'wall',16,24,0},{'wall_alt',16,24,0},{'ore',16,28,0},{'wood_wall',16,28,0},{'wood_floor',16,16,0},{'workbench',42,34,1},{'rock',40,44,1},{'tent',64,54,1},{'campfire_0',32,36,1},{'campfire_1',32,36,1},{'campfire_2',32,36,1},{'campfire_3',32,36,1},{'shrine',54,64,1},{'chest',28,26,1},{'torch',16,32,1},{'chips',16,12,1}}
 local xs={0,314,636,944,1254}
 local ys={0,312,613,918,1254}
 for i,d in ipairs(defs) do
  local col,row=(i-1)%4,math.floor((i-1)/4)
  local result=crop(img,xs[col+1],ys[row+1],xs[col+2],ys[row+2],d[2],d[3],d[4],nil,i<=5)
  save(result,d[1])
 end
 -- Use one authored hearth for every flame frame to prevent the base swimming.
 local base=Image{fromFile=out..'campfire_0.png'}
 local strip=Image(128,36,ColorMode.RGB)
 local spr=Sprite(32,36,ColorMode.RGB)
 for i=0,3 do
  local frame=Image{fromFile=out..'campfire_'..i..'.png'}
  for y=24,35 do for x=0,31 do frame:drawPixel(x,y,base:getPixel(x,y)) end end
  save(frame,'campfire_'..i);strip:drawImage(frame,Point(i*32,0))
  if i==0 then spr.cels[1].image=frame else spr:newEmptyFrame();spr:newCel(spr.layers[1],i+1,frame,Point(0,0)) end
  spr.frames[i+1].duration=0.14
 end
 save(strip,'campfire');spr:saveAs(out..'campfire.aseprite')
end
