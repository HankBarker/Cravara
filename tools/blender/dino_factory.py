"""Cravera Dinosaur Factory (pass 12 experiment): a dinosaur built, rigged and
animated in Blender, then rendered from Cravera's fixed camera in each facing,
so every frame of every clip shows the very same animal.

    blender --background --python tools/blender/dino_factory.py -- --species carno
        [--clips idle,walk] [--facings side,down,up] [--frames-only 0] [--still]

Writes art/blender/<species>/raw/<clip>_<facing>/NNN.png (renders at SCALE x
the game's pixel size, transparent). tools/blender/pixelize.py turns them into
the game's sprite strips (palette, outline, DinoArt catalogue).

The animal is built from lofted cross-sections (body, head, jaw, legs, arms)
coloured by vertex (base, back stripes, belly, spots), shaded in toon bands
by one sun from the upper left (EEVEE: Diffuse -> Shader to RGB -> constant
ramp), rigged with an armature (IK legs: the ankles follow targets that walk
the feet along the ground, so planted feet never slide) and animated by the
clip functions below. Facings turn the whole rig about its feet: side faces
+X (screen right), down faces the camera, up faces away.

Everything is data + code: a new species is a new SPECIES entry (and, if its
body plan differs, its own clip functions).
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SCALE = 4  # render at SCALE x the game's pixels; pixelize.py brings it down

# --- the animals ----------------------------------------------------------------------------------

def srgb(r, g, b):
    """0-255 sRGB -> linear floats (vertex colours are linear)."""
    def lin(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (lin(r), lin(g), lin(b), 1.0)


SPECIES = {
    # The Scarhorn: a Carnotaurus. Short deep skull, a thick horn over each
    # eye, tiny arms, long legs; crimson with maroon bands down the back.
    "carno": {
        "canvas": (128, 112), "px_per_unit": 8.8, "elevation": 26.0,
        "colours": {
            "base": srgb(178, 58, 42), "back": srgb(104, 30, 30), "belly": srgb(228, 186, 136),
            "light": srgb(222, 104, 66), "spot": srgb(132, 38, 34), "horn": srgb(240, 230, 204),
            "horn_tip": srgb(150, 134, 108), "eye": srgb(255, 196, 56), "pupil": srgb(22, 10, 10),
            "mouth": srgb(70, 16, 20), "teeth": srgb(246, 238, 216), "claw": srgb(40, 28, 24),
            "shin": srgb(120, 30, 28), "brow": srgb(192, 64, 48),
        },
        # Upright like Cravera's hunters: the chest rises to a high neck.
        # Spine from the tail tip forward: x, centre z, height, width.
        "spine": [(-3.5, 1.72, 0.16, 0.185), (-3.0, 1.88, 0.34, 0.37), (-2.4, 2.08, 0.58, 0.607),
                  (-1.75, 2.34, 0.84, 0.845), (-1.05, 2.62, 1.14, 1.109), (-0.35, 2.86, 1.42, 1.32),
                  (0.35, 3.04, 1.64, 1.452), (1.0, 3.2, 1.74, 1.478), (1.55, 3.44, 1.58, 1.32),
                  (1.95, 3.8, 1.18, 1.03), (2.25, 4.2, 0.88, 0.845), (2.5, 4.52, 0.8, 0.818)],
        # Skull (upper jaw) from its back to the snout: x, top z, mouth line z, width.
        "head": [(2.4, 5.04, 4.1, 1.049), (2.78, 5.12, 4.1, 1.074), (3.14, 5.0, 4.12, 0.976),
                 (3.5, 4.78, 4.15, 0.805), (3.8, 4.52, 4.18, 0.537)],
        # Lower jaw: x, top z (the mouth line), bottom z, width.
        "jaw": [(2.44, 4.1, 3.7, 0.952), (2.9, 4.12, 3.8, 0.83), (3.35, 4.15, 3.94, 0.634), (3.74, 4.18, 4.06, 0.366)],
        "jaw_hinge": (2.5, 4.05),
        "horns": {"base": (2.8, 0.42, 5.02), "dir": (0.18, 0.72, 0.62), "length": 0.66, "radius": 0.28},
        "eye": (3.0, 0.5, 4.74), "eye_radius": 0.18,
        # Leg: hip, knee, ankle, ball, toe (y is the side's offset), widths along it.
        "leg": {"hip": (0.4, 0.8, 3.0), "knee": (1.15, 0.86, 1.72), "ankle": (0.36, 0.84, 0.76),
                "ball": (0.72, 0.84, 0.14), "toe": (1.22, 0.84, 0.04),
                "widths": [1.06, 0.56, 0.36, 0.34, 0.24]},
        "arm": {"shoulder": (1.75, 0.62, 3.1), "elbow": (1.86, 0.74, 2.8), "hand": (2.04, 0.72, 2.68), "widths": [0.2, 0.15, 0.11]},
        "bones": {"pelvis": ((-0.1, 3.0), (1.05, 3.2)), "chest": ((1.05, 3.2), (1.95, 3.8)), "neck": ((1.95, 3.8), (2.3, 4.3)),
                  "neck2": ((2.3, 4.3), (2.48, 4.6)), "head": ((2.48, 4.6), (3.8, 4.5)), "jaw_tip": (3.72, 4.1),
                  "tail": [(-0.1, 3.0), (-1.0, 2.6), (-1.9, 2.26), (-2.7, 1.98), (-3.5, 1.72)]},
        "gait": {"walk_stride": 1.7, "run_stride": 2.6},
    },
}


# --- building -------------------------------------------------------------------------------------

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def ring(centre, forward, width, height, n):
    """An ellipse of n points round `centre`, in the plane across `forward`,
    `height` measured along world up (as near as the direction allows)."""
    f = forward.normalized()
    up = Vector((0, 0, 1))
    side = f.cross(up)
    if side.length < 1e-4:
        side = Vector((0, 1, 0))
    side.normalize()
    up2 = side.cross(f).normalized()
    pts = []
    for i in range(n):
        a = 2.0 * math.pi * i / n
        pts.append(centre + side * (math.cos(a) * width * 0.5) + up2 * (math.sin(a) * height * 0.5))
    return pts


def loft(name, stations, n=12, cap_start=True, cap_end=True):
    """A tube through stations [(centre Vector, width, height)], capped."""
    verts, faces = [], []
    count = len(stations)
    for i, (c, w, h) in enumerate(stations):
        prev_c = stations[max(0, i - 1)][0]
        next_c = stations[min(count - 1, i + 1)][0]
        fwd = next_c - prev_c
        if fwd.length < 1e-5:
            fwd = Vector((1, 0, 0))
        verts.extend(ring(c, fwd, w, h, n))
    for i in range(count - 1):
        for j in range(n):
            a = i * n + j
            b = i * n + (j + 1) % n
            c2 = (i + 1) * n + (j + 1) % n
            d = (i + 1) * n + j
            faces.append((a, b, c2, d))
    if cap_start:
        verts.append(stations[0][0].copy())
        centre = len(verts) - 1
        for j in range(n):
            faces.append((centre, (j + 1) % n, j))
    if cap_end:
        verts.append(stations[-1][0].copy())
        centre = len(verts) - 1
        base = (count - 1) * n
        for j in range(n):
            faces.append((centre, base + j, base + (j + 1) % n))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    # Faces outward (the belly is below, the light from above).
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def smooth(obj, levels=2):
    for poly in obj.data.polygons:
        poly.use_smooth = True
    mod = obj.modifiers.new("Subsurf", "SUBSURF")
    mod.levels = levels
    mod.render_levels = levels
    # Bake the subdivision so the vertex colours and weights live on the dense mesh.
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.select_set(False)


def paint(obj, colour_of):
    """Vertex colours from colour_of(world_co, normal) (linear RGBA)."""
    mesh = obj.data
    attr = mesh.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="POINT")
    mw = obj.matrix_world
    for v in mesh.vertices:
        co = mw @ v.co
        n = (mw.to_3x3() @ v.normal).normalized()
        attr.data[v.index].color = colour_of(co, n)
    mesh.color_attributes.active_color = attr


def toon_material():
    mat = bpy.data.materials.new("Toon")
    mat.use_nodes = True
    nt = mat.node_tree
    for node in list(nt.nodes):
        nt.nodes.remove(node)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    col = nt.nodes.new("ShaderNodeVertexColor")
    col.layer_name = "Col"
    diffuse = nt.nodes.new("ShaderNodeBsdfDiffuse")
    diffuse.inputs["Color"].default_value = (1, 1, 1, 1)
    to_rgb = nt.nodes.new("ShaderNodeShaderToRGB")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    els = ramp.color_ramp.elements
    # Four bands: shadow, shade, lit, highlight (the colours are the lit
    # tone). Hue-shifted like hand-made pixel art: shadows go cool and
    # purple-brown, highlights warm toward orange (linear values).
    els[0].position = 0.0
    els[0].color = (0.30, 0.22, 0.34, 1)
    els[1].position = 0.2
    els[1].color = (0.56, 0.46, 0.56, 1)
    e3 = els.new(0.5)
    e3.color = (0.86, 0.82, 0.80, 1)
    e4 = els.new(0.85)
    e4.color = (1.0, 0.94, 0.76, 1)
    # base colour x shade band (a vector multiply: Blender 5's Mix node has
    # a socket per type under the same name)
    mix = nt.nodes.new("ShaderNodeVectorMath")
    mix.operation = "MULTIPLY"
    emit = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(diffuse.outputs["BSDF"], to_rgb.inputs["Shader"])
    nt.links.new(to_rgb.outputs["Color"], ramp.inputs["Fac"])
    nt.links.new(col.outputs["Color"], mix.inputs[0])
    nt.links.new(ramp.outputs["Color"], mix.inputs[1])
    nt.links.new(mix.outputs["Vector"], emit.inputs["Color"])
    nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    return mat


def V(t):
    return Vector(t)


def build(spec):
    col = spec["colours"]
    parts = {}

    # Body: tail tip to neck.
    stations = [(Vector((x, 0.0, z)), w, hgt) for (x, z, hgt, w) in spec["spine"]]
    body = loft("Body", stations, n=16)
    smooth(body)

    def speck(co, k=1.0):
        """A stable per-point hash in 0..1 (scale texture)."""
        v = math.sin(co.x * 91.7 + co.y * 47.3 + co.z * 63.1) * 43758.5453
        return v - math.floor(v)

    def body_colour(co, n):
        # A pale belly low on the flank; maroon bands over the back and upper
        # flanks; a lighter rim along the top where the sun catches it; and a
        # speckle of scales, lighter and darker.
        if n.z < -0.25:
            return col["belly"] if speck(co) > 0.12 else col["base"]
        band = math.sin(co.x * 4.4 + 0.6 * co.z)
        if n.z > 0.0 and band > 0.62:
            return col["back"]
        if n.z > 0.82:
            return col["light"] if speck(co) > 0.3 else col["base"]
        r = speck(co)
        if r < 0.07:
            return col["spot"]
        if r > 0.95:
            return col["light"]
        return col["base"]
    paint(body, body_colour)
    parts["body"] = body

    # Skull (upper jaw) and lower jaw: the mouth's inside and teeth show when it opens.
    stations = [(Vector((x, 0.0, (top + mouth) * 0.5)), w, top - mouth) for (x, top, mouth, w) in spec["head"]]
    head = loft("Head", stations, n=14)
    smooth(head)
    mouth_z = spec["head"][0][2]

    def head_colour(co, n):
        if n.z < -0.55:
            return col["mouth"]
        if co.z < mouth_z + 0.07 and n.z < 0.2:
            return col["teeth"]
        if co.z < mouth_z + 0.16 and n.z < 0.4:
            return col["mouth"]
        # nostril near the snout tip
        if co.x > spec["head"][-1][0] - 0.22 and abs(abs(co.y) - 0.12) < 0.07 and n.z > 0.1:
            return col["mouth"]
        if n.z > 0.6:
            return col["back"]
        if n.z > 0.2 and co.x < spec["head"][2][0]:
            return col["brow"]
        return col["base"]
    paint(head, head_colour)
    parts["head"] = head
    stations = [(Vector((x, 0.0, (top + bottom) * 0.5)), w, top - bottom) for (x, top, bottom, w) in spec["jaw"]]
    jaw = loft("Jaw", stations, n=12)
    smooth(jaw)

    def jaw_colour(co, n):
        if n.z > 0.55:
            return col["mouth"]
        if co.z > spec["jaw"][0][1] - 0.06 and n.z > -0.2:
            return col["teeth"]
        if n.z < -0.3:
            return col["belly"]
        return col["base"]
    paint(jaw, jaw_colour)
    parts["jaw"] = jaw

    # Horns: a cone over each eye.
    h = spec["horns"]
    for side in (1, -1):
        base = V((h["base"][0], h["base"][1] * side, h["base"][2]))
        d = V((h["dir"][0], h["dir"][1] * side, h["dir"][2])).normalized()
        tip = base + d * h["length"]
        stations = [(base - d * 0.08, h["radius"] * 2.0, h["radius"] * 2.0), (base + d * h["length"] * 0.5, h["radius"] * 1.3, h["radius"] * 1.3),
                    (tip, 0.03, 0.03)]
        horn = loft("Horn" + ("L" if side > 0 else "R"), stations, n=8)
        smooth(horn, 1)
        paint(horn, lambda co, n, tip=tip: col["horn_tip"] if (co - tip).length < h["length"] * 0.35 else col["horn"])
        parts["horn" + ("L" if side > 0 else "R")] = horn

    # Eyes: dark, with a gold glint toward the light.
    for side in (1, -1):
        e = spec["eye"]
        bpy.ops.mesh.primitive_uv_sphere_add(radius=spec.get("eye_radius", 0.1), segments=12, ring_count=8, location=(e[0], e[1] * side, e[2]))
        eye = bpy.context.active_object
        eye.name = "Eye" + ("L" if side > 0 else "R")
        paint(eye, lambda co, n: col["pupil"] if n.x > 0.55 else col["eye"])
        parts[eye.name] = eye

    # Legs and arms.
    lg = spec["leg"]
    for side, tag in ((1, "L"), (-1, "R")):
        pts = [V((p[0], p[1] * side, p[2])) for p in (lg["hip"], lg["knee"], lg["ankle"], lg["ball"], lg["toe"])]
        ws = lg["widths"]
        stations = [(pts[0], ws[0], ws[0] * 1.5), (pts[0].lerp(pts[1], 0.45), ws[0] * 0.95, ws[0] * 1.25),
                    (pts[0].lerp(pts[1], 0.8), ws[0] * 0.7, ws[0] * 0.85), (pts[1], ws[1], ws[1]),
                    (pts[1].lerp(pts[2], 0.5), ws[1] * 0.75, ws[1] * 0.75), (pts[2], ws[2], ws[2]), (pts[3], ws[3], ws[3] * 0.8),
                    (pts[4], ws[4], ws[4] * 0.55)]
        leg = loft("Leg" + tag, stations, n=10)
        smooth(leg)
        ball_z = pts[3].z

        def leg_colour(co, n, ball_z=ball_z):
            if co.z < ball_z + 0.02 and co.x > 0.85:
                return col["claw"]
            if co.z < 1.25:
                return col["shin"]
            if n.z < -0.4:
                return col["belly"]
            return col["base"]
        paint(leg, leg_colour)
        parts["leg" + tag] = leg
        ar = spec["arm"]
        pts = [V((p[0], p[1] * side, p[2])) for p in (ar["shoulder"], ar["elbow"], ar["hand"])]
        aws = ar["widths"]
        arm = loft("Arm" + tag, [(pts[0], aws[0], aws[0]), (pts[1], aws[1], aws[1]), (pts[2], aws[2], aws[2])], n=8)
        smooth(arm, 1)
        paint(arm, lambda co, n: col["base"])
        parts["arm" + tag] = arm

    mat = toon_material()
    for obj in parts.values():
        obj.data.materials.clear()
        obj.data.materials.append(mat)
    return parts


# --- the rig --------------------------------------------------------------------------------------

def rig(spec, parts):
    lg = spec["leg"]
    ar = spec["arm"]
    hx, hz = spec["jaw_hinge"]
    arm_data = bpy.data.armatures.new("Rig")
    arm_obj = bpy.data.objects.new("Rig", arm_data)
    bpy.context.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones

    def bone(name, head, tail, parent=None, connect=False, deform=True):
        b = eb.new(name)
        b.head = V(head)
        b.tail = V(tail)
        if parent:
            b.parent = eb[parent]
            b.use_connect = connect
        b.use_deform = deform
        return b

    bone("root", (0, 0, 0), (0, 0, 0.5), deform=False)
    bs = spec["bones"]

    def xz(p):
        return (p[0], 0, p[1])
    bone("pelvis", xz(bs["pelvis"][0]), xz(bs["pelvis"][1]), "root")
    bone("chest", xz(bs["chest"][0]), xz(bs["chest"][1]), "pelvis", True)
    bone("neck", xz(bs["neck"][0]), xz(bs["neck"][1]), "chest", True)
    bone("neck2", xz(bs["neck2"][0]), xz(bs["neck2"][1]), "neck", True)
    bone("head", xz(bs["head"][0]), xz(bs["head"][1]), "neck2", True)
    bone("jaw", (hx, 0, hz), xz(bs["jaw_tip"]), "head")
    tail = bs["tail"]
    for i in range(len(tail) - 1):
        bone("tail%d" % (i + 1), xz(tail[i]), xz(tail[i + 1]), "pelvis" if i == 0 else "tail%d" % i, i > 0)
    for side, tag in ((1, "L"), (-1, "R")):
        def at(p):
            return (p[0], p[1] * side, p[2])
        bone("thigh." + tag, at(lg["hip"]), at(lg["knee"]), "pelvis")
        bone("shin." + tag, at(lg["knee"]), at(lg["ankle"]), "thigh." + tag, True)
        bone("meta." + tag, at(lg["ankle"]), at(lg["ball"]), "shin." + tag, True)
        bone("toe." + tag, at(lg["ball"]), at(lg["toe"]), "meta." + tag, True)
        # Controls (not deforming): the ankle target, the foot's angle, the knee pole.
        a = at(lg["ankle"])
        bone("ik." + tag, a, (a[0] + 0.3, a[1], a[2]), "root", deform=False)
        bone("foot." + tag, at(lg["ankle"]), at(lg["ball"]), "root", deform=False)
        k = at(lg["knee"])
        bone("pole." + tag, (k[0] + 1.6, k[1], k[2]), (k[0] + 1.9, k[1], k[2]), "pelvis", deform=False)
        bone("arm." + tag, at(ar["shoulder"]), at(ar["elbow"]), "chest")
        bone("hand." + tag, at(ar["elbow"]), at(ar["hand"]), "arm." + tag, True)
    bpy.ops.object.mode_set(mode="POSE")
    pb = arm_obj.pose.bones
    for tag in ("L", "R"):
        ik = pb["shin." + tag].constraints.new("IK")
        ik.target = arm_obj
        ik.subtarget = "ik." + tag
        ik.pole_target = arm_obj
        ik.pole_subtarget = "pole." + tag
        ik.pole_angle = math.radians(-90.0)
        ik.chain_count = 2
        cr = pb["meta." + tag].constraints.new("COPY_ROTATION")
        cr.target = arm_obj
        cr.subtarget = "foot." + tag
    for b in pb:
        b.rotation_mode = "XYZ"
    # The pole angle that keeps each knee where it rests (it depends on the
    # bone's roll): searched, not guessed.
    for tag in ("L", "R"):
        rest = pb["shin." + tag].bone.head_local.copy()
        ik = pb["shin." + tag].constraints["IK"]

        def miss(a):
            ik.pole_angle = math.radians(a)
            bpy.context.view_layer.update()
            return (pb["shin." + tag].head - rest).length
        best = min(range(-180, 180, 4), key=miss)
        fine = min([best + d * 0.5 for d in range(-8, 9)], key=miss)
        ik.pole_angle = math.radians(fine)
    bpy.context.view_layer.update()
    bpy.ops.object.mode_set(mode="OBJECT")

    # Skin: the body, legs and arms bend with the bones (automatic weights);
    # the skull, horns and eyes ride the head, the jaw its bone.
    for key in ("body", "legL", "legR", "armL", "armR"):
        obj = parts[key]
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        arm_obj.select_set(True)
        bpy.context.view_layer.objects.active = arm_obj
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    for key, bone_name in (("head", "head"), ("hornL", "head"), ("hornR", "head"), ("EyeL", "head"), ("EyeR", "head"), ("jaw", "jaw")):
        obj = parts[key]
        mw = obj.matrix_world.copy()
        obj.parent = arm_obj
        obj.parent_type = "BONE"
        obj.parent_bone = bone_name
        obj.matrix_world = mw
    return arm_obj


# --- clips ----------------------------------------------------------------------------------------

def smoothstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


class Pose:
    """One frame's pose, set on the rig and keyed."""

    def __init__(self, rig):
        self.rig = rig
        self.pb = rig.pose.bones
        self.rest_ik = {t: self.pb["ik." + t].bone.head_local.copy() for t in ("L", "R")}

    def reset(self):
        for b in self.pb:
            b.location = (0, 0, 0)
            b.rotation_euler = (0, 0, 0)
            b.scale = (1, 1, 1)

    def rot(self, name, x=0.0, y=0.0, z=0.0):
        """Degrees about the bone's own axes (y runs along the bone)."""
        self.pb[name].rotation_euler = (math.radians(x), math.radians(y), math.radians(z))

    def ankle(self, tag, dx, dz, pitch=0.0):
        """Move the ankle target by (dx forward, dz up) in the rig's space;
        pitch the foot (degrees, toe down positive)."""
        b = self.pb["ik." + tag]
        b.location = self._local(b, Vector((dx, 0.0, dz)))
        self.pb["foot." + tag].rotation_euler = (math.radians(-pitch), 0, 0)

    def _local(self, b, world_delta):
        m = b.bone.matrix_local.to_3x3().inverted()
        return m @ world_delta

    def body(self, dz=0.0, pitch=0.0, roll=0.0, yaw=0.0):
        """Pelvis offset up (world) and turn (degrees)."""
        b = self.pb["pelvis"]
        b.location = self._local(b, Vector((0.0, 0.0, dz)))
        # pelvis y axis = forward: pitch about its x, roll about y, yaw about z.
        b.rotation_euler = (math.radians(pitch), math.radians(roll), math.radians(yaw))

    def key(self, frame):
        for b in self.pb:
            b.keyframe_insert("location", frame=frame)
            b.keyframe_insert("rotation_euler", frame=frame)


def clip_idle(p, n=8):
    for f in range(n):
        t = f / n
        br = math.sin(t * 2 * math.pi)
        p.reset()
        p.body(dz=0.025 * br, pitch=0.6 * br)
        p.rot("chest", x=0.8 * br)
        p.rot("neck", x=-1.5 * br)
        p.rot("head", x=1.0 * math.sin(t * 2 * math.pi + 0.8), z=2.0 * math.sin(t * 2 * math.pi + 1.5))
        for i in range(1, 5):
            p.rot("tail%d" % i, z=2.4 * math.sin(t * 2 * math.pi - i * 0.6), x=0.8 * br)
        p.rot("arm.L", x=4 * br)
        p.rot("arm.R", x=4 * br)
        yield f


def gait(p, n, stride, lift, stance, bob, lean, head_low, tail_swing, speed_up=1.0):
    for f in range(n):
        t = f / n
        p.reset()
        for tag, off in (("L", 0.0), ("R", 0.5)):
            ph = (t + off) % 1.0
            if ph < stance:
                q = ph / stance
                dx = stride * (0.5 - q)
                dz = 0.0
                # Heel peels up at the end of the stance, toe pushes off.
                pitch = 26.0 * smoothstep((q - 0.7) / 0.3)
            else:
                q = (ph - stance) / (1.0 - stance)
                dx = stride * (-0.5 + smoothstep(q))
                dz = lift * math.sin(math.pi * q)
                pitch = 26.0 * (1.0 - smoothstep(q / 0.4)) - 12.0 * smoothstep((q - 0.6) / 0.4)
            p.ankle(tag, dx, dz, pitch)
        # Two dips a stride (each footfall), a sway toward the planted leg.
        dip = math.cos(t * 4 * math.pi)
        side = math.sin(t * 2 * math.pi)
        p.body(dz=-bob * (0.5 + 0.5 * dip), pitch=lean, roll=3.0 * side, yaw=2.0 * side)
        p.rot("chest", x=-lean * 0.3)
        p.rot("neck", x=head_low * 0.5 + 2.0 * dip, z=-2.5 * side)
        p.rot("head", x=head_low * 0.5 - 1.5 * dip)
        for i in range(1, 5):
            p.rot("tail%d" % i, z=tail_swing * math.sin(t * 2 * math.pi - i * 0.7), x=-lean * 0.25 + 1.5 * dip)
        p.rot("arm.L", x=10 * side)
        p.rot("arm.R", x=-10 * side)
        yield f


def clip_walk(p, spec, n=8):
    yield from gait(p, n, spec["gait"]["walk_stride"], 0.32, 0.56, 0.06, 0.0, 0.0, 4.0)


def clip_run(p, spec, n=8):
    yield from gait(p, n, spec["gait"]["run_stride"], 0.5, 0.4, 0.14, -8.0, -10.0, 2.0)


def clip_bite(p, n=9):
    # Rest, draw the head back and up (jaws parting), lunge and snap shut on
    # frame 5, hold, recover.
    keys = [  # (neck x, head x, jaw x, body pitch, body dz)
        (0, 0, 0, 0, 0), (-10, -6, -8, 3, 0.0), (-16, -10, -18, 5, 0.02), (-12, -6, -30, 3, 0.0),
        (14, 6, -36, -8, -0.08), (20, 10, 0, -10, -0.1), (16, 8, 0, -8, -0.08), (8, 4, -4, -4, -0.04), (2, 1, 0, -1, 0.0)]
    for f in range(n):
        nk, hk, jk, pk, dz = keys[f]
        p.reset()
        p.body(dz=dz, pitch=pk)
        p.rot("neck", x=nk)
        p.rot("neck2", x=nk * 0.4)
        p.rot("head", x=hk)
        p.rot("jaw", x=jk)
        for i in range(1, 5):
            p.rot("tail%d" % i, x=-pk * 0.4)
        yield f


def clip_roar(p, n=12):
    for f in range(n):
        t = f / (n - 1)
        up = smoothstep(t / 0.35) * (1.0 - smoothstep((t - 0.75) / 0.25))
        crouch = math.sin(min(1.0, t / 0.25) * math.pi) * (1.0 - up)
        shake = math.sin(f * 2.6) * 1.2 * up
        p.reset()
        p.body(dz=-0.1 * crouch, pitch=6.0 * up)
        p.rot("chest", x=-4 * up)
        p.rot("neck", x=-22 * up + shake)
        p.rot("neck2", x=-8 * up)
        p.rot("head", x=-14 * up)
        p.rot("jaw", x=-42 * up)
        for i in range(1, 5):
            p.rot("tail%d" % i, x=-5 * up, z=shake)
        yield f


def clip_hurt(p, n=5):
    keys = [0, 1.0, 0.8, 0.35, 0.1]
    for f in range(n):
        k = keys[f]
        p.reset()
        p.body(dz=0.04 * k, pitch=8 * k, roll=4 * k)
        p.rot("neck", x=-14 * k, z=6 * k)
        p.rot("head", x=-8 * k)
        p.rot("jaw", x=-14 * k)
        for i in range(1, 5):
            p.rot("tail%d" % i, z=-5 * k)
        yield f


def clip_death(p, n=12):
    """The legs buckle, it slumps belly-down onto the ground, the neck and
    tail droop, a last sag to one side. (Rolled flank-up it read as a flat
    line from Cravera's low camera.)"""
    for f in range(n):
        t = f / (n - 1)
        buckle = smoothstep(t / 0.45)
        slump = smoothstep((t - 0.2) / 0.55)
        p.reset()
        for tag, lag in (("L", 0.0), ("R", 0.12)):
            b = smoothstep((t - lag) / 0.45)
            p.ankle(tag, 0.55 * b, 0.0, 40.0 * b)
        p.body(dz=-1.85 * buckle, pitch=6.0 * slump, roll=10.0 * slump)
        root = p.pb["root"]
        root.rotation_euler = (math.radians(14.0 * slump), 0.0, 0.0)
        p.rot("chest", x=4 * slump)
        p.rot("neck", x=26 * slump - 8 * math.sin(min(1.0, t / 0.3) * math.pi))
        p.rot("neck2", x=10 * slump)
        p.rot("head", x=14 * slump)
        p.rot("jaw", x=-12 * slump)
        for i in range(1, 5):
            p.rot("tail%d" % i, x=5 * slump, z=4 * slump)
        p.rot("arm.L", x=20 * slump)
        p.rot("arm.R", x=20 * slump)
        yield f


CLIPS = {"idle": (clip_idle, 6, True), "walk": (clip_walk, 9, True), "run": (clip_run, 13, True),
         "bite": (clip_bite, 14, False), "roar": (clip_roar, 10, False), "hurt": (clip_hurt, 12, False),
         "death": (clip_death, 10, False)}


# --- camera, light, render ------------------------------------------------------------------------

def stage(spec):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    w, h = spec["canvas"]
    scene.render.resolution_x = w * SCALE
    scene.render.resolution_y = h * SCALE
    scene.render.film_transparent = True
    scene.render.filter_size = 0.01
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0, 0, 0, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.0
    scene.world = world
    el = math.radians(spec["elevation"])
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = w / spec["px_per_unit"]
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.collection.objects.link(cam)
    dist = 30.0
    cam.location = (0.0, -dist * math.cos(el), dist * math.sin(el))
    cam.rotation_euler = (math.pi / 2 - el, 0.0, 0.0)
    # The feet (world origin) land on the game's ground row (h - 7).
    ground = h - 7
    cam_data.shift_y = (ground + 0.5 - h / 2.0) / float(w)
    scene.camera = cam
    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 3.0
    sun_data.angle = math.radians(3.0)
    sun = bpy.data.objects.new("Sun", sun_data)
    bpy.context.collection.objects.link(sun)
    # From the upper left, a little toward the viewer.
    sun.rotation_euler = Euler((math.radians(42.0), math.radians(-28.0), math.radians(-38.0)), "XYZ")
    return scene


FACING_YAW = {"side": 0.0, "down": -90.0, "up": 90.0}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

    def opt(flag, default=None):
        return argv[argv.index(flag) + 1] if flag in argv else default

    key = opt("--species", "carno")
    spec = SPECIES[key]
    clips = opt("--clips", ",".join(CLIPS.keys())).split(",")
    facings = opt("--facings", "side,down,up").split(",")
    out = os.path.join(ROOT, "art", "blender", key, "raw")
    clear_scene()
    parts = build(spec)
    rig_obj = rig(spec, parts)
    scene = stage(spec)
    pose = Pose(rig_obj)
    bpy.context.view_layer.objects.active = rig_obj
    bpy.ops.object.mode_set(mode="POSE")
    for clip in clips:
        fn, fps, loop = CLIPS[clip]
        rig_obj.animation_data_clear()
        pose.reset()
        frames = list(fn(pose, spec) if clip in ("walk", "run") else fn(pose))
        # Key every frame (fn left the pose of its last frame; rebuild per frame).
        rig_obj.animation_data_clear()
        gen = fn(pose, spec) if clip in ("walk", "run") else fn(pose)
        for f in gen:
            pose.key(f + 1)
        for facing in facings:
            yaw = math.radians(FACING_YAW[facing])
            rig_obj.rotation_euler = (0.0, 0.0, yaw)
            d = os.path.join(out, "%s_%s" % (clip, facing))
            os.makedirs(d, exist_ok=True)
            for f in range(len(frames)):
                if "--still" in argv and f > 0:
                    break
                scene.frame_set(f + 1)
                scene.render.filepath = os.path.join(d, "%03d.png" % f)
                bpy.ops.render.render(write_still=True)
            print("CLIP", clip, facing, len(frames), "frames", flush=True)
        rig_obj.rotation_euler = (0.0, 0.0, 0.0)
    bpy.ops.object.mode_set(mode="OBJECT")
    print("FACTORY_DONE", key, flush=True)


if __name__ == "__main__":
    main()
