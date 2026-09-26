import struct, json

def read_glb(path):
    with open(path, "rb") as f:
        magic, version, length = struct.unpack("<3I", f.read(12))
        chunk_len, chunk_type = struct.unpack("<2I", f.read(8))
        data = json.loads(f.read(chunk_len))
        return data

def accessor_max_min(g, acc_idx):
    return g["accessors"][acc_idx].get("max"), g["accessors"][acc_idx].get("min")

for label, path in [
    ("BACKUP", r"C:\Users\hp\Documents\sabira\backups\PhotoBox.glb.bak_20260924_103534"),
    ("NEW", r"C:\Users\hp\Documents\sabira\props\PhotoBox.glb"),
]:
    g = read_glb(path)
    print("====", label, "nodes/anims ====")
    for i,n in enumerate(g.get("nodes",[])):
        print(f"  node[{i}] {n.get('name')} T={n.get('translation')} R={n.get('rotation')}")
    for a in g.get("animations", []):
        print(f" ANIM {a['name']} n_ch={len(a['channels'])}")
        for ch in a["channels"]:
            node = g["nodes"][ch["target"]["node"]]
            samp = a["samplers"][ch["sampler"]]
            out_acc = samp["output"]
            mx, mn = accessor_max_min(g, out_acc)
            print(f"  {node.get('name')}.{ch['target']['path']} min={mn} max={mx}")
