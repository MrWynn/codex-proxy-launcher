param(
  [ValidateSet("start", "stop", "restart", "status", "log")]
  [string]$Command = "start"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$HttpProxy = if ($env:CODEX_HTTP_PROXY) { $env:CODEX_HTTP_PROXY } else { "http://127.0.0.1:7890" }
$AllProxy = if ($env:CODEX_ALL_PROXY) { $env:CODEX_ALL_PROXY } else { "socks5://127.0.0.1:7890" }
$NoProxy = if ($env:CODEX_NO_PROXY) { $env:CODEX_NO_PROXY } else { "localhost,127.0.0.1,::1" }

$StateDir = if ($env:CODEX_PROXY_STATE_DIR) {
  $env:CODEX_PROXY_STATE_DIR
} else {
  Join-Path $env:LOCALAPPDATA "codex-proxy"
}
$LogDir = Join-Path $StateDir "Logs"
$LogFile = Join-Path $LogDir "codex-proxy.log"
$PidFile = Join-Path $StateDir "codex.pid"

New-Item -ItemType Directory -Force -Path $StateDir, $LogDir | Out-Null

function Write-Log {
  param([string]$Message)
  $line = "{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
  Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Resolve-ShortcutTarget {
  param([string]$ShortcutPath)

  try {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($ShortcutPath)
    if ($shortcut.TargetPath -and (Test-Path -LiteralPath $shortcut.TargetPath)) {
      return $shortcut.TargetPath
    }
  } catch {
    return $null
  }

  return $null
}

function Send-EnvironmentChanged {
  try {
    if (-not ("NativeMethods" -as [type])) {
      Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class NativeMethods {
  [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
  public static extern IntPtr SendMessageTimeout(
    IntPtr hWnd,
    uint Msg,
    UIntPtr wParam,
    string lParam,
    uint fuFlags,
    uint uTimeout,
    out UIntPtr lpdwResult);
}
"@
    }

    $result = [UIntPtr]::Zero
    [NativeMethods]::SendMessageTimeout(
      [IntPtr]0xffff,
      0x001A,
      [UIntPtr]::Zero,
      "Environment",
      0x0002,
      5000,
      [ref]$result
    ) | Out-Null
  } catch {
    Write-Log "Send-EnvironmentChanged failed: $($_.Exception.Message)"
  }
}

function Get-UserEnvironmentValue {
  param([string]$Name)

  $key = "HKCU:\Environment"
  $property = Get-ItemProperty -Path $key -Name $Name -ErrorAction SilentlyContinue
  if ($null -eq $property) {
    return [pscustomobject]@{ Exists = $false; Value = $null }
  }

  [pscustomobject]@{ Exists = $true; Value = $property.$Name }
}

function Set-UserEnvironmentValue {
  param(
    [string]$Name,
    [AllowNull()][string]$Value,
    [bool]$Exists
  )

  $key = "HKCU:\Environment"
  if ($Exists) {
    Set-ItemProperty -Path $key -Name $Name -Value $Value
  } else {
    Remove-ItemProperty -Path $key -Name $Name -ErrorAction SilentlyContinue
  }
}

function Get-CodexAppxInfo {
  try {
    $package = Get-AppxPackage -Name "OpenAI.Codex" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $package) {
      return $null
    }

    $manifestPath = Join-Path $package.InstallLocation "AppxManifest.xml"
    if (-not (Test-Path -LiteralPath $manifestPath)) {
      return $null
    }

    [xml]$manifest = Get-Content -LiteralPath $manifestPath
    $application = $manifest.Package.Applications.Application | Select-Object -First 1
    if (-not $application) {
      return $null
    }

    [pscustomobject]@{
      PackageFamilyName = $package.PackageFamilyName
      AppId = $application.Id
      InstallLocation = $package.InstallLocation
      Executable = (Join-Path $package.InstallLocation $application.Executable)
      ShellTarget = "shell:AppsFolder\$($package.PackageFamilyName)!$($application.Id)"
    }
  } catch {
    Write-Log "Get-CodexAppxInfo failed: $($_.Exception.Message)"
    return $null
  }
}

function Get-CodexExecutable {
  $candidates = New-Object System.Collections.Generic.List[string]

  if ($env:CODEX_EXE) {
    $candidates.Add($env:CODEX_EXE)
  }

  if ($env:CODEX_APP) {
    if (Test-Path -LiteralPath $env:CODEX_APP -PathType Leaf) {
      $candidates.Add($env:CODEX_APP)
    } elseif (Test-Path -LiteralPath $env:CODEX_APP -PathType Container) {
      $candidates.Add((Join-Path $env:CODEX_APP "Codex.exe"))
      $candidates.Add((Join-Path $env:CODEX_APP "app\Codex.exe"))
    }
  }

  Get-CimInstance Win32_Process -Filter "Name = 'Codex.exe'" -ErrorAction SilentlyContinue |
    Where-Object {
      $_.ExecutablePath -and
      $_.ExecutablePath -like "*\app\Codex.exe" -and
      ($_.CommandLine -notmatch "--type=")
    } |
    Select-Object -ExpandProperty ExecutablePath -First 5 |
    ForEach-Object { $candidates.Add($_) }

  $appx = Get-CodexAppxInfo
  if ($appx) {
    $candidates.Add($appx.Executable)
  }

  $knownDirs = @(
    (Join-Path $env:LOCALAPPDATA "Programs\Codex"),
    (Join-Path $env:LOCALAPPDATA "Codex"),
    (Join-Path $env:ProgramFiles "Codex")
  )

  if (${env:ProgramFiles(x86)}) {
    $knownDirs += (Join-Path ${env:ProgramFiles(x86)} "Codex")
  }

  foreach ($dir in $knownDirs) {
    $candidates.Add((Join-Path $dir "Codex.exe"))
  }

  $shortcutDirs = @(
    (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"),
    (Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs")
  )

  foreach ($dir in $shortcutDirs) {
    if (Test-Path -LiteralPath $dir -PathType Container) {
      Get-ChildItem -LiteralPath $dir -Filter "Codex*.lnk" -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 10 |
        ForEach-Object {
          $target = Resolve-ShortcutTarget -ShortcutPath $_.FullName
          if ($target) {
            $candidates.Add($target)
          }
        }
    }
  }

  foreach ($candidate in ($candidates | Select-Object -Unique)) {
    if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }

  throw "Cannot find Codex.exe. Set CODEX_EXE to the full Codex.exe path and retry."
}

function Test-IsAppxExecutable {
  param([string]$Exe)

  $appx = Get-CodexAppxInfo
  if (-not $appx) {
    return $false
  }

  try {
    $resolvedExe = (Resolve-Path -LiteralPath $Exe).Path
    $resolvedAppxExe = (Resolve-Path -LiteralPath $appx.Executable).Path
    return $resolvedExe -eq $resolvedAppxExe
  } catch {
    return $false
  }
}

function Get-CodexProcesses {
  param([string]$Exe)

  Get-CimInstance Win32_Process -Filter "Name = 'Codex.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.ExecutablePath -eq $Exe } |
    ForEach-Object {
      [pscustomobject]@{
        Id = $_.ProcessId
        ProcessName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
        Path = $_.ExecutablePath
        CommandLine = $_.CommandLine
        IsMain = ($_.CommandLine -notmatch "--type=")
      }
    }
}

function Stop-Codex {
  param([string]$Exe)

  Write-Host "Stopping Codex..."
  Write-Log "Stopping Codex"

  $processes = @(Get-CodexProcesses -Exe $Exe)
  foreach ($process in ($processes | Where-Object { $_.IsMain })) {
    try {
      $nativeProcess = Get-Process -Id $process.Id -ErrorAction Stop
      $nativeProcess.CloseMainWindow() | Out-Null
    } catch {
      Write-Log "CloseMainWindow failed for PID $($process.Id): $($_.Exception.Message)"
    }
  }

  Start-Sleep -Seconds 1

  $remaining = @(Get-CodexProcesses -Exe $Exe)
  foreach ($process in $remaining) {
    try {
      Stop-Process -Id $process.Id -Force
    } catch {
      Write-Log "Stop-Process failed for PID $($process.Id): $($_.Exception.Message)"
    }
  }

  Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
}

function Invoke-WithProxyEnvironment {
  param([scriptblock]$Script)

  $proxyNames = @(
    "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY",
    "http_proxy", "https_proxy", "all_proxy",
    "NO_PROXY", "no_proxy"
  )

  $oldValues = @{}
  foreach ($name in $proxyNames) {
    $oldValues[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
  }

  try {
    $env:HTTP_PROXY = $HttpProxy
    $env:HTTPS_PROXY = $HttpProxy
    $env:ALL_PROXY = $AllProxy
    $env:http_proxy = $HttpProxy
    $env:https_proxy = $HttpProxy
    $env:all_proxy = $AllProxy
    $env:NO_PROXY = $NoProxy
    $env:no_proxy = $NoProxy

    & $Script
  } finally {
    foreach ($name in $proxyNames) {
      [Environment]::SetEnvironmentVariable($name, $oldValues[$name], "Process")
    }
  }
}

function Start-AppxCodex {
  param([string]$Exe)

  $appx = Get-CodexAppxInfo
  if (-not $appx) {
    throw "Cannot find Codex Appx package metadata."
  }

  Write-Log "Launching Appx Codex through $($appx.ShellTarget)"

  $proxyValues = @(
    [pscustomobject]@{ Name = "HTTP_PROXY"; Value = $HttpProxy },
    [pscustomobject]@{ Name = "HTTPS_PROXY"; Value = $HttpProxy },
    [pscustomobject]@{ Name = "ALL_PROXY"; Value = $AllProxy },
    [pscustomobject]@{ Name = "NO_PROXY"; Value = $NoProxy }
  )

  $oldUserValues = @{}
  foreach ($proxyValue in $proxyValues) {
    $oldUserValues[$proxyValue.Name] = Get-UserEnvironmentValue -Name $proxyValue.Name
  }

  try {
    foreach ($proxyValue in $proxyValues) {
      Set-ItemProperty -Path "HKCU:\Environment" -Name $proxyValue.Name -Value $proxyValue.Value
    }
    Send-EnvironmentChanged

    Invoke-WithProxyEnvironment {
      Start-Process explorer.exe $appx.ShellTarget
    }

    $deadline = (Get-Date).AddSeconds(10)
    do {
      Start-Sleep -Milliseconds 500
      $running = @(Get-CodexProcesses -Exe $Exe | Where-Object { $_.IsMain })
    } while ($running.Count -eq 0 -and (Get-Date) -lt $deadline)

    if ($running.Count -gt 0) {
      Set-Content -Path $PidFile -Value $running[0].Id -Encoding ASCII
      Write-Log "Started Appx Codex PID: $($running[0].Id)"
    }
  } finally {
    foreach ($proxyValue in $proxyValues) {
      $oldValue = $oldUserValues[$proxyValue.Name]
      Set-UserEnvironmentValue -Name $proxyValue.Name -Value $oldValue.Value -Exists $oldValue.Exists
    }
    Send-EnvironmentChanged
  }
}

function Start-Codex {
  $exe = Get-CodexExecutable

  Write-Host "Starting Codex with proxy..."
  Write-Host "Executable: $exe"
  Write-Host "HTTP_PROXY: $HttpProxy"
  Write-Host "ALL_PROXY: $AllProxy"
  Write-Host "Log: $LogFile"

  Write-Log "Starting Codex with proxy"
  Write-Log "Executable: $exe"
  Write-Log "HTTP_PROXY: $HttpProxy"
  Write-Log "ALL_PROXY: $AllProxy"

  Stop-Codex -Exe $exe

  if (Test-IsAppxExecutable -Exe $exe) {
    Start-AppxCodex -Exe $exe
  } else {
    Invoke-WithProxyEnvironment {
      $process = Start-Process -FilePath $exe -WorkingDirectory (Split-Path -Parent $exe) -PassThru
      Set-Content -Path $PidFile -Value $process.Id -Encoding ASCII
      Write-Log "Started Codex PID: $($process.Id)"
    }
  }

  Start-Sleep -Seconds 1

  $running = @(Get-CodexProcesses -Exe $exe)
  if ($running.Count -gt 0) {
    Write-Host "Codex started."
    $running | Select-Object Id, ProcessName, Path | Format-Table -AutoSize
  } else {
    Write-Host "Codex may not have started. Check log: $LogFile"
    exit 1
  }
}

function Show-Status {
  $exe = Get-CodexExecutable
  $running = @(Get-CodexProcesses -Exe $exe)

  if ($running.Count -gt 0) {
    Write-Host "Codex is running."
    $running | Select-Object Id, ProcessName, Path | Format-Table -AutoSize
  } else {
    Write-Host "Codex is not running."
  }
}

function Show-Log {
  if (!(Test-Path -LiteralPath $LogFile)) {
    New-Item -ItemType File -Force -Path $LogFile | Out-Null
  }

  Get-Content -Path $LogFile -Tail 100 -Wait
}

switch ($Command) {
  "start" { Start-Codex }
  "stop" { Stop-Codex -Exe (Get-CodexExecutable) }
  "restart" {
    $exe = Get-CodexExecutable
    Stop-Codex -Exe $exe
    Start-Codex
  }
  "status" { Show-Status }
  "log" { Show-Log }
}
