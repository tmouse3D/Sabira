import struct, json, os
path = r"C:\Users\hp\Documents\sabira\props\Mom_Amina.glb"
with open(path,"rb") as f:
    f.read(12)
    cl, ct = struct.unpack("<I4s", f.read(8))
    j = json.loads(f.read(cl))
print("ANIMS", [a.get("name") for a in j.get("animations",[])])
print("NODES", [n.get("name") for n in j.get("nodes",[])])
nodes=j["nodes"]
for i,n in enumerate(nodes):
    if n.get("children"):
        print("PARENT", n.get("name"), "->", [nodes[k].get("name") for k in n["children"]])
print("SIZE", os.path.getsize(path))
