#!/system/bin/sh
#===============================================================================
# 清湫 - API 端点 (CGI / CLI 双模)
# HTTP CGI: ?action=xxx  + POST body
# CLI:       api.sh <action> [key=val ...]
#===============================================================================

API_DIR="$(cd "$(dirname "$0")" && pwd)"
MODDIR="$(dirname "$(dirname "$API_DIR")")"
WEB_DIR="$MODDIR/webroot"
export QH_DATA_DIR="${QH_DATA_DIR:-}"
export QIUHE_HOME="$MODDIR"

# 加载库
. "$MODDIR/lib/common.sh" 2>/dev/null || . "$WEB_DIR/common.sh" 2>/dev/null
. "$MODDIR/lib/games.sh"  2>/dev/null || . "$WEB_DIR/games.sh"  2>/dev/null
. "$MODDIR/lib/crypto.sh" 2>/dev/null
. "$MODDIR/lib/account.sh" 2>/dev/null
. "$MODDIR/lib/detect.sh"  2>/dev/null
. "$MODDIR/lib/switch.sh"  2>/dev/null

ensure_data_dirs

# JSON 输出
json() { echo "$1"; }
json_ok() { json "{\"ok\":true}"; }
json_err() { json "{\"error\":\"$1\"}" >&2; json "{\"error\":\"$1\"}"; }
respond_ok() { respond '{"ok":true}'; }

# === HTTP 模式: 从 query string / POST body 取参 ===
http_get_param() {
    _key="$1"; _default="$2"; _val=""
    if [ "$REQUEST_METHOD" = "POST" ] && [ -n "$CONTENT_LENGTH" ] && [ "$CONTENT_LENGTH" -gt 0 ]; then
        _body="$(dd bs=1 count="$CONTENT_LENGTH" 2>/dev/null)"
        _val="$(echo "$_body" | grep -o "${_key}=[^&]*" | head -1 | sed "s/${_key}=//;s/+/ /g")"
    fi
    [ -z "$_val" ] && _val="$(echo "$QUERY_STRING" | grep -o "${_key}=[^&]*" | head -1 | sed "s/${_key}=//;s/+/ /g")"
    [ -n "$_val" ] && echo "$_val" || echo "$_default"
}

# --- 检测运行模式 ---
if [ -n "$REQUEST_METHOD" ]; then
    # HTTP CGI 模式
    MODE="cgi"
    content_type_json() { echo "Content-Type: application/json"; echo ""; }
    cgi_json() { content_type_json; echo "$1"; }
    cgi_err() { cgi_json "{\"error\":\"$1\"}"; }

    _action="$(http_get_param action "")"
    getp() { http_get_param "$@"; }
    respond() { cgi_json "$1"; }
    respond_err() { cgi_err "$1"; }
else
    # CLI 模式 (ksu.exec / 终端)
    MODE="cli"
    _action="$1"
    shift 2>/dev/null
    _TMP_ARGS="/tmp/qh_api_$$"
    printf '%s\n' "$@" > "$_TMP_ARGS"
    trap "rm -f $_TMP_ARGS 2>/dev/null" EXIT
    getp() {
        _key="$1"; _default="$2"
        while IFS= read -r _a 2>/dev/null; do
            case "$_a" in
                "${_key}="*) echo "${_a#${_key}=}"; return ;;
            esac
        done < "$_TMP_ARGS"
        echo "$_default"
    }
    respond() { json "$1"; }
    respond_err() { json_err "$1"; }
fi

# 所有日志到 stderr, 保证 stdout 是纯 JSON
check_root
detect_env 2>/dev/null

# SELinux 诊断
_selinux_status="$(getenforce 2>/dev/null || echo 'unknown')"
if [ "$_selinux_status" = "Enforcing" ]; then
    echo "[WARN] SELinux 处于 Enforcing 模式, 可能阻止读取游戏数据目录" >&2
    echo "[INFO] 如备份失败, 可尝试在终端执行: setenforce 0 临时关闭" >&2
fi

# --- 路由 ---
case "$_action" in
    detect)
        _entries="$(detect_all_entries)"
        [ -z "$_entries" ] && respond "{\"games\":[]}" || respond "{\"games\":[$_entries]}"
        ;;
    detect_game)
        _n="$(getp name "")"
        [ -z "$_n" ] && { respond_err "需要 name"; exit 1; }
        _r="$(detect_game_paths "$_n")"
        [ -n "$_r" ] && respond "$_r" || respond_err "游戏不存在"
        ;;
    accounts)
        _game="$(getp game "")"; _found=""; _dir="${ACCOUNTS_DIR}${_game:+/$_game}"
        if [ -d "$_dir" ]; then
            for _m in $(find "$_dir" -name meta.json 2>/dev/null); do
                [ -f "$_m" ] || continue
                _al="$(grep '"alias"' "$_m" | head -1 | sed 's/.*"alias": *"//;s/".*//')"
                _gn="$(grep '"game"' "$_m" | head -1 | sed 's/.*"game": *"//;s/".*//')"
                _tm="$(grep '"created_at"' "$_m" | head -1 | sed 's/.*"created_at": *"//;s/".*//')"
                _sz="$(grep '"data_size"' "$_m" | head -1 | sed 's/.*"data_size": *"//;s/".*//')"
                _dp="$(get_display_name "$_gn")"
                [ -n "$_found" ] && _found="$_found,"
                _found="${_found}{\"alias\":\"$_al\",\"game\":\"$_gn\",\"display\":\"$_dp\",\"time\":\"$_tm\",\"size\":\"$_sz\"}"
            done
        fi
        respond "{\"accounts\":[${_found}]}"
        ;;
    backup)
        _g="$(getp game ""); _a="$(getp alias ""); _p="$(getp path "")"
        [ -z "$_g" ] || [ -z "$_a" ] && { respond_err "需要 game 和 alias"; exit 1; }
        _elog="/tmp/qh_bak_$$"
        account_backup "$_g" "$_a" "$_p" >"$_elog" 2>&1; _rc=$?
        if [ $_rc -eq 0 ]; then rm -f "$_elog"; respond "{\"ok\":true,\"alias\":\"$_a\"}"
        else _tl=$(tail -2 "$_elog" 2>/dev/null | tr '\n' '|' | sed 's/"/\\"/g'); rm -f "$_elog"; respond_err "${_tl:-备份失败}"
        fi
        ;;
    restore)
        _a="$(getp alias "")"
        [ -z "$_a" ] && { respond_err "需要 alias"; exit 1; }
        _elog="/tmp/qh_res_$$"
        switch_account "$_a" >"$_elog" 2>&1; _rc=$?
        if [ $_rc -eq 0 ]; then rm -f "$_elog"; respond "{\"ok\":true,\"alias\":\"$_a\"}"
        else _tl=$(tail -2 "$_elog" 2>/dev/null | tr '\n' '|' | sed 's/"/\\"/g'); rm -f "$_elog"; respond_err "${_tl:-切换失败}"
        fi
        ;;
    delete)
        _a="$(getp alias "")"
        [ -z "$_a" ] && { respond_err "需要 alias"; exit 1; }
        _elog="/tmp/qh_del_$$"
        account_delete "$_a" 1 >"$_elog" 2>&1; _rc=$?
        if [ $_rc -eq 0 ]; then rm -f "$_elog"; respond "{\"ok\":true,\"alias\":\"$_a\"}"
        else _tl=$(tail -2 "$_elog" 2>/dev/null | tr '\n' '|' | sed 's/"/\\"/g'); rm -f "$_elog"; respond_err "${_tl:-删除失败}"
        fi
        ;;
    status)
        _se="$(getenforce 2>/dev/null || echo 'unknown')"
        respond "{\"ok\":true,\"version\":\"v2.1.5\",\"dataDir\":\"$DATA_DIR\",\"selinux\":\"$_se\"}"
        ;;
    *)  respond_err "未知接口: $_action" ;;
esac
exit 0
