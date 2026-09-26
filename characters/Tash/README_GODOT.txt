PS1 / BLOODWASH-STYLE CHARACTER TEXTURES
=======================================
Based on the provided portrait. Low-res, dithered, grainy, limited-palette
"crusty" analog look suitable for Godot PS1-style projects.

FILES
-----
face_albedo_128.png / 256.png   - Front face
vest_pattern_128.png / 256.png  - Tileable-ish geometric vest fabric
shirt_albedo_128.png / 256.png  - Beige shirt with dirty/worn stains
hair_albedo_64.png / 128.png    - Dark slicked hair
skin_albedo_128.png / 256.png   - Weathered tanned skin
torso_preview_256.png           - Combined reference (not UV ready)

GODOT 4 IMPORT SETTINGS (important for authentic PS1 look)
----------------------------------------------------------
1. Import each PNG.
2. In Import dock:
   - Compress Mode: Lossless (or VRAM Compressed if you want, but Lossless better for pixel look)
   - Repeat: Enabled (for vest/skin/shirt if tiling)
   - Filter: Disabled  << CRITICAL, no bilinear
   - Mipmaps: Disabled
   - Fix Alpha Border: Off
3. Create StandardMaterial3D (or use a PSX shader addon):
   - Albedo > Texture: assign the png
   - Shading Mode: Unshaded  (or Per-Pixel if you want some lighting)
   - Texture Filter: Nearest
   - Disable metallic/roughness or set roughness high (~0.8-1.0)
4. For extra authenticity install a PS1 shader pack such as:
   - https://github.com/snotbane/psx_visuals
   - or search "Godot PSX shader" / affine mapping + vertex snap

USAGE TIPS
----------
- Keep models very low poly (200-800 tris for a character).
- Use vertex colors to add extra dirt / lighting variation.
- Apply a post-process VHS/CRT/dither shader on the camera for full Bloodwash vibe.
- 128px textures are closer to real PS1; 256px is a bit cleaner but still crusty.

These textures are generated/processed for this request and intended as
starting assets you can further paint over in Aseprite / Photoshop.
