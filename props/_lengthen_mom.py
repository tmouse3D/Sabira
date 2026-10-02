# Mom_Amina lengthen-only pass, 2026-09-26
import bpy, os, json, struct, hashlib
from mathutils import Vector

BLEND = r'C:\Users\hp\Documents\sabira\props\Mom_Amina.blend'
GLB = r'C:\Users\hp\Documents\sabira\props\Mom_Amina.glb'
PROJ = r'C:\Users\hp\Documents\sabira'
NOTES = r'C:\Users\hp\Documents\sabira\props\_Mom_Amina_PSX_NOTES.txt'
LOG=[]
def log(s):
    print(s); LOG.append(str(s))

def bounds(block):
    pts=[v.co for v in block.data]
    mn=tuple(min(p[i] for p in pts) for i in range(3))
    mx=tuple(max(p[i] for p in pts) for i in range(3))
    return mn,mx,tuple(mx[i]-mn[i] for i in range(3))

def anim_names():
    return sorted(a.name for a in bpy.data.actions)

def glb_meta(path):
    try:
        with open(path,'rb') as f: data=f.read()
        jl=struct.unpack_from('<I',data,12)[0]
        j=json.loads(data[20:20+jl].decode('utf-8').rstrip('\x00'))
        return [a.get('name','') for a in j.get('animations',[])], [n.get('name','') for n in j.get('nodes',[])]
    except Exception as e:
        log('GLB_META_ERR '+repr(e)); return [],[]

# Loaded from the target blend by Blender command line.
body=bpy.data.objects.get('Body')
root=bpy.data.objects.get('Mom_Amina_Root')
assert body and body.type=='MESH', 'Body mesh missing'
assert root, 'Mom_Amina_Root missing'
assert body.parent == root, 'Body hierarchy changed'
assert body.data.shape_keys and body.data.shape_keys.key_blocks.get('Basis'), 'Body Basis missing'
me=body.data; sk=me.shape_keys; basis=sk.key_blocks['Basis']
assert body.name=='Body' and root.name=='Mom_Amina_Root'

# Verify length axis from Basis bounds: local Y is the dominant long axis.
before=bounds(basis)
axis_sizes=before[2]
axis=max(range(3), key=lambda i:axis_sizes[i])
log('AXIS_SIZES_LOCAL '+repr(tuple(round(x,8) for x in axis_sizes)))
assert axis==1, 'Expected local Y length axis, got %d'%axis
log('LENGTH_AXIS local Y (dominant Basis axis)')

# Capture all shape-key deltas, including look_L/look_R, before editing Basis.
deltas={}
for kb in sk.key_blocks:
    if kb.name=='Basis': continue
    deltas[kb.name]=[(kb.data[i].co-basis.data[i].co).copy() for i in range(len(basis.data))]
    log('CAPTURE_DELTA %s nonzero=%d'%(kb.name,sum(d.length>1e-8 for d in deltas[kb.name])))
assert 'look_L' in deltas and 'look_R' in deltas

# Basis-only lengthening along local Y. Width X and thickness Z are untouched.
FACTOR=1.02
for v in basis.data:
    v.co.y *= FACTOR
# Restore shape-key deltas relative to the new Basis.
for nm, ds in deltas.items():
    kb=sk.key_blocks.get(nm); assert kb
    for i,d in enumerate(ds): kb.data[i].co=basis.data[i].co+d
# Keep mesh vertex buffer synchronized with Basis without changing topology/materials.
for i,v in enumerate(me.vertices): v.co=basis.data[i].co
me.update()
after=bounds(basis)
log('BODY_BOUNDS_BEFORE_LOCAL mn=%s mx=%s size=%s'%tuple(repr(tuple(round(x,8) for x in q)) for q in before))
log('BODY_BOUNDS_AFTER_LOCAL mn=%s mx=%s size=%s'%tuple(repr(tuple(round(x,8) for x in q)) for q in after))
log('LENGTH_RATIO %.8f'%(after[2][1]/before[2][1]))
log('WIDTH_X_UNCHANGED %.8f -> %.8f'%(before[2][0],after[2][0]))
log('DEPTH_Z_UNCHANGED %.8f -> %.8f'%(before[2][2],after[2][2]))

# Mouths are parented to the protected root. Scale their local-Y placement by the same
# origin-relative factor so their existing Y=0.885 face convention remains snapped to
# the stretched face; X/Z and mesh data remain untouched.
mouth_names=['Mouth_Plea','Mouth_Scream','Mouth_Grimace']
for nm in mouth_names:
    o=bpy.data.objects.get(nm); assert o, nm+' missing'
    assert o.parent==root, nm+' parent changed'
    old=tuple(o.location)
    o.location.y *= FACTOR
    log('MOUTH %s LOC %s -> %s'%(nm,tuple(round(x,8) for x in old),tuple(round(x,8) for x in o.location)))

# Mosaic material remains in Body; because all Body vertices (including caps) were
# transformed together, material assignments/topology are unchanged.
mos_idx=None
for i,m in enumerate(me.materials):
    if m and 'Mosaic' in m.name: mos_idx=i
assert mos_idx is not None, 'Mosaic material missing'
mos_faces=[p for p in me.polygons if p.material_index==mos_idx]
log('MOSAIC_CAP_FACES %d MATERIAL_INDEX %d'%(len(mos_faces),mos_idx))
assert len(mos_faces)>0
assert not any(o.name.startswith('StumpBox_') for o in bpy.data.objects), 'StumpBox prohibited'

# Protected animation/hierarchy audit before save.
assert bpy.data.actions.get('idle_restless')
assert bpy.data.actions.get('idle_restless_body')
assert bpy.data.actions.get('idle_restless_shapekeys')
assert body.animation_data and body.animation_data.action and body.animation_data.action.name=='idle_restless_body'
assert root.animation_data and root.animation_data.action and root.animation_data.action.name=='idle_restless'
assert sk.animation_data and sk.animation_data.action and sk.animation_data.action.name=='idle_restless_shapekeys'
log('ANIMS_OK idle_restless + idle_restless_body + idle_restless_shapekeys')
log('HIERARCHY_OK root=%s body_parent=%s mouths_parent=%s'%(root.name,body.parent.name,','.join(bpy.data.objects[n].parent.name for n in mouth_names)))

# Save the edited blend first.
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
log('SAVED_BLEND '+BLEND)

# Export the protected Mom node set; no Mom_Restraint is opened or selected.
bpy.ops.object.select_all(action='DESELECT')
keep={'Body','Mom_Amina_Root'}|set(mouth_names)
for o in bpy.data.objects:
    if o.name in keep:
        o.hide_set(False); o.hide_render=False; o.select_set(True)
bpy.context.view_layer.objects.active=root
try:
    bpy.ops.export_scene.gltf(filepath=GLB,use_selection=True,export_format='GLB',export_animations=True,export_animation_mode='ACTIONS',export_apply=False,export_image_format='AUTO',export_morph=True,export_morph_animation=True)
except TypeError:
    bpy.ops.export_scene.gltf(filepath=GLB,use_selection=True,export_format='GLB',export_animations=True,export_apply=False,export_image_format='AUTO',export_morph=True,export_morph_animation=True)
assert os.path.isfile(GLB) and os.path.getsize(GLB)>0
anims,nodes=glb_meta(GLB)
log('EXPORTED_GLB size=%d'%os.path.getsize(GLB))
log('GLB_ANIMS '+repr(anims))
log('GLB_NODES '+repr(nodes))
assert 'Body' in nodes and 'Mom_Amina_Root' in nodes
assert not any(n.startswith('StumpBox_') for n in nodes)

# Clear Godot's imported Mom_Amina cache entries only.
imp=os.path.join(PROJ,'.godot','imported'); cleared=[]
if os.path.isdir(imp):
    for fn in os.listdir(imp):
        if 'mom_amina' in fn.lower():
            fp=os.path.join(imp,fn)
            if os.path.isfile(fp):
                try: os.remove(fp); cleared.append(fn)
                except Exception as e: log('CLEAR_FAIL '+fn+' '+repr(e))
log('CLEARED_IMPORTS %d'%len(cleared))

# Append requested note, preserving existing notes.
with open(NOTES,'a',encoding='utf-8') as f:
    f.write('\nLENGTHEN +2% 2026-09-26: Body Basis scaled 1.02 along local Y (head-to-feet); look_L/look_R deltas restored; mouths Y placement scaled with face; mosaic caps preserved; thin/exhaust width and Z unchanged.\n')
log('NOTED LENGTHEN +2% 2026-09-26')
print('RESULT_OK')
