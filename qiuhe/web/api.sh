#!/system/bin/sh
#===============================================================================
# 清湫 - CGI API 端点
#===============================================================================

WEB_DIR="$(cd "$(dirname "$0")" && pwd)"
QIUHE_HOME="$(dirname "$WEB_DIR")"
export QH_DATA_DIR="${QH_DATA_DIR:-}"

# 加载库 (优先模块 lib 目录，回退到 webroot)
. "$QIUHE_HOME/lib/common.sh" 2>/dev/null || . "$WEB_DIR/common.sh" 2>/dev/null
. "$QIUHE_HOME/lib/games.sh"  2>/dev/null || . "$WEB_DIR/games.sh"  2>/dev/null
. "$QIUHE_HOME/lib/crypto.sh"  2>/dev/null
. "$QIUHE_HOME/lib/account.sh" 2>/dev/null
. "$QIUHE_HOME/lib/detect.sh"  2>/dev/null
. "$QIUHE_HOME/lib/switch.sh"  2>/dev/null
. "$QIUHE_HOME/lib/ai.sh"      2>/dev/null

ensure_data_dirs

json() { echo "Content-Type: application/json"; echo ""; echo "$1"; }
json_err() { json "{\"error\":\"$1\"}"; }

# URL 参数解析
get_param() {
    _key="$1"; _default="$2"
    if [ "$REQUEST_METHOD" = "POST" ] && [ -n "$CONTENT_LENGTH" ] && [ "$CONTENT_LENGTH" -gt 0 ]; then
        _body="$(dd bs=1 count="$CONTENT_LENGTH" 2>/dev/null)"
        _val="$(echo "$_body" | grep -o "${_key}=[^&]*" | head -1 | sed "s/${_key}=//" | sed 's/+/ /g')"
    else
        _val="$(echo "$QUERY_STRING" | grep -o "${_key}=[^&]*" | head -1 | sed "s/${_key}=//" | sed 's/+/ /g')"
    fi
    [ -n "$_val" ] && echo "$_val" || echo "$_default"
}

_url_decode() { echo "$1" | sed 's/%20/ /g;s/%0A/\n/g;s/+/ /g'; }

check_root
detect_env

# 路由: 从 PATH_INFO 提取 action
_action="${PATH_INFO#/}"
_action="${_action%%\?*}"

case "$_action" in
    detect)
        _entries="$(detect_all_entries)"
        if [ -z "$_entries" ]; then json "{\"games\":[]}"
        else json "{\"games\":[$_entries]}"; fi
        ;;
    accounts)
        _game="$(get_param game "")"
        _found=""; _dir="${ACCOUNTS_DIR}${_game:+/$_game}"
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
        json "{\"accounts\":[${_found}]}"
        ;;
    backup)
        _game="$(get_param game "")"; _alias="$(get_param alias "")"; _path="$(get_param path "")"
        [ -z "$_game" ] || [ -z "$_alias" ] && { json_err "需要 game 和 alias"; exit 1; }
        if account_backup "$_game" "$_alias" "$_path" >/dev/null 2>&1; then
            json "{\"ok\":true,\"alias\":\"$_alias\"}"
        else json_err "备份失败"; fi
        ;;
    restore)
        _alias="$(get_param alias "")"
        [ -z "$_alias" ] && { json_err "需要 alias"; exit 1; }
        if switch_account "$_alias" >/dev/null 2>&1; then
            json "{\"ok\":true,\"alias\":\"$_alias\"}"
        else json_err "切换失败"; fi
        ;;
    delete)
        _alias="$(get_param alias "")"
        [ -z "$_alias" ] && { json_err "需要 alias"; exit 1; }
        if account_delete "$_alias" >/dev/null 2>&1; then
            json "{\"ok\":true,\"alias\":\"$_alias\"}"
        else json_err "删除失败"; fi
        ;;
    status)
        json "{\"ok\":true,\"version\":\"v2.0.0\",\"dataDir\":\"$DATA_DIR\"}"
        ;;
    ai/chat)
        _msg="$(_url_decode "$(get_param msg "")")"
        [ -z "$_msg" ] && { json_err "需要 msg"; exit 1; }
        _resp="$(ai_chat "$_msg" 2>/dev/null)"
        [ -z "$_resp" ] && { json_err "AI 请求失败，请确认 API Key 已配置"; exit 1; }
        json "$_resp"
        ;;
    ai/config)
        _act="$(get_param action "")"
        case "$_act" in
            get)  json "{\"configured\":$(ai_is_configured)}" ;;
            set)  _key="$(get_param key "")"; ai_set_key "$_key"; json "{\"ok\":true}" ;;
            delete) ai_clear_config; json "{\"ok\":true}" ;;
            *) json_err "action: get|set|delete" ;;
        esac
        ;;
    ai/command)
        _msg="$(_url_decode "$(get_param msg "")")"
        _cmd="$(ai_parse_command "$_msg" 2>/dev/null)"
        [ -n "$_cmd" ] && json "$_cmd" || json "{\"cmd\":\"chat\"}"
        ;;
    *)
        json_err "未知接口: $_action"
        ;;
esac
exit 0
