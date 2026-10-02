import bpy, json, math
from mathutils import Vector
p=bpy.data.filepath
print('FILE',p)
print('SCENE',bpy.context.scene.name)
print('OBJECTS')
for o in bpy.data.objects:
    if any(s in o.name for s in ['Mom','Body','Mouth','Stump','Restraint','Root']) or o.type in {'ARMATURE'}:
        print('OBJ',o.name,'TYPE',o.type,'PARENT',o.parent.name if o.parent else None,'DATA',o.data.name if getattr(o,'data',None) else None,'LOC',tuple(round(x,6) for x in o.location),'SCALE',tuple(round(x,6) for x in o.scale),'ROT',tuple(round(x,6) for x in o.rotation_euler))
        if o.type=='MESH':
            me=o.data
            print('  VERTS',len(me.vertices),'POLYS',len(me.polygons),'MAT',[(i,m.name if m else None) for i,m in enumerate(me.materials)])
            if me.shape_keys:
                print('  SHAPES',[(k.name,k.value,k.mute) for k in me.shape_keys.key_blocks])
                basis=me.shape_keys.key_blocks.get('Basis')
                if basis:
                    co=[v.co for v in basis.data]
                    mn=[min(v[i] for v in co) for i in range(3)]; mx=[max(v[i] for v in co) for i in range(3)]
                    print('  BASIS_BOUNDS_LOCAL',tuple(round(x,8) for x in mn),tuple(round(x,8) for x in mx),'SIZE',tuple(round(mx[i]-mn[i],8) for i in range(3)))
                    # world bounds from basis points
                    wc=[o.matrix_world@v.co for v in basis.data]
                    wmn=[min(v[i] for v in wc) for i in range(3)]; wmx=[max(v[i] for v in wc) for i in range(3)]
                    print('  BASIS_BOUNDS_WORLD',tuple(round(x,8) for x in wmn),tuple(round(x,8) for x in wmx),'SIZE',tuple(round(wmx[i]-wmn[i],8) for i in range(3)))
            else:
                co=[v.co for v in me.vertices]
                if co:
                    mn=[min(v[i] for v in co) for i in range(3)]; mx=[max(v[i] for v in co) for i in range(3)]
                    print('  MESH_BOUNDS_LOCAL',tuple(round(x,8) for x in mn),tuple(round(x,8) for x in mx),'SIZE',tuple(round(mx[i]-mn[i],8) for i in range(3)))
        if o.type=='ARMATURE':
            print('  BONES',[(b.name,b.parent.name if b.parent else None,tuple(round(x,5) for x in b.head_local),tuple(round(x,5) for x in b.tail_local)) for b in o.data.bones])
print('ACTIONS')
for a in bpy.data.actions:
 print('ACT',a.name,'FCURVES',len(a.fcurves),'FRAMES',tuple(round(x,2) for x in a.frame_range))
print('COLLECTIONS')
for c in bpy.data.collections:
 print('COL',c.name,'OBJS',[o.name for o in c.objects])
