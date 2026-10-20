Add-Type -AssemblyName System.Drawing

$srcPath = "d:\DevSpace\ENOSIS\ENOSIS-Every-Task-One-Solution-\frontend\assets\branding\enosis_logo.png"
$resDir = "d:\DevSpace\ENOSIS\ENOSIS-Every-Task-One-Solution-\frontend\android\app\src\main\res"

$src = [System.Drawing.Image]::FromFile($srcPath)

$sizes = [ordered]@{
    "mipmap-mdpi" = 48
    "mipmap-hdpi" = 72
    "mipmap-xhdpi" = 96
    "mipmap-xxhdpi" = 144
    "mipmap-xxxhdpi" = 192
}

foreach ($folder in $sizes.Keys) {
    $size = $sizes[$folder]
    $destFolder = Join-Path $resDir $folder
    if (-not (Test-Path $destFolder)) {
        New-Item -ItemType Directory -Path $destFolder -Force | Out-Null
    }
    
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    
    $g.DrawImage($src, 0, 0, $size, $size)
    
    $outPath = Join-Path $destFolder "ic_launcher.png"
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    
    $g.Dispose()
    $bmp.Dispose()
    Write-Host "Created: $outPath ($size x $size)"
}

$src.Dispose()
Write-Host "All icons replaced with ENOSIS branding logo successfully!"
