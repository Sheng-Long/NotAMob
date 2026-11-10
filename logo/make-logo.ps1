# Draws NotAMob logo variants (400x400 PNG) with .NET System.Drawing,
# plus a comparison sheet (each variant at 200px and 64px).
# Run:  powershell -ExecutionPolicy Bypass -File logo\make-logo.ps1
Add-Type -AssemblyName System.Drawing

$size = 400

function C($hex, $a = 255) {
    $c = [System.Drawing.ColorTranslator]::FromHtml($hex)
    [System.Drawing.Color]::FromArgb($a, $c.R, $c.G, $c.B)
}

# Color schemes: background center/edge, bar border, crosshair
$schemes = [ordered]@{
    classic = @{ bgIn = '#2a3446'; bgOut = '#0a0d13'; border = '#d8b04a'; cross = '#d8b04a' }
    arcane  = @{ bgIn = '#2e2246'; bgOut = '#0a0712'; border = '#a335ee'; cross = '#c79cff' }
}

# Rounded rectangle path
function RoundRect($x, $y, $w, $h, $r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = 2 * $r
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

# Skull in the style of WoW's "dangerous enemy" skull: wide cranium, angry
# angular eye sockets, warm bone shading, bold black outline. Drawn from
# shapes here (original art, not Blizzard's icon). Centered at cx, cy.
function P($cx, $cy, $s, $x, $y) { New-Object System.Drawing.PointF ($cx + $s * $x), ($cy + $s * $y) }

function Skull($g, $cx, $cy, $s) {
    # head outline: round cranium, cheekbones, tapered jaw (one closed shape)
    $head = New-Object System.Drawing.Drawing2D.GraphicsPath
    $head.AddBezier((P $cx $cy $s -0.30 0.46), (P $cx $cy $s -0.34 0.30), (P $cx $cy $s -0.40 0.22), (P $cx $cy $s -0.44 0.12))
    $head.AddBezier((P $cx $cy $s -0.44 0.12), (P $cx $cy $s -0.56 -0.05), (P $cx $cy $s -0.52 -0.50), (P $cx $cy $s 0.00 -0.52))
    $head.AddBezier((P $cx $cy $s 0.00 -0.52), (P $cx $cy $s 0.52 -0.50), (P $cx $cy $s 0.56 -0.05), (P $cx $cy $s 0.44 0.12))
    $head.AddBezier((P $cx $cy $s 0.44 0.12), (P $cx $cy $s 0.40 0.22), (P $cx $cy $s 0.34 0.30), (P $cx $cy $s 0.30 0.46))
    $head.AddLine((P $cx $cy $s 0.30 0.46), (P $cx $cy $s -0.30 0.46))
    $head.CloseFigure()

    $bounds = New-Object System.Drawing.RectangleF ($cx - $s * 0.6), ($cy - $s * 0.55), ($s * 1.2), ($s * 1.05)
    $bone = New-Object System.Drawing.Drawing2D.LinearGradientBrush $bounds, (C '#fbf1d6'), (C '#b89a62'), 90
    $outline = New-Object System.Drawing.Pen (C '#000000'), ([Math]::Max(2, $s * 0.11))
    $outline.LineJoin = 'Round'
    $g.DrawPath($outline, $head)
    $g.FillPath($bone, $head)

    $dark = New-Object System.Drawing.SolidBrush (C '#120808')
    # angry, angular eye sockets (higher at the outer edge, slanting down inward)
    $g.FillPolygon($dark, [System.Drawing.PointF[]]@(
        (P $cx $cy $s -0.40 -0.16), (P $cx $cy $s -0.06 -0.04), (P $cx $cy $s -0.08 0.16), (P $cx $cy $s -0.34 0.14)))
    $g.FillPolygon($dark, [System.Drawing.PointF[]]@(
        (P $cx $cy $s 0.40 -0.16), (P $cx $cy $s 0.06 -0.04), (P $cx $cy $s 0.08 0.16), (P $cx $cy $s 0.34 0.14)))
    # nose: small upside-down heart-ish triangle
    $g.FillPolygon($dark, [System.Drawing.PointF[]]@(
        (P $cx $cy $s 0.00 0.18), (P $cx $cy $s -0.07 0.29), (P $cx $cy $s 0.07 0.29)))
    # mouth line and teeth
    $tpen = New-Object System.Drawing.Pen (C '#120808'), ([Math]::Max(1.2, $s * 0.06))
    $g.DrawLine($tpen, (P $cx $cy $s -0.24 0.36), (P $cx $cy $s 0.24 0.36))
    foreach ($t in @(-0.16, -0.05, 0.05, 0.16)) {
        $g.DrawLine($tpen, (P $cx $cy $s $t 0.33), (P $cx $cy $s $t 0.46))
    }
}

function Outlined-Text($g, $text, $fontSize, $cx, $topY, $fill, $outlineW, $alpha) {
    $font = New-Object System.Drawing.FontFamily 'Georgia'
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = 'Center'
    $path.AddString($text, $font, [int][System.Drawing.FontStyle]::Bold, $fontSize,
        (New-Object System.Drawing.PointF $cx, $topY), $fmt)
    if ($outlineW -gt 0) {
        $pen = New-Object System.Drawing.Pen (C '#000000' $alpha), $outlineW
        $pen.LineJoin = 'Round'
        $g.DrawPath($pen, $path)
    }
    $g.FillPath((New-Object System.Drawing.SolidBrush $fill), $path)
}

function Bar($g, $x, $y, $w, $h, $borderW, $borderColor, $alpha) {
    $r = [Math]::Max(2, $h * 0.18)  # square bar, slightly rounded corners
    $outer = RoundRect ($x - $borderW - 2) ($y - $borderW - 2) ($w + 2 * ($borderW + 2)) ($h + 2 * ($borderW + 2)) ($r + $borderW + 2)
    $g.FillPath((New-Object System.Drawing.SolidBrush (C '#000000' $alpha)), $outer)
    $ring = RoundRect ($x - $borderW / 2 - 1) ($y - $borderW / 2 - 1) ($w + $borderW + 2) ($h + $borderW + 2) ($r + $borderW / 2 + 1)
    $g.DrawPath((New-Object System.Drawing.Pen $borderColor, $borderW), $ring)
    $inner = RoundRect $x $y $w $h $r
    $rect = New-Object System.Drawing.RectangleF $x, $y, $w, $h
    $fill = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, (C '#e03a2f' $alpha), (C '#7d0f0c' $alpha), 90
    $g.FillPath($fill, $inner)
    # soft shine on the top part, clipped to the rounded bar
    $g.SetClip($inner)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush (C '#ffffff' ([int]($alpha * 0.18)))), $x, $y, $w, $h * 0.4)
    $g.ResetClip()
}

function Draw-Logo($name, $s) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.TextRenderingHint = 'AntiAliasGridFit'

    # background
    $bgPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $bgPath.AddEllipse(-120, -100, $size + 240, $size + 240)
    $bg = New-Object System.Drawing.Drawing2D.PathGradientBrush $bgPath
    $bg.CenterColor = C $s.bgIn
    $bg.SurroundColors = @(C $s.bgOut)
    $g.FillRectangle($bg, 0, 0, $size, $size)

    # crosshair, centered on the player plate, behind it
    # (only top and bottom ticks: side ticks would collide with the bar)
    $cx = 200; $cy = 226; $r = 138
    $cpen = New-Object System.Drawing.Pen (C $s.cross 150), 5
    $g.DrawEllipse($cpen, $cx - $r, $cy - $r, 2 * $r, 2 * $r)
    $tpen = New-Object System.Drawing.Pen (C $s.cross 150), 5
    $g.DrawLine($tpen, $cx, $cy - $r - 22, $cx, $cy - $r + 34)   # top
    $g.DrawLine($tpen, $cx, $cy + $r - 34, $cx, $cy + $r + 22)   # bottom

    # two dim mob plates, small, near the top
    foreach ($m in @(@(92, 66), @(306, 44))) {
        Bar $g ($m[0] - 50) $m[1] 100 10 1 (C '#8a8a8a' 110) 110
        Outlined-Text $g 'Mob' 18 $m[0] ($m[1] - 25) (C '#c8c8c8' 110) 3 110
    }

    # the enemy player: name, bar and level box
    Outlined-Text $g 'NOT A MOB' 44 $cx 166 (C '#ffffff') 8 255
    # bar + level box together are centered on the image
    $barX = 52; $barY = 228; $barW = 232; $barH = 32
    Bar $g $barX $barY $barW $barH 4 (C $s.border) 255
    # level box (like a real nameplate's), with a skull for a dangerous player
    $lx = $barX + $barW + 14; $lw = 50; $ly = $barY - 4; $lh = $barH + 8
    $g.FillPath((New-Object System.Drawing.SolidBrush (C '#000000')), (RoundRect ($lx - 2) ($ly - 2) ($lw + 4) ($lh + 4) 10))
    $g.DrawPath((New-Object System.Drawing.Pen (C $s.border), 4), (RoundRect $lx $ly $lw $lh 9))
    Skull $g ($lx + $lw / 2) ($ly + $lh / 2 + 1) 29

    $out = Join-Path $PSScriptRoot "logo-$name.png"
    $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    return $out
}

$files = @()
foreach ($k in $schemes.Keys) { $files += Draw-Logo $k $schemes[$k] }

# comparison sheet: each variant at 200px with a 64px copy below it
$n = $files.Count
$sheet = New-Object System.Drawing.Bitmap ($n * 220 + 20), 330
$sg = [System.Drawing.Graphics]::FromImage($sheet)
$sg.Clear((C '#1a1a1a'))
$sg.InterpolationMode = 'HighQualityBicubic'
$sg.TextRenderingHint = 'AntiAliasGridFit'
$labelFont = New-Object System.Drawing.Font 'Segoe UI', 12
$i = 0
foreach ($k in $schemes.Keys) {
    $img = [System.Drawing.Image]::FromFile($files[$i])
    $x = 20 + $i * 220
    $sg.DrawImage($img, $x, 20, 200, 200)
    $sg.DrawImage($img, $x + 68, 236, 64, 64)
    $sg.DrawString($k, $labelFont, [System.Drawing.Brushes]::White, $x, 305)
    $img.Dispose()
    $i++
}
$sheetOut = Join-Path $PSScriptRoot "logo-comparison.png"
$sheet.Save($sheetOut, [System.Drawing.Imaging.ImageFormat]::Png)
$sg.Dispose(); $sheet.Dispose()
"saved: " + (($files + $sheetOut) -join ', ')
