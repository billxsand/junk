param(
  [string]$AppRoot = "$env:LOCALAPPDATA\razer_taskbar\app-0.12.0"
)

$assets = Join-Path $AppRoot 'resources\assets'
if (-not (Test-Path -LiteralPath $assets)) {
  throw "Razer Taskbar assets were not found at: $assets"
}

# Close the app so Windows does not hold its icon files open.
Get-Process -Name 'razer-taskbar' -ErrorAction SilentlyContinue | Stop-Process -Force

# Keep one recoverable copy of the original icons.
$backup = Join-Path $AppRoot 'resources\assets-backup-before-white'
if (-not (Test-Path -LiteralPath $backup)) {
  Copy-Item -LiteralPath $assets -Destination $backup -Recurse
}

Add-Type -AssemblyName System.Drawing

function Set-WhiteForeground([string]$Path) {
  $image = [System.Drawing.Bitmap]::new($Path)
  $temporary = "$Path.white.tmp.png"
  try {
    for ($x = 0; $x -lt $image.Width; $x++) {
      for ($y = 0; $y -lt $image.Height; $y++) {
        $pixel = $image.GetPixel($x, $y)
        $maximum = [Math]::Max($pixel.R, [Math]::Max($pixel.G, $pixel.B))
        $minimum = [Math]::Min($pixel.R, [Math]::Min($pixel.G, $pixel.B))

        # The icons use a near-black neutral background. Their yellow/green
        # battery areas are bright, saturated pixels, so only those are changed.
        if ($pixel.A -gt 0 -and $maximum -gt 75 -and ($maximum - $minimum) -gt 15) {
          $image.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($pixel.A, 255, 255, 255))
        }
      }
    }

    $image.Save($temporary, [System.Drawing.Imaging.ImageFormat]::Png)
  }
  finally {
    $image.Dispose()
  }
  Move-Item -LiteralPath $temporary -Destination $Path -Force
}

$iconFiles = Get-ChildItem -LiteralPath $assets -Recurse -Filter 'battery*.png' |
  Where-Object {
    if ($_.Name -match '^battery(\d{1,3})') {
      [int]$Matches[1] -ge 20
    }
    else {
      $false
    }
  }

foreach ($icon in $iconFiles) {
  Set-WhiteForeground $icon.FullName
}

Start-Process -FilePath (Join-Path (Split-Path $AppRoot -Parent) 'razer-taskbar.exe')
Write-Host "Updated $($iconFiles.Count) normal/charging icons to white. 0-19% red icons were left unchanged."
