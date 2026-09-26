from pathlib import Path
base = Path(r"C:\Users\hp\Documents\sabira")
path = base / "world" / "BookcaseMover.gd"
bak = base / "backups" / "BookcaseMover.gd.bak_20260924_1052"
bak.write_bytes(path.read_bytes())
raw = path.read_bytes()
text = raw.decode("utf-8", errors="replace")
for a, b in [
    ("\u2014", "-"), ("\u2013", "-"), ("\u2026", "..."),
    ("\u2018", "'"), ("\u2019", "'"), ("\u201c", '"'), ("\u201d", '"'),
    ("\ufffd", "-"),
]:
    text = text.replace(a, b)
# strip any leftover non-ascii in comments by replacing high chars
clean = []
for ch in text:
    o = ord(ch)
    if o < 128 or ch in "\n\r\t":
        clean.append(ch)
    else:
        clean.append("-" if o in (0x2013, 0x2014) else "?")
text = "".join(clean)
# better: only ASCII for safety on this file
text2 = []
for ch in raw.decode("utf-8", errors="replace"):
    o = ord(ch)
    if o < 128:
        text2.append(ch)
    elif ch in "\n\r\t":
        text2.append(ch)
    else:
        text2.append("-")
text = "".join(text2)
lines = text.splitlines()
if lines and "Godot" in lines[0]:
    lines[0] = "# Godot 4.x - Sabira / HOUSE"
text = "\n".join(lines) + "\n"
path.write_bytes(text.encode("ascii"))
print("wrote", path, "bytes", path.stat().st_size)
print("head", path.read_bytes()[:50])
# verify all gd ascii-or-valid-utf8
bad = []
for p in base.rglob("*.gd"):
    if ".godot" in p.parts or "backups" in p.parts:
        continue
    data = p.read_bytes()
    try:
        data.decode("utf-8")
    except UnicodeDecodeError as e:
        bad.append((str(p.relative_to(base)), str(e)))
        continue
    if any(x >= 0x80 for x in data):
        # valid utf8 non-ascii - list
        bad.append((str(p.relative_to(base)), "has non-ascii utf8 ok"))
print("issues", len(bad))
for x in bad[:25]:
    print(x)
