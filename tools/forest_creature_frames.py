"""Build SpriteFrames metadata for the native Aseprite-produced forest sheets."""
from pathlib import Path

DIMENSIONS = {'raptor': (42, 32), 'stego': (60, 40), 'trike': (54, 42),
              'longneck': (70, 60), 'dodo': (20, 24), 'rex': (76, 56)}
ROOT = Path(__file__).resolve().parents[1] / 'game/Forest/creatures/art'
for species, (width, height) in DIMENSIONS.items():
    text = '[gd_resource type="SpriteFrames" load_steps=55 format=3]\n'
    for direction in ('side', 'down', 'up'):
        suffix = '' if direction == 'side' else '_' + direction
        text += f'\n[ext_resource type="Texture2D" path="res://Forest/creatures/art/{species}{suffix}.png" id="{direction}"]\n'
    for direction in ('side', 'down', 'up'):
        for frame in range(17):
            text += (f'\n[sub_resource type="AtlasTexture" id="{direction}{frame}"]\n'
                     f'atlas = ExtResource("{direction}")\n'
                     f'region = Rect2({frame * width}, 0, {width}, {height})\n')
    animations = []
    for direction in ('side', 'down', 'up'):
        for name, first, count, speed in [('idle', 0, 4, 4.5), ('walk', 4, 8, 10), ('attack', 12, 5, 6)]:
            frames = ','.join(f'{{"duration": 1.0, "texture": SubResource("{direction}{frame}")}}' for frame in range(first, first + count))
            animations.append(f'{{"frames": [{frames}], "loop": true, "name": &"{name}_{direction}", "speed": {speed}}}')
    text += '\n[resource]\nanimations = [' + ','.join(animations) + ']\n'
    (ROOT / f'{species}_frames.tres').write_text(text)
print('Built 6 species, 54 clips, 306 native pixel frames.')
