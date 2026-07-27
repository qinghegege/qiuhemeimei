#!/system/bin/sh
#===============================================================================
# 清湫 - 开机服务 (KSU WebUI 无需 HTTP 服务, ksu.exec 直连 Shell)
#===============================================================================

DATA_DIR="/data/qinghe"

while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done

mkdir -p "$DATA_DIR/accounts" "$DATA_DIR/snapshots" "$DATA_DIR/logs" 2>/dev/null
echo "[qinghe] v2.0.1 booted" >> "$DATA_DIR/logs/boot.log"
