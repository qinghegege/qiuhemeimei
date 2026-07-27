#!/system/bin/sh
#===============================================================================
# 清湫 - Magisk/KSU 安装脚本
#===============================================================================

MODDIR="${MODDIR:-${0%/*}}"
SCRIPT_DIR="/data/adb/qinghe"
DATA_DIR="/data/qinghe"

ui_print() { echo "$1"; }

ui_print "=========================================="
ui_print "  清湫 v2.0.0 - 腾讯手游账号切换器"
ui_print "=========================================="

# --- 1. 目录 ---
ui_print "- 创建目录..."
mkdir -p "$SCRIPT_DIR/lib"
mkdir -p "$SCRIPT_DIR/web"
mkdir -p "$DATA_DIR/accounts"
mkdir -p "$DATA_DIR/snapshots"
mkdir -p "$DATA_DIR/logs"

# --- 2. 复制脚本到持久化目录 ---
ui_print "- 复制脚本库..."
for _f in common.sh games.sh games.ini crypto.sh account.sh detect.sh switch.sh ai.sh; do
    cp -f "$MODDIR/lib/$_f" "$SCRIPT_DIR/lib/" 2>/dev/null
done
cp -f "$MODDIR/web/server.sh" "$SCRIPT_DIR/web/" 2>/dev/null
cp -f "$MODDIR/web/api.sh"    "$SCRIPT_DIR/web/" 2>/dev/null
cp -f "$MODDIR/web/index.html" "$SCRIPT_DIR/web/" 2>/dev/null

# --- 3. 设置 webroot (KSU WebUI 入口) ---
ui_print "- 配置 WebUI..."
# 复制 lib 到 webroot 供 CGI 就近访问
cp -f "$MODDIR/lib/common.sh"  "$MODDIR/webroot/" 2>/dev/null
cp -f "$MODDIR/lib/games.sh"   "$MODDIR/webroot/" 2>/dev/null
cp -f "$MODDIR/lib/games.ini"  "$MODDIR/webroot/" 2>/dev/null
cp -f "$MODDIR/lib/crypto.sh"  "$MODDIR/webroot/" 2>/dev/null
cp -f "$MODDIR/lib/account.sh" "$MODDIR/webroot/" 2>/dev/null
cp -f "$MODDIR/lib/detect.sh"  "$MODDIR/webroot/" 2>/dev/null
cp -f "$MODDIR/lib/switch.sh"  "$MODDIR/webroot/" 2>/dev/null
cp -f "$MODDIR/lib/ai.sh"      "$MODDIR/webroot/" 2>/dev/null

# CGI 入口: busybox httpd 通过 cgi-bin/ 路径触发
mkdir -p "$MODDIR/webroot/cgi-bin" 2>/dev/null
cp -f "$MODDIR/web/api.sh" "$MODDIR/webroot/cgi-bin/api" 2>/dev/null
chmod 755 "$MODDIR/webroot/cgi-bin/api" 2>/dev/null

# --- 4. 全局命令 ---
ui_print "- 安装全局命令..."
mkdir -p "$MODDIR/system/bin"
cat > "$MODDIR/system/bin/qh" << 'EOF'
#!/system/bin/sh
export QH_DATA_DIR="/data/qinghe"
SCRIPT_DIR="/data/adb/qinghe"
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
        help|-h|--help)
            echo "清湫 命令: detect | backup <游戏> <别名> | list [游戏] | switch <别名> | delete <别名> | info <别名> | help"
            ;;
        *) echo "清湫 v2.0.0  用法: qh <命令> [参数]  输入 'qh help' 查看帮助" ;;
    esac
}
main "$@"
EOF
chmod 755 "$MODDIR/system/bin/qh"

# --- 5. 启动后台服务 ---
ui_print "- 启动 Web 服务..."

# 停止旧实例
pkill -f "busybox httpd.*8848" 2>/dev/null
sleep 1

_BB=""
for _p in /system/xbin/busybox /system/bin/busybox \
          /data/adb/modules/busybox-ndk/system/xbin/busybox \
          /data/adb/modules/busybox-ndk/system/bin/busybox; do
    [ -x "$_p" ] && { _BB="$_p"; break; }
done
[ -z "$_BB" ] && _BB="$(command -v busybox 2>/dev/null)"

if [ -n "$_BB" ] && [ -x "$MODDIR/webroot/cgi-bin/api" ]; then
    "$_BB" httpd -f -p 8848 -h "$MODDIR/webroot" >> "$DATA_DIR/logs/httpd.log" 2>&1 &
    sleep 1
    if ps -A 2>/dev/null | grep -q "httpd.*8848"; then
        _ip="$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)"
        [ -z "$_ip" ] && _ip="127.0.0.1"
        ui_print "  Web UI 已启动!"
        ui_print "  http://127.0.0.1:8848"
        [ "$_ip" != "127.0.0.1" ] && ui_print "  http://${_ip}:8848"
    else
        ui_print "  Web 服务启动失败，查看日志: $DATA_DIR/logs/httpd.log"
    fi
else
    ui_print "  busybox 不可用，请先安装 busybox-ndk 模块并重启"
fi

ui_print ""
ui_print "安装完成!"
ui_print ""
exit 0
