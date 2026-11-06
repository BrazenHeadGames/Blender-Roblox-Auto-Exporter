"""Blender -> Roblox FBX exporter.

Exports every mesh object inside the collection named `export_collection` (including child
collections) as its own FBX, named after the object, into `export_dir`. Lights, cameras and
empties are ignored. An object is re-exported only when its geometry/UV/material/transform
signature changed (FBX bytes differ on every export because of embedded timestamps).

You get feedback in three places:
  - the status bar (bottom of the Blender window) after every save
  - a "Roblox" tab in the 3D Viewport sidebar (press N) with an Export button and the last result
  - the system console / Info editor

Install: copy this file to  <Blender config>/<version>/scripts/startup/  and restart Blender.
Config:  ~/.rbx_pipeline/config.json  (see config.example.json), or env var RBX_PIPELINE_CONFIG.
Manual:  blender -b file.blend --python rbx_export.py -- --run [--force]
"""
import sys
import os
import json
import time
import hashlib
import bpy
from bpy.app.handlers import persistent

_DEFAULTS = {
    "export_dir": os.path.join(os.path.expanduser("~"), "RobloxExports"),
    "export_collection": "Export",
    "signature_file": os.path.join(os.path.expanduser("~"), ".rbx_pipeline", "signatures.json"),
}

# Result of the most recent export, shown in the sidebar panel.
_last = {"time": None, "written": [], "skipped": [], "errors": [], "dir": ""}


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


def _export(obj, cfg, sigs, force, result):
    name = obj.name
    path = os.path.join(cfg["export_dir"], name + ".fbx")
    try:
        sig = _signature(obj)
        if not force and sigs.get(name) == sig and os.path.exists(path):
            print(f"[rbx_export] {name}: unchanged, skipped")
            result["skipped"].append(name)
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
        result["written"].append(name)
    except Exception as e:
        print(f"[rbx_export] ERROR exporting {name}: {e}")
        result["errors"].append(f"{name}: {e}")


def export_all(force=False):
    """Export changed objects. Returns a result dict and stores it for the sidebar panel."""
    cfg = _config()
    result = {"time": time.time(), "written": [], "skipped": [], "errors": [], "dir": cfg["export_dir"]}
    root = bpy.data.collections.get(cfg["export_collection"])
    if root is None:
        result["errors"].append(f"No collection named '{cfg['export_collection']}'")
    else:
        os.makedirs(cfg["export_dir"], exist_ok=True)
        os.makedirs(os.path.dirname(cfg["signature_file"]), exist_ok=True)
        sigs = _load_sigs(cfg["signature_file"])
        meshes = [o for o in root.all_objects if o.type == 'MESH']
        if not meshes:
            result["errors"].append(f"'{cfg['export_collection']}' has no mesh objects")
        for o in meshes:
            _export(o, cfg, sigs, force, result)
        with open(cfg["signature_file"], "w") as f:
            json.dump(sigs, f, indent=1)
    _last.update(result)
    return result


def summary(result):
    """One short, plain sentence describing an export."""
    if result["errors"]:
        return "Roblox export problem: " + result["errors"][0]
    n, k = len(result["written"]), len(result["skipped"])
    if n:
        return f"Roblox export: {n} file(s) written ({', '.join(result['written'])}). Next: push to Roblox."
    return f"Roblox export: nothing changed ({k} model(s) already up to date)."


def _show_status(msg):
    """Show a message in the status bar for a few seconds. Safe to call without a window."""
    try:
        ws = bpy.context.workspace
        if ws is None:
            return
        ws.status_text_set(msg)

        def _clear():
            try:
                bpy.context.workspace.status_text_set(None)
            except Exception:
                pass
            return None
        bpy.app.timers.register(_clear, first_interval=12.0)
    except Exception:
        pass


@persistent
def _on_save(_dummy):
    try:
        result = export_all()
        _show_status(summary(result))
    except Exception as e:  # never block a save
        print(f"[rbx_export] ERROR: {e}")
        _show_status(f"Roblox export failed: {e}")


class RBX_OT_export(bpy.types.Operator):
    """Export changed models in the Export collection to FBX files for Roblox"""
    bl_idname = "rbx.export"
    bl_label = "Export to Roblox"

    force: bpy.props.BoolProperty(name="Export everything", default=False)

    def execute(self, context):
        result = export_all(force=self.force)
        self.report({'ERROR' if result["errors"] else 'INFO'}, summary(result))
        _show_status(summary(result))
        return {'FINISHED'}


class RBX_PT_panel(bpy.types.Panel):
    bl_label = "Roblox Export"
    bl_idname = "RBX_PT_panel"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = "Roblox"

    def draw(self, context):
        col = self.layout.column(align=True)
        col.operator("rbx.export", text="Export changed models", icon='EXPORT').force = False
        col.operator("rbx.export", text="Re-export everything", icon='FILE_REFRESH').force = True
        box = self.layout.box()
        if _last["time"] is None:
            box.label(text="No export yet this session.")
            box.label(text="Saving also exports.")
            return
        box.label(text="Last export: " + time.strftime("%H:%M:%S", time.localtime(_last["time"])))
        for name in _last["written"]:
            box.label(text="Written: " + name, icon='CHECKMARK')
        if _last["skipped"]:
            box.label(text=f"Unchanged: {len(_last['skipped'])}")
        for err in _last["errors"]:
            box.label(text=err, icon='ERROR')
        if _last["written"]:
            box.label(text="Next: push to Roblox.")
            box.label(text="Studio updates after the push.")
        box.label(text="Folder: " + _last["dir"])


_classes = (RBX_OT_export, RBX_PT_panel)


def register():
    for c in _classes:
        try:
            bpy.utils.unregister_class(c)  # tolerate script reloads
        except Exception:
            pass
        bpy.utils.register_class(c)
    if _on_save not in bpy.app.handlers.save_post:
        bpy.app.handlers.save_post.append(_on_save)


if __name__ == "__main__" and "--run" in sys.argv:
    export_all(force="--force" in sys.argv)  # manual: blender -b file.blend --python rbx_export.py -- --run
else:
    register()  # startup script: hook export onto every save and add the sidebar panel
