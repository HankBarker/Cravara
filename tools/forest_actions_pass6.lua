-- Native 64x64 authoring in Aseprite. Exact original head cels and palette;
-- fixed feet/canvas, independently keyed shoulders, elbows, grips and torso.
local root='C:/Cravera/'
local out=root..'game/Forest/equipment/art/actions/'
app.fs.makeAllDirectories(out)
local dirs={down='front',up='back',left='side_left',right='side_right'}
local actions={'axe','pickaxe','weapon','sword','bow_draw','bow_release','fishing_cast','fishing_reel','hoe','net','bucket','pet','pickup'}
local pc=app.pixelColor
local skin=pc.rgba(211,161,105,255)
local shade=pc.rgba(129,79,52,255)
local shine=pc.rgba(237,191,130,255)
local function pixel(img,x,y,c) if x>=0 and y>=0 and x<64 and y<64 then img:putPixel(x,y,c) end end
local function line(img,a,b,c,width)
 local steps=math.max(math.abs(b[1]-a[1]),math.abs(b[2]-a[2]),1)
 for i=0,steps do
  local x=math.floor(a[1]+(b[1]-a[1])*i/steps+.5)
  local y=math.floor(a[2]+(b[2]-a[2])*i/steps+.5)
  for dy=0,(width or 1)-1 do pixel(img,x,y+dy,c) end
 end
end
local function interpolate(keys,f)
 local at=(f-1)/7*(#keys-1)+1
 local i=math.min(math.floor(at),#keys-1)
 local t=at-i
 local result={}
 for n=1,#keys[i] do result[n]=math.floor(keys[i][n]*(1-t)+keys[i+1][n]*t+.5) end
 return result
end
-- each pose: forward reach, hand height, body lean, head drop, offhand reach,
-- offhand height. Reach is projected into the actual facing; vertical views
-- deliberately retain a left/right offset so both hands remain readable.
local poses={
 axe={{5,36,0,0, -4,36},{-2,23,-1,-1, -3,28},{9,39,2,2, 4,35},{5,36,0,0,-4,36}},
 pickaxe={{4,36,0,0,1,37},{1,22,-1,-2,-3,24},{7,42,2,3,4,39},{4,36,0,0,1,37}},
 weapon={{4,36,0,0,-4,37},{1,34,-1,0,-4,36},{13,35,3,0,-3,37},{5,36,0,0,-4,37}},
 sword={{5,36,0,0,-4,37},{-5,29,-2,-1,-5,36},{12,38,3,1,1,37},{5,36,0,0,-4,37}},
 bow_draw={{6,35,0,0,3,36},{10,34,1,0,1,34},{11,34,1,0,-2,32},{11,34,1,0,-3,32}},
 bow_release={{11,34,1,0,-3,32},{11,34,1,-1,-6,32},{8,35,0,0,-3,35},{5,36,0,0,-4,37}},
 fishing_cast={{5,36,0,0,1,37},{-4,25,-2,-1,-1,30},{13,32,2,1,3,36},{8,35,1,0,2,37}},
 fishing_reel={{9,35,0,0,5,37},{9,35,0,1,3,35},{9,35,0,0,6,33},{9,35,0,0,5,37}},
 hoe={{6,37,0,0,2,37},{11,39,2,2,6,37},{7,42,2,3,3,40},{4,37,-1,0,1,37}},
 net={{5,36,0,0,-4,37},{-3,22,-1,-1,-5,33},{13,31,2,0,1,37},{8,38,1,1,-3,37}},
 bucket={{5,37,0,0,-4,37},{8,44,2,4,-2,39},{7,40,1,2,-4,38},{5,35,0,0,-4,37}},
 pet={{5,36,0,0,-4,37},{10,40,2,3,0,39},{11,38,2,3,0,39},{5,36,0,0,-4,37}},
 pickup={{5,36,0,0,-4,37},{5,44,2,5,2,43},{4,39,1,2,1,40},{2,35,0,0,-1,36}}
}
local all={}
for dir,suffix in pairs(dirs) do
 local src=app.open(root..'assets_raw/Main Character/ASEPRITE/Unarmed_Idle/Unarmed_Idle_'..suffix..'.aseprite')
 local body,head
 local cel=(dir=='left') and 6 or 1
 for _,layer in ipairs(src.layers) do if layer.name=='body' then body=layer:cel(cel) elseif layer.name=='head' then head=layer:cel(cel) end end
 local refbody,refhead
 for _,layer in ipairs(src.layers) do if layer.name=='body' then refbody=layer:cel(1) elseif layer.name=='head' then refhead=layer:cel(1) end end
 local rows={}
 for y=0,head.image.height-1 do
  local lo,hi=head.image.width,-1
  for x=0,head.image.width-1 do if pc.rgbaA(head.image:getPixel(x,y))>0 then lo=math.min(lo,x);hi=math.max(hi,x) end end
  rows[#rows+1]=string.format('[%d,%d]',lo,hi)
 end
 for _,action in ipairs(actions) do
  local spr=Sprite(64,64,ColorMode.RGB)
  spr.layers[1].name='Source anatomy and keyed limbs'
  local sheet=Image(512,64,ColorMode.RGB)
  local metadata={}
  for f=1,8 do
   if f>1 then spr:newEmptyFrame() end
   local p=interpolate(poses[action],f)
   local sign=(dir=='left') and -1 or 1
   local bx=(dir=='left' or dir=='right') and p[3]*sign or 0
   local by=math.floor(p[4]/2)
   local hx=bx
   local hy=p[4]
   local img=Image(64,64,ColorMode.RGB)
   -- Keep original feet grounded while the torso folds at the waist.
   for y=0,body.image.height-1 do for x=0,body.image.width-1 do
    local c=body.image:getPixel(x,y)
    local xx,yy=x+body.position.x,y+body.position.y
    if pc.rgbaA(c)>0 then
     local outer=xx<29 or xx>35
     if not (outer and yy>=34 and yy<40) then
      pixel(img,xx+(yy<40 and bx or 0),yy+(yy<40 and by or 0),c)
     end
    end
   end end
   local function project(reach,height,off)
    if dir=='left' or dir=='right' then return {32+reach*sign,height} end
    return {32+(off and -3 or 3)+math.floor(reach*.28),height+((dir=='up') and -math.floor(reach*.35) or math.floor(reach*.25))}
   end
   local grip=project(p[1],p[2],false)
   local other=project(p[5],p[6],true)
   local function arm(shoulder,hand)
    local elbow={math.floor((shoulder[1]+hand[1])/2),math.floor((shoulder[2]+hand[2])/2)+1}
    line(img,shoulder,elbow,shade,3);line(img,elbow,hand,shade,3)
    line(img,{shoulder[1],shoulder[2]},{elbow[1],elbow[2]},skin,2)
    line(img,{elbow[1],elbow[2]},hand,skin,2)
    pixel(img,hand[1],hand[2],shine)
   end
   arm({29+bx,35+by},other)
   arm({35+bx,35+by},grip)
   img:drawImage(head.image,Point(head.position.x+hx,head.position.y+hy))
   -- Front-facing hands must pass in front of chin on draw/reel gestures.
   if dir~='up' and p[2]<35 and p[2]>29 then pixel(img,grip[1],grip[2],shine);pixel(img,grip[1],grip[2]+1,skin) end
   spr:newCel(spr.layers[1],spr.frames[f],img,Point(0,0));spr.frames[f].duration=.08
   sheet:drawImage(img,Point((f-1)*64,0))
   metadata[#metadata+1]=string.format('{"head":[%d,%d],"body":[%d,%d],"head_origin":[%d,%d],"head_rows":[%s],"head_center":6,"head_facing":"%s","hand":[%d,%d],"offhand":[%d,%d]}',head.position.x+hx-refhead.position.x,head.position.y+hy-refhead.position.y,bx+body.position.x-refbody.position.x,by+body.position.y-refbody.position.y,head.position.x+hx,head.position.y+hy,table.concat(rows,','),dir,grip[1],grip[2],other[1],other[2])
  end
  spr:saveAs(out..action..'_'..dir..'.aseprite');spr:close()
  local png=Sprite(512,64,ColorMode.RGB);png:newCel(png.layers[1],png.frames[1],sheet,Point(0,0));png:saveCopyAs(out..action..'_'..dir..'.png');png:close()
  all[#all+1]='"'..action..'_'..dir..'":['..table.concat(metadata,',')..']'
 end
 src:close()
 print('Authored 13 distinct actions x8 native frames: '..dir)
end
local file=io.open(root..'game/Forest/equipment/art/action_anchors.json','w');file:write('{'..table.concat(all,',')..'}');file:close()
print('Exported 416 action frames with head/body/hand anchors. Original source files untouched.')
