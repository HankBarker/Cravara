"""Approval integrity and export regression tests, isolated from real projects."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from PIL import Image
import character_studio as studio


class StudioTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='cravera-studio-test-')
        self.root = Path(self.tmp.name)
        self.root_patch = patch.object(studio, 'ROOT', self.root)
        self.data_patch = patch.object(studio, 'DATA', self.root / 'art')
        self.root_patch.start(); self.data_patch.start()
        studio.new('test-raptor', 'Synthetic test fixture, not production artwork')
        self.frames = []
        for i in range(2):
            image = Image.new('RGBA', (16, 16))
            image.putpixel((7+i, 8), (100, 120, 140, 255))
            p = self.root / f'fixture-{i}.png'
            image.save(p)
            self.frames.append(p)
        studio.add_concept('test-raptor', self.frames[0])

    def tearDown(self):
        self.data_patch.stop(); self.root_patch.stop(); self.tmp.cleanup()

    def approve(self):
        studio.action('test-raptor', {'action': 'approve_concept'})

    def test_blocks_animation_before_approval(self):
        with self.assertRaisesRegex(ValueError, 'Approve'):
            studio.add_clip('test-raptor', 'walk_right', self.frames)
        with self.assertRaisesRegex(ValueError, 'Approve'):
            studio.action('test-raptor', {'action': 'request_walk'})

    def test_changed_concept_invalidates_approval(self):
        self.approve()
        d = studio.read('test-raptor')
        studio.asset('test-raptor', d['concept']['file']).write_bytes(self.frames[1].read_bytes())
        self.assertFalse(studio.concept_ok('test-raptor', d))

    def test_invalid_frames_cannot_be_approved(self):
        self.approve()
        p = self.root / 'opaque.png'
        Image.new('RGB', (16,16)).save(p)
        studio.add_clip('test-raptor', 'walk_right', [p, p])
        with self.assertRaisesRegex(ValueError, 'transparency'):
            studio.action('test-raptor', {'action': 'approve_clip', 'clip': 'walk_right'})

    def test_missing_animations_block_export(self):
        self.approve()
        with self.assertRaisesRegex(ValueError, 'Missing animations'):
            studio.export('test-raptor')

    def test_changed_timing_invalidates_clip(self):
        self.approve()
        studio.add_clip('test-raptor', 'walk_right', self.frames)
        studio.action('test-raptor', {'action': 'approve_clip', 'clip': 'walk_right'})
        d = studio.read('test-raptor')
        clip = d['clips']['walk_right']
        clip['fps'] = 12
        self.assertNotEqual(clip['approved_sha256'], studio.clip_hash('test-raptor', clip))

    def test_path_traversal_rejected(self):
        with self.assertRaises(ValueError): studio.folder('../elsewhere')
        with self.assertRaises(ValueError): studio.asset('test-raptor', '../other.png')

    def test_export_loads_in_real_godot(self):
        self.approve()
        for key in studio.REQUIRED:
            studio.add_clip('test-raptor', key, self.frames)
            studio.action('test-raptor', {'action': 'approve_clip', 'clip': key})
        output = Path(studio.export('test-raptor'))
        self.assertTrue(output.is_file())
        game = self.root / 'game'
        (game / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Studio export test"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        res = output.relative_to(game).as_posix()
        script = 'extends SceneTree\nfunc _initialize():\n\tvar sf = load("res://'+res+'")\n\tassert(sf is SpriteFrames)\n\tassert(sf.get_animation_names().size() == 13)\n\tassert(not sf.get_animation_loop("death"))\n\tassert(sf.get_frame_count("walk_right") == 2)\n\tprint("STUDIO_GODOT_EXPORT_OK")\n\tquit()\n'
        (game / 'verify.gd').write_text(script)
        godot = Path.home() / 'OneDrive/Desktop/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe'
        if not godot.is_file():
            self.skipTest('Local Godot executable unavailable')
        imported = subprocess.run([str(godot), '--headless', '--path', str(game), '--editor', '--import'], capture_output=True, text=True, timeout=60)
        self.assertEqual(imported.returncode, 0, imported.stderr)
        result = subprocess.run([str(godot), '--headless', '--path', str(game), '--script', 'res://verify.gd'], capture_output=True, text=True, timeout=30)
        self.assertIn('STUDIO_GODOT_EXPORT_OK', result.stdout, result.stdout + result.stderr)
        self.assertNotIn('SCRIPT ERROR', result.stderr)


if __name__ == '__main__': unittest.main(verbosity=2)
