import struct, json, math
def load(path):
    with open(path,"rb") as f: data=f.read()
    jlen=struct.unpack_from("<I",data,12)[0]
    return json.loads(data[20:20+jlen].decode().rstrip("\x00"))
mom=load(r"C:\Users\hp\Documents\sabira\props\Mom_Amina.glb")
res=load(r"C:\Users\hp\Documents\sabira\props\Mom_Restraint.glb")
print("RESTRAINT nodes:")
for i,n in enumerate(res.get("nodes",[])):
    print(i, n.get("name"), "t", n.get("translation"), "children", n.get("children"))
print("RESTRAINT scenes", res.get("scenes"))
# Mouth / approx neck from mom
for nm in ["Mouth_Plea","Body"]:
    n=next(x for x in mom["nodes"] if x.get("name")==nm)
    print("MOM", nm, "t", n.get("translation"))
# Body bbox center/neck estimate: high -Z end is head; neck slightly below mouth
mouth=next(x for x in mom["nodes"] if x.get("name")=="Mouth_Plea")["translation"]
print("mouth gltf", mouth)
# Apply current House transforms and compare world positions
# Godot Transform3D(xx, yx, zx, xy, yy, zy, xz, yz, zz, ox, oy, oz) means basis columns?
# From Godot docs source serialization:
# The format is: basis.xx, basis.xy, basis.xz? 
# Actually in ResourceFormat: Transform3D written as 12 floats:
# Looking at Godot scene format documentation:
# Transform3D(xAxis.x, yAxis.x, zAxis.x, xAxis.y, yAxis.y, zAxis.y, xAxis.z, yAxis.z, zAxis.z, origin.x, origin.y, origin.z)
# So first 3 = x components of the three axes (row of matrix with columns = axes)

def xform(basis_vals, origin, p):
    # basis_vals = (Xx,Yx,Zx, Xy,Yy,Zy, Xz,Yz,Zz)
    Xx,Yx,Zx,Xy,Yy,Zy,Xz,Yz,Zz = basis_vals
    # columns are axes: X_axis=(Xx,Xy,Xz), etc.
    x = Xx*p[0] + Yx*p[1] + Zx*p[2] + origin[0]
    y = Xy*p[0] + Yy*p[1] + Zy*p[2] + origin[1]
    z = Xz*p[0] + Yz*p[1] + Zz*p[2] + origin[2]
    return (x,y,z)

mom_b = (-4.3711385e-08, -0.99999994, 0, 0.99999994, -4.3711385e-08, 0, 0, 0, 0.9499165)
mom_o = (-0.8499999, 0.7746154, 0.099999905)
# Root override approx identity + offset
root_o = (-0.21135968, -0.13259506, 0.12507367)
# mouth in root space then root offset then mom
# Root transform ~ I + root_o, mouths parented to root
mw = xform(mom_b, mom_o, (mouth[0]+root_o[0], mouth[1]+root_o[1], mouth[2]+root_o[2]))
print("mouth WORLD current (with root offset)", tuple(round(v,4) for v in mw))
mw2 = xform(mom_b, mom_o, mouth)
print("mouth WORLD without root offset", tuple(round(v,4) for v in mw2))

res_b = (-1, 8.742278e-08, 0, -8.742278e-08, -1, 0, 0, 0, 0.94991654)
res_o = (-0.8499999, 0.7746154, 0.099999905)
# find LockRect / NeckPlate in restraint
for n in res["nodes"]:
    if n.get("name") in ("LockRect","NeckPlate_Top","NeckPlate_L","Mom_Restraint_Root","NeckBar"):
        t=n.get("translation") or [0,0,0]
        print("RES", n["name"], "local", t, "world", tuple(round(v,4) for v in xform(res_b, res_o, t)))

# Propose face-up bed: Y-up face, head -Z along room -Z
# euler (0,-90,0): axes ex=(0,0,-1), ey=(0,1,0), ez=(1,0,0) from earlier
# Wait face_up_FOV had head along -X not -Z.
# For identity: face +Y, head -Z - good face-up along Z bed
# Keep same origin first
id_b = (1,0,0, 0,1,0, 0,0,0.95)
print("mouth WORLD identity*0.95z", tuple(round(v,4) for v in xform(id_b, mom_o, mouth)))
# With (0,-90,0): X_axis=(0,0,-1)? 
# R_y(-90): x' = x*c - z*s with c=0,s=-1 -> x'=z, z'=-x, y'=y
# Maps e_x->(0,0,-1)? R*(1,0,0)=(0,0,-1); R*(0,1,0)=(0,1,0); R*(0,0,1)=(1,0,0)
# axes: X=(0,0,-1), Y=(0,1,0), Z=(1,0,0)
# Serialized: Xx,Yx,Zx, Xy,Yy,Zy, Xz,Yz,Zz = 0,0,1,  0,1,0,  -1,0,0
b90 = (0, 0, 1,  0, 1, 0,  -1, 0, 0)
# with z scale 0.95 on Z axis: Z*=0.95 -> (0,0,0.95, 0,1,0, -1,0,0)
b90s = (0, 0, 0.95,  0, 1, 0,  -1, 0, 0)
print("mouth WORLD Ry-90", tuple(round(v,4) for v in xform(b90s, mom_o, mouth)))
# Current mom maps: X=(0,1,0), Y=(-1,0,0), Z=(0,0,0.95)
print("body bbox world current:")
for corner in [(-0.025,0.071,-0.889),(0.234,0.464,0.239),(-0.025,0.071,0.239),(0.234,0.464,-0.889)]:
    print(" ", tuple(round(v,3) for v in xform(mom_b, mom_o, corner)))
print("body bbox world identity:")
for corner in [(-0.025,0.071,-0.889),(0.234,0.464,0.239)]:
    print(" ", tuple(round(v,3) for v in xform(id_b, mom_o, corner)))
print("body bbox world Ry-90:")
for corner in [(-0.025,0.071,-0.889),(0.234,0.464,0.239)]:
    print(" ", tuple(round(v,3) for v in xform(b90s, mom_o, corner)))
# Back of body y_min~0.07 should sit near mattress. Mattress height ~ mom origin y - something
# With identity, back at y = 0.775+0.07=0.845; face top 0.775+0.464=1.24
# With CURRENT: local Y -> -X, so thickness goes horizontal; local X -> +Y so width is vertical - she's ON HER SIDE
print("CONFIRMED: current transform puts thickness on world X (side-lying), width on Y")
# Bed node
