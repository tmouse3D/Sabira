import struct, json

def read_glb(path):
    with open(path, "rb") as f:
        magic, version, length = struct.unpack("<3I", f.read(12))
        json_len, json_type = struct.unpack("<2I", f.read(8))
        j = json.loads(f.read(json_len))
        bin_len, bin_type = struct.unpack("<2I", f.read(8))
        blob = f.read(bin_len)
        return j, blob

def read_accessor(g, blob, acc_idx):
    acc = g["accessors"][acc_idx]
    bv = g["bufferViews"][acc["bufferView"]]
    offset = (bv.get("byteOffset", 0) + acc.get("byteOffset", 0))
    count = acc["count"]
    typ = acc["type"]
    comp = acc["componentType"]
    assert comp == 5126
    n = {"SCALAR":1, "VEC2":2, "VEC3":3, "VEC4":4}[typ]
    fmt = "<" + "f"*n
    size = 4*n
    out = []
    for i in range(count):
        out.append(struct.unpack_from(fmt, blob, offset + i*size))
    return out

def dump_anim(path, label):
    g, blob = read_glb(path)
    print("====", label, "====")
    for a in g["animations"]:
        if not a["name"].startswith("tip_spill"):
            continue
        for ch in a["channels"]:
            if ch["target"]["path"] != "translation":
                continue
            node = g["nodes"][ch["target"]["node"]]["name"]
            samp = a["samplers"][ch["sampler"]]
            times = read_accessor(g, blob, samp["input"])
            vals = read_accessor(g, blob, samp["output"])
            print(f"{a['name']} -> {node}  n={len(vals)}  t0={times[0][0]:.3f} tN={times[-1][0]:.3f}")
            print(f"  start XYZ={tuple(round(x,4) for x in vals[0])}")
            print(f"  end   XYZ={tuple(round(x,4) for x in vals[-1])}")
            dx = vals[-1][0]-vals[0][0]; dy=vals[-1][1]-vals[0][1]; dz=vals[-1][2]-vals[0][2]
            print(f"  delta dx={dx:.4f} dy={dy:.4f} dz={dz:.4f}")

dump_anim(r"C:\Users\hp\Documents\sabira\backups\PhotoBox.glb.bak_20260924_103534", "BACKUP")
dump_anim(r"C:\Users\hp\Documents\sabira\props\PhotoBox.glb", "NEW")
