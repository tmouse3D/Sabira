import bpy
bpy.ops.wm.open_mainfile(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend")
root = [n for n in bpy.data.objects.keys() if "Root" in n][0]
print("ROOT_REPR", repr(root))
gd_path = r"C:\Users\hp\Documents\sabira\interact\MomLockRect.gd"
import re
text = open(gd_path, encoding="utf-8").read()
m = re.search(r'NodePath\("([^"]+)"\)', text)
print("GD_PATH", repr(m.group(1) if m else None))
# extract expected root from path
parts = m.group(1).split("/")
print("GD_ROOT_SEGMENT", repr(parts[-2]))
print("MATCH", parts[-2] == root)