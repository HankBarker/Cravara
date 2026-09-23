"""Original pixel icons for the river set. Integer coordinates, 32px source canvas."""
from pathlib import Path
from PIL import Image, ImageDraw

out = Path(__file__).resolve().parents[1] / 'game/Forest/art/fishing'
out.mkdir(parents=True, exist_ok=True)
for key, colors in {
    'reed_perch': ('#557e56', '#9bbe79', '#d6d5a0', '#9b6c42'),
    'shardfin': ('#237d78', '#63b7a3', '#b6e6c3', '#527db1'),
    'moonscale': ('#635386', '#a69ac7', '#e6dccb', '#3d9fa9'),
}.items():
    im=Image.new('RGBA',(32,32))
    d=ImageDraw.Draw(im)
    shadow, body, light, fin=colors
    outline='#182f33'
    d.polygon([(3,10),(10,13),(14,8),(21,8),(27,12),(30,17),(27,21),(19,24),(11,20),(8,19),(2,24),(3,17),(2,10)],fill=outline)
    d.polygon([(4,12),(10,15),(9,18),(4,21),(5,17)],fill=fin)
    d.polygon([(10,14),(15,10),(21,10),(26,13),(28,17),(25,20),(19,22),(12,19)],fill=shadow)
    d.polygon([(11,14),(16,11),(21,11),(25,14),(26,17),(21,19),(14,18)],fill=body)
    d.line([(13,14),(17,12),(22,12),(24,14)],fill=light,width=1)
    d.line([(14,20),(19,22),(25,19)],fill=light,width=1)
    d.polygon([(14,10),(14,6),(17,9),(19,4),(21,9),(23,7),(24,12)],fill=outline)
    d.polygon([(16,10),(15,8),(18,10),(19,6),(20,10),(22,9),(22,11)],fill=fin)
    d.line([(19,6),(19,9)],fill=light)
    d.polygon([(17,18),(17,22),(21,19)],fill=fin)
    d.point((17,14),fill=light); d.point((19,16),fill=light); d.point((15,16),fill=light)
    d.rectangle((24,14,26,16),fill=outline); d.point((25,14),fill='#f2e9c7')
    d.point((28,18),fill=light)
    im.save(out/f'{key}.png')

im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
d.line([(6,28),(8,22),(12,14),(19,5),(24,3)],fill='#172e32',width=4)
d.line([(6,27),(10,18),(15,10),(20,5),(24,4)],fill='#997047',width=2)
d.line([(9,20),(15,10),(20,5),(24,4)],fill='#d7ba7a',width=1)
for x,y in [(7,25),(8,22),(11,16),(16,9)]: d.line([(x-1,y-1),(x+2,y+1)],fill='#ddd4a8',width=1)
d.line([(24,4),(28,10),(28,23),(25,26)],fill='#c7d8c2',width=1)
d.polygon([(26,17),(29,17),(30,20),(28,23),(25,20)],fill='#182f33')
d.rectangle((27,17,28,19),fill='#dc8c69');d.rectangle((26,20,29,20),fill='#e7d5a3')
d.polygon([(10,18),(14,17),(17,20),(15,23),(11,22)],fill='#182f33')
d.polygon([(11,19),(14,18),(16,20),(14,22),(11,21)],fill='#4b9c95')
d.line([(12,19),(14,19)],fill='#a5ddc6')
im.save(out/'fishing_rod.png')
