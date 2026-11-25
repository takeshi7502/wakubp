# ==============================================================================
# wakubp :: GUI LAUNCHER (WINDOWS)
# WinForms front-end over src\engine.ps1 (sourced as a library, no console menu).
# Run via: wakubp.vbs (zero-flash) or wakubp.bat
# ==============================================================================

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$EnginePath = Join-Path $PSScriptRoot "engine.ps1"
if (-not (Test-Path -LiteralPath $EnginePath -PathType Leaf)) {
    [System.Windows.Forms.MessageBox]::Show("src\engine.ps1 not found next to src\gui.ps1.", "wakubp",
        [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    exit 1
}

# Source the engine as a library (dispatch/menu section self-skips when dot-sourced).
. $EnginePath
$global:WakuGui = $true

# --- palette -------------------------------------------------------------------
$Ice       = [System.Drawing.Color]::FromArgb(224, 242, 254)
$Cyan      = [System.Drawing.Color]::FromArgb(56, 189, 248)
$Green     = [System.Drawing.Color]::FromArgb(34, 197, 94)
$GreenGlow = [System.Drawing.Color]::FromArgb(74, 222, 128)
$Muted     = [System.Drawing.Color]::FromArgb(126, 147, 168)
$White     = [System.Drawing.Color]::FromArgb(232, 238, 245)
$Surface   = [System.Drawing.Color]::FromArgb(13, 20, 28)
$Hover     = [System.Drawing.Color]::FromArgb(21, 35, 47)
$RmSurface = [System.Drawing.Color]::FromArgb(18, 22, 30)
$RmHover   = [System.Drawing.Color]::FromArgb(46, 20, 28)
$Rose      = [System.Drawing.Color]::FromArgb(244, 63, 94)
$Divider   = [System.Drawing.Color]::FromArgb(22, 48, 63)

# --- GUI log & prompts (override engine defaults) -------------------------------
$global:WakuGuiLog = $null
$AnsiRe = "$([char]27)\[[0-9;]*m"

function global:Say([string]$m) {
    $box = $global:WakuGuiLog
    if ((-not $box) -or $box.IsDisposed) { return }
    $plain = ($m -replace $AnsiRe, "").TrimEnd()
    $color = [System.Drawing.Color]::FromArgb(154, 167, 179)
    if ($plain -match "INSTALL WAKU|DELETE WAKU|DELETE ANTIGRAVITY|INJECT OPENCODE|REMOVE OPENCODE|INJECT DEEPSEEK|REMOVE DEEPSEEK|INSTALLED & ACTIVE") {
        $color = [System.Drawing.Color]::FromArgb(125, 211, 252)
    } elseif ($plain -match "\[\!\]") {
        $color = [System.Drawing.Color]::FromArgb(245, 158, 11)
    } elseif ($plain -match "\[\=\]") {
        $color = [System.Drawing.Color]::FromArgb(34, 211, 238)
    } elseif ($plain -match "\[\+\]") {
        $color = [System.Drawing.Color]::FromArgb(52, 211, 153)
    }
    $box.SelectionStart = $box.TextLength
    $box.SelectionLength = 0
    $box.SelectionColor = $color
    $box.AppendText($plain + "`r`n")
    $box.SelectionColor = $box.ForeColor
    $box.ScrollToCaret()
}

function global:Confirm([string]$prompt, [string]$def = "y") {
    if ($AutoYes) { return $true }
    $defBtn = if ($def -eq "y") {
        [System.Windows.Forms.MessageBoxDefaultButton]::Button1
    } else {
        [System.Windows.Forms.MessageBoxDefaultButton]::Button2
    }
    $r = [System.Windows.Forms.MessageBox]::Show($prompt.Trim(), "wakubp",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question, $defBtn)
    return ($r -eq [System.Windows.Forms.DialogResult]::Yes)
}

# --- form ------------------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "wakubp"
$form.BackColor = [System.Drawing.Color]::FromArgb(7, 10, 14)
$form.ForeColor = $White
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.ClientSize = New-Object System.Drawing.Size(480, 520)
$IconFile = Join-Path $PSScriptRoot "waku.ico"
if (Test-Path -LiteralPath $IconFile -PathType Leaf) {
    try { $form.Icon = New-Object System.Drawing.Icon($IconFile) } catch {}
}

# --- header ----------------------------------------------------------------------
$header = New-Object System.Windows.Forms.Panel
$header.Location = New-Object System.Drawing.Point(0, 0)
$header.Size = New-Object System.Drawing.Size(480, 116)
$header.Add_Paint({
    param($sender, $e)
    $g = $e.Graphics
    $top = [System.Drawing.Color]::FromArgb(13, 22, 32)
    $bottom = [System.Drawing.Color]::FromArgb(7, 10, 14)
    $brush = New-Object System.Drawing.SolidBrush($top)
    $g.FillRectangle($brush, 0, 0, $sender.Width, $sender.Height)
    $brush.Dispose()
    $rect = New-Object System.Drawing.Rectangle(0, 0, $sender.Width, $sender.Height)
    $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $top, $bottom, 90)
    $g.FillRectangle($grad, $rect)
    $grad.Dispose()

    # accent bar
    $bar = New-Object System.Drawing.SolidBrush($Cyan)
    $g.FillRectangle($bar, 24, 28, 3, 50)
    $bar.Dispose()

    $titleFont = New-Object System.Drawing.Font("Segoe UI", 25, [System.Drawing.FontStyle]::Bold)
    $subFont = New-Object System.Drawing.Font("Segoe UI", 9)
    [System.Windows.Forms.TextRenderer]::DrawText($g, $BuildTag, $titleFont, (New-Object System.Drawing.Point(40, 22)), $Ice)
    [System.Windows.Forms.TextRenderer]::DrawText($g, "Bypass by waku on Teyvat", $subFont, (New-Object System.Drawing.Point(42, 62)), $Muted)
    $titleFont.Dispose()
    $subFont.Dispose()

    $line = New-Object System.Drawing.SolidBrush($Divider)
    $g.FillRectangle($line, 0, 113, $sender.Width, 1)
    $line.Dispose()
})
$form.Controls.Add($header)

# --- updater badge & logic -------------------------------------------------------
$RootDirLocal = Split-Path $PSScriptRoot -Parent
$LocalVerFile = Join-Path $RootDirLocal "version.json"
$LocalVersion = if ($env:WAKUBP_VERSION) { $env:WAKUBP_VERSION } else { "1.0.0" }
if ((-not $env:WAKUBP_VERSION) -and (Test-Path -LiteralPath $LocalVerFile -PathType Leaf)) {
    try { $LocalVersion = "$((Get-Content -LiteralPath $LocalVerFile -Raw | ConvertFrom-Json).version)" } catch {}
}
$UpdateManifestUrl = "https://raw.githubusercontent.com/takeshi7502/wakubp/master/version.json"
$script:RemoteUpdate = $null

$btnUpdate = New-Object System.Windows.Forms.Button
$btnUpdate.Location = New-Object System.Drawing.Point(344, 28)
$btnUpdate.Size = New-Object System.Drawing.Size(116, 26)
$btnUpdate.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnUpdate.FlatAppearance.BorderSize = 0
$btnUpdate.BackColor = $Surface
$btnUpdate.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnUpdate.Text = ""
$btnUpdate.Tag = @{ Text = "v$LocalVersion"; HasUpdate = $false; Hover = $false; Checking = $false }
$btnUpdate.Add_Paint({
    param($s, $e)
    $tag = $s.Tag
    $g = $e.Graphics
    $bg = if ($tag.HasUpdate) {
        if ($tag.Hover) { [System.Drawing.Color]::FromArgb(26, 72, 46) } else { [System.Drawing.Color]::FromArgb(18, 52, 34) }
    } else {
        if ($tag.Hover) { $Hover } else { $Surface }
    }
    $fill = New-Object System.Drawing.SolidBrush($bg)
    $g.FillRectangle($fill, 0, 0, $s.Width, $s.Height)
    $fill.Dispose()
    $borderCol = if ($tag.HasUpdate) { $GreenGlow } else { $Divider }
    $pen = New-Object System.Drawing.Pen($borderCol, 1)
    $g.DrawRectangle($pen, 0, 0, ($s.Width - 1), ($s.Height - 1))
    $pen.Dispose()
    $fg = if ($tag.HasUpdate) { $GreenGlow } elseif ($tag.Hover) { $Cyan } else { $Muted }
    $fnt = New-Object System.Drawing.Font("Consolas", 8.5, [System.Drawing.FontStyle]::Bold)
    $flags = [System.Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [System.Windows.Forms.TextFormatFlags]::VerticalCenter
    [System.Windows.Forms.TextRenderer]::DrawText($g, $tag.Text, $fnt, (New-Object System.Drawing.Rectangle(0, 0, $s.Width, $s.Height)), $fg, $flags)
    $fnt.Dispose()
})
$btnUpdate.Add_MouseEnter({ param($s, $e) $s.Tag.Hover = $true; $s.Invalidate() })
$btnUpdate.Add_MouseLeave({ param($s, $e) $s.Tag.Hover = $false; $s.Invalidate() })
$header.Controls.Add($btnUpdate)

function Compare-SemVer([string]$a, [string]$b) {
    try { return ([version]($a.TrimStart('v'))).CompareTo([version]($b.TrimStart('v'))) }
    catch { return [string]::Compare($a, $b, $true) }
}

function Invoke-SelfUpdate($info) {
    $exePath = $env:WAKUBP_EXE_PATH
    if (-not $exePath) {
        Say "   [=] Running from source (.bat). Run 'git pull' to update."
        return
    }
    $msg = "New version v$($info.version) is available (current: v$LocalVersion).`n`nChanges: $($info.notes)`n`nDownload and update now?"
    if (-not (Confirm $msg "y")) { return }

    Say "   [=] Downloading wakubp v$($info.version)..."
    $tmpExe = Join-Path ([System.IO.Path]::GetTempPath()) "wakubp-update.exe"
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "wakubp/$LocalVersion")
        $wc.DownloadFile($info.downloadUrl, $tmpExe)
        $wc.Dispose()
    } catch {
        Say "   [!] Download failed: $($_.Exception.Message)"
        return
    }

    if ($info.sha256) {
        $actual = (Get-FileHash -LiteralPath $tmpExe -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $info.sha256.ToLowerInvariant()) {
            Remove-Item -LiteralPath $tmpExe -Force -ErrorAction SilentlyContinue
            Say "   [!] SHA-256 mismatch! Update aborted for safety."
            return
        }
    }

    Say "   [+] Verified. Applying update and restarting..."
    $parentPid = if ($env:WAKUBP_PID) { $env:WAKUBP_PID } else { $PID }
    $swapScript = Join-Path ([System.IO.Path]::GetTempPath()) "wakubp-swap.ps1"
    $swapBody = @"
`$ErrorActionPreference = 'SilentlyContinue'
for (`$i = 0; `$i -lt 40; `$i++) {
    if (-not (Get-Process -Id $parentPid)) { break }
    Start-Sleep -Milliseconds 150
}
for (`$i = 0; `$i -lt 20; `$i++) {
    try {
        Copy-Item -LiteralPath '$($tmpExe.Replace("'","''"))' -Destination '$($exePath.Replace("'","''"))' -Force -ErrorAction Stop
        Remove-Item -LiteralPath '$($tmpExe.Replace("'","''"))' -Force
        Start-Process -FilePath '$($exePath.Replace("'","''"))'
        break
    } catch {
        Start-Sleep -Milliseconds 200
    }
}
Remove-Item -LiteralPath '$($swapScript.Replace("'","''"))' -Force
"@
    Set-Content -LiteralPath $swapScript -Value $swapBody -Encoding UTF8
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$swapScript`""
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    $form.Close()
}

function Start-UpdateCheck([bool]$interactive = $false) {
    if ($btnUpdate.Tag.Checking) { return }
    $btnUpdate.Tag.Checking = $true
    if ($interactive) {
        $btnUpdate.Tag.Text = "Checking..."
        $btnUpdate.Invalidate()
    }
    $script:UpdPs = [powershell]::Create()
    $script:UpdPs.AddScript({
        param($url, $ver)
        try {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            $req = [System.Net.HttpWebRequest]::Create($url)
            $req.Timeout = 3500
            $req.UserAgent = "wakubp/$ver"
            $resp = $req.GetResponse()
            $sr = New-Object System.IO.StreamReader($resp.GetResponseStream())
            $raw = $sr.ReadToEnd()
            $sr.Close()
            $resp.Close()
            return @{ ok = $true; json = $raw }
        } catch {
            return @{ ok = $false; err = $_.Exception.Message }
        }
    }).AddArgument($UpdateManifestUrl).AddArgument($LocalVersion) | Out-Null
    $script:UpdAsync = $script:UpdPs.BeginInvoke()

    if ($script:UpdTimer) {
        try { $script:UpdTimer.Stop(); $script:UpdTimer.Dispose() } catch {}
    }
    $script:UpdTimer = New-Object System.Windows.Forms.Timer
    $script:UpdTimer.Interval = 150
    $script:UpdTimer.Add_Tick({
        if (-not $script:UpdAsync -or -not $script:UpdAsync.IsCompleted) { return }
        $script:UpdTimer.Stop()
        $script:UpdTimer.Dispose()
        $script:UpdTimer = $null
        $res = $null
        try { $res = $script:UpdPs.EndInvoke($script:UpdAsync) } catch {}
        try { $script:UpdPs.Dispose() } catch {}
        $script:UpdPs = $null
        $script:UpdAsync = $null
        $btnUpdate.Tag.Checking = $false

        if ($res -and $res.Count -gt 0 -and $res[0].ok) {
            try {
                $info = $res[0].json | ConvertFrom-Json
                if ($info.version -and ((Compare-SemVer $info.version $LocalVersion) -gt 0)) {
                    $script:RemoteUpdate = $info
                    $btnUpdate.Tag.HasUpdate = $true
                    $btnUpdate.Tag.Text = "Update v$($info.version)"
                    $btnUpdate.Invalidate()
                    Say "   [+] Update available: v$($info.version) - $($info.notes)"
                    return
                }
            } catch {}
            $btnUpdate.Tag.Text = "v$LocalVersion"
            $btnUpdate.Invalidate()
            if ($interactive) { Say "   [=] wakubp v$LocalVersion is up to date." }
        } else {
            $btnUpdate.Tag.Text = "v$LocalVersion"
            $btnUpdate.Invalidate()
            if ($interactive) { Say "   [!] Update check unavailable (offline or private repo)." }
        }
    })
    $script:UpdTimer.Start()
}

$btnUpdate.Add_Click({
    if ($script:RemoteUpdate) { Invoke-SelfUpdate $script:RemoteUpdate }
    else { Start-UpdateCheck $true }
})

# --- menu rows -------------------------------------------------------------------
$buttons  = New-Object System.Collections.Generic.List[System.Windows.Forms.Button]
$mainRows = New-Object System.Collections.Generic.List[System.Windows.Forms.Button]

function New-MenuRow([string]$num, [string]$title, [string]$subtitle, [int]$top, [scriptblock]$onClick, [scriptblock]$onRemove = $null, [string]$removeLabel = "Remove", [string]$appKey = "") {
    $hasRemove = ($null -ne $onRemove)
    $mainWidth = if ($hasRemove) { 338 } else { 440 }

    $b = New-Object System.Windows.Forms.Button
    $b.Location = New-Object System.Drawing.Point(20, $top)
    $b.Size = New-Object System.Drawing.Size($mainWidth, 54)
    $b.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $b.FlatAppearance.BorderSize = 0
    $b.BackColor = $Surface
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    $b.Text = ""
    $b.Tag = @{ Num = $num; Title = $title; Subtitle = $subtitle; Hover = $false; AppKey = $appKey; Installed = $false }
    $b.Add_Paint({
        param($s, $e)
        $tag = $s.Tag
        $g = $e.Graphics
        $bg = if ($s.Enabled -and $tag.Hover) { $Hover } else { $Surface }
        $fill = New-Object System.Drawing.SolidBrush($bg)
        $g.FillRectangle($fill, 0, 0, $s.Width, $s.Height)
        $fill.Dispose()
        $barColor = if ($tag.Installed) {
            if ($tag.Hover) { $GreenGlow } else { $Green }
        } else {
            if ($tag.Hover) { $Cyan } else { [System.Drawing.Color]::FromArgb(27, 75, 99) }
        }
        $accent = New-Object System.Drawing.SolidBrush($barColor)
        $g.FillRectangle($accent, 0, 0, 3, $s.Height)
        $accent.Dispose()
        $numFont = New-Object System.Drawing.Font("Consolas", 14, [System.Drawing.FontStyle]::Bold)
        $titleFont = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        $subFont = New-Object System.Drawing.Font("Segoe UI", 8)
        $numColor = if ($tag.Installed) { $GreenGlow } else { $Cyan }
        [System.Windows.Forms.TextRenderer]::DrawText($g, $tag.Num, $numFont, (New-Object System.Drawing.Point(20, 15)), $numColor)
        [System.Windows.Forms.TextRenderer]::DrawText($g, $tag.Title, $titleFont, (New-Object System.Drawing.Point(62, 9)), $(if ($s.Enabled) { $White } else { $Muted }))
        [System.Windows.Forms.TextRenderer]::DrawText($g, $tag.Subtitle, $subFont, (New-Object System.Drawing.Point(62, 31)), $Muted)
        $numFont.Dispose()
        $titleFont.Dispose()
        $subFont.Dispose()
    })
    $b.Add_MouseEnter({ param($s, $e) $s.Tag.Hover = $true; $s.Invalidate() })
    $b.Add_MouseLeave({ param($s, $e) $s.Tag.Hover = $false; $s.Invalidate() })
    $b.Add_Click($onClick)
    $form.Controls.Add($b)
    $buttons.Add($b) | Out-Null
    $mainRows.Add($b) | Out-Null

    if ($hasRemove) {
        $rm = New-Object System.Windows.Forms.Button
        $rm.Location = New-Object System.Drawing.Point(366, $top)
        $rm.Size = New-Object System.Drawing.Size(94, 54)
        $rm.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $rm.FlatAppearance.BorderSize = 0
        $rm.BackColor = $RmSurface
        $rm.Cursor = [System.Windows.Forms.Cursors]::Hand
        $rm.Text = ""
        $rm.Tag = @{ Label = $removeLabel; Hover = $false }
        $rm.Add_Paint({
            param($s, $e)
            $tag = $s.Tag
            $g = $e.Graphics
            $bg = if ($s.Enabled -and $tag.Hover) { $RmHover } else { $RmSurface }
            $fill = New-Object System.Drawing.SolidBrush($bg)
            $g.FillRectangle($fill, 0, 0, $s.Width, $s.Height)
            $fill.Dispose()
            $accent = New-Object System.Drawing.SolidBrush($(if ($tag.Hover) { $Rose } else { [System.Drawing.Color]::FromArgb(76, 29, 44) }))
            $g.FillRectangle($accent, ($s.Width - 3), 0, 3, $s.Height)
            $accent.Dispose()
            $lblFont = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
            $fg = if (-not $s.Enabled) { $Muted } elseif ($tag.Hover) { $Rose } else { [System.Drawing.Color]::FromArgb(200, 140, 155) }
            $flags = [System.Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [System.Windows.Forms.TextFormatFlags]::VerticalCenter
            [System.Windows.Forms.TextRenderer]::DrawText($g, $tag.Label, $lblFont, (New-Object System.Drawing.Rectangle(0, 0, $s.Width, $s.Height)), $fg, $flags)
            $lblFont.Dispose()
        })
        $rm.Add_MouseEnter({ param($s, $e) $s.Tag.Hover = $true; $s.Invalidate() })
        $rm.Add_MouseLeave({ param($s, $e) $s.Tag.Hover = $false; $s.Invalidate() })
        $rm.Add_Click($onRemove)
        $form.Controls.Add($rm)
        $buttons.Add($rm) | Out-Null
    }
    return $b
}

New-MenuRow "1" "Antigravity"       "Install bypass + AGENT.md" 132 { Run-Action ${function:Action-Install} "Install" }      { Run-Action ${function:Action-Delete} "Delete" }        "Delete" "antigravity" | Out-Null
New-MenuRow "2" "OpenCode"          "Inject global AGENTS.md"   194 { Run-Action ${function:Action-InjectBypass} "Inject" }  { Run-Action ${function:Action-RemoveBypass} "Remove" }  "Remove" "opencode"    | Out-Null
New-MenuRow "3" "DeepSeek Harness"  "Inject global AGENTS.md"   256 { Run-Action ${function:Action-InjectDsh} "Inject DSH" } { Run-Action ${function:Action-RemoveDsh} "Remove DSH" } "Remove" "dsh"         | Out-Null
New-MenuRow "0" "Exit"              "Close this window"         318 { $form.Close() } | Out-Null

function Update-MenuStatus {
    try {
        $st = Get-AppInstallStatus
        foreach ($r in $mainRows) {
            $k = $r.Tag.AppKey
            if ($k -and $st.ContainsKey($k)) {
                $r.Tag.Installed = [bool]$st[$k]
                $r.Invalidate()
            }
        }
    } catch {}
}

# --- log -------------------------------------------------------------------------
$log = New-Object System.Windows.Forms.RichTextBox
$log.Location = New-Object System.Drawing.Point(20, 390)
$log.Size = New-Object System.Drawing.Size(440, 110)
$log.BackColor = [System.Drawing.Color]::FromArgb(5, 8, 11)
$log.ForeColor = [System.Drawing.Color]::FromArgb(154, 167, 179)
$log.Font = New-Object System.Drawing.Font("Consolas", 9)
$log.ReadOnly = $true
$log.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$log.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
$form.Controls.Add($log)
$global:WakuGuiLog = $log

function Run-Action([scriptblock]$action, [string]$name) {
    foreach ($b in $buttons) { $b.Enabled = $false }
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    try {
        Say ""
        & $action
    } catch {
        Say "   [!] $name failed: $($_.Exception.Message)"
    } finally {
        foreach ($b in $buttons) { $b.Enabled = $true }
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        Update-MenuStatus
    }
}

Update-MenuStatus
$form.Add_Shown({ Start-UpdateCheck $false })

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::Run($form)
exit 0
