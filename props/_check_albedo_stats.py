import bpy, numpy as np
img = bpy.data.images.load(r"C:\Users\hp\Documents\sabira\props\Mom_Amina_albedo_256.png", check_existing=False)
w,h = img.size
arr = np.array(img.pixels[:], np.float32).reshape(h,w,4)
rgb = arr[:,:,:3]
# sample blue-ish clothing region: find pixels with b>r and mid lum
r,g,b = rgb[:,:,0],rgb[:,:,1],rgb[:,:,2]
lum=(r+g+b)/3
tee = (lum>0.25)&(lum<0.7)&(b>=r*0.95)&((rgb.max(2)-rgb.min(2))<0.3)
skin = (lum>0.4)&(r>g)&(g>=b*0.85)
print("size",w,h)
for name,m in (("tee",tee),("skin",skin)):
    if not m.any():
        print(name,"empty"); continue
    cols=rgb[m]
    print(name,"n",m.sum(),"mean",cols.mean(0),"std",cols.std(0),"unique_approx",len(np.unique(np.round(cols,2),axis=0)))
# count high-freq local outliers (dot signature): pixel differs from 3x3 median a lot
from numpy.lib.stride_tricks import sliding_window_view
pad=np.pad(rgb,((1,1),(1,1),(0,0)),mode="edge")
# rough: compare to mean of neighbors
acc=np.zeros_like(rgb)
for dy in range(3):
  for dx in range(3):
    if dy==1 and dx==1: continue
    acc += pad[dy:dy+h, dx:dx+w]
acc/=8
diff=np.abs(rgb-acc).sum(2)
content=(arr[:,:,3]>0.1)&(lum>0.1)
outliers=((diff>0.15)&content).sum()
print("outliers_vs_neighbors",int(outliers),"of",int(content.sum()),"pct",100*outliers/max(1,content.sum()))