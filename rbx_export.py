"""Blender -> Roblox FBX exporter (save hook).

Exports every mesh object inside the collection named EXPORT_COLLECTION (including child
collections) as its own FBX, named after the object, into EXPORT_DIR. Lights, cameras and
empties are ignored. An object is re-exported only when its geometry/UV/material/transform
signature changed (FBX bytes differ on every export because of embedded timestamps).

Install: copy this file to  <Blender config>/<version>/scripts/startup/  and restart Blender.
Config:  ~/.rbx_pipeline/config.json  (see config.example.json), or env var RBX_PIPELINE_CONFIG.
Manual:  blender -b file.blend --python rbx_export.py -- --run [--force]
"""
import sys
import os
import json
import hashlib
import bpy
from bpy.app.handlers import persistent

_DEFAULTS = {
    "export_dir": os.path.join(os.path.expanduser("~"), "RobloxExports"),
    "export_collection": "Export",
    "signature_file": os.path.join(os.path.expanduser("~"), ".rbx_pipeline", "signatures.json"),
}


def _config():
    path = os.environ.get("RBX_PIPELINE_CONFIG") or os.path.join(
        os.path.expanduser("~"), ".rbx_pipeline", "config.json")
    cfg = dict(_DEFAULTS)
    try:
        with open(path) as f:
            cfg.update(json.load(f))
    except FileNotFoundError:
        pass
    return cfg


def _signature(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = ev.to_mesh()
    try:
        h = hashlib.sha1()
        h.update(repr([round(v, 5) for row in ev.matrix_world for v in row]).encode())
        h.update(repr([round(c, 5) for v in me.vertices for c in v.co]).encode())
        h.update(repr([tuple(p.vertices) for p in me.polygons]).encode())
        for uv in me.uv_layers:
            h.update(uv.name.encode())
            h.update(repr([round(c, 5) for d in uv.data for c in d.uv]).encode())
        h.update(repr([m.name if m else None for m in me.materials]).encode())
        return h.hexdigest()
    finally:
        ev.to_mesh_clear()


def _load_sigs(path):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return {}


def _export(obj, cfg, sigs, force):
    name = obj.name
    path = os.path.join(cfg["export_dir"], name + ".fbx")
    sig = _signature(obj)
    if not force and sigs.get(name) == sig and os.path.exists(path):
        print(f"[rbx_export] {name}: unchanged, skipped")
        return
    view_layer = bpy.context.view_layer
    for o in view_layer.objects:
        o.select_set(False)
    obj.select_set(True)
    view_layer.objects.active = obj
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={'MESH'},
        apply_scale_options='FBX_SCALE_UNITS',  # Roblox Blender guide: Apply Scaling -> FBX Unit Scale
        global_scale=1.0,
    )
    sigs[name] = sig
    print(f"[rbx_export] wrote {path}")


def export_all(force=False):
    cfg = _config()
    root = bpy.data.collections.get(cfg["export_collection"])
    if root is None:
        print(f"[rbx_export] no '{cfg['export_collection']}' collection, nothing exported")
        return
    os.makedirs(cfg["export_dir"], exist_ok=True)
    os.makedirs(os.path.dirname(cfg["signature_file"]), exist_ok=True)
    sigs = _load_sigs(cfg["signature_file"])
    for o in root.all_objects:
        if o.type == 'MESH':
            _export(o, cfg, sigs, force)
    with open(cfg["signature_file"], "w") as f:
        json.dump(sigs, f, indent=1)


@persistent
def _on_save(_dummy):
    try:
        export_all()
    except Exception as e:  # never block a save
        print(f"[rbx_export] ERROR: {e}")


def register():
    if _on_save not in bpy.app.handlers.save_post:
        bpy.app.handlers.save_post.append(_on_save)


if __name__ == "__main__" and "--run" in sys.argv:
    export_all(force="--force" in sys.argv)
else:
    register()
