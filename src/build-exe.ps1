# ==============================================================================
# wakubp :: SINGLE-FILE EXE BUILDER (WINDOWS)
# Packs src\ + payload\ into a standalone zero-flash WinForms executable:
#   dist\wakubp.exe
# Converts src\waku.jpg (or custom -IconSource) into a multi-size .ico (256..16)
# and embeds it as the Win32 application icon + window/taskbar icon.
# ==============================================================================

param(
    [string]$IconSource = ""
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$SrcDir  = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$RootDir = Split-Path $SrcDir -Parent
$DistDir = Join-Path $RootDir "dist"
$OutExe  = Join-Path $DistDir "wakubp.exe"
$IcoPath = Join-Path $SrcDir "waku.ico"
$JpgPath = Join-Path $SrcDir "waku.jpg"

if (-not (Test-Path -LiteralPath $DistDir -PathType Container)) {
    New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
}

function New-RoundedRectPath([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $d = $r * 2.0
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function ConvertTo-MultiSizeIco([string]$srcImgPath, [string]$dstIcoPath) {
    $srcImg = [System.Drawing.Image]::FromFile($srcImgPath)
    try {
        # Center-crop to square so avatar doesn't stretch
        $side = [Math]::Min($srcImg.Width, $srcImg.Height)
        $cropX = [int][Math]::Floor(($srcImg.Width - $side) / 2)
        $cropY = [int][Math]::Floor(($srcImg.Height - $side) / 2)
        $cropRect = New-Object System.Drawing.Rectangle($cropX, $cropY, $side, $side)

        # First render high-res square cropped bitmap for clean TextureBrush sampling
        $sqBmp = New-Object System.Drawing.Bitmap($side, $side, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $gSq = [System.Drawing.Graphics]::FromImage($sqBmp)
        $gSq.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $gSq.DrawImage($srcImg, (New-Object System.Drawing.Rectangle(0, 0, $side, $side)), $cropRect, [System.Drawing.GraphicsUnit]::Pixel)
        $gSq.Dispose()

        $sizes = @(256, 64, 48, 32, 16)
        $pngBuffers = New-Object System.Collections.Generic.List[byte[]]

        foreach ($sz in $sizes) {
            # Render scaled square first
            $scaled = New-Object System.Drawing.Bitmap($sz, $sz, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $gs = [System.Drawing.Graphics]::FromImage($scaled)
            $gs.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $gs.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $gs.PixelOffsetMode    = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $gs.DrawImage($sqBmp, 0, 0, $sz, $sz)
            $gs.Dispose()

            # Fill anti-aliased rounded rectangle (22% corner radius) using TextureBrush
            $bmp = New-Object System.Drawing.Bitmap($sz, $sz, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            $g.Clear([System.Drawing.Color]::Transparent)
            $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

            $radius = [float]([Math]::Max(2.0, $sz * 0.22))
            $path = New-RoundedRectPath 0 0 ([float]$sz) ([float]$sz) $radius
            $tBrush = New-Object System.Drawing.TextureBrush($scaled)
            $g.FillPath($tBrush, $path)

            $tBrush.Dispose()
            $path.Dispose()
            $g.Dispose()
            $scaled.Dispose()

            $msPng = New-Object System.IO.MemoryStream
            $bmp.Save($msPng, [System.Drawing.Imaging.ImageFormat]::Png)
            $bmp.Dispose()
            $pngBuffers.Add($msPng.ToArray()) | Out-Null
            $msPng.Dispose()
        }
        $sqBmp.Dispose()

        $fs = [System.IO.File]::Open($dstIcoPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
        $bw = New-Object System.IO.BinaryWriter($fs)
        # ICONDIR header
        $bw.Write([uint16]0)                 # Reserved
        $bw.Write([uint16]1)                 # Type: 1 = ICO
        $bw.Write([uint16]$sizes.Count)      # Image count

        $offset = 6 + (16 * $sizes.Count)
        for ($i = 0; $i -lt $sizes.Count; $i++) {
            $sz = $sizes[$i]
            $data = $pngBuffers[$i]
            $dimByte = if ($sz -ge 256) { [byte]0 } else { [byte]$sz }
            $bw.Write([byte]$dimByte)        # Width
            $bw.Write([byte]$dimByte)        # Height
            $bw.Write([byte]0)               # ColorCount
            $bw.Write([byte]0)               # Reserved
            $bw.Write([uint16]1)             # Planes
            $bw.Write([uint16]32)            # BitCount
            $bw.Write([uint32]$data.Length)  # BytesInRes
            $bw.Write([uint32]$offset)       # ImageOffset
            $offset += $data.Length
        }
        for ($i = 0; $i -lt $sizes.Count; $i++) {
            $bw.Write($pngBuffers[$i])
        }
        $bw.Flush()
        $fs.Dispose()
    } finally {
        $srcImg.Dispose()
    }
}

if ($IconSource -and (Test-Path -LiteralPath $IconSource -PathType Leaf)) {
    Copy-Item -LiteralPath $IconSource -Destination $JpgPath -Force
}
if (Test-Path -LiteralPath $JpgPath -PathType Leaf) {
    ConvertTo-MultiSizeIco -srcImgPath $JpgPath -dstIcoPath $IcoPath
    Remove-Item -LiteralPath $JpgPath -Force -ErrorAction SilentlyContinue
}

# Collect all files from src\ (gui.ps1, engine.ps1, waku.ico) and payload\
$FilesToPack = @(
    @{ Rel = "src\gui.ps1";    Full = (Join-Path $RootDir "src\gui.ps1") },
    @{ Rel = "src\engine.ps1"; Full = (Join-Path $RootDir "src\engine.ps1") }
)
if (Test-Path -LiteralPath $IcoPath -PathType Leaf) {
    $FilesToPack += @{ Rel = "src\waku.ico"; Full = $IcoPath }
}

$PayloadRoot = Join-Path $RootDir "payload"
Get-ChildItem -LiteralPath $PayloadRoot -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($RootDir.Length).TrimStart('\', '/')
    $FilesToPack += @{ Rel = $rel; Full = $_.FullName }
}

# Build compressed bundle in memory
$ms = New-Object System.IO.MemoryStream
$gz = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionMode]::Compress, $true)
$bw = New-Object System.IO.BinaryWriter($gz, [System.Text.Encoding]::UTF8)

$bw.Write([int]$FilesToPack.Count)
foreach ($item in $FilesToPack) {
    $bytes = [System.IO.File]::ReadAllBytes($item.Full)
    $bw.Write([string]$item.Rel)
    $bw.Write([int]$bytes.Length)
    $bw.Write($bytes)
}
$bw.Flush()
$gz.Dispose()

$BundleB64 = [Convert]::ToBase64String($ms.ToArray())
$ms.Dispose()

$CSharpSource = @"
using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Text;

[assembly: AssemblyTitle("wakubp")]
[assembly: AssemblyDescription("wakubp - Bypass by waku on Teyvat")]
[assembly: AssemblyProduct("wakubp")]
[assembly: AssemblyCopyright("Copyright (c) 2026 waku")]
[assembly: AssemblyVersion("2.0.0.0")]
[assembly: AssemblyFileVersion("2.0.0.0")]

namespace WakuBp {
    internal static class Program {
        private const string PayloadB64 = "$BundleB64";

        [STAThread]
        private static int Main(string[] args) {
            string workDir = Path.Combine(Path.GetTempPath(), "wakubp-runtime");
            try {
                ExtractBundle(workDir);
                string guiScript = Path.Combine(workDir, "src", "gui.ps1");

                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = "powershell.exe";
                psi.Arguments = "-STA -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + guiScript + "\"";
                psi.WorkingDirectory = workDir;
                psi.UseShellExecute = false;
                psi.CreateNoWindow = true;
                psi.WindowStyle = ProcessWindowStyle.Hidden;

                using (Process p = Process.Start(psi)) {
                    if (p != null) {
                        p.WaitForExit();
                        return p.ExitCode;
                    }
                }
                return 0;
            } catch (Exception ex) {
                System.Windows.Forms.MessageBox.Show(
                    "Failed to launch wakubp:\n" + ex.Message,
                    "wakubp",
                    System.Windows.Forms.MessageBoxButtons.OK,
                    System.Windows.Forms.MessageBoxIcon.Error);
                return 1;
            }
        }

        private static void ExtractBundle(string targetRoot) {
            byte[] compressed = Convert.FromBase64String(PayloadB64);
            using (MemoryStream ms = new MemoryStream(compressed))
            using (GZipStream gz = new GZipStream(ms, CompressionMode.Decompress))
            using (BinaryReader br = new BinaryReader(gz, Encoding.UTF8)) {
                int count = br.ReadInt32();
                for (int i = 0; i < count; i++) {
                    string relPath = br.ReadString().Replace('/', Path.DirectorySeparatorChar).Replace('\\', Path.DirectorySeparatorChar);
                    int len = br.ReadInt32();
                    byte[] data = br.ReadBytes(len);
                    string fullPath = Path.Combine(targetRoot, relPath);
                    string dir = Path.GetDirectoryName(fullPath);
                    if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir)) {
                        Directory.CreateDirectory(dir);
                    }
                    File.WriteAllBytes(fullPath, data);
                }
            }
        }
    }
}
"@

$provider = New-Object Microsoft.CSharp.CSharpCodeProvider
$params   = New-Object System.CodeDom.Compiler.CompilerParameters
$params.GenerateExecutable = $true
$params.OutputAssembly     = $OutExe
$win32IconOpt = if (Test-Path -LiteralPath $IcoPath -PathType Leaf) { " /win32icon:`"$IcoPath`"" } else { "" }
$params.CompilerOptions    = "/target:winexe /optimize+ /platform:anycpu$win32IconOpt"
$params.ReferencedAssemblies.Add("System.dll") | Out-Null
$params.ReferencedAssemblies.Add("System.Windows.Forms.dll") | Out-Null

$results = $provider.CompileAssemblyFromSource($params, $CSharpSource)
if ($results.Errors.HasErrors) {
    foreach ($err in $results.Errors) {
        Write-Error $err.ToString()
    }
    exit 1
}

$sizeKb = [Math]::Round((Get-Item -LiteralPath $OutExe).Length / 1KB, 1)
Write-Host "[+] Built standalone executable: $OutExe ($sizeKb KB, $($FilesToPack.Count) embedded files, icon: $(Test-Path -LiteralPath $IcoPath))"
