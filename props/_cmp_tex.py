from PIL import Image
import os
paths = [
 r"C:\Users\hp\Documents\sabira\art\source\characters_psx\textures\Character_Female_05.png",
 r"C:\Users\hp\Documents\sabira\props\Mom_Amina_albedo_256.png",
]
for p in paths:
    im = Image.open(p)
    print(p, im.size, im.mode)
# find face region heuristically - sample current albedo vs original mid bands
o = Image.open(paths[0]).convert("RGBA")
c = Image.open(paths[1]).convert("RGBA")
if o.size != c.size:
    c = c.resize(o.size, Image.NEAREST)
# save side by side crop of likely face UV (top-leftish for PSX packs often)
# dump a few corner crops for inspection
os.makedirs(r"C:\Users\hp\Documents\sabira\props\_tmp_texcmp", exist_ok=True)
o.save(r"C:\Users\hp\Documents\sabira\props\_tmp_texcmp\f05_full.png")
c.resize(o.size, Image.NEAREST).save(r"C:\Users\hp\Documents\sabira\props\_tmp_texcmp\cur_full.png")
print("saved cmp")
