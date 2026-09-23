from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]/'game'
items={
 'reed_bow':('Reedwood Bow','Hold left-click to draw; release to fire a bone arrow. Usable from a stego or trike saddle.',{'tool_type':'bow','damage':9,'max_stack':1}),
 'bone_arrow':('Bone Arrow','A straight reed shaft, bone point and feather fletching. Ammunition for a reedwood bow.',{'max_stack':99,'damage':9}),
 'garden_hoe':('Stone Hoe','Right-click clear earth to prepare a garden plot. Sow berries or mushroom spores on tilled earth.',{'tool_type':'hoe','damage':2,'max_stack':1}),
 'berry_seed':('Berry Seeds','Sow on tilled soil. Water once with a water bucket; harvest ripe berries and a replacement seed.',{'max_stack':99}),
 'mushroom_spore':('Mushroom Spores','Sow on tilled soil. Water once to grow a patch of edible mushrooms.',{'max_stack':99}),
 'dodo_egg':('Dodo Egg','Fresh from a bonded dodo. Cook with mushrooms for a sustaining camp breakfast.',{'max_stack':30,'consumable':True,'hunger_value':12,'food_satiation_seconds':20.0}),
 'forest_omelet':('Forest Omelet','Dodo eggs folded around woodland mushrooms. 75 hunger, 150 seconds of fullness and 24 vitality over 24 seconds.',{'max_stack':20,'consumable':True,'hunger_value':75,'food_satiation_seconds':150.0,'healing_total':24.0,'healing_duration':24.0}),
 'berry_compote':('Warm Berry Compote','Slow-cooked berries. 40 hunger, 90 seconds of fullness and 10 vitality over 20 seconds.',{'max_stack':20,'consumable':True,'hunger_value':40,'food_satiation_seconds':90.0,'healing_total':10.0,'healing_duration':20.0}),
 'crystal_pickaxe':('Shardbound Pickaxe','Pickaxe power 2. Breaks dense violet crystal seams and mines ordinary stone faster.',{'tool_type':'pickaxe','mining_power':2,'damage':4,'max_stack':1}),
 'crystal_axe':('Shardbound Axe','Axe power 2. Fells trees in two swings.',{'tool_type':'axe','chop_power':2,'damage':6,'max_stack':1}),
 'prism_crystal':('Prism Crystal','A dense violet crystal found in distant forest seams. Requires pickaxe power 2.',{'max_stack':99,'rarity':'rare'}),
 'shard_sword':('Skyshard Sword','A broad crystal-edged blade. A sweeping slash with greater reach than a dagger.',{'tool_type':'sword','damage':8,'max_stack':1})
}
for key,(name,desc,props) in items.items():
 fields={'id':key,'name':name,'description':desc,'icon_generator':'forest',**props}
 text='[gd_resource type="Resource" script_class="Item" load_steps=2 format=3]\n[ext_resource type="Script" path="res://Items/Item.gd" id="1"]\n[resource]\nscript = ExtResource("1")\n'
 text+=''.join(f'{k} = {json.dumps(v)}\n' for k,v in fields.items())
 (root/'Items/Data'/f'{key}.tres').write_text(text,encoding='utf-8')
recipes=[
 ('Reedwood Bow','reed_bow',{'log':5,'plant_fiber':8},'Tools','workbench',1),
 ('Bone Arrows','bone_arrow',{'log':1,'raptor_fang':1},'Tools','',8),
 ('Stone Hoe','garden_hoe',{'log':3,'stone':2},'Tools','',1),
 ('Berry Seeds','berry_seed',{'berry':1},'Materials','',2),
 ('Mushroom Spores','mushroom_spore',{'mushroom':1},'Materials','',2),
 ('Forest Omelet','forest_omelet',{'dodo_egg':1,'mushroom':2},'Food','campfire',1),
 ('Warm Berry Compote','berry_compote',{'berry':3},'Food','campfire',1),
 ('Shardbound Pickaxe','crystal_pickaxe',{'basic_pickaxe':1,'crystal_shard':6,'plant_fiber':3},'Tools','workbench',1),
 ('Shardbound Axe','crystal_axe',{'basic_axe':1,'crystal_shard':6,'plant_fiber':3},'Tools','workbench',1),
 ('Skyshard Sword','shard_sword',{'prism_crystal':3,'plank':2,'plant_fiber':2},'Tools','workbench',1)]
p=root/'Scripts/CraftingManager.gd'; s=p.read_text(encoding='utf-8')
marker='var personal_recipes: Array = [\n'
if '"item_id":"reed_bow"' not in s:
 rows=[]
 for name,key,ingredients,cat,station,count in recipes:
  d={'name':name,'item_id':key,'ingredients':ingredients,'category':cat,'quantity':count,'description':items[key][1]}
  if station:d['station']=station
  rows.append('\t'+json.dumps(d,separators=(',',':'))+',\n')
 s=s.replace(marker,marker+''.join(rows)); p.write_text(s,encoding='utf-8')
print('12 items and 10 recipes authored')
