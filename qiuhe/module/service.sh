#!/system/bin/sh
#===============================================================================
# Magisk/KSU 模块 - 开机服务
# 启动后台 HTTP API 供 WebUI 调用
#===============================================================================

MODDIR=${0%/*}
WEB_DIR="$MODDIR/webroot"
SCRIPT_DIR="/data/adb/清荷"
DATA_DIR="/data/清荷"
API_PORT=8848

# 确保数据目录存在
mkdir -p "$DATA_DIR/accounts" 2>/dev/null
mkdir -p "$DATA_DIR/snapshots" 2>/dev/null
mkdir -p "$DATA_DIR/logs" 2>/dev/null

# 复制 API 脚本到 webroot（CGI 模式需要）
cp -f "$SCRIPT_DIR/lib/common.sh"  "$WEB_DIR/" 2>/dev/null
cp -f "$SCRIPT_DIR/lib/games.sh"   "$WEB_DIR/" 2>/dev/null
cp -f "$SCRIPT_DIR/lib/games.ini"  "$WEB_DIR/" 2>/dev/null
cp -f "$SCRIPT_DIR/lib/crypto.sh"  "$WEB_DIR/" 2>/dev/null
cp -f "$SCRIPT_DIR/lib/account.sh" "$WEB_DIR/" 2>/dev/null
cp -f "$SCRIPT_DIR/lib/detect.sh"  "$WEB_DIR/" 2>/dev/null
cp -f "$SCRIPT_DIR/lib/switch.sh"  "$WEB_DIR/" 2>/dev/null
cp -f "$SCRIPT_DIR/lib/ai.sh"      "$WEB_DIR/" 2>/dev/null

# 等待设备启动完成
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
done

# 杀掉可能残留的旧进程
pkill -f "busybox httpd.*8848" 2>/dev/null
sleep 1

# 启动 busybox httpd 作为 API 后端
if command -v busybox >/dev/null 2>&1; then
    busybox httpd -f -p "$API_PORT" -h "$WEB_DIR" -c "$WEB_DIR/api.sh" \
        >> "$DATA_DIR/logs/httpd.log" 2>&1 &
    echo "[清荷] HTTP API started on port $API_PORT" >> "$DATA_DIR/logs/boot.log"
else
    echo "[清荷] busybox not found, WebUI API disabled" >> "$DATA_DIR/logs/boot.log"
fi
