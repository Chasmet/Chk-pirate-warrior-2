"""Original CHK scenery, metres / Y-up, merged by material for mobile.

Reproduce with Python 3, numpy and trimesh (no Blender or downloaded assets).
Animation tracks are embedded in the GLB, not simulated preview animations.
"""
import json
import math
import struct
from pathlib import Path

import numpy as np
import trimesh as tm

OUT = Path(__file__).resolve().parents[1] / "assets/decors_v12"
PALETTE = {
    "wood": (91, 54, 35), "dark": (33, 39, 47), "brass": (207, 162, 79),
    "ivory": (235, 222, 186), "red": (151, 46, 51), "teal": (34, 132, 139),
    "stone": (97, 115, 122), "leaf": (48, 121, 90), "glow": (83, 225, 207),
}


class Model:
    def __init__(self):
        self.parts = {}

    def add(self, mesh, material, pos=(0, 0, 0), rotation=None, group="static"):
        if rotation is not None:
            mesh.apply_transform(tm.transformations.rotation_matrix(*rotation))
        mesh.apply_translation(pos)
        self.parts.setdefault((group, material), []).append(mesh)

    def box(self, size, pos, mat="wood", rotation=None, group="static"):
        self.add(tm.creation.box(size), mat, pos, rotation, group)

    def cylinder(self, radius, height, pos, mat="wood", top=None, sections=12, group="static"):
        # Trimesh primitives point along Z; rotate to Godot's Y-up coordinates.
        if top is None:
            mesh = tm.creation.cylinder(radius, height, sections=sections)
        else:
            profile = np.array([[0, -height/2], [radius, -height/2], [top, height/2], [0, height/2]])
            mesh = tm.creation.revolve(profile, sections=sections)
        self.add(mesh, mat, pos, (math.pi/2, [1, 0, 0]), group)

    def gem(self, size, pos, mat="glow", group="static"):
        mesh = tm.creation.icosphere(subdivisions=0)
        mesh.apply_scale(size)
        self.add(mesh, mat, pos, group=group)

    def barrel(self, x, z, scale=1):
        self.cylinder(.48*scale, 1.15*scale, (x, .575*scale, z))
        for y in [.15, .55, 1.0]:
            self.cylinder(.495*scale, .07*scale, (x, y*scale, z), "dark")
        self.cylinder(.40*scale, .04*scale, (x, 1.17*scale, z), "brass")

    def crate(self, x, y, z):
        self.box((1, 1, 1), (x, y+.5, z))
        for side in [-.45, .45]:
            self.box((.10, 1.05, 1.05), (x+side, y+.5, z), "brass")
        self.box((1.04, .09, 1.04), (x, y+.5, z), "dark")

    def save(self, name, animation=None):
        scene = tm.Scene()
        triangle_count = 0
        for (group, material), meshes in self.parts.items():
            mesh = tm.util.concatenate(meshes)
            color = list(PALETTE[material]) + [255]
            pbr = tm.visual.material.PBRMaterial(name=material, baseColorFactor=color,
                roughnessFactor=.82 if material in ["wood", "stone", "leaf"] else .38,
                metallicFactor=.65 if material == "brass" else .0,
                emissiveFactor=[.10, .55, .43] if material == "glow" else [0, 0, 0])
            mesh.visual = tm.visual.TextureVisuals(material=pbr)
            scene.add_geometry(mesh, node_name=f"{group}_{material}", geom_name=f"{group}_{material}")
            triangle_count += len(mesh.faces)
        raw = scene.export(file_type="glb")
        doc_len = struct.unpack_from("<I", raw, 12)[0]
        doc = json.loads(raw[20:20+doc_len])
        bin_offset = 20 + doc_len
        binary = bytearray(raw[bin_offset+8:])
        doc["asset"]["generator"] = "CHK original scenery kit V12"
        if animation:
            group, mode, values, duration = animation
            def accessor(values, shape):
                data = np.array(values, dtype="<f4")
                while len(binary) % 4: binary.append(0)
                offset = len(binary)
                binary.extend(data.tobytes())
                views = doc.setdefault("bufferViews", [])
                views.append({"buffer": 0, "byteOffset": offset, "byteLength": data.nbytes})
                acc = {"bufferView": len(views)-1, "componentType": 5126, "count": len(values), "type": shape}
                if shape == "SCALAR": acc.update(min=[float(data.min())], max=[float(data.max())])
                doc.setdefault("accessors", []).append(acc)
                return len(doc["accessors"])-1
            times = accessor(np.linspace(0, duration, len(values)), "SCALAR")
            output = accessor(values, "VEC4" if mode == "rotation" else "VEC3")
            channels = []
            for i, node in enumerate(doc["nodes"]):
                if node.get("name", "").startswith(group+"_"):
                    node.pop("matrix", None)
                    channels.append({"sampler": 0, "target": {"node": i, "path": mode}})
            doc["animations"] = [{"name": "Ambiance_loop", "samplers": [{"input": times, "output": output, "interpolation": "LINEAR"}], "channels": channels}]
        doc["buffers"][0]["byteLength"] = len(binary)
        j = json.dumps(doc, separators=(",", ":")).encode()
        j += b" " * (-len(j) % 4)
        binary.extend(b"\0" * (-len(binary) % 4))
        payload = struct.pack("<III", 0x46546C67, 2, 28+len(j)+len(binary))
        payload += struct.pack("<II", len(j), 0x4E4F534A) + j
        payload += struct.pack("<II", len(binary), 0x004E4942) + binary
        (OUT / (name+".glb")).write_bytes(payload)
        return {"file": name+".glb", "triangles": triangle_count, "bytes": len(payload), "animated": bool(animation)}


def create_models():
    OUT.mkdir(parents=True, exist_ok=True)
    report = []
    m = Model()
    m.cylinder(2.2, .5, (0, .25, 0), "stone", sections=16)
    for i in range(5):
        m.cylinder(1.7-i*.15, 1.7, (0, 1.35+i*1.7, 0), "ivory" if i%2 == 0 else "red", top=1.55-i*.15, sections=16)
    m.cylinder(1.7, .2, (0, 8.9, 0), "dark", sections=16)
    for a in np.linspace(0, math.tau, 8, endpoint=False):
        m.cylinder(.06, 1.4, (math.cos(a)*1.1, 9.55, math.sin(a)*1.1), "brass", sections=6)
    m.cylinder(1.55, 1.2, (0, 10.75, 0), "teal", top=0, sections=16)
    m.gem((.45, .65, .45), (0, 9.6, 0), "glow", "beacon")
    m.box((1.9, .12, .22), (.7, 9.6, 0), "brass", group="beacon")
    for i in range(4): m.box((.55, .70, .1), (0, 1.4+i*1.65, 1.62-i*.15), "dark")
    rotations = [[0, math.sin(a/2), 0, math.cos(a/2)] for a in np.linspace(0, math.tau, 9)]
    report.append(m.save("phare_corsaire", ("beacon", "rotation", rotations, 7)))

    m = Model()
    for x in [-2.2, 2.2]:
        for z in [-1.3, 1.3]: m.cylinder(.11, 3.5, (x, 1.75, z))
    m.box((4.5, .2, 1.6), (0, 1.05, .45))
    m.box((4.5, .8, .15), (0, .55, 1.2), "dark")
    for i in range(8):
        m.box((.6, .12, 3.4), (-2.1+i*.6, 3.4, 0), "teal" if i%2 else "ivory")
        m.box((.6, .35, .08), (-2.1+i*.6, 3.25, 1.7), "teal" if i%2 else "ivory")
    for i in range(5):
        m.gem((.22, .18, .22), (-1.3+i*.65, 1.3, .5), "red" if i%2 else "brass")
    m.barrel(2.9, .5); m.crate(-2.9, 0, -.2)
    report.append(m.save("marche_des_corsaires"))

    m = Model()
    for x in [-3, 3]:
        m.cylinder(.9, .4, (x, .2, 0), "stone")
        m.box((1.4, 4.5, 1.6), (x, 2.65, 0), "stone")
        for y in [1, 2.3, 3.6, 4.8]: m.box((1.6, .16, 1.8), (x, y, 0), "ivory")
        for z in [-.6, .6]: m.box((.5, .7, .45), (x, 5.3, z), "stone")
    m.box((5, .65, 1.1), (0, 4.8, 0), "dark")
    m.box((4.8, .12, 1.2), (0, 5.15, 0), "brass")
    m.gem((.5, .65, .25), (0, 4.8, .65), "glow")
    report.append(m.save("arche_du_port"))

    m = Model()
    for y, r in [(0.2, 1.8), (.6, 1.35), (.95, .9)]: m.cylinder(r, .35, (0, y, 0), "stone", sections=8)
    for a in np.linspace(0, math.tau, 6, endpoint=False):
        m.gem((.15, .25, .15), (math.cos(a)*1.35, .9, math.sin(a)*1.35), "brass")
    m.gem((.65, 1.15, .65), (0, 2.3, 0), "glow", "crystal")
    for x in [-1, 1]: m.gem((.25, .55, .25), (x, 1.6, .4), "teal")
    report.append(m.save("sanctuaire_des_marees", ("crystal", "translation", [[0, 0, 0], [0, .25, 0], [0, 0, 0]], 3)))

    m = Model()
    for x, z, s in [(-.6, 0, 1), (.5, -.5, .9), (.5, .7, .7)]: m.barrel(x, z, s)
    m.crate(-1.5, 0, .7); m.crate(-1.5, 1, .7)
    report.append(m.save("reserves_du_port"))

    m = Model()
    m.cylinder(.5, .25, (0, .125, 0), "stone")
    m.cylinder(.09, 4.2, (0, 2.1, 0), "brass", sections=8)
    m.gem((.18, .3, .18), (0, 4.35, 0), "brass")
    m.box((1.7, 1.0, .045), (.9, 3.45, 0), "red", group="flag")
    m.gem((.26, .29, .06), (.9, 3.45, .05), "ivory", "flag")
    angles = [-.09, .09, -.09]
    report.append(m.save("banniere_chk", ("flag", "rotation", [[0, math.sin(a/2), 0, math.cos(a/2)] for a in angles], 2.5)))

    m = Model()
    for i in range(11): m.box((3, .16, .58), (0, .25, -3+i*.6))
    for x in [-1.55, 1.55]:
        for z in [-3.3, -.9, 1.5, 3.3]: m.cylinder(.12, 1.7, (x, .85, z))
        for y in [.8, 1.35]: m.box((.06, .06, 7), (x, y, 0), "ivory")
    report.append(m.save("passerelle_cotiere"))

    m = Model()
    for i in range(7):
        a = i*2.4
        x, z = math.cos(a)*.8, math.sin(a)*.8
        m.gem((.28, .5+i*.09, .25), (x, .5+i*.09, z), "teal" if i%2 else "red")
    m.cylinder(1.4, .15, (0, .075, 0), "stone")
    report.append(m.save("corail_des_abysses"))
    (OUT / "manifest.json").write_text(json.dumps(report, indent=2)+"\n")
    print(json.dumps({"models": len(report), "total_bytes": sum(x["bytes"] for x in report)}, indent=2))


if __name__ == "__main__":
    create_models()
