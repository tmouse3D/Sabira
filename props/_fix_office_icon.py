import bpy, os
path = r"C:\Users\hp\Documents\sabira\ui\icons\office_key.png"
size = 64
img = bpy.data.images.new("oki", width=size, height=size, alpha=True)
px = [0.0]*(size*size*4)
for i in range(0,len(px),4):
    px[i:i+4]=[0,0,0,1.0]

def ink(x,y,b=1.0):
    if 0<=x<size and 0<=y<size:
        i=(y*size+x)*4
        n=((x*13+y*7)%5)/5.0
        v=0.75+0.22*b+0.04*n
        px[i:i+4]=[v,v,v*0.98,1.0]

cx,cy=20,44
# diamond bow outline (manhattan ring)
for y in range(size):
    for x in range(size):
        man=abs(x-cx)+abs(y-cy)
        if 7<=man<=11:
            ink(x,y,0.95)
# shank diagonal
for s in range(28):
    x=int(26+s*0.9); y=int(36-s*0.7)
    for t in range(-2,3):
        ink(x+t,y); ink(x,y+t)
# double stepped bit
tx,ty=int(26+26*0.9), int(36-26*0.7)
for s in range(9):
    for t in range(-2,3):
        ink(tx-s, ty-1+t, 1.0)
        ink(tx-s-1, ty-6+t, 1.0)
for s in range(4):
    for t in range(-3,4):
        ink(tx+1, ty-s+t)
        ink(tx-2, ty-5-s+t)

img.pixels=px
img.filepath_raw=path
img.file_format="PNG"
img.save()
print("icon ok", path)
