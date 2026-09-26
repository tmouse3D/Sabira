import bpy
p=r"C:\Users\hp\Documents\sabira\art\source\characters_psx\textures\Character_Female_05.png"
img=bpy.data.images.load(p)
print("F05", img.size[0], img.size[1])
p2=r"C:\Users\hp\Documents\sabira\props\Mom_Amina_albedo_256.png"
img2=bpy.data.images.load(p2)
print("CUR", img2.size[0], img2.size[1])
