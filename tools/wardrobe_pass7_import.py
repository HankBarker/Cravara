"""Register reviewed PixelLab art as independent equipment layers, never alter source hero.
Explicit integer cut/paste only: no sprite rescaling, no generated animation clocks.
Raw images and job provenance remain in art/character-pass7.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import json

ROOT=Path(__file__).resolve().parents[1]
RAW=ROOT/'art/character-pass7/raw'
OUT=ROOT/'game/Forest/equipment/art/wardrobe'
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'icons').mkdir(exist_ok=True)
DIRS=['down','up','left','right']
PAL=[tuple(bytes.fromhex(x.strip())) for x in (ROOT/'art/palettes/cravera_master.hex').read_text().splitlines() if len(x.strip())==6]
def palette(im,material=None):
    im=im.copy();cache={}
    colors=PAL
    if material=='leather':
        colors=[tuple(bytes.fromhex(c)) for c in ['2e241f','3a2a1e','6e5a3e','9c8348','c7a85c','d9c39a']]
    for y in range(im.height):
        for x in range(im.width):
            r,g,b,a=im.getpixel((x,y))
            if a<128: im.putpixel((x,y),(0,0,0,0));continue
            c=(r,g,b)
            if c not in cache:cache[c]=min(colors,key=lambda p:sum((p[i]-c[i])**2 for i in range(3)))
            im.putpixel((x,y),cache[c]+(255,))
    return im
def cutface(im,d):
    # Original head/eyes remain visible through the open helmet or hairstyle.
    hx=25 if d in ['down','up'] else 26
    box={'down':(hx+3,28,hx+10,35),'left':(hx,28,hx+8,35),'right':(hx+5,28,hx+13,35)}.get(d)
    if box:im.paste((0,0,0,0),box)
def new():return Image.new('RGBA',(64,64))
for kind in ['leather','bone','crystal']:
    for i,d in enumerate(DIRS):
        src=Image.open(RAW/f'{"leather_small" if kind=="leather" else kind}_{i}.png').convert('RGBA')
        if kind=='leather':
            full=new();full.paste(src,(16,16));src=full
            dx=[-1,-1,-1,-2][i];head_shift=0;chest_shift=0;head_end=35;chest_start=35;leg_start=41
        elif kind=='bone':
            dx=[-1,-1,-1,-2][i];head_shift=-2;chest_shift=-3;head_end=38;chest_start=38;leg_start=44
        else:
            dx=[0,0,-1,-1][i];head_shift=0;chest_shift=-1;head_end=36;chest_start=36;leg_start=42
        for slot in ['head','chest','legs']:
            layer=new()
            if slot=='head':
                layer.paste(src.crop((0,0,64,head_end)),(dx,head_shift));cutface(layer,d)
            elif slot=='chest':
                layer.paste(src.crop((25,chest_start,40,leg_start)),(25+dx,chest_start+chest_shift))
            else:
                layer.paste(src.crop((25,leg_start,42,src.getbbox()[3])),(25+dx,41))
            layer=palette(layer,kind);layer.save(OUT/f'{kind}_{slot}_{d}.png')
            if d=='down':
                bbox=layer.getbbox();piece=layer.crop(bbox);icon=Image.new('RGBA',(24,24))
                icon.paste(piece,((24-piece.width)//2,(24-piece.height)//2))
                suffix={'head':'helmet','chest':'chestplate','legs':'leggings'}[slot]
                icon.save(OUT/'icons'/f'{kind}_{suffix}.png')
for kind in ['braid','curly','ponytail']:
    for i,d in enumerate(DIRS):
        src=Image.open(RAW/f'{kind}_{i}.png').convert('RGBA');layer=new()
        # Ponytail art puts its crown above the original head, rather than elongating the neck.
        dy=-3 if kind=='ponytail' else 0
        for y in range(18,41):
            for x in range(19,45):
                r,g,b,a=src.getpixel((x,y))
                if a<128:continue
                # Rich brown hair vs lighter peach face/body; preserve braid below jaw.
                if r>g*1.45 and r<192 and b<g*.95:
                    if y+dy < 35 or kind=='braid' and (x>=36 or x<=26):layer.putpixel((x,y+dy),(r,g,b,255))
        cutface(layer,d);palette(layer).save(OUT/f'hair_{kind}_{d}.png')
for i,d in enumerate(DIRS):
    src=Image.open(RAW/f'cloth_{i}.png').convert('RGBA')
    layer=new()
    layer.paste(src.crop((8,19,25,25)),(24-(1 if i>=2 else 0),35))
    palette(layer).save(OUT/f'cloth_chest_{d}.png')
board=Image.new('RGBA',(256,256),(29,43,38,255));draw=ImageDraw.Draw(board)
for row,kind in enumerate(['leather','bone','crystal']):
    for col,d in enumerate(DIRS):
        src=Image.open(ROOT/f'art/character-pass7/input/{d}.png').convert('RGBA')
        for slot in ['legs','chest','head']:src.alpha_composite(Image.open(OUT/f'{kind}_{slot}_{d}.png'))
        board.alpha_composite(src,(64*col,64*row+10))
    draw.text((2,row*64),kind,fill='white')
board.resize((1024,1024),Image.Resampling.NEAREST).save(ROOT/'art/character-pass7/registered-review.png')
print('Imported 36 equipment layers, 12 hair layers, 9 matching icons; binary alpha, master palette.')
