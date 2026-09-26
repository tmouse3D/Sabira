$path = "C:\Users\hp\Documents\sabira\world\House.tscn"
$raw = [System.IO.File]::ReadAllText($path)
$n = 0

# Normalize newlines to LF for matching, write back CRLF
$raw = $raw -replace "`r`n", "`n"

$oldBook = "[sub_resource type=`"BoxShape3D`" id=`"BoxShape_bookprop`"]`nsize = Vector3(0.14, 0.03, 0.1)"
$newBook = "[sub_resource type=`"BoxShape3D`" id=`"BoxShape_bookprop`"]`nsize = Vector3(0.28, 0.1, 0.22)"
if ($raw.Contains($oldBook)) { $raw = $raw.Replace($oldBook, $newBook); $n++; Write-Host "OK book shape" } else { Write-Host "MISS book shape" }

$livingAnchor = "[node name=`"CollisionShape3D`" type=`"CollisionShape3D`" parent=`"Structure/Living/Living_CouchBody`" unique_id=566308333]`nshape = SubResource(`"BoxShape_couch`")"
$livingSolid = @"
[node name="CollisionShape3D" type="CollisionShape3D" parent="Structure/Living/Living_CouchBody" unique_id=566308333]
shape = SubResource("BoxShape_couch")

[node name="Living_CouchSolid" type="StaticBody3D" parent="Structure/Living" unique_id=970000910]
transform = Transform3D(1, 0, 0, 0, 1.1147072, 0, 0, 0, 1.0931994, 0, 0.425, 1.2)
collision_layer = 8
collision_mask = 0

[node name="CollisionShape3D" type="CollisionShape3D" parent="Structure/Living/Living_CouchSolid" unique_id=970000911]
shape = SubResource("BoxShape_couch")
"@
if ($raw.Contains("Living_CouchSolid")) { Write-Host "SKIP Living_CouchSolid exists" }
elseif ($raw.Contains($livingAnchor)) { $raw = $raw.Replace($livingAnchor, $livingSolid); $n++; Write-Host "OK Living_CouchSolid" }
else { Write-Host "MISS Living anchor" }

$oldBookBody = "[node name=`"Landing_BookBody`" type=`"StaticBody3D`" parent=`"Structure/Landing`" unique_id=970600021]`ntransform = Transform3D(1.8400333, 0, 1.0907143, 0, 1.3064134, 0, -1.0623437, 0, 1.8891726, -0.7304325, 0.29331422, -0.54999995)`ncollision_layer = 5`ncollision_mask = 0`nscript = ExtResource(`"99_bookread`")`nprompt_text = `"[E] Read the book.`""
$newBookBody = "[node name=`"Landing_BookBody`" type=`"StaticBody3D`" parent=`"Structure/Landing`" unique_id=970600021]`ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.7304325, 0.38, -0.54999995)`ncollision_layer = 5`ncollision_mask = 0`nscript = ExtResource(`"99_bookread`")`nprompt_text = `"[E] Read the book.`""
if ($raw.Contains($oldBookBody)) { $raw = $raw.Replace($oldBookBody, $newBookBody); $n++; Write-Host "OK BookBody raise" } else { Write-Host "MISS BookBody" }

$oldLC = "[node name=`"Landing_CouchBody`" type=`"StaticBody3D`" parent=`"Structure/Landing`" unique_id=970000902]`ntransform = Transform3D(2.9802322e-08, 0, -1, 0, 1, 0, 1, 0, 2.9802322e-08, -0.8430836, 0.2739492, -0.60939246)`n`n[node name=`"CollisionShape3D`" type=`"CollisionShape3D`" parent=`"Structure/Landing/Landing_CouchBody`" unique_id=970000903]`nshape = SubResource(`"BoxShape_couch`")"
$newLC = @"
[node name="Landing_CouchBody" type="StaticBody3D" parent="Structure/Landing" unique_id=970000902]
transform = Transform3D(2.9802322e-08, 0, -1, 0, 1, 0, 1, 0, 2.9802322e-08, -0.8430836, 0.2739492, -0.60939246)
collision_layer = 5
collision_mask = 0
script = ExtResource("96_couchsearch")
prompt_text = "[E] Search the couch."

[node name="CollisionShape3D" type="CollisionShape3D" parent="Structure/Landing/Landing_CouchBody" unique_id=970000903]
shape = SubResource("BoxShape_couch")

[node name="Landing_CouchSolid" type="StaticBody3D" parent="Structure/Landing" unique_id=970000912]
transform = Transform3D(2.9802322e-08, 0, -1, 0, 1, 0, 1, 0, 2.9802322e-08, -0.8430836, 0.2739492, -0.60939246)
collision_layer = 8
collision_mask = 0

[node name="CollisionShape3D" type="CollisionShape3D" parent="Structure/Landing/Landing_CouchSolid" unique_id=970000913]
shape = SubResource("BoxShape_couch")
"@
if ($raw.Contains("Landing_CouchSolid")) { Write-Host "SKIP Landing_CouchSolid exists" }
elseif ($raw.Contains($oldLC)) { $raw = $raw.Replace($oldLC, $newLC); $n++; Write-Host "OK Landing couch+solid" }
else {
  Write-Host "MISS Landing couch"
  $i = $raw.IndexOf("[node name=`"Landing_CouchBody`"")
  if ($i -ge 0) { Write-Host ($raw.Substring($i, 350)) }
}

$out = $raw -replace "`n", "`r`n"
[System.IO.File]::WriteAllText($path, $out)
Write-Host "DONE patches=$n size=$($out.Length)"
