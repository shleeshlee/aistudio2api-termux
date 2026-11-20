#!/data/data/com.termux/files/usr/bin/bash
# AIStudio2API Termux 安装脚本
# 下载官方 linux-arm64 命令行版，用 proot 把 Termux 的 resolv.conf 映射到 /etc，
# 生成 aistudio2api 启动命令。重复运行即更新到最新版（数据保留）。
#
# 用法：
#   curl -fsSL https://raw.githubusercontent.com/shleeshlee/aistudio2api-termux/main/install.sh | bash
#   指定版本：... | bash -s -- v0.3.12
set -euo pipefail

UPSTREAM="Mag1cFall/AIStudio2API"
BACKUP="shleeshlee/AIStudio2API" # 上游删库或停更时的备份 fork
APP_DIR="${AISTUDIO2API_HOME:-$HOME/aistudio2api}"
TAG="${1:-}"

say() { printf '\033[1;36m[aistudio2api]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[aistudio2api] %s\033[0m\n' "$*" >&2; exit 1; }

[ -n "${PREFIX:-}" ] && [ -d "$PREFIX" ] || die "请在 Termux 里运行"
case "$(uname -m)" in
  aarch64|arm64) ;;
  *) die "只支持 64 位 ARM 手机（当前 $(uname -m)）；官方没有 32 位 ARM 包" ;;
esac

# 只装缺的包，已有的不碰：减少 apt 工作量，也避免顺带升级正在用的库
NEED=""
command -v proot >/dev/null 2>&1 || NEED="$NEED proot"
command -v curl  >/dev/null 2>&1 || NEED="$NEED curl"
command -v tar   >/dev/null 2>&1 || NEED="$NEED tar"
[ -s "$PREFIX/etc/tls/cert.pem" ] || NEED="$NEED ca-certificates"
[ -e "$PREFIX/etc/resolv.conf" ]  || NEED="$NEED resolv-conf"
if [ -n "$NEED" ]; then
  say "安装依赖:$NEED"
  # shellcheck disable=SC2086
  apt-get install -y --no-upgrade $NEED </dev/null || {
    say "直接安装失败，先刷新软件源再试"
    apt-get update </dev/null && apt-get install -y --no-upgrade $NEED </dev/null
  } || die "依赖安装失败。可以先单独运行：pkg install$NEED"
else
  say "依赖已齐全"
fi

if [ -z "$TAG" ]; then
  say "查询最新版本"
  # 跟随 releases/latest 的跳转拿版本号：不走 API（无限流），也没有管道提前关闭导致 curl 报 23
  # 上游不可用时改用备份 fork
  for src in "$UPSTREAM" "$BACKUP"; do
    LATEST_URL="$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/$src/releases/latest" 2>/dev/null)" || continue
    TAG="${LATEST_URL##*/tag/}"
    if [ "$TAG" != "$LATEST_URL" ] && [ -n "$TAG" ]; then
      [ "$src" = "$UPSTREAM" ] || say "上游不可用，改用备份 $src"
      break
    fi
    TAG=""
  done
  [ -n "$TAG" ] || die "查不到最新版本，可以手动指定：bash -s -- v0.3.12"
fi

PKG="aistudio2api-$TAG-linux-arm64"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say "下载 $TAG"
GOT=false
for src in "$UPSTREAM" "$BACKUP"; do
  if curl -fL --progress-bar "https://github.com/$src/releases/download/$TAG/$PKG.tar.gz" -o "$TMP/pkg.tar.gz"; then
    GOT=true; break
  fi
  say "从 $src 下载失败，换下一个来源"
done
$GOT || die "下载失败：上游和备份都下不到 $TAG"
tar -xzf "$TMP/pkg.tar.gz" -C "$TMP"
[ -f "$TMP/$PKG/aistudio2api" ] || die "压缩包里没有 aistudio2api，上游包结构可能变了"

mkdir -p "$APP_DIR"
if pgrep -f "$APP_DIR/aistudio2api" >/dev/null 2>&1; then
  die "服务正在运行，先在它的窗口按 Ctrl+C 停掉再更新"
fi
install -m 755 "$TMP/$PKG/aistudio2api" "$APP_DIR/aistudio2api"
echo "$TAG" > "$APP_DIR/.termux-version"

# Go 的 netgo 解析器读 /etc/resolv.conf；安卓没有这个文件，DNS 会全部失败
RESOLV="$PREFIX/etc/resolv.conf"
if [ ! -s "$RESOLV" ]; then
  printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' > "$RESOLV"
fi

LAUNCHER="$PREFIX/bin/aistudio2api"
cat > "$LAUNCHER" <<EOF
#!$PREFIX/bin/bash
# 由 aistudio2api-termux 生成；重新运行 install.sh 会覆盖
cd "$APP_DIR"
if [ "\${1:-}" = "update" ]; then
  shift
  exec bash -c "\$(curl -fsSL https://raw.githubusercontent.com/shleeshlee/aistudio2api-termux/main/install.sh)" -- "\$@"
fi
if [ \$# -eq 0 ]; then
  termux-wake-lock 2>/dev/null || true
fi
export SSL_CERT_FILE="$PREFIX/etc/tls/cert.pem"
# termux-exec 的 LD_PRELOAD 会让系统加载器接手，静态程序报 "unexpected e_type: 2"
unset LD_PRELOAD
exec proot -b "$RESOLV:/etc/resolv.conf" "$APP_DIR/aistudio2api" "\$@"
EOF
chmod 755 "$LAUNCHER"

say "完成：$TAG 已装到 $APP_DIR"
cat <<EOF

  启动服务：   aistudio2api
  管理页面：   手机浏览器打开 http://127.0.0.1:2048
  更新：       aistudio2api update
  导入账号：   见 README「添加账号」（手机上不能用浏览器登录，用粘贴 Cookie 或电脑远程添加）

EOF
