import bpy
print('ANIM_DATA')
for o in bpy.data.objects:
 ad=o.animation_data
 if ad:
  act=ad.action
  print('ANIM_OBJ',o.name,'ACTION',act.name if act else None,'NLA',len(ad.nla_tracks))
  if act:
   print(' ACTION_TYPE',type(act).__name__,'SLOTS',getattr(act,'slots',None),'SLOT',getattr(ad,'action_slot',None))
   print(' ACTION_DIR',[x for x in dir(act) if 'layer' in x.lower() or 'curve' in x.lower() or 'slot' in x.lower()])
   print(' ACTION_FCURVE',getattr(act,'fcurves',None))
print('ACTIONS',len(bpy.data.actions))
for a in bpy.data.actions:
 print('ACT',a.name,'FRAME',tuple(round(x,2) for x in a.frame_range),'SLOTS',len(getattr(a,'slots',[])),'USERS',a.users)
 print(' DIR',[x for x in dir(a) if 'layer' in x.lower() or 'curve' in x.lower() or 'slot' in x.lower()])
print('SHAPE_ANIM')
for o in bpy.data.objects:
 if o.type=='MESH' and o.data.shape_keys:
  sk=o.data.shape_keys
  print('SK',o.name,'ANIM',bool(sk.animation_data),'ACT',sk.animation_data.action.name if sk.animation_data and sk.animation_data.action else None)
