$ErrorActionPreference = "Stop"
$house = "C:\Users\hp\Documents\sabira\world\House.tscn"
$lockGd = "C:\Users\hp\Documents\sabira\interact\MomLockRect.gd"
$wrapGd = "C:\Users\hp\Documents\sabira\interact\MomWrap.gd"

# --- Remove Godot-lift leftover ---
Remove-Item "C:\Users\hp\Documents\sabira\interact\MomRestraintLift.gd" -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Users\hp\Documents\sabira\interact\MomRestraintLift.gd.uid" -Force -ErrorAction SilentlyContinue
Write-Output "removed lift script"

# --- Read House ---
$lines = [System.Collections.Generic.List[string]]::new()
$lines.AddRange([string[]][System.IO.File]::ReadAllLines($house))

# Update Mom_Amina uid in ext_resource
for ($i=0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match 'path="res://props/Mom_Amina\.glb"') {
    $old = $lines[$i]
    $lines[$i] = $lines[$i] -replace 'uid="uid://[^"]+"', 'uid="uid://bfohhb5sl2jgl"'
    Write-Output "amina uid line: $($lines[$i])"
    Write-Output "  was: $old"
  }
}

# Insert Mom_Restraint ext_resource after Mom_Amina ext_resource if missing
$hasRestraintExt = $false
foreach ($l in $lines) { if ($l -match 'Mom_Restraint\.glb') { $hasRestraintExt = $true; break } }
if (-not $hasRestraintExt) {
  $insAt = -1
  for ($i=0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'id="93_mom_amina"') { $insAt = $i; break }
  }
  if ($insAt -lt 0) { throw "93_mom_amina not found" }
  $extLine = '[ext_resource type="PackedScene" uid="uid://dq75sq87ta1sb" path="res://props/Mom_Restraint.glb" id="100_mom_restraint"]'
  $lines.Insert($insAt + 1, $extLine)
  Write-Output "inserted restraint ext at $($insAt+1)"
} else {
  Write-Output "restraint ext already present"
}

# Remove NeckPlate_L / NeckPlate_R / NeckPlate_Top / LockRect editable override blocks under Mom
# Each is a [node ...] line optionally followed by transform= line(s) until blank or next [node
$removeNames = @("NeckPlate_L","NeckPlate_R","NeckPlate_Top","LockRect")
$newLines = [System.Collections.Generic.List[string]]::new()
$skip = $false
$removed = 0
for ($i=0; $i -lt $lines.Count; $i++) {
  $line = $lines[$i]
  if ($line -match '^\[node name="(NeckPlate_L|NeckPlate_R|NeckPlate_Top|LockRect)"') {
    # Only remove if parent path is under Hidden_Mom_Amina
    if ($line -match 'Hidden_Mom_Amina') {
      $skip = $true
      $removed++
      Write-Output "removing block: $line"
      continue
    }
  }
  if ($skip) {
    if ($line -match '^\[node ' -or $line -match '^\[editable ' -or $line -match '^\[connection ') {
      $skip = $false
      # fall through to add this line
    } elseif ($line -match '^\[/') {
      $skip = $false
      $newLines.Add($line)
      continue
    } else {
      # skip property lines belonging to removed node (transform etc.)
      continue
    }
  }
  if (-not $skip) {
    # When we ended skip because new [node, need to process current line normally
  }
  if ($line -match '^\[node name="(NeckPlate_L|NeckPlate_R|NeckPlate_Top|LockRect)"' -and $line -match 'Hidden_Mom_Amina') {
    # shouldn't reach
    continue
  }
  $newLines.Add($line)
}
$lines = $newLines
Write-Output "removed plate/lock override blocks: $removed"

# Insert Hidden_Mom_Restraint node after Hidden_Mom_Amina block (before Mom_LockRectBody or mouth nodes?)
# Prefer: after mouth overrides (which stay under Mom), before Mom_LockRectBody
$hasRestraintNode = $false
foreach ($l in $lines) { if ($l -match 'name="Hidden_Mom_Restraint"') { $hasRestraintNode = $true; break } }

# Capture Mom transform
$momXform = $null
for ($i=0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match 'name="Hidden_Mom_Amina"') {
    # next non-empty property lines may include transform
    for ($j=$i+1; $j -lt [Math]::Min($i+6, $lines.Count); $j++) {
      if ($lines[$j] -match '^transform = (.+)$') { $momXform = $Matches[1]; break }
      if ($lines[$j] -match '^\[node ') { break }
    }
    break
  }
}
if (-not $momXform) { throw "Hidden_Mom_Amina transform not found" }
Write-Output "momXform=$momXform"

if (-not $hasRestraintNode) {
  $insertAt = -1
  for ($i=0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'name="Mom_LockRectBody"' -or $lines[$i] -match 'name="Mom_LockRectBody"') {
      $insertAt = $i
      break
    }
  }
  # Also try Mom_LockRectBody exact from file
  if ($insertAt -lt 0) {
    for ($i=0; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -match 'LockRectBody') { $insertAt = $i; Write-Output "lock body line: $($lines[$i])"; break }
    }
  }
  if ($insertAt -lt 0) { throw "Mom_LockRectBody not found" }

  $block = @(
    '[node name="Hidden_Mom_Restraint" parent="Structure/HiddenRoom" unique_id=970800005 instance=ExtResource("100_mom_restraint")]',
    "transform = $momXform",
    ''
  )
  $lines.InsertRange($insertAt, $block)
  Write-Output "inserted Hidden_Mom_Restraint before line $insertAt"
} else {
  Write-Output "Hidden_Mom_Restraint already present"
}

$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines($house, $lines.ToArray(), $utf8)
Write-Output "House.tscn written lines=$($lines.Count)"

# Verify
Write-Output "==== verify House ===="
Select-String -Path $house -Pattern "Mom_Restraint|Hidden_Mom_Restraint|NeckPlate|100_mom_restraint|uid://bfohhb5sl2jgl|uid://dq75sq87ta1sb" | ForEach-Object { "$($_.LineNumber):$($_.Line)" }