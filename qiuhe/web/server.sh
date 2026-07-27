#!/system/bin/sh
#===============================================================================
# 清湫 - Web 服务启动脚本 (独立脚本模式)
#===============================================================================

WEB_DIR="$(cd "$(dirname "$0")" && pwd)"
QIUHE_HOME="$(dirname "$WEB_DIR")"
PORT="${1:-8848}"

. "$QIUHE_HOME/lib/common.sh"

start_web() {
    log_info "清湫 Web UI 启动中..."

    # 查找 busybox
    _BB="$(find_busybox 2>/dev/null)"
    if [ -z "$_BB" ]; then
        log_err "未找到 busybox, 请先安装 busybox-ndk 模块"
        exit 1
    fi

    # 复制依赖到 web 目录
    cp -f "$QIUHE_HOME/lib/common.sh"  "$WEB_DIR/" 2>/dev/null
    cp -f "$QIUHE_HOME/lib/games.sh"   "$WEB_DIR/" 2>/dev/null
    cp -f "$QIUHE_HOME/lib/games.ini"  "$WEB_DIR/" 2>/dev/null

    # CGI 入口
    mkdir -p "$WEB_DIR/cgi-bin" 2>/dev/null
    cp -f "$WEB_DIR/api.sh" "$WEB_DIR/cgi-bin/api" 2>/dev/null
    chmod 755 "$WEB_DIR/api.sh" "$WEB_DIR/cgi-bin/api" 2>/dev/null

    echo ""
    log_info "========================================"
    log_info "  清湫 Web UI 已启动"
    log_info "  http://127.0.0.1:$PORT"
    log_info ""
    log_info "  按 Ctrl+C 停止服务"
    log_info "========================================"
    echo ""

    "$_BB" httpd -f -p "$PORT" -h "$WEB_DIR"
}

start_web
