import bpy, numpy as np
img=bpy.data.images.load(r"C:\Users\hp\Documents\sabira\props\Mom_Amina_stump_bandage_64.png", check_existing=False)
arr=np.array(img.pixels[:],np.float32).reshape(img.size[1],img.size[0],4)[:,:,:3]
print("bandage std",arr.std(axis=(0,1)),"mean",arr.mean(axis=(0,1)),"minmax",arr.min(),arr.max())