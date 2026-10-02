import bpy
print('FILE',bpy.data.filepath)
print('ALL_OBJECTS')
for o in bpy.data.objects:
 print('OBJ',o.name,'TYPE',o.type,'PARENT',o.parent.name if o.parent else None,'HIDDEN',o.hide_viewport,o.hide_render)
 if o.type=='MESH':
  me=o.data
  basis=me.shape_keys.key_blocks.get('Basis') if me.shape_keys else None
  co=[v.co for v in (basis.data if basis else me.vertices)]
  if co:
   mn=[min(v[i] for v in co) for i in range(3)]; mx=[max(v[i] for v in co) for i in range(3)]
   print('  BOUNDS',tuple(round(x,8) for x in mn),tuple(round(x,8) for x in mx),'SIZE',tuple(round(mx[i]-mn[i],8) for i in range(3)))
  if me.shape_keys: print('  SHAPES',[(k.name,round(k.value,3),k.mute) for k in me.shape_keys.key_blocks])
  print('  MATS',[(i,m.name if m else None) for i,m in enumerate(me.materials)])
  # face bounds per material index
  for mi in range(len(me.materials)):
   ys=[]; xs=[]; zs=[]; counts=0
   for poly in me.polygons:
    if poly.material_index==mi:
     counts+=1
     for vi in poly.vertices:
      vv=(basis.data[vi].co if basis else me.vertices[vi].co); xs.append(vv.x);ys.append(vv.y);zs.append(vv.z)
   if counts: print('  MAT_BOUNDS',mi,me.materials[mi].name if me.materials[mi] else None,'FACES',counts,'X',round(min(xs),8),round(max(xs),8),'Y',round(min(ys),8),round(max(ys),8),'Z',round(min(zs),8),round(max(zs),8))
print('ANIM_DATA')
for o in bpy.data.objects:
 ad=o.animation_data
 if ad:
  print('ANIM_OBJ',o.name,'ACTION',ad.action.name if ad.action else None,'SLOTS',len(ad.action_slots) if ad.action else None,'NLA',len(ad.nla_tracks))
print('ACTIONS')
for a in bpy.data.actions:
 print('ACT',a.name,'SLOTS',len(a.slots),'FRAME',tuple(round(x,2) for x in a.frame_range))
print('NOTES')
for o in bpy.data.objects:
 for k,v in o.items():
  if k not in {'_RNA_UI'}: print('PROP',o.name,k,repr(v))
