import struct, json, math
path=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.glb"
with open(path,"rb") as f: data=f.read()
jlen=struct.unpack_from("<I",data,12)[0]
j=json.loads(data[20:20+jlen].decode().rstrip("\x00"))
# hierarchy print
nodes=j["nodes"]
def walk(i, ind=0):
    n=nodes[i]
    print("  "*ind + n.get("name","?"), "t", n.get("translation"), "r", n.get("rotation"))
    for c in n.get("children") or []:
        walk(c, ind+1)
print("HIERARCHY:")
for si in j["scenes"][0]["nodes"]:
    walk(si)
# Body mesh bbox from accessors
body_i=next(i for i,n in enumerate(nodes) if n.get("name")=="Body")
mesh=j["meshes"][nodes[body_i]["mesh"]]
# first primitive POSITION
prim=mesh["primitives"][0]
acc=j["accessors"][prim["attributes"]["POSITION"]]
print("Body POSITION count", acc["count"], "min", acc.get("min"), "max", acc.get("max"))
# mouths
for nm in ["Mouth_Plea","Mouth_Scream","Mouth_Grimace","StumpBox_LArm","StumpBox_RArm","StumpBox_LLeg","StumpBox_RLeg"]:
    i=next(i for i,n in enumerate(nodes) if n.get("name")==nm)
    n=nodes[i]
    parent=next(nodes[p].get("name") for p,pn in enumerate(nodes) if n in [nodes[p]] or False)
# parent lookup
for i,n in enumerate(nodes):
    for c in n.get("children") or []:
        if nodes[c].get("name","").startswith(("Mouth","Stump")):
            print("PARENT", nodes[c]["name"], "<-", n["name"])
# materials / textures naming mosaic
print("images", [im.get("name") or im.get("uri") for im in j.get("images",[])])
print("materials", [m.get("name") for m in j.get("materials",[])])
# Compute carry euler: map mesh head(-Z)->cam(-X), face(+Y)->cam(+Z)
# R columns = images of basis: R*[1,0,0]=(0,1,0)? earlier: want R e_y=(0,0,1), R e_z=(1,0,0), R e_x=(0,1,0)
# Wait head is -e_z -> -e_x so R e_z = e_x
# face e_y -> e_z so R e_y = e_z
# then R e_x = R e_y x R e_z = e_z x e_x = e_y
# Matrix (cols): e_x_img=(0,1,0), e_y_img=(0,0,1), e_z_img=(1,0,0)
# | 0 0 1 |
# | 1 0 0 |
# | 0 1 0 |
import math
# Extract Godot Euler XYZ degrees from basis
# basis as rows for Godot Basis.get_euler
bx=(0,1,0); by=(0,0,1); bz=(1,0,0)
# Godot Basis from axes: basis.x=bx etc as Vector3 columns in matrix
# m = [[bx.x, by.x, bz.x],[bx.y, by.y, bz.y],[bx.z, by.z, bz.z]]
# = [[0,0,1],[1,0,0],[0,1,0]]
# Euler XYZ extraction (Godot):
m00,m01,m02 = 0,0,1
m10,m11,m12 = 1,0,0
m20,m21,m22 = 0,1,0
# from Godot Basis.get_euler(EULER_ORDER_XYZ)
sy = m02  # sin(y) related... actually Godot:
# https://github.com/godotengine/godot/blob/master/core/math/basis.cpp
# For XYZ: 
# Y = asin(clamp(m[2].x? wait column major m[i][j] = axis_i.component_j
# In Godot Basis: elements[i][j] where elements[0] is x-axis
# get_euler XYZ:
# from basis.cpp EulerOrder::XYZ:
#  float sy = elements[0][2];  // x-axis z component = m02 in row form of columns...
# Actually elements[0] = x axis = (0,1,0) so elements[0][0]=0,[1]=1,[2]=0
# elements[1] = y = (0,0,1)
# elements[2] = z = (1,0,0)
ex = [0.0,1.0,0.0]; ey=[0.0,0.0,1.0]; ez=[1.0,0.0,0.0]
# sy = elements[0][2] = ex[2] = 0
sy = ex[2]
if abs(sy) < 0.999999:
    x = math.atan2(-ey[2], ez[2])
    y = math.asin(sy)
    z = math.atan2(-ex[1], ex[0])
else:
    x = math.atan2(ez[1], ey[1])
    y = math.copysign(math.pi/2, sy)
    z = 0
print("CARRY_EULER_XYZ_deg face_to_cam", (round(math.degrees(x),2), round(math.degrees(y),2), round(math.degrees(z),2)))
# Alt: face toward +Y (up in FOV) head -X: R e_y=(0,1,0), R (-e_z)=(-1,0,0) => R e_z=(1,0,0)
# R e_x = e_y x e_z = (0,1,0)x(1,0,0)=(0,0,-1)? 
# e_y_img=(0,1,0), e_z_img=(1,0,0), e_x_img = e_y x e_z = |i j k; 0 1 0; 1 0 0| = i(0)-j(0)+k(-1)=(0,0,-1)
ex=(0,0,-1); ey=(0,1,0); ez=(1,0,0)
sy=ex[2]  # -1
if abs(sy) < 0.999999:
    x=math.atan2(-ey[2], ez[2]); y=math.asin(max(-1,min(1,sy))); z=math.atan2(-ex[1], ex[0])
else:
    x=math.atan2(ez[1], ey[1]); y=math.copysign(math.pi/2, sy); z=0
print("CARRY_EULER_face_up_FOV", (round(math.degrees(x),2), round(math.degrees(y),2), round(math.degrees(z),2)))
# With 8 deg pitch toward camera from face-up FOV: rotate additional around X after
# For bed: face +Y world, head along -X (match prior head toward -X from old transform)
# R e_y = (0,1,0), R (-e_z)=(-1,0,0) => R e_z=(1,0,0), R e_x=(0,0,-1)  SAME as face_up_FOV above
print("BED same as face_up_FOV euler", (round(math.degrees(x),2), round(math.degrees(y),2), round(math.degrees(z),2)))
# Also check materials for stump mosaic on StumpBox meshes
for i,n in enumerate(nodes):
    if n.get("name","").startswith("StumpBox") and "mesh" in n:
        m=j["meshes"][n["mesh"]]
        for p in m["primitives"]:
            mat=j["materials"][p["material"]] if "material" in p else None
            print(n["name"], "mat", mat.get("name") if mat else None)
