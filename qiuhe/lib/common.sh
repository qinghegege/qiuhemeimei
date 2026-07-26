#!/system/bin/sh
#===============================================================================
# 腾讯手游账号本地切换器 - 公共函数库
#===============================================================================

# --- 脚本自身路径解析 ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if echo "$SCRIPT_DIR" | grep -q '/lib$'; then
    QIUHE_HOME="$(dirname "$SCRIPT_DIR")"
else
    QIUHE_HOME="$SCRIPT_DIR"
fi

# --- 日志函数 ---
# 自动适配 MT 管理器 / 终端模拟器 / ADB Shell 的输出格式

MT_MODE=false
ADB_MODE=false

log_info() { echo "[INFO] $1"; }
log_warn() { echo "[WARN] $1"; }
log_err()  { echo "[ERR] $1" >&2; }
log_ok()   { echo "[OK] $1"; }

# 检测运行环境
detect_env() {
    if [ -n "$TERM" ] && echo "$TERM" | grep -q 'screen\|xterm'; then
        log_info "运行环境: 终端模拟器"
    elif [ -d "/sdcard/MT2" ] || [ -f "/data/data/bin.mt.plus/files/term/usr/bin/bash" ]; then
        MT_MODE=true
        log_info "运行环境: MT 管理器"
    elif [ -n "$ANDROID_SOCKET_adbd" ] || echo "$TERM" | grep -q 'dumb'; then
        ADB_MODE=true
        log_info "运行环境: ADB Shell"
    else
        log_info "运行环境: Shell"
    fi
}

# --- 权限检测 ---
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_err "需要 Root 权限才能访问游戏数据目录 (/data/data/)"
        log_err "请使用 Root 权限重新执行本脚本"
        exit 1
    fi
}

# --- 依赖检查 ---
require_cmd() {
    _cmd="$1"
    _required="${2:-yes}"
    _hint="${3:-}"

    if command -v "$_cmd" >/dev/null 2>&1; then
        return 0
    fi

    if [ "$_required" = "yes" ]; then
        log_err "缺少必需命令: $_cmd"
        if [ -n "$_hint" ]; then
            log_err "提示: $_hint"
        fi
        exit 1
    else
        log_warn "缺少可选命令: $_cmd"
        if [ -n "$_hint" ]; then
            log_warn "提示: $_hint"
        fi
        HAS_OPENSSL=false
        return 1
    fi
}

HAS_OPENSSL=true
HAS_PGREP=true
HAS_PM=true
HAS_RESTORECON=true

check_dependencies() {
    require_cmd "tar" "yes" "请安装 busybox"
    require_cmd "gzip" "yes" "请安装 busybox"
    require_cmd "cp" "yes"
    require_cmd "rm" "yes"
    require_cmd "mv" "yes"

    require_cmd "openssl" "no" "加密功能将不可用"
    require_cmd "pgrep" "no" "运行中的游戏进程检测将不可用" && HAS_PGREP=true || HAS_PGREP=false
    require_cmd "pm" "no" "游戏检测功能将不可用" && HAS_PM=true || HAS_PM=false
    require_cmd "restorecon" "no" "SELinux 上下文修复将不可用" && HAS_RESTORECON=true || HAS_RESTORECON=false
}

# --- 数据目录获取 ---
# 三种策略: 环境变量 > Magisk模块路径 > 脚本同级目录
get_data_dir() {
    if [ -n "$QH_DATA_DIR" ]; then
        echo "$QH_DATA_DIR"
        return
    fi

    # Magisk/KSU 模块环境: 数据在 /data/qinghe/
    if [ -d "/data/adb/modules/qinghe" ]; then
        _dd="/data/qinghe"
        mkdir -p "$_dd" 2>/dev/null
        echo "$_dd"
        return
    fi

    # 脚本同级目录
    echo "$QIUHE_HOME/清荷-data"
}

DATA_DIR="$(get_data_dir)"
ACCOUNTS_DIR="$DATA_DIR/accounts"
SNAPSHOTS_DIR="$DATA_DIR/snapshots"

ensure_data_dirs() {
    mkdir -p "$ACCOUNTS_DIR" 2>/dev/null
    mkdir -p "$SNAPSHOTS_DIR" 2>/dev/null
}

# --- 游戏数据路径 ---
get_game_data() {
    _pkg="$1"
    if [ -z "$_pkg" ]; then
        log_err "缺少包名参数"
        return 1
    fi
    _path="/data/data/$_pkg"
    if [ -d "$_path" ]; then
        echo "$_path"
    else
        return 1
    fi
}

# --- 磁盘空间检查 ---
check_disk_space() {
    _path="$1"
    _required_mb="${2:-100}"

    _available_kb="$(df "$_path" 2>/dev/null | tail -1 | awk '{print $4}')"
    if [ -z "$_available_kb" ]; then
        log_warn "无法检测磁盘空间, 跳过检查"
        return 0
    fi

    _available_mb="$(( _available_kb / 1024 ))"

    if [ "$_available_mb" -lt "$_required_mb" ]; then
        log_err "磁盘空间不足: 可用 ${_available_mb}M, 需要至少 ${_required_mb}M"
        return 1
    fi
    return 0
}

# --- 目录大小 ---
dir_size() {
    _dir="$1"
    if [ -d "$_dir" ]; then
        du -sh "$_dir" 2>/dev/null | awk '{print $1}'
    else
        echo "0"
    fi
}
