from PIL import Image
import collections
img = Image.open(r"C:\Users\hp\Documents\sabira\props\Mom_Amina_albedo_256.png").convert("RGB")
w,h = img.size
print("albedo size", w,h)
# Sample regions - look for blue/white mosaic-like high variance tiles
pix = img.load()
# find high local variance patches
import statistics
hotspots = []
step = 8
for y in range(0,h-step,step):
    for x in range(0,w-step,step):
        cols = [pix[x+i,y+j] for i in range(step) for j in range(step)]
        rs=[c[0] for c in cols]; gs=[c[1] for c in cols]; bs=[c[2] for c in cols]
        var = statistics.pstdev(rs)+statistics.pstdev(gs)+statistics.pstdev(bs)
        mean_b = sum(bs)/len(bs); mean_r=sum(rs)/len(rs)
        # mosaic often high variance OR blue-ish weird
        if var > 80:
            hotspots.append((var, x, y, mean_r, mean_b))
hotspots.sort(reverse=True)
print("top variance tiles:")
for t in hotspots[:25]:
    print(t)

# Also check bandaged / wounded atlas size
for p in [r"C:\Users\hp\Documents\Assets for games\Additional textures\bandaged_textures.jpg",
          r"C:\Users\hp\Documents\Assets for games\Additional textures\wounded_textures.jpg"]:
    im=Image.open(p); print(p, im.size, im.mode)
