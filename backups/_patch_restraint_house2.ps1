$ErrorActionPreference = "Stop"
$house = "C:\Users\hp\Documents\sabira\world\House.tscn"
$aminaUid = (Select-String -Path "C:\Users\hp\Documents\sabira\props\Mom_Amina.glb.import" -Pattern '^uid="([^"]+)"').Matches[0].Groups[1].Value
$restUid  = (Select-String -Path "C:\Users\hp\Documents\sabira\props\Mom_Restraint.glb.import" -Pattern '^uid="([^"]+)"').Matches[0].Groups[1].Value
Write-Output "aminaUid=$aminaUid restUid=$restUid"

$lines = New-Object System.Collections.Generic.List[string]
foreach ($ln in [System.IO.File]::ReadAllLines($house)) { [void]$lines.Add($ln) }

# Fix amina uid
for ($i=0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match 'path="res://props/Mom_Amina\.glb"') {
    $lines[$i] = [regex]::Replace($lines[$i], 'uid="uid://[^"]+"', ('uid="' + $aminaUid + '"'))
    Write-Output ("amina ext: " + $lines[$i])
  }
}

# Add restraint ext if missing
$hasExt = $false
foreach ($l in $lines) { if ($l -match 'Mom_Restraint\.glb') { $hasExt = $true; break } }
if (-not $hasExt) {
  $idx = -1
  for ($i=0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match 'id="93_mom_amina"') { $idx = $i; break } }
  if ($idx -lt 0) { throw "no 93_mom_amina" }
  $ext = '[ext_resource type="PackedScene" uid="' + $restUid + '" path="res://props/Mom_Restraint.glb" id="100_mom_restraint"]'
  $lines.Insert($idx + 1, $ext)
  Write-Output "inserted ext"
} else { Write-Output "ext ok" }

# Rebuild without plate/lock overrides under Mom
$out = New-Object System.Collections.Generic.List[string]
$skip = $false
$removed = 0
for ($i=0; $i -lt $lines.Count; $i++) {
  $line = $lines[$i]
  if ($line -match '^\[node name="(NeckPlate_L|NeckPlate_R|NeckPlate_Top|LockRect)"' -and $line -match 'Hidden_Mom_Amina') {
    $skip = $true
    $removed++
    Write-Output ("drop: " + $line)
    continue
  }
  if ($skip) {
    if ($line -match '^\[node ' -or $line -match '^\[editable ' -or $line -match '^\[connection ') {
      $skip = $false
      # process this line below
    } else {
      continue
    }
  }
  if ($skip) { continue }
  # If this line itself is a plate node we just ended skip for another plate, handled at top on next iter - but we need to re-check
  if ($line -match '^\[node name="(NeckPlate_L|NeckPlate_R|NeckPlate_Top|LockRect)"' -and $line -match 'Hidden_Mom_Amina') {
    $skip = $true
    $removed++
    Write-Output ("drop2: " + $line)
    continue
  }
  [void]$out.Add($line)
}
Write-Output "removed=$removed"
$lines = $out

# Mom transform
$momXform = $null
for ($i=0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match 'name="Hidden_Mom_Amina"') {
    for ($j=$i+1; $j -lt [Math]::Min($i+8,$lines.Count); $j++) {
      if ($lines[$j] -match '^transform = (.+)$') { $momXform = $Matches[1]; break }
      if ($lines[$j] -match '^\[node ') { break }
    }
    break
  }
}
if (-not $momXform) { throw "no mom transform" }
Write-Output "momXform=$momXform"

# Insert Hidden_Mom_Restraint if missing
$hasNode = $false
foreach ($l in $lines) { if ($l -match 'name="Hidden_Mom_Restraint"') { $hasNode = $true; break } }
if (-not $hasNode) {
  $insertAt = -1
  for ($i=0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'name="Mom_LockRectBody"') { $insertAt = $i; break }
  }
  if ($insertAt -lt 0) {
    for ($i=0; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -match 'LockRectBody') { Write-Output ("candidate: " + $lines[$i]); $insertAt = $i; break }
    }
  }
  if ($insertAt -lt 0) { throw "no LockRectBody" }
  Write-Output ("insert before: " + $lines[$insertAt])
  $a = '[node name="Hidden_Mom_Restraint" parent="Structure/HiddenRoom" unique_id=970800005 instance=ExtResource("100_mom_restraint")]'
  $b = "transform = $momXform"
  $c = ""
  $lines.Insert($insertAt, $c)
  $lines.Insert($insertAt, $b)
  $lines.Insert($insertAt, $a)
  Write-Output "inserted Hidden_Mom_Restraint"
} else { Write-Output "node ok" }

$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines($house, $lines.ToArray(), $utf8)
Write-Output ("wrote House lines=" + $lines.Count)

Write-Output "==== verify ===="
Select-String -Path $house -Pattern "Mom_Restraint|Hidden_Mom_Restraint|NeckPlate|100_mom_restraint|LockRect" | ForEach-Object { $_.LineNumber.ToString() + ":" + $_.Line }