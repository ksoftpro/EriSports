param(
    [string]$SourceIcon = "assets/icon/icon.png",
    [string]$AndroidAppDir = "android/app"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $repoRoot $SourceIcon
$androidAppPath = Join-Path $repoRoot $AndroidAppDir

if (-not (Test-Path $sourcePath)) {
    throw "Source icon not found: $sourcePath"
}

$densities = @{
    "mipmap-mdpi" = 48
    "mipmap-hdpi" = 72
    "mipmap-xhdpi" = 96
    "mipmap-xxhdpi" = 144
    "mipmap-xxxhdpi" = 192
}

function New-SquareBitmap {
    param(
        [System.Drawing.Bitmap]$BaseImage,
        [int]$Size,
        [switch]$AdminBadge
    )

    $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.DrawImage($BaseImage, 0, 0, $Size, $Size)

        if ($AdminBadge) {
            $badgeHeight = [int]([Math]::Round($Size * 0.22))
            $badgeWidth = [int]([Math]::Round($Size * 0.64))
            $badgeX = $Size - $badgeWidth - [int]([Math]::Round($Size * 0.06))
            $badgeY = [int]([Math]::Round($Size * 0.06))
            $cornerRadius = [int]([Math]::Max(6, [Math]::Round($Size * 0.06)))

            $badgeRect = New-Object System.Drawing.Rectangle($badgeX, $badgeY, $badgeWidth, $badgeHeight)
            $path = New-Object System.Drawing.Drawing2D.GraphicsPath
            $diameter = $cornerRadius * 2
            $path.AddArc($badgeRect.X, $badgeRect.Y, $diameter, $diameter, 180, 90)
            $path.AddArc($badgeRect.Right - $diameter, $badgeRect.Y, $diameter, $diameter, 270, 90)
            $path.AddArc($badgeRect.Right - $diameter, $badgeRect.Bottom - $diameter, $diameter, $diameter, 0, 90)
            $path.AddArc($badgeRect.X, $badgeRect.Bottom - $diameter, $diameter, $diameter, 90, 90)
            $path.CloseFigure()

            $badgeColor = [System.Drawing.Color]::FromArgb(232, 12, 35, 64)
            $borderColor = [System.Drawing.Color]::FromArgb(255, 247, 197, 72)
            $textColor = [System.Drawing.Color]::FromArgb(255, 255, 248, 225)

            $badgeBrush = New-Object System.Drawing.SolidBrush($badgeColor)
            $borderPen = New-Object System.Drawing.Pen($borderColor, [Math]::Max(2, [Math]::Round($Size * 0.018)))
            $graphics.FillPath($badgeBrush, $path)
            $graphics.DrawPath($borderPen, $path)

            $fontSize = [Math]::Max(10, [Math]::Round($Size * 0.12))
            $font = New-Object System.Drawing.Font("Segoe UI", $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
            $textBrush = New-Object System.Drawing.SolidBrush($textColor)
            $format = New-Object System.Drawing.StringFormat
            $textRect = New-Object System.Drawing.RectangleF($badgeRect.X, $badgeRect.Y, $badgeRect.Width, $badgeRect.Height)
            $format.Alignment = [System.Drawing.StringAlignment]::Center
            $format.LineAlignment = [System.Drawing.StringAlignment]::Center
            $graphics.DrawString("ADMIN", $font, $textBrush, $textRect, $format)

            $format.Dispose()
            $textBrush.Dispose()
            $font.Dispose()
            $borderPen.Dispose()
            $badgeBrush.Dispose()
            $path.Dispose()
        }
    }
    finally {
        $graphics.Dispose()
    }

    return $bitmap
}

$baseImage = [System.Drawing.Bitmap]::FromFile($sourcePath)
try {
    foreach ($flavor in @("client", "admin")) {
        foreach ($density in $densities.GetEnumerator()) {
            $targetDir = Join-Path $androidAppPath ("src/{0}/res/{1}" -f $flavor, $density.Key)
            New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

            $targetFile = Join-Path $targetDir "ic_launcher.png"
            $bitmap = New-SquareBitmap -BaseImage $baseImage -Size $density.Value -AdminBadge:($flavor -eq "admin")
            try {
                $bitmap.Save($targetFile, [System.Drawing.Imaging.ImageFormat]::Png)
            }
            finally {
                $bitmap.Dispose()
            }
        }
    }
}
finally {
    $baseImage.Dispose()
}

Write-Host "Generated Android launcher icons for client and admin flavors."