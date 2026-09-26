import struct, json
path=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.glb"
with open(path,"rb") as f: data=f.read()
jlen=struct.unpack_from("<I",data,12)[0]
j=json.loads(data[20:20+jlen].decode().rstrip("\x00"))
# Body may have multiple primitives - invisible distal?
n=next(x for x in j["nodes"] if x.get("name")=="Body")
m=j["meshes"][n["mesh"]]
print("Body primitives", len(m["primitives"]))
for i,p in enumerate(m["primitives"]):
    mat=j["materials"][p["material"]]["name"] if "material" in p else None
    acc=j["accessors"][p["attributes"]["POSITION"]]
    print(i, "mat", mat, "verts", acc["count"], "min", [round(x,3) for x in acc.get("min",[])], "max", [round(x,3) for x in acc.get("max",[])])
