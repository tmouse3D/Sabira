from pathlib import Path
import re

p = Path(r"C:\Users\hp\Documents\sabira\world\House.tscn")
text = p.read_text(encoding="utf-8")

old3 = """[node name=\"Kitchen_Chair_3Body\" type=\"StaticBody3D\" parent=\"Structure/KitchenDining\" unique_id=412266195]
transform = Transform3D(1, 0, -4.371139e-08, 0, 1, 0, 4.371139e-08, 0, 1, -0.62652636, 0.45, -2.5500002)
collision_layer = 5
collision_mask = 0
script = ExtResource(\"101_chairsit\")
"""

new3 = """[node name=\"Kitchen_Chair_3Body\" type=\"StaticBody3D\" parent=\"Structure/KitchenDining\" unique_id=412266195]
transform = Transform3D(1, 0, -4.371139e-08, 0, 1, 0, 4.371139e-08, 0, 1, -0.62652636, 0.45, -2.5500002)
"""

old4 = """[node name=\"Kitchen_Chair_4Body\" type=\"StaticBody3D\" parent=\"Structure/KitchenDining\" unique_id=1797505917]
transform = Transform3D(-1, 0, 4.371139e-08, 0, 1, 0, -4.371139e-08, 0, -1, 0.38055563, 0.45, -0.95557547)
"""

new4 = """[node name=\"Kitchen_Chair_4Body\" type=\"StaticBody3D\" parent=\"Structure/KitchenDining\" unique_id=1797505917]
transform = Transform3D(-1, 0, 4.371139e-08, 0, 1, 0, -4.371139e-08, 0, -1, 0.38055563, 0.45, -0.95557547)
collision_layer = 5
collision_mask = 0
script = ExtResource(\"101_chairsit\")
sit_pose_offset = Vector3(1.04, -0.45, 0.08)
sit_pose_yaw_deg = 0.0
editor_description = \"Chair_4 sit-able only. Mesh at (-0.66,0,-0.96) yaw180; body at (0.38,0.45,-0.96). sit_pose_offset body-local to mesh seat: local +X~1.04 maps world -X; y -0.45 floor; +Z toward table.\"
"""

assert old3 in text, "Chair_3Body block not found"
assert old4 in text, "Chair_4Body block not found"
text = text.replace(old3, new3, 1)
text = text.replace(old4, new4, 1)
p.write_text(text, encoding="utf-8")
print("House.tscn updated OK")

v = p.read_text(encoding="utf-8")
for name in ["Kitchen_Chair_3Body", "Kitchen_Chair_4Body"]:
    m = re.search(rf'\[node name="{name}".*?(?=\n\[node |\Z)', v, re.S)
    print("---", name, "---")
    print(m.group(0)[:600] if m else "MISSING")
