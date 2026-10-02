import bpy
b=bpy.data.objects['Body']
print('VG',[(g.name,g.index) for g in b.vertex_groups])
me=b.data; sk=me.shape_keys; base=sk.key_blocks['Basis']
for nm in ['mixamorig:Head','Head','head']:
 gi=b.vertex_groups.get(nm)
 if not gi: continue
 pts=[]
 for i in range(len(base.data)):
  try:
   w=gi.weight(i)
  except: w=0
  if w>=0.35: pts.append(base.data[i].co.copy())
 print(nm,'N',len(pts),'BOUNDS', (min(p.y for p in pts),max(p.y for p in pts),min(p.z for p in pts),max(p.z for p in pts)) if pts else None,'NOSE',max(pts,key=lambda p:p.z) if pts else None)
# high y face body polys/vertices by z
pts=[v.co.copy() for v in base.data if v.co.y>0.72]
print('HIGHY',len(pts),'BOUNDS',min(p.y for p in pts),max(p.y for p in pts),min(p.z for p in pts),max(p.z for p in pts))
for p in sorted(pts,key=lambda p:p.z,reverse=True)[:20]: print('P',tuple(round(q,6) for q in p))
