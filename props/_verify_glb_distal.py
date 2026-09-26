import json, struct, os
path = r"C:\Users\hp\Documents\sabira\props\Mom_Amina.glb"
with open(path,"rb") as f: data=f.read()
chunk_len,=struct.unpack_from("<I", data, 12)
js=data[20:20+chunk_len].decode("utf-8","ignore").rstrip("\x00")
meta=json.loads(js)
mats=[m.get("name") for m in meta.get("materials",[])]
print("MATERIALS", mats)
for m in meta.get("materials",[]):
    name=m.get("name")
    pbr=m.get("pbrMetallicRoughness",{})
    bc=pbr.get("baseColorFactor")
    am=m.get("alphaMode")
    print(f"  {name}: alphaMode={am} baseColorFactor={bc}")
print("ANIMS", [a.get("name") for a in meta.get("animations",[])])
print("NODES", [n.get("name") for n in meta.get("nodes",[])])
# morph targets?
mesh_extras=0
for mesh in meta.get("meshes",[]):
    for p in mesh.get("primitives",[]):
        if "targets" in p: mesh_extras += len(p["targets"])
print("MORPH_TARGETS_TOTAL", mesh_extras)
print("SIZE", os.path.getsize(path))
