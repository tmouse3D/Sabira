import bpy, json, statistics
from mathutils import Vector

bpy.ops.wm.open_mainfile(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend")
body = bpy.data.objects["Body"]
bb = [body.matrix_world @ Vector(c) for c in body.bound_box]
xs,ys,zs = zip(*[(v.x,v.y,v.z) for v in bb])
print("BODY", dict(xmin=round(min(xs),4),xmax=round(max(xs),4),ymin=round(min(ys),4),ymax=round(max(ys),4),zmin=round(min(zs),4),zmax=round(max(zs),4)))

zs_neck=[]
for p in body.data.polygons:
    c = body.matrix_world @ p.center
    if 0.65<=c.y<=0.76 and abs(c.x)<0.18:
        zs_neck.append(round(c.z,4))
print("neck Z", min(zs_neck), max(zs_neck), "n", len(zs_neck), "sorted", sorted(zs_neck)[:8], "...", sorted(zs_neck)[-8:])

# Load albedo via bpy
img = bpy.data.images.load(r"C:\Users\hp\Documents\sabira\props\Mom_Amina_albedo_256.png", check_existing=True)
w,h = img.size[0], img.size[1]
pixels = list(img.pixels)  # RGBA float 0-1, bottom-left origin
print("img", w, h, "pixlen", len(pixels))

def sample(u,v):
    # Blender UV: v=0 bottom. Image pixels also bottom-left.
    x = min(w-1, max(0, int(u * w)))
    y = min(h-1, max(0, int(v * h)))
    i = (y * w + x) * 4
    return (pixels[i]*255, pixels[i+1]*255, pixels[i+2]*255)

uv = body.data.uv_layers.active
mosaic=[]
for p in body.data.polygons:
    uvs=[uv.data[li].uv for li in p.loop_indices]
    samples=[sample(u.x, u.y) for u in uvs]
    uc=sum(u.x for u in uvs)/len(uvs); vc=sum(u.y for u in uvs)/len(uvs)
    samples.append(sample(uc,vc))
    rs=[s[0] for s in samples]; gs=[s[1] for s in samples]; bs=[s[2] for s in samples]
    var=statistics.pstdev(rs)+statistics.pstdev(gs)+statistics.pstdev(bs) if len(samples)>1 else 0
    mean_b=sum(bs)/len(bs); mean_g=sum(gs)/len(gs); mean_r=sum(rs)/len(rs)
    blueish = mean_b > mean_r + 20 and mean_b > 90
    # also detect "busy atlas" - high variance with mixed colors
    highvar = var > 40
    if blueish or highvar:
        c = body.matrix_world @ p.center
        mat=body.material_slots[p.material_index].material
        mosaic.append({"i":p.index,"c":[round(c.x,3),round(c.y,3),round(c.z,3)],"uv":[round(uc,3),round(vc,3)],
                       "var":round(var,1),"rgb":[int(mean_r),int(mean_g),int(mean_b)],
                       "mat": mat.name if mat else "?", "a":round(p.area,4)})
print("MOSAIC cand", len(mosaic))
for m in sorted(mosaic, key=lambda x: -x["var"])[:50]:
    print(m)

# Also dump ALL faces with body mat near stump tips (arms/legs ends)
tips=[]
for p in body.data.polygons:
    c = body.matrix_world @ p.center
    mat=body.material_slots[p.material_index].material
    mn=mat.name if mat else "?"
    # arm stumps: |x|>0.28, y in 0.25..0.60
    # leg stumps: y < -0.45 or y around feet cut
    arm = abs(c.x)>0.27 and 0.2<c.y<0.65
    leg = c.y < -0.45
    hip_side = abs(c.x)>0.18 and -0.35<c.y<0.15 and mn=="Mom_Body_Mat"
    if (arm or leg or hip_side) and mn=="Mom_Body_Mat":
        uvs=[uv.data[li].uv for li in p.loop_indices]
        uc=sum(u.x for u in uvs)/len(uvs); vc=sum(u.y for u in uvs)/len(uvs)
        rgb=sample(uc,vc)
        tips.append({"i":p.index,"c":[round(c.x,3),round(c.y,3),round(c.z,3)],"uv":[round(uc,3),round(vc,3)],"rgb":[int(rgb[0]),int(rgb[1]),int(rgb[2])],"a":round(p.area,4),"tag":"arm" if arm else ("leg" if leg else "hip")})
print("BODY tip/hip still Body mat", len(tips))
for t in tips:
    print(t)
