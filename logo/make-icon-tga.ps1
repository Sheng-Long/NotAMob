# Makes the in-game AddOns-list icon, saved as an uncompressed 32-bit TGA
# (a format WoW reads) into the addon folder. The AddOns list draws icons
# tiny (about 22 px), so this is just "NAM" in hostile-name red with a black
# outline, like an enemy name seen at long range, on a transparent square.
# Arial Black: its even, thick strokes stay readable at that size (Georgia's
# thin N diagonal disappeared under the outline).
# Run:  powershell -ExecutionPolicy Bypass -File logo\make-icon-tga.ps1
Add-Type -AssemblyName System.Drawing

$out = Join-Path $PSScriptRoot "..\NotAMob\icon.tga"
$w = 128; $h = 128   # square, power of two

$bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::Transparent)
$g.SmoothingMode = 'AntiAlias'

# Build the text as a path, then scale it to fill the width with a margin
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddString('NAM', (New-Object System.Drawing.FontFamily 'Arial Black'),
    [int][System.Drawing.FontStyle]::Bold, 100, (New-Object System.Drawing.PointF 0, 0),
    [System.Drawing.StringFormat]::GenericTypographic)
$r = $path.GetBounds()
$outline = 8
$scale = ($w - $outline - 4) / $r.Width
$m = New-Object System.Drawing.Drawing2D.Matrix
$m.Translate(-$r.X, -$r.Y, 'Append')
$m.Scale($scale, $scale, 'Append')
$m.Translate(($w - $r.Width * $scale) / 2, ($h - $r.Height * $scale) / 2, 'Append')
$path.Transform($m)

$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::Black), $outline
$pen.LineJoin = 'Round'
$g.DrawPath($pen, $path)
# WoW's hostile-name red
$g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 32, 32))), $path)
$g.Dispose()
$bmp.Save((Join-Path $PSScriptRoot "icon-preview.png"))   # PNG copy to look at

# TGA header: uncompressed true-color, 32 bits, 8 alpha bits, origin bottom-left
$header = New-Object byte[] 18
$header[2] = 2
$header[12] = $w % 256; $header[13] = [math]::Floor($w / 256)
$header[14] = $h % 256; $header[15] = [math]::Floor($h / 256)
$header[16] = 32
$header[17] = 8

$pixels = New-Object byte[] ($w * $h * 4)
$i = 0
for ($y = $h - 1; $y -ge 0; $y--) {          # bottom row first
    for ($x = 0; $x -lt $w; $x++) {
        $c = $bmp.GetPixel($x, $y)
        $pixels[$i] = $c.B; $pixels[$i + 1] = $c.G; $pixels[$i + 2] = $c.R; $pixels[$i + 3] = $c.A
        $i += 4
    }
}
$bmp.Dispose()

$fs = [System.IO.File]::Create((Resolve-Path (Split-Path $out)).Path + "\icon.tga")
$fs.Write($header, 0, 18)
$fs.Write($pixels, 0, $pixels.Length)
$fs.Close()
"saved icon.tga ($($pixels.Length + 18) bytes)"
