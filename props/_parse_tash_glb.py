import struct, json, os
path = r"C:\Users\hp\Documents\sabira\props\Tash.glb"
with open(path, "rb") as f:
    magic, version, length = struct.unpack("<3I", f.read(12))
    print("magic", magic, "ver", version, "len", length)
    while f.tell() < length:
        chunk_len, chunk_type = struct.unpack("<2I", f.read(8))
        data = f.read(chunk_len)
        if chunk_type == 0x4E4F534A:  # JSON
            j = json.loads(data.decode("utf-8"))
            print("nodes:", [(n.get("name"), n.get("mesh"), n.get("skin"), n.get("children")) for n in j.get("nodes", [])])
            print("meshes:", [m.get("name") for m in j.get("meshes", [])])
            print("skins:", len(j.get("skins", [])))
            print("scenes", j.get("scenes"))
