"""Nuclear albedo solid-fill (kill ALL grid dots) + tip-cap bandage force."""
import bpy, bmesh, math, os, shutil
import numpy as np
from collections import Counter, deque
from datetime import datetime
from mathutils import Vector

OUT = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
TEX = os.path.join(OUT, "Mom_Amina_albedo_256.png")
TEX_STUMP = os.path.join(OUT, "Mom_Amina_stump_bandage_64.png")
TEX_STUMP2 = os.path.join(OUT, "Mom_Amina_stump_injury_64.png")
BACKUPS = r"C:\Users\hp\Documents\sabira\backups"
IMPORTED = r"C:\Users\hp\Documents\sabira\.godot\imported"
PREVIEW = os.path.join(OUT, "_Mom_Amina_preview.png")
PREVIEW_LOCK = os.path.join(OUT, "_Mom_Amina_preview_lock_close.png")
PREVIEW_STUMP = os.path.join(OUT, "_Mom_Amina_preview_stump_close.png")
PREVIEW_UNLOCKED = os.path.join(OUT, "_Mom_Amina_preview_unlocked.png")
NOTES = os.path.join(OUT, "_Mom_Amina_PSX_NOTES.txt")

BANDAGE = np.array([0.831, 0.804, 0.749], np.float32)
TEE = np.array([0.38, 0.46, 0.54], np.float32)
SKIN = np.array([0.80, 0.64, 0.52], np.float32)


def bak(p):
    if os.path.isfile(p):
        os.makedirs(BACKUPS, exist_ok=True)
        shutil.copy2(p, os.path.join(BACKUPS, os.path.basename(p)+".bak_nuclear_"+datetime.now().strftime("%Y%m%d_%H%M%S")))


def connected_components(mask):
    h, w = mask.shape
    labels = np.full((h, w), -1, np.int32)
    comps = []
    lid = 0
    for y in range(h):
        for x in range(w):
            if not mask[y, x] or labels[y, x] >= 0:
                continue
            q = deque([(y, x)])
            labels[y, x] = lid
            cells = [(y, x)]
            while q:
                cy, cx = q.popleft()
                for dy, dx in ((0,1),(0,-1),(1,0),(-1,0)):
                    ny, nx = cy+dy, cx+dx
                    if 0<=ny<h and 0<=nx<w and mask[ny,nx] and labels[ny,nx]<0:
                        labels[ny,nx]=lid; q.append((ny,nx)); cells.append((ny,nx))
            comps.append(cells); lid += 1
    return labels, comps


def nuclear_albedo():
    img = bpy.data.images.load(TEX, check_existing=False)
    w, h = img.size
    arr = np.array(img.pixels[:], np.float32).reshape(h, w, 4)
    rgb = arr[:,:,:3]
    a = arr[:,:,3]
    content = (a > 0.15) & (rgb.sum(2) > 0.08)
    labels, comps = connected_components(content)
    print("ISLANDS", len(comps))
    out = rgb.copy()
    rng = np.random.RandomState(42)
    for cells in comps:
        if len(cells) < 4:
            continue
        ys = np.array([c[0] for c in cells]); xs = np.array([c[1] for c in cells])
        cols = rgb[ys, xs]
        # median color of island
        med = np.median(cols, axis=0)
        lum = float(med.mean()); sat = float(med.max()-med.min())
        # classify and force flat PSX palette
        if lum < 0.22:
            base = med  # keep dark hair/eyes median (already dark)
        elif med[0] > med[1]*1.2 and med[0] > med[2]*1.2 and lum < 0.6:
            base = med  # lips
        elif lum > 0.25 and lum < 0.75 and sat < 0.25 and med[2] >= med[0]*0.9:
            base = TEE
        elif lum > 0.12 and med[2] > med[0]+0.04 and med[2] > med[1]:
            base = np.array([0.18, 0.26, 0.42], np.float32)  # shorts
        elif lum > 0.35 and med[0] >= med[1] >= med[2]*0.85:
            base = SKIN
        elif lum > 0.7 and sat < 0.15:
            base = BANDAGE  # light bandage-ish islands
        else:
            base = med
        # solid fill + tiny noise (no grid)
        noise = (rng.rand(len(cells)).astype(np.float32) - 0.5) * 0.018
        for i, (y, x) in enumerate(cells):
            out[y, x] = np.clip(base + noise[i], 0, 1)

    # paint dedicated bandage patches into unused black corners for UV tips if needed
    # (stump mat uses separate tex; also stamp solid bandage into a safe atlas corner)
    out[0:48, 0:48] = BANDAGE
    # light noise
    n = (rng.rand(48,48).astype(np.float32)-0.5)*0.02
    for c in range(3):
        out[0:48,0:48,c] = np.clip(out[0:48,0:48,c] + n, 0, 1)

    arr[:,:,:3] = out
    img.pixels = arr.ravel().tolist()
    img.filepath_raw = TEX; img.file_format="PNG"; img.save()
    print("NUCLEAR_SAVED", TEX)
    bpy.data.images.remove(img)


def write_bandage():
    img = bpy.data.images.new("B", 64, 64, alpha=True)
    px=[]
    for y in range(64):
        for x in range(64):
            d = 0.02*math.sin(y*0.45) + (((x*13+y*7)%19)/19-0.5)*0.015
            px += [max(0,min(1,BANDAGE[0]+d)), max(0,min(1,BANDAGE[1]+d*0.9)), max(0,min(1,BANDAGE[2]+d*0.7)), 1]
    img.pixels=px
    for p in (TEX_STUMP, TEX_STUMP2):
        img.filepath_raw=p; img.file_format="PNG"; img.save()


def retag_tips(body):
    mesh = body.data
    coords=[v.co.copy() for v in mesh.vertices]
    xmin,xmax=min(c.x for c in coords),max(c.x for c in coords)
    ymin,ymax=min(c.y for c in coords),max(c.y for c in coords)
    # reset then mark
    for p in mesh.polygons: p.material_index=0
    stump=[]
    WRAP=0.05
    for p in mesh.polygons:
        c=Vector(p.center); n=p.normal
        arm=(ymin+0.08)<c.y<(ymax-0.14)
        # ANY face near extreme limb end
        if arm and (c.x < xmin+0.14 or c.x > xmax-0.14) and p.area<0.06:
            # prefer tip-ish or wrap
            if abs(n.x)>0.3 or c.x<xmin+0.08 or c.x>xmax-0.08 or c.x<xmin+WRAP+0.12 or c.x>xmax-WRAP-0.12:
                stump.append(p.index)
        if c.y < ymin+0.16 and p.area<0.06 and abs(c.x)>0.03:
            stump.append(p.index)
    stump=list(set(stump))
    for i in stump: mesh.polygons[i].material_index=1

    # UV all stump -> solid bandage tex center OR albedo bandage corner (0-48)
    # stump mat uses separate bandage tex, so UV into 0.2-0.8 of that tex
    bm=bmesh.new(); bm.from_mesh(mesh)
    uv=bm.loops.layers.uv.active or bm.loops.layers.uv.new("UVMap")
    bm.faces.ensure_lookup_table()
    for f in bm.faces:
        if f.material_index!=1: continue
        n=f.normal
        if abs(n.x)>=abs(n.y) and abs(n.x)>=abs(n.z): ax,ay=1,2
        elif abs(n.y)>=abs(n.z): ax,ay=0,2
        else: ax,ay=0,1
        comps=[(l.vert.co[ax], l.vert.co[ay]) for l in f.loops]
        minx,maxx=min(v[0] for v in comps),max(v[0] for v in comps)
        miny,maxy=min(v[1] for v in comps),max(v[1] for v in comps)
        sx,sy=max(1e-6,maxx-minx),max(1e-6,maxy-miny)
        for l in f.loops:
            u=(l.vert.co[ax]-minx)/sx; v=(l.vert.co[ay]-miny)/sy
            l[uv].uv=(0.25+u*0.5, 0.25+v*0.5)
    bm.to_mesh(mesh); bm.free(); mesh.update()

    # ALSO paint body albedo UV of stump+near to solid bandage (soft) so any leftover mat0 looks wrapped
    paint_albedo_stump(body, stump)
    print("STUMP", len(stump), dict(Counter(p.material_index for p in mesh.polygons)))
    return len(stump)


def paint_albedo_stump(body, stump):
    mesh=body.data
    img=bpy.data.images.load(TEX, check_existing=False)
    w,h=img.size
    px=np.array(img.pixels[:],np.float32).reshape(h,w,4)
    uv=mesh.uv_layers.active
    coords=[v.co for v in mesh.vertices]
    xmin,xmax=min(c.x for c in coords),max(c.x for c in coords)
    ymin=min(c.y for c in coords)
    paint=set(stump)
    for p in mesh.polygons:
        c=Vector(p.center)
        if (c.x<xmin+0.18 or c.x>xmax-0.18) and (ymin+0.08)<c.y<(max(cc.y for cc in coords)-0.14):
            paint.add(p.index)
        if c.y<ymin+0.20: paint.add(p.index)
    for pi in paint:
        p=mesh.polygons[pi]
        s0=1.0 if p.material_index==1 else 0.85
        for li in p.loop_indices:
            u,v=uv.data[li].uv
            cx,cy=int(u*w)%w, int(v*h)%h
            for dy in range(-5,6):
                for dx in range(-5,6):
                    x=(cx+dx)%w; y=(cy+dy)%h
                    if px[y,x,0]+px[y,x,1]+px[y,x,2]<0.12: continue
                    s=s0*(1.0-0.1*(abs(dx)+abs(dy))/5)
                    px[y,x,:3]=(1-s)*px[y,x,:3]+s*BANDAGE
    img.pixels=px.ravel().tolist()
    img.filepath_raw=TEX; img.file_format="PNG"; img.save()
    print("PAINT_OK")
    bpy.data.images.remove(img)


def fix_mats(body):
    # stump mat solid
    name="Mom_Stump_Mat"
    old=bpy.data.materials.get(name)
    if old: bpy.data.materials.remove(old)
    mat=bpy.data.materials.new(name); mat.use_nodes=True
    nt=mat.node_tree; nt.nodes.clear()
    out=nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf=nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value=(*BANDAGE.tolist(),1)
    bsdf.inputs["Roughness"].default_value=0.95
    if "Metallic" in bsdf.inputs: bsdf.inputs["Metallic"].default_value=0.0
    tex=nt.nodes.new("ShaderNodeTexImage")
    tex.image=bpy.data.images.load(TEX_STUMP, check_existing=True)
    tex.interpolation="Closest"; tex.extension="EXTEND"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    mat.diffuse_color=(*BANDAGE.tolist(),1)
    while len(body.data.materials)<2: body.data.materials.append(None)
    body.data.materials[1]=mat
    for m in body.data.materials:
        if not m or not m.use_nodes: continue
        for n in m.node_tree.nodes:
            if n.type=="TEX_IMAGE":
                n.extension="EXTEND"; n.interpolation="Closest"
                if n.image and "albedo" in (n.image.name+n.image.filepath).lower():
                    n.image.filepath=TEX; n.image.reload()


def render():
    scene=bpy.context.scene
    scene.render.engine="BLENDER_EEVEE"
    scene.render.resolution_x=768; scene.render.resolution_y=768
    cam=bpy.data.objects.get("P"); scene.camera=cam
    lock=bpy.data.objects["LockRect"]
    rest=lock.location.copy()
    # rim light from back so lock reads in Blender too
    for o in list(bpy.data.objects):
        if o.type=="LIGHT": bpy.data.objects.remove(o, do_unlink=True)
    for nm,loc,e in (("K",(0.8,-0.5,1.2),70),("R",(0.2,0.7,-1.0),90)):
        ld=bpy.data.lights.new(nm,"AREA"); ld.energy=e; ld.size=2
        lo=bpy.data.objects.new(nm,ld); bpy.context.scene.collection.objects.link(lo); lo.location=loc
    shots=[
        (PREVIEW,(1.5,-0.9,0.4),(0.0,0.25,0.05)),
        (PREVIEW_LOCK,(0.45,0.55,-0.7),(0.2,0.70,-0.02)),
        (PREVIEW_STUMP,(0.9,0.05,0.3),(0.30,0.02,0.12)),
    ]
    for path,loc,look in shots:
        cam.location=loc
        cam.rotation_euler=(Vector(look)-Vector(loc)).to_track_quat("-Z","Y").to_euler()
        scene.render.filepath=path; bpy.ops.render.render(write_still=True); print("preview",path)
    lock.location=Vector(rest)+Vector((0,0,-0.2))
    scene.render.filepath=PREVIEW_UNLOCKED; bpy.ops.render.render(write_still=True)
    lock.location=rest


def export():
    for nm in ("LockRect","NeckBar","Body"):
        o=bpy.data.objects.get(nm)
        if o and o.type=="MESH": o.data.name=nm
    bpy.ops.object.select_all(action="DESELECT")
    root=bpy.data.objects.get("Mom_Amina_Root")
    for nm in ("Body","NeckBar","LockRect","Mom_Amina_Root"):
        o=bpy.data.objects.get(nm)
        if o: o.select_set(True)
    if root: bpy.context.view_layer.objects.active=root
    kwargs=dict(filepath=GLB,use_selection=True,export_format="GLB",export_animations=True,export_apply=False,export_image_format="AUTO")
    try: bpy.ops.export_scene.gltf(export_animation_mode="ACTIONS",**kwargs)
    except TypeError: bpy.ops.export_scene.gltf(**kwargs)
    print("glb",os.path.getsize(GLB))


def clear():
    n=0
    if os.path.isdir(IMPORTED):
        for fn in os.listdir(IMPORTED):
            if "Mom_Amina" in fn or "mom_amina" in fn.lower():
                try: os.remove(os.path.join(IMPORTED,fn)); n+=1
                except OSError: pass
    print("CLEARED",n)


def main():
    bak(TEX); bak(BLEND); bak(GLB)
    write_bandage()
    nuclear_albedo()
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    body=bpy.data.objects["Body"]
    fix_mats(body)
    n=retag_tips(body)
    fix_mats(body)
    render()
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    export(); clear()
    with open(NOTES,"a",encoding="utf-8") as f:
        f.write(f"\nNUCLEAR ALBEDO 2026-09-25 10:08 BST: per-island solid PSX fill (grid dots removed); stump faces={n}; re-export.\n")
    print("DONE",n)


if __name__=="__main__":
    main()