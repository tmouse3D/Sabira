import struct, json
path=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.glb"
with open(path,"rb") as f: data=f.read()
jlen=struct.unpack_from("<I",data,12)[0]
j=json.loads(data[20:20+jlen].decode().rstrip("\x00"))
print("nodes:")
for i,n in enumerate(j.get("nodes",[])):
    print(i, n.get("name"), "trans", n.get("translation"), "rot", n.get("rotation"), "children", n.get("children"))
print("scenes", j.get("scenes"))
print("anims", [a.get("name") for a in j.get("animations",[])])
