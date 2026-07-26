#!/system/bin/sh
#===============================================================================
# Magisk/KSU 模块 - 安装脚本
#===============================================================================

MODDIR=${0%/*}
SCRIPT_DIR="/data/adb/清荷"
DATA_DIR="/data/清荷"

ui_print "=========================================="
ui_print "  腾讯手游账号切换器 v1.0.0"
ui_print "=========================================="

ui_print "- 创建脚本目录..."
mkdir -p "$SCRIPT_DIR/lib"
mkdir -p "$SCRIPT_DIR/web"

ui_print "- 创建数据目录..."
mkdir -p "$DATA_DIR/accounts"
mkdir -p "$DATA_DIR/snapshots"
mkdir -p "$DATA_DIR/logs"

ui_print "- 设置目录权限..."
chmod 755 "$SCRIPT_DIR"
chmod 755 "$DATA_DIR"

ui_print "- 复制脚本文件..."
cp -f "$MODDIR/../lib/common.sh"    "$SCRIPT_DIR/lib/" 2>/dev/null || true
cp -f "$MODDIR/../lib/games.sh"     "$SCRIPT_DIR/lib/" 2>/dev/null || true
cp -f "$MODDIR/../lib/games.ini"    "$SCRIPT_DIR/lib/" 2>/dev/null || true
cp -f "$MODDIR/../lib/crypto.sh"    "$SCRIPT_DIR/lib/" 2>/dev/null || true
cp -f "$MODDIR/../lib/account.sh"   "$SCRIPT_DIR/lib/" 2>/dev/null || true
cp -f "$MODDIR/../lib/detect.sh"    "$SCRIPT_DIR/lib/" 2>/dev/null || true
cp -f "$MODDIR/../lib/switch.sh"    "$SCRIPT_DIR/lib/" 2>/dev/null || true
cp -f "$MODDIR/../lib/ai.sh"        "$SCRIPT_DIR/lib/" 2>/dev/null || true

ui_print "- 复制 Web UI 文件..."
cp -f "$MODDIR/../web/server.sh"    "$SCRIPT_DIR/web/" 2>/dev/null || true
cp -f "$MODDIR/../web/api.sh"       "$SCRIPT_DIR/web/" 2>/dev/null || true
cp -f "$MODDIR/../web/index.html"   "$SCRIPT_DIR/web/" 2>/dev/null || true
chmod 755 "$SCRIPT_DIR/web/api.sh"
chmod 755 "$SCRIPT_DIR/web/server.sh"

ui_print "- 设置 WebUI..."
cp -f "$MODDIR/../web/api.sh"       "$MODDIR/webroot/api.sh" 2>/dev/null || true
chmod 755 "$MODDIR/webroot/api.sh" 2>/dev/null || true

ui_print "- 创建全局命令..."
mkdir -p "$MODDIR/system/bin"
cat > "$MODDIR/system/bin/清荷" << 'SCRIPT'
#!/system/bin/sh
export QH_DATA_DIR="/data/清荷"
QH_SCRIPT_DIR="/data/adb/清荷"
. "$QH_SCRIPT_DIR/lib/common.sh"
. "$QH_SCRIPT_DIR/lib/games.sh"
. "$QH_SCRIPT_DIR/lib/crypto.sh"
. "$QH_SCRIPT_DIR/lib/account.sh"
. "$QH_SCRIPT_DIR/lib/detect.sh"
. "$QH_SCRIPT_DIR/lib/switch.sh"

detect_env
check_dependencies
ensure_data_dirs

main() {
    if [ $# -eq 0 ]; then
        echo "用法: 清荷 <命令> [参数...]"
        echo "使用 '清荷 help' 获取帮助"
        return 1
    fi

    _cmd="$1"
    shift

    case "$_cmd" in
        help|-h|--help)
            echo "腾讯手游账号切换器 (清荷)"
            echo ""
            echo "命令:"
            echo "  backup   <游戏> <别名>   备份当前游戏数据"
            echo "  list     [游戏]          列出已备份账号"
            echo "  info     <别名>          查看账号详情"
            echo "  delete   <别名>          删除账号"
            echo "  switch   <别名>          切换账号"
            echo "  detect                   检测已安装游戏"
            echo "  snapshot <游戏>          快照列表"
            echo "  restore  <游戏> <ID>     回滚快照"
            echo "  export   <别名> --output <路径> [--pass <密码>]"
            echo "  export   --all --output <目录> [--pass <密码>]"
            echo "  import   <文件> [--pass <密码>]"
            echo "  web      [端口]          启动 Web UI"
            echo "  help                     帮助"
            ;;
        detect) detect_games ;;
        backup) account_backup "$1" "$2" ;;
        list) account_list "$1" ;;
        info) account_info "$1" ;;
        delete|remove) account_delete "$1" ;;
        switch) switch_account "$1" ;;
        snapshot) snapshot_list "$1" ;;
        restore) restore_snapshot "$1" "$2" ;;
        export)
            if [ "$1" = "--all" ]; then shift; export_all "$@"
            else export_account "$1" "$@"; fi ;;
        import) import_account "$1" "$@" ;;
        web) exec "$QH_SCRIPT_DIR/web/server.sh" "${1:-8848}" ;;
        *) echo "未知命令: $_cmd, 使用 '清荷 help' 查看帮助"; return 1 ;;
    esac
}

main "$@"
SCRIPT
chmod 755 "$MODDIR/system/bin/清荷"

ui_print ""
ui_print "安装完成!"
ui_print "终端输入 '清荷' 即可使用"
ui_print "数据存储在: $DATA_DIR"
ui_print ""
