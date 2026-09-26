import struct, json
def load(path):
    with open(path,"rb") as f: data=f.read()
    jlen=struct.unpack_from("<I",data,12)[0]
    return json.loads(data[20:20+jlen].decode().rstrip("\x00"))
res=load(r"C:\Users\hp\Documents\sabira\props\Mom_Restraint.glb")
mom=load(r"C:\Users\hp\Documents\sabira\props\Mom_Amina.glb")
for n in res["nodes"]:
    if "mesh" in n:
        m=res["meshes"][n["mesh"]]
        acc=res["accessors"][m["primitives"][0]["attributes"]["POSITION"]]
        print(n["name"], "min", [round(x,3) for x in acc.get("min",[])], "max", [round(x,3) for x in acc.get("max",[])])
print("--- mom body ---")
n=next(x for x in mom["nodes"] if x.get("name")=="Body")
m=mom["meshes"][n["mesh"]]
acc=mom["accessors"][m["primitives"][0]["attributes"]["POSITION"]]
print("Body", [round(x,3) for x in acc["min"]], [round(x,3) for x in acc["max"]])
# Neck estimate: verts near mouth z with mid y
print("LockRect local", next(x for x in res["nodes"] if x["name"]=="LockRect").get("translation"))
# What rotation makes Mom face-up AND neck near LockRect world?
# Lock world (-0.85, 0.649, -0.494)
# Prefer face +Y world.
# Neck approx at mouth but slightly toward body center / lower face Y: (0.09, 0.28, -0.70)
neck=(0.09, 0.28, -0.70)
# identity origin such that neck maps near lock:
# origin = lock_w - neck_l
ox=-0.85-0.09; oy=0.649-0.28; oz=-0.494-(-0.70)
print("identity origin for neck~lock", (round(ox,3), round(oy,3), round(oz,3)))
# back on mattress: back_y_world = oy + 0.07; want ~0.55-0.70
print("back y with that origin", round(oy+0.07,3), "face top", round(oy+0.46,3))
# Bed mattress - check Bed.glb
bed=load(r"C:\Users\hp\Documents\sabira\props\Bed.glb")
print("BED nodes", [(n.get("name"), n.get("translation")) for n in bed.get("nodes",[])])
for n in bed["nodes"]:
    if "mesh" in n:
        m=bed["meshes"][n["mesh"]]
        for pi,p in enumerate(m["primitives"]):
            acc=bed["accessors"][p["attributes"]["POSITION"]]
            print(" bed mesh", n.get("name"), "prim", pi, "min", [round(x,3) for x in acc.get("min",[])], "max", [round(x,3) for x in acc.get("max",[])])
