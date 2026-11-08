# crop.ps1 <src> <out> <x> <y> <w> <h>: PNG crop for `np-verify shot` on Windows.
# With only <src>, prints the image's pixel height.
param([string]$Src, [string]$Out, [int]$X, [int]$Y, [int]$W, [int]$H)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Bitmap]::FromFile($Src)
try {
  if (-not $Out) { $img.Height; return }
  $part = $img.Clone([System.Drawing.Rectangle]::new($X, $Y, $W, $H), $img.PixelFormat)
  $part.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
  "$($part.Width)x$($part.Height)"
  $part.Dispose()
} finally {
  $img.Dispose()
}
