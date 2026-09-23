local base='C:/Cravera/assets_raw/Main Character/ASEPRITE/'
local entries={}
local dirs={down='front',up='back',left='side_left',right='side_right'}
local actions={idle='Unarmed_Idle',walk='Unarmed_Walk',run='Unarmed_Run',hurt='Unarmed_Hurt',attack='Sword_Attack',death='Unarmed_Death'}
for facing,suffix in pairs(dirs) do
 local reference=app.open(base..'Unarmed_Idle/Unarmed_Idle_'..suffix..'.aseprite')
 local ref={}
 for _,l in ipairs(reference.layers) do
  if l.name=='head' or l.name=='body' then local c=l:cel(1); ref[l.name]={x=c.position.x,y=c.position.y} end
 end
 reference:close()
 for key,folder in pairs(actions) do
  local stem=folder=='Sword_Attack' and 'Sword_attack' or folder
  if key=='death' and facing=='down' then stem='Unarmed_Death1' end
  local s=app.open(base..folder..'/'..stem..'_'..suffix..'.aseprite')
  local frames={}
  local prior_looking=facing
  for i=1,#s.frames do
   local parts={}
   for _,l in ipairs(s.layers) do
    if ref[l.name] then
     local c=l:cel(i)
     if c then
      parts[#parts+1]=string.format('"%s":[%d,%d]',l.name,c.position.x-ref[l.name].x,c.position.y-ref[l.name].y)
      if l.name=='head' then
       parts[#parts+1]=string.format('"head_origin":[%d,%d]',c.position.x,c.position.y)
       local looking=facing
       local eye_min,eye_max=c.image.width,-1
       for y=5,c.image.height-1 do
        for x=0,c.image.width-1 do
         local px=c.image:getPixel(x,y)
         if app.pixelColor.rgbaA(px)>0 and app.pixelColor.rgbaB(px)>app.pixelColor.rgbaR(px)+10 then
          eye_min,eye_max=math.min(eye_min,x),math.max(eye_max,x)
         end
        end
       end
       if eye_max-eye_min>=5 then looking='down' end
       if eye_max<0 and facing~='up' then looking=prior_looking end
       prior_looking=looking
       parts[#parts+1]='"head_facing":"'..looking..'"'
       local rows={}
       local moment,weight=0,0
       for y=0,c.image.height-1 do
        local lo,hi=c.image.width,-1
        for x=0,c.image.width-1 do
         local color=c.image:getPixel(x,y)
         if app.pixelColor.rgbaA(color)>0 then
          lo,hi=math.min(lo,x),math.max(hi,x)
          if y<6 then
           local value=app.pixelColor.rgbaR(color)+app.pixelColor.rgbaG(color)+app.pixelColor.rgbaB(color)
           moment,weight=moment+x*value,weight+value
          end
         end
        end
        rows[#rows+1]=string.format('[%d,%d]',lo,hi)
       end
       parts[#parts+1]='"head_rows":['..table.concat(rows,',')..']'
       parts[#parts+1]=string.format('"head_center":%d',math.floor(moment/math.max(weight,1)+0.5))
      end
     end
    end
   end
   frames[#frames+1]='{'..table.concat(parts,',')..'}'
  end
  entries[#entries+1]='"'..key..'_'..facing..'":['..table.concat(frames,',')..']'
  s:close()
 end
end
local f=io.open('C:/Cravera/game/Forest/equipment/art/pose_anchors.json','w')
f:write('{'..table.concat(entries,',')..'}')
f:close()
