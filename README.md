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

## 中文说明

使用进程级代理环境变量启动 Codex Desktop。

当 Codex 的普通 HTTP 请求可以走代理，但 WebSocket 连接不能稳定遵循系统代理时，这个工具会有帮助。通过在 Codex 进程环境中设置 `HTTP_PROXY`、`HTTPS_PROXY` 和 `ALL_PROXY`，可以让 HTTP 和 WebSocket 流量都使用本地 Clash 代理，而不需要开启 TUN 模式。

## 支持的平台

- macOS: `codex-proxy`
- Windows: `codex-proxy.ps1`

## 默认配置

两个脚本默认使用以下代理配置：

```text
HTTP proxy:  http://127.0.0.1:7890
ALL proxy:   socks5://127.0.0.1:7890
NO_PROXY:    localhost,127.0.0.1,::1
```

可以通过环境变量覆盖默认值：

```bash
CODEX_HTTP_PROXY=http://127.0.0.1:7890
CODEX_ALL_PROXY=socks5://127.0.0.1:7890
CODEX_NO_PROXY=localhost,127.0.0.1,::1
```

在 Windows 上，如果脚本无法自动找到 Codex，也可以把 `CODEX_EXE` 设置为 `Codex.exe` 的完整路径。
如果想把日志和 pid 文件放到 `%LOCALAPPDATA%\codex-proxy` 以外的位置，可以设置 `CODEX_PROXY_STATE_DIR`。
对于 Microsoft Store/Appx 版本，脚本会通过 `shell:AppsFolder` 启动 Codex，因为 Windows 不允许直接运行 `C:\Program Files\WindowsApps` 下的应用。脚本只会在启动窗口期临时写入 `HKCU:\Environment` 中的代理变量，启动后会恢复之前的值。

## macOS 使用说明

安装：

```bash
mkdir -p ~/bin
cp codex-proxy ~/bin/codex-proxy
chmod +x ~/bin/codex-proxy
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

使用：

```bash
codex-proxy start
codex-proxy stop
codex-proxy restart
codex-proxy status
codex-proxy log
```

macOS 专用环境变量：

```bash
export CODEX_APP="/Applications/Codex.app"
```

日志位置：

```text
~/Library/Logs/codex-proxy.log
```

## Windows 使用说明

在 PowerShell 中运行：

```powershell
.\codex-proxy.ps1 start
.\codex-proxy.ps1 stop
.\codex-proxy.ps1 restart
.\codex-proxy.ps1 status
.\codex-proxy.ps1 log
```

如果 PowerShell 阻止运行本地脚本，可以在当前 shell 中先执行一次：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

如果脚本没有自动找到 Codex：

```powershell
$env:CODEX_EXE = "$env:LOCALAPPDATA\Programs\Codex\Codex.exe"
.\codex-proxy.ps1 start
```

持久化自定义代理配置：

```powershell
[Environment]::SetEnvironmentVariable("CODEX_HTTP_PROXY", "http://127.0.0.1:7890", "User")
[Environment]::SetEnvironmentVariable("CODEX_ALL_PROXY", "socks5://127.0.0.1:7890", "User")
[Environment]::SetEnvironmentVariable("CODEX_NO_PROXY", "localhost,127.0.0.1,::1", "User")
```

手动为 Codex App 设置代理环境变量：

```powershell
[Environment]::SetEnvironmentVariable("HTTP_PROXY", "http://127.0.0.1:7890", "User")
[Environment]::SetEnvironmentVariable("HTTPS_PROXY", "http://127.0.0.1:7890", "User")
[Environment]::SetEnvironmentVariable("ALL_PROXY", "socks5://127.0.0.1:7890", "User")
[Environment]::SetEnvironmentVariable("NO_PROXY", "localhost,127.0.0.1,::1", "User")
```

手动设置用户环境变量后，需要完全退出并重启 Codex App，新进程才能读取到这些变量。如果 Codex 仍在后台运行，可以从任务管理器关闭它，或运行：

```powershell
Stop-Process -Name Codex -Force
```

然后从开始菜单重新打开 Codex App。

查看当前 proxy 变量：

```powershell
Get-ChildItem Env:*PROXY*
[Environment]::GetEnvironmentVariable("HTTP_PROXY", "User")
[Environment]::GetEnvironmentVariable("HTTPS_PROXY", "User")
[Environment]::GetEnvironmentVariable("ALL_PROXY", "User")
[Environment]::GetEnvironmentVariable("NO_PROXY", "User")
```

日志位置：

```text
%LOCALAPPDATA%\codex-proxy\Logs\codex-proxy.log
```

## 工作原理

脚本会先关闭已有的 Codex 进程，然后带着以下环境变量重新启动 Codex：

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

这样 Codex 及其子进程就会通过本地代理连接网络，包括那些会读取进程级代理变量、但不能完全遵循操作系统代理设置的 WebSocket 客户端。

## License

MIT
