#!/system/bin/sh
#===============================================================================
# Magisk/KSU 模块 - 安装脚本
# 新版 KSU 通过 WebUI 直接执行此脚本
#===============================================================================

# MODDIR 由 Magisk/KSU 环境变量提供，指向模块根目录
# 注意: 不应通过 ${0%/*} 覆盖 MODDIR, KSU 传入的 MODDIR 才是正确路径
MODDIR="${MODDIR:-${0%/*}}"
SCRIPT_DIR="/data/adb/qinghe"
DATA_DIR="/data/qinghe"

ui_print() {
    echo "$1"
}

ui_print "=========================================="
ui_print "  清荷 - 腾讯手游账号切换器 v1.0.1"
ui_print "=========================================="

ui_print "- 创建脚本目录..."
mkdir -p "$SCRIPT_DIR/lib"
mkdir -p "$SCRIPT_DIR/web"

ui_print "- 创建数据目录..."
mkdir -p "$DATA_DIR/accounts"
mkdir -p "$DATA_DIR/snapshots"
mkdir -p "$DATA_DIR/logs"

ui_print "- 设置目录权限..."
chmod 755 "$SCRIPT_DIR" 2>/dev/null
chmod 755 "$DATA_DIR" 2>/dev/null

ui_print "- 复制脚本文件..."
cp -f "$MODDIR/lib/common.sh"    "$SCRIPT_DIR/lib/" 2>/dev/null || true
cp -f "$MODDIR/lib/games.sh"     "$SCRIPT_DIR/lib/" 2>/dev/null || true
cp -f "$MODDIR/lib/games.ini"    "$SCRIPT_DIR/lib/" 2>/dev/null || true
cp -f "$MODDIR/lib/crypto.sh"    "$SCRIPT_DIR/lib/" 2>/dev/null || true
cp -f "$MODDIR/lib/account.sh"   "$SCRIPT_DIR/lib/" 2>/dev/null || true
cp -f "$MODDIR/lib/detect.sh"    "$SCRIPT_DIR/lib/" 2>/dev/null || true
cp -f "$MODDIR/lib/switch.sh"    "$SCRIPT_DIR/lib/" 2>/dev/null || true
cp -f "$MODDIR/lib/ai.sh"        "$SCRIPT_DIR/lib/" 2>/dev/null || true

ui_print "- 复制 Web UI 文件..."
cp -f "$MODDIR/web/server.sh"    "$SCRIPT_DIR/web/" 2>/dev/null || true
cp -f "$MODDIR/web/api.sh"       "$SCRIPT_DIR/web/" 2>/dev/null || true
cp -f "$MODDIR/web/index.html"   "$SCRIPT_DIR/web/" 2>/dev/null || true
chmod 755 "$SCRIPT_DIR/web/api.sh" 2>/dev/null || true
chmod 755 "$SCRIPT_DIR/web/server.sh" 2>/dev/null || true

ui_print "- 设置 WebUI..."
cp -f "$SCRIPT_DIR/web/api.sh"       "$MODDIR/webroot/api.sh" 2>/dev/null || true
chmod 755 "$MODDIR/webroot/api.sh" 2>/dev/null || true

ui_print "- 创建全局命令..."
mkdir -p "$MODDIR/system/bin"
cat > "$MODDIR/system/bin/qh" << 'SCRIPT'
#!/system/bin/sh
QH_DATA_DIR="/data/qinghe"
QH_SCRIPT_DIR="/data/adb/qinghe"
export QH_DATA_DIR
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
        echo "清荷 - 腾讯手游账号切换器"
        echo "用法: qh <命令> [参数...]"
        echo "使用 'qh help' 获取帮助"
        return 1
    fi

    _cmd="$1"
    shift

    case "$_cmd" in
        help|-h|--help)
            echo "清荷 (腾讯手游账号切换器)"
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
            echo ""
            echo "数据目录: /data/qinghe/"
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
        *) echo "未知命令: $_cmd, 使用 'qh help' 查看帮助"; return 1 ;;
    esac
}

main "$@"
SCRIPT
chmod 755 "$MODDIR/system/bin/qh"

ui_print ""
ui_print "安装完成!"
ui_print "终端输入 'qh' 即可使用"
ui_print "数据存储在: $DATA_DIR"
ui_print ""

# 复制 lib 到 webroot 供 CGI 使用
cp -f "$MODDIR/lib/common.sh"   "$MODDIR/webroot/" 2>/dev/null || true
cp -f "$MODDIR/lib/games.sh"    "$MODDIR/webroot/" 2>/dev/null || true
cp -f "$MODDIR/lib/games.ini"   "$MODDIR/webroot/" 2>/dev/null || true
cp -f "$MODDIR/lib/crypto.sh"   "$MODDIR/webroot/" 2>/dev/null || true
cp -f "$MODDIR/lib/account.sh"  "$MODDIR/webroot/" 2>/dev/null || true
cp -f "$MODDIR/lib/detect.sh"   "$MODDIR/webroot/" 2>/dev/null || true
cp -f "$MODDIR/lib/switch.sh"   "$MODDIR/webroot/" 2>/dev/null || true
cp -f "$MODDIR/lib/ai.sh"       "$MODDIR/webroot/" 2>/dev/null || true

# 查找 busybox (兼容 busybox-ndk 非标准路径)
_BUSYBOX=""
for _p in /system/xbin/busybox /system/bin/busybox \
          /data/adb/modules/busybox-ndk/system/xbin/busybox \
          /data/adb/modules/busybox-ndk/system/bin/busybox; do
    [ -x "$_p" ] && _BUSYBOX="$_p" && break
done
[ -z "$_BUSYBOX" ] && _BUSYBOX="$(command -v busybox 2>/dev/null)"

# 安装后立即启动后台服务，无需重启
if [ -n "$_BUSYBOX" ]; then
    pkill -f "busybox httpd.*8848" 2>/dev/null
    sleep 1
    "$_BUSYBOX" httpd -f -p 8848 -h "$MODDIR/webroot" -c "$MODDIR/webroot/api.sh" \
        >> "$DATA_DIR/logs/httpd.log" 2>&1 &
    ui_print "- Web UI 已启动: http://127.0.0.1:8848"
else
    ui_print "- 未检测到 busybox, Web UI 需重启后生效"
fi

exit 0
