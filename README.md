# codex-proxy

让 macOS 版 [Codex](https://github.com/openai/codex) 通过 Clash 代理联网的启动脚本。解决在不开启 TUN 模式的情况下，Codex App 无法走代理访问 API 的问题，同时不影响其他 App 的代理设置。

## 背景

macOS 下用 Codex App + Clash 环境时，如果不开 TUN 模式，Codex 无法通过代理连接后端服务。开启 TUN 模式会影响整机网络流量。这个脚本通过环境变量注入代理配置，只让 Codex 进程走代理。

## 前置条件

- macOS
- [Clash](https://github.com/Dreamacro/clash) 或兼容客户端（Clash Verge、ClashX 等）
- 代理端口默认 `7890`（Clash 默认端口）

## 安装

```bash
mkdir -p ~/bin

# 将 codex-proxy 脚本复制到 ~/bin/
cp codex-proxy ~/bin/codex-proxy
chmod +x ~/bin/codex-proxy

# 确保 ~/bin 在 PATH 中
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## 使用

```bash
codex-proxy start     # 启动 Codex（带代理）
codex-proxy stop      # 退出 Codex
codex-proxy restart   # 重启 Codex
codex-proxy status    # 查看运行状态
codex-proxy log       # 实时查看日志
```

## 自定义配置

通过环境变量覆盖默认值：

```bash
# 自定义 Codex App 路径
export CODEX_APP="/Applications/Codex.app"

# 自定义 HTTP 代理地址
export CODEX_HTTP_PROXY="http://127.0.0.1:7890"

# 自定义 SOCKS5 代理地址
export CODEX_ALL_PROXY="socks5://127.0.0.1:7890"

# 自定义不走代理的地址列表
export CODEX_NO_PROXY="localhost,127.0.0.1,::1"
```

可将以上配置写入 `~/.zshrc` 持久化。

## 原理

Codex App 启动时，通过 `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY` 等环境变量注入代理配置，使 Codex 进程的所有网络请求经过 Clash 代理转发。脚本在启动前会先退出已有的 Codex 进程，确保不带代理的残留进程不存在。

## 日志

日志文件位于 `~/Library/Logs/codex-proxy.log`。

## License

MIT
