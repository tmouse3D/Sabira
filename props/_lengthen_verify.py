import bpy, os, json, struct, hashlib
from mathutils import Vector
print('FILE',bpy.data.filepath)
b=bpy.data.objects['Body']; r=bpy.data.objects['Mom_Amina_Root']; sk=b.data.shape_keys; base=sk.key_blocks['Basis']
pts=[v.co for v in base.data]
mn=tuple(min(p[i] for p in pts) for i in range(3)); mx=tuple(max(p[i] for p in pts) for i in range(3)); size=tuple(mx[i]-mn[i] for i in range(3))
print('FINAL_BOUNDS',tuple(round(x,8) for x in mn),tuple(round(x,8) for x in mx),tuple(round(x,8) for x in size))
print('SHAPES',[(k.name,k.value) for k in sk.key_blocks])
print('DELTA_COUNTS',[(k.name,sum((k.data[i].co-base.data[i].co).length>1e-8 for i in range(len(base.data)))) for k in sk.key_blocks if k.name!='Basis'])
print('MESH_SYNC',all((b.data.vertices[i].co-base.data[i].co).length<1e-8 for i in range(len(base.data))))
print('HIER',r.name,b.parent.name,[(n,bpy.data.objects[n].parent.name,tuple(round(x,8) for x in bpy.data.objects[n].location)) for n in ['Mouth_Plea','Mouth_Scream','Mouth_Grimace']])
print('ACTIONS',sorted(a.name for a in bpy.data.actions))
print('ACTIVE',b.animation_data.action.name,r.animation_data.action.name,sk.animation_data.action.name)
print('STUMPBOX',[o.name for o in bpy.data.objects if o.name.startswith('StumpBox_')])
print('MOSAIC_FACES',sum(p.material_index==2 for p in b.data.polygons))
print('RESTRAINT_SHA',hashlib.sha256(open(r'C:\Users\hp\Documents\sabira\props\Mom_Restraint.glb','rb').read()).hexdigest())
# GLB JSON
p=r'C:\Users\hp\Documents\sabira\props\Mom_Amina.glb'; d=open(p,'rb').read(); jl=struct.unpack_from('<I',d,12)[0]; j=json.loads(d[20:20+jl].decode('utf8').rstrip('\0'))
print('GLB_SIZE',len(d)); print('GLB_ANIMS',[a.get('name') for a in j.get('animations',[])]); print('GLB_NODES',[n.get('name') for n in j.get('nodes',[])])
