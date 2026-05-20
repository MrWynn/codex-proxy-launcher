# codex-proxy-launcher

Start Codex Desktop with process-level proxy environment variables.

This is useful when Codex can make normal HTTP requests through a proxy, but WebSocket connections do not reliably follow the system proxy. Starting Codex with `HTTP_PROXY`, `HTTPS_PROXY`, and `ALL_PROXY` in its process environment can make both HTTP and WebSocket traffic use the local Clash proxy without enabling TUN mode.

## Supported Platforms

- macOS: `codex-proxy`
- Windows: `codex-proxy.ps1`

## Defaults

Both scripts use these defaults:

```text
HTTP proxy:  http://127.0.0.1:7890
ALL proxy:   socks5://127.0.0.1:7890
NO_PROXY:    localhost,127.0.0.1,::1
```

Override them with environment variables:

```bash
CODEX_HTTP_PROXY=http://127.0.0.1:7890
CODEX_ALL_PROXY=socks5://127.0.0.1:7890
CODEX_NO_PROXY=localhost,127.0.0.1,::1
```

On Windows, you can also set `CODEX_EXE` to the full `Codex.exe` path if auto-detection does not find it.
Set `CODEX_PROXY_STATE_DIR` if you want logs and pid files somewhere other than `%LOCALAPPDATA%\codex-proxy`.
For the Microsoft Store/Appx build, the script launches Codex through `shell:AppsFolder` because Windows blocks direct execution from `C:\Program Files\WindowsApps`. It temporarily writes the proxy variables to `HKCU:\Environment` only for the launch window, then restores the previous values.

## macOS

Install:

```bash
mkdir -p ~/bin
cp codex-proxy ~/bin/codex-proxy
chmod +x ~/bin/codex-proxy
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Usage:

```bash
codex-proxy start
codex-proxy stop
codex-proxy restart
codex-proxy status
codex-proxy log
```

macOS-specific environment variable:

```bash
export CODEX_APP="/Applications/Codex.app"
```

Logs:

```text
~/Library/Logs/codex-proxy.log
```

## Windows

Run from PowerShell:

```powershell
.\codex-proxy.ps1 start
.\codex-proxy.ps1 stop
.\codex-proxy.ps1 restart
.\codex-proxy.ps1 status
.\codex-proxy.ps1 log
```

If PowerShell blocks local scripts, run this once in the current shell:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

If Codex is not found automatically:

```powershell
$env:CODEX_EXE = "$env:LOCALAPPDATA\Programs\Codex\Codex.exe"
.\codex-proxy.ps1 start
```

Persist custom proxy settings:

```powershell
[Environment]::SetEnvironmentVariable("CODEX_HTTP_PROXY", "http://127.0.0.1:7890", "User")
[Environment]::SetEnvironmentVariable("CODEX_ALL_PROXY", "socks5://127.0.0.1:7890", "User")
[Environment]::SetEnvironmentVariable("CODEX_NO_PROXY", "localhost,127.0.0.1,::1", "User")
```

Manually set proxy environment variables for Codex App:

```powershell
[Environment]::SetEnvironmentVariable("HTTP_PROXY", "http://127.0.0.1:7890", "User")
[Environment]::SetEnvironmentVariable("HTTPS_PROXY", "http://127.0.0.1:7890", "User")
[Environment]::SetEnvironmentVariable("ALL_PROXY", "socks5://127.0.0.1:7890", "User")
[Environment]::SetEnvironmentVariable("NO_PROXY", "localhost,127.0.0.1,::1", "User")
```

After setting user environment variables manually, fully quit and restart Codex App so the new process can read them. If Codex is still running in the background, close it from Task Manager or run:

```powershell
Stop-Process -Name Codex -Force
```

Then open Codex App again from the Start menu.

View the current proxy variables:

```powershell
Get-ChildItem Env:*PROXY*
[Environment]::GetEnvironmentVariable("HTTP_PROXY", "User")
[Environment]::GetEnvironmentVariable("HTTPS_PROXY", "User")
[Environment]::GetEnvironmentVariable("ALL_PROXY", "User")
[Environment]::GetEnvironmentVariable("NO_PROXY", "User")
```

Logs:

```text
%LOCALAPPDATA%\codex-proxy\Logs\codex-proxy.log
```

## How It Works

The scripts first close any existing Codex process, then relaunch Codex with these environment variables:

```text
HTTP_PROXY
HTTPS_PROXY
ALL_PROXY
http_proxy
https_proxy
all_proxy
NO_PROXY
no_proxy
```

That makes Codex and its child processes connect through the local proxy, including WebSocket clients that read process-level proxy variables but do not fully honor the OS system proxy.

## License

MIT
