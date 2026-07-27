#!/system/bin/sh
#===============================================================================
# 清湫 - 开机自启动服务
#===============================================================================

MODDIR="${MODDIR:-${0%/*}}"
WEB_DIR="$MODDIR/webroot"
DATA_DIR="/data/qinghe"
PORT=8848

# 等待系统启动完成
while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done

mkdir -p "$DATA_DIR/accounts" "$DATA_DIR/snapshots" "$DATA_DIR/logs" 2>/dev/null

# 复制 lib + api 到 webroot
for _f in common.sh games.sh games.ini crypto.sh account.sh detect.sh switch.sh ai.sh; do
    cp -f "$MODDIR/lib/$_f" "$WEB_DIR/" 2>/dev/null
done
mkdir -p "$WEB_DIR/cgi-bin" 2>/dev/null
cp -f "$MODDIR/web/api.sh" "$WEB_DIR/cgi-bin/api" 2>/dev/null
chmod 755 "$WEB_DIR/cgi-bin/api" 2>/dev/null

# 查找 busybox
_BB=""
for _p in /system/xbin/busybox /system/bin/busybox \
          /data/adb/modules/busybox-ndk/system/xbin/busybox \
          /data/adb/modules/busybox-ndk/system/bin/busybox; do
    [ -x "$_p" ] && { _BB="$_p"; break; }
done
[ -z "$_BB" ] && _BB="$(command -v busybox 2>/dev/null)"

# 终止旧进程
pkill -f "busybox httpd.*$PORT" 2>/dev/null
sleep 1

if [ -n "$_BB" ]; then
    "$_BB" httpd -f -p "$PORT" -h "$WEB_DIR" >> "$DATA_DIR/logs/httpd.log" 2>&1 &
    echo "[qinghe] WebUI started on :$PORT" >> "$DATA_DIR/logs/boot.log"
else
    echo "[qinghe] busybox not found" >> "$DATA_DIR/logs/boot.log"
fi
