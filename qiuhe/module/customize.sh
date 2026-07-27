#!/system/bin/sh
#===============================================================================
# 清湫 v2.1.2 - KSU 安装脚本
# 无外部依赖: 使用 KSU WebUI ksu.exec 桥接, 零 HTTP 服务
#===============================================================================

MODDIR="${MODDIR:-${0%/*}}"
SCRIPT_DIR="/data/adb/qinghe"
DATA_DIR="/data/qinghe"

ui_print() { echo "$1"; }

ui_print "=========================================="
ui_print "  清湫 v2.0.0 - 腾讯手游账号切换器"
ui_print "=========================================="

# 目录
ui_print "- 创建目录..."
mkdir -p "$SCRIPT_DIR/lib" "$SCRIPT_DIR/web"
mkdir -p "$DATA_DIR/accounts" "$DATA_DIR/snapshots" "$DATA_DIR/logs"

# 脚本
ui_print "- 复制脚本库..."
for _f in common.sh games.sh games.ini crypto.sh account.sh detect.sh switch.sh; do
    cp -f "$MODDIR/lib/$_f" "$SCRIPT_DIR/lib/" 2>/dev/null
done
cp -f "$MODDIR/web/server.sh" "$SCRIPT_DIR/web/" 2>/dev/null
cp -f "$MODDIR/web/api.sh"    "$SCRIPT_DIR/web/" 2>/dev/null
cp -f "$MODDIR/web/index.html" "$SCRIPT_DIR/web/" 2>/dev/null
chmod 755 "$SCRIPT_DIR/web/api.sh" 2>/dev/null

# webroot (KSU WebUI 入口, ksu.exec 调用 cgi-bin/api)
ui_print "- 配置 WebUI..."
cp -f "$MODDIR/lib/common.sh"  "$MODDIR/webroot/" 2>/dev/null
cp -f "$MODDIR/lib/games.sh"   "$MODDIR/webroot/" 2>/dev/null
cp -f "$MODDIR/lib/games.ini"  "$MODDIR/webroot/" 2>/dev/null
cp -f "$MODDIR/lib/crypto.sh"  "$MODDIR/webroot/" 2>/dev/null
cp -f "$MODDIR/lib/account.sh" "$MODDIR/webroot/" 2>/dev/null
cp -f "$MODDIR/lib/detect.sh"  "$MODDIR/webroot/" 2>/dev/null
cp -f "$MODDIR/lib/switch.sh"  "$MODDIR/webroot/" 2>/dev/null
mkdir -p "$MODDIR/webroot/cgi-bin" 2>/dev/null
cp -f "$MODDIR/web/api.sh" "$MODDIR/webroot/cgi-bin/api" 2>/dev/null
chmod 755 "$MODDIR/webroot/cgi-bin/api" 2>/dev/null

# 全局命令
ui_print "- 安装全局命令..."
mkdir -p "$MODDIR/system/bin"
cat > "$MODDIR/system/bin/qh" << 'EOF'
#!/system/bin/sh
export QH_DATA_DIR="/data/qinghe"
SCRIPT_DIR="/data/adb/qinghe"
export QIUHE_HOME="$SCRIPT_DIR"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/games.sh"
. "$SCRIPT_DIR/lib/crypto.sh"
. "$SCRIPT_DIR/lib/account.sh"
. "$SCRIPT_DIR/lib/detect.sh"
. "$SCRIPT_DIR/lib/switch.sh"
detect_env; check_dependencies; ensure_data_dirs
main() {
    case "${1:-}" in
        detect) detect_games ;;
        backup) account_backup "$2" "$3" ;;
        list)   account_list "$2" ;;
        info)   account_info "$2" ;;
        delete|remove) account_delete "$2" ;;
        switch) switch_account "$2" ;;
        help|-h|--help) echo "清湫: detect | backup <游戏> <别名> | list | switch <别名> | delete <别名> | help" ;;
        *) echo "清湫 v2.1.2  用法: qh help" ;;
    esac
}
main "$@"
EOF
chmod 755 "$MODDIR/system/bin/qh"

ui_print ""
ui_print "安装完成! KSU 管理器内打开模块即可使用 Web UI"
ui_print "终端输入 'qh' 使用命令行模式"
ui_print ""

exit 0
