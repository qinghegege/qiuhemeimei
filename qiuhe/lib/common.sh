#!/system/bin/sh
#===============================================================================
# 清湫 - 公共函数库
#===============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -z "$QIUHE_HOME" ]; then
    if echo "$SCRIPT_DIR" | grep -q '/lib$'; then
        QIUHE_HOME="$(dirname "$SCRIPT_DIR")"
    else
        QIUHE_HOME="$SCRIPT_DIR"
    fi
fi

# --- 日志 ---
log_info() { echo "[INFO] $1"; }
log_warn() { echo "[WARN] $1"; }
log_err()  { echo "[ERR] $1" >&2; }
log_ok()   { echo "[OK] $1"; }

# --- 环境检测 ---
detect_env() {
    MT_MODE=false; ADB_MODE=false
    [ -d "/sdcard/MT2" ] && MT_MODE=true
    [ -n "$ANDROID_SOCKET_adbd" ] && ADB_MODE=true
}

# --- Root 检测 ---
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_err "需要 Root 权限"
        exit 1
    fi
}

# --- 依赖检查 ---
HAS_OPENSSL=true; HAS_PGREP=true; HAS_PM=true; HAS_RESTORECON=true

check_dependencies() {
    for _cmd in tar gzip cp rm mv; do
        command -v "$_cmd" >/dev/null 2>&1 || { log_err "缺少命令: $_cmd"; exit 1; }
    done
    command -v openssl >/dev/null 2>&1 || { HAS_OPENSSL=false; log_warn "openssl 不可用，加密功能禁用"; }
    command -v pgrep >/dev/null 2>&1 || { HAS_PGREP=false; log_warn "pgrep 不可用"; }
    command -v pm >/dev/null 2>&1 || { HAS_PM=false; log_warn "pm 不可用，检测功能禁用"; }
    command -v restorecon >/dev/null 2>&1 || HAS_RESTORECON=false
}

# --- SELinux 临时关闭 ---
_SELINUX_SAVED=""

selinux_temp_disable() {
    _SELINUX_SAVED="$(getenforce 2>/dev/null)"
    if [ "$_SELINUX_SAVED" = "Enforcing" ]; then
        setenforce 0 2>/dev/null && log_info "SELinux 临时关闭" || log_warn "无法修改 SELinux 状态"
    fi
}

selinux_restore() {
    if [ -n "$_SELINUX_SAVED" ] && [ "$_SELINUX_SAVED" = "Enforcing" ]; then
        setenforce 1 2>/dev/null && log_info "SELinux 已恢复" || log_warn "无法恢复 SELinux 状态"
    fi
    _SELINUX_SAVED=""
}

# --- 查找 busybox (兼容 busybox-ndk 等非标准路径) ---
find_busybox() {
    for _p in /system/xbin/busybox /system/bin/busybox \
              /data/adb/modules/busybox-ndk/system/xbin/busybox \
              /data/adb/modules/busybox-ndk/system/bin/busybox; do
        [ -x "$_p" ] && { echo "$_p"; return 0; }
    done
    _b="$(command -v busybox 2>/dev/null)"
    [ -n "$_b" ] && { echo "$_b"; return 0; }
    return 1
}

# --- 数据目录 ---
get_data_dir() {
    [ -n "$QH_DATA_DIR" ] && { echo "$QH_DATA_DIR"; return; }
    if [ -d "/data/adb/modules/qinghe" ]; then
        _dd="/data/qinghe"; mkdir -p "$_dd" 2>/dev/null; echo "$_dd"; return
    fi
    echo "$QIUHE_HOME/清湫-data"
}

DATA_DIR="$(get_data_dir)"
ACCOUNTS_DIR="$DATA_DIR/accounts"
SNAPSHOTS_DIR="$DATA_DIR/snapshots"

ensure_data_dirs() {
    mkdir -p "$ACCOUNTS_DIR" "$SNAPSHOTS_DIR" 2>/dev/null
}

# --- 目录大小 ---
dir_size() { [ -d "$1" ] && du -sh "$1" 2>/dev/null | awk '{print $1}' || echo "0"; }

# --- 磁盘空间 ---
check_disk_space() {
    _avail="$(df "$1" 2>/dev/null | tail -1 | awk '{print $4}')"
    [ -z "$_avail" ] && return 0
    [ "$(( _avail / 1024 ))" -lt "${2:-100}" ] && { log_err "磁盘空间不足"; return 1; }
    return 0
}
