import bpy, json
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"C:\Users\hp\Documents\sabira\props\PhotoBox.glb")
# Blender 5: Action.layers / slots
rows=[]
for a in bpy.data.actions:
    info={"name":a.name,"frame_range":[float(a.frame_range[0]),float(a.frame_range[1])]}
    # try channels
    ch=[]
    if hasattr(a, "fcurves"):
        ch=["legacy_fcurves", len(a.fcurves)]
    if hasattr(a, "layers"):
        for layer in a.layers:
            for strip in getattr(layer, "strips", []) or []:
                for chn in getattr(strip, "channelbags", []) or []:
                    pass
        info["layers"]=len(a.layers)
    if hasattr(a, "slots"):
        info["slots"]= [s.identifier if hasattr(s,"identifier") else str(s) for s in a.slots]
    rows.append(info)
# also object anim
for o in bpy.data.objects:
    ad = o.animation_data
    if not ad: continue
    rows.append({"obj":o.name,"action": ad.action.name if ad.action else None, "loc":list(o.location)})
# print action attributes
a0 = bpy.data.actions[0] if bpy.data.actions else None
attrs = [x for x in dir(a0) if not x.startswith("_")] if a0 else []
open(r"C:\Users\hp\Documents\sabira\backups\pb_api.json","w").write(json.dumps({"attrs":attrs,"rows":rows}, indent=2, default=str))
print("ok", len(rows), "attrs", len(attrs))
