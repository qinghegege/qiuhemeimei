#!/system/bin/sh
#===============================================================================
# qiuhe Web UI 服务启动脚本
#===============================================================================

WEB_DIR="$(cd "$(dirname "$0")" && pwd)"
QIUHE_HOME="$(dirname "$WEB_DIR")"
PORT="${1:-8848}"

# 加载核心库
. "$QIUHE_HOME/lib/common.sh"

start_web() {
    log_info "正在启动 qiuhe Web UI..."

    if ! command -v busybox >/dev/null 2>&1; then
        log_err "需要 busybox (httpd 功能)"
        log_err "请安装 busybox 后重试"
        exit 1
    fi

    if ! busybox httpd --help >/dev/null 2>&1; then
        log_err "当前 busybox 不支持 httpd"
        log_err "请安装完整版 busybox"
        exit 1
    fi

    cp "$QIUHE_HOME/lib/games.sh" "$WEB_DIR/" 2>/dev/null
    cp "$QIUHE_HOME/lib/games.ini" "$WEB_DIR/" 2>/dev/null
    cp "$QIUHE_HOME/lib/common.sh" "$WEB_DIR/" 2>/dev/null
    cp "$QIUHE_HOME/lib/ai.sh" "$WEB_DIR/" 2>/dev/null

    chmod 755 "$WEB_DIR/api.sh"

    echo ""
    log_info "=========================================="
    log_info "  qiuhe Web UI 已启动"
    log_info "  请在浏览器中打开:"
    log_info "  http://127.0.0.1:$PORT"
    log_info ""
    log_info "  按 Ctrl+C 停止服务"
    log_info "=========================================="
    echo ""

    busybox httpd -f -p "$PORT" -h "$WEB_DIR" -c "$WEB_DIR/api.sh"
}

start_web
