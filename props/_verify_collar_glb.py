import json, struct, os
path = r"C:\Users\hp\Documents\sabira\props\Mom_Amina.glb"
with open(path,"rb") as f:
    magic, ver, length = struct.unpack("<4sII", f.read(12))
    chunk_len, chunk_type = struct.unpack("<I4s", f.read(8))
    data = f.read(chunk_len)
j = json.loads(data)
print("NODES", [n.get("name") for n in j.get("nodes",[])])
print("ANIMS", [a.get("name") for a in j.get("animations",[])])
print("MESHES", [m.get("name") for m in j.get("meshes",[])])
# parent hierarchy
nodes = j["nodes"]
for i,n in enumerate(nodes):
    kids = n.get("children",[])
    if kids:
        print("PARENT", n.get("name"), "->", [nodes[k].get("name") for k in kids])
print("SIZE", os.path.getsize(path))
