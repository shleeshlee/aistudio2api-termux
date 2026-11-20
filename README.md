# aistudio2api-termux

在安卓手机的 [Termux](https://github.com/termux/termux-app) 里一键安装 [AIStudio2API](https://github.com/Mag1cFall/AIStudio2API)。

本仓库只有一个安装脚本，不修改上游程序：脚本下载上游发布的 `linux-arm64` 命令行版（静态链接，不依赖系统 C 库），再处理安卓上缺的那一点环境。

## 安装

Termux 请从 F-Droid 或 GitHub 安装（Play 商店版已停更）。打开 Termux 执行：

```sh
curl -fsSL https://raw.githubusercontent.com/shleeshlee/aistudio2api-termux/main/install.sh | bash
```

指定版本：

```sh
curl -fsSL https://raw.githubusercontent.com/shleeshlee/aistudio2api-termux/main/install.sh | bash -s -- v0.3.12
```

要求：64 位 ARM 手机（aarch64），绝大多数近年手机都是。

## 使用

| 操作 | 命令 |
| --- | --- |
| 启动 | `aistudio2api` |
| 停止 | 在它的窗口按 `Ctrl+C` |
| 更新 | `aistudio2api update`（先停掉服务） |
| 其他子命令 | `aistudio2api setup ...` 等，参数原样转给上游程序 |

启动后用手机浏览器打开 `http://127.0.0.1:2048` 进入管理页面。手机上的酒馆、聊天 App 把 API 地址填 `http://127.0.0.1:2048/v1`（OpenAI 格式）。

程序和数据都在 `~/aistudio2api/`：`.env` 是配置，`auth/` 是账号，`runtime/` 是数据库和日志。更新只替换程序本身，这三项保留。

## 添加账号

手机上运行不了上游的浏览器登录（Camoufox）。可用的两种方式：

1. **粘贴 Cookie**：在能装扩展的浏览器（如 Kiwi、狐猴）里装 Cookie-Editor，登录 aistudio.google.com 后导出 JSON，到管理页面「添加账户 → 粘贴 Cookie」。
2. **电脑远程添加**：管理页面「添加账户 → 远程添加」会给出一条命令，在能登录 Google 的电脑上运行，账号会推送到手机。电脑和手机要能互相访问（同一局域网时，手机端需把 `.env` 里的 `LISTEN_ADDR` 改成 `0.0.0.0:2048`，并设置 `PROXY_API_KEY` 和管理密码）。

## 保持后台运行

安卓会杀后台进程，建议：

- 启动时脚本会自动 `termux-wake-lock`（通知栏出现 Termux 常驻通知）
- 系统设置里把 Termux 的电池优化设为「不限制」
- Android 12 及以上如果仍被杀，在电脑上用 adb 关闭「幻影进程限制」：
  `adb shell device_config put activity_manager max_phantom_processes 2147483647`

## 脚本做了什么

1. `pkg install` proot、curl、tar、ca-certificates、resolv-conf
2. 从上游 Releases 下载 `linux-arm64` 包，程序放到 `~/aistudio2api/aistudio2api`
3. 生成启动命令 `$PREFIX/bin/aistudio2api`，用 `proot -b $PREFIX/etc/resolv.conf:/etc/resolv.conf` 启动程序

为什么要 proot：上游程序用 Go 自带的 DNS 解析器，读 `/etc/resolv.conf` 找 DNS 服务器；安卓没有这个文件，不处理的话所有域名都解析失败。这里的 proot 只做这一个文件的映射，不安装 Linux 发行版。

## 已知限制

- 只能用 SpiderMonkey 后端（默认），`WAA_BACKEND=camoufox` 在手机上不可用
- 从 Chrome 导入、指纹浏览器导入是电脑功能，手机上不可用
- 问题与功能请求属于上游程序的，请到 [上游仓库](https://github.com/Mag1cFall/AIStudio2API/issues) 反馈；本仓库只处理 Termux 安装相关问题

## 许可

安装脚本以 MIT 许可发布。AIStudio2API 本身的许可见上游仓库。
