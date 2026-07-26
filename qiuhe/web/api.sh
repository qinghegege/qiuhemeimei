#!/system/bin/sh
#===============================================================================
# qiuhe Web UI - CGI API 处理
#===============================================================================

WEB_DIR="$(cd "$(dirname "$0")" && pwd)"
QIUHE_HOME="$(dirname "$WEB_DIR")"

# QH_DATA_DIR 若已由环境设置则沿用，否则交 common.sh 自动检测
# （Magisk 模块环境由开机脚本导出，独立运行由终端用户设置）
export QH_DATA_DIR="${QH_DATA_DIR:-}"

. "$QIUHE_HOME/lib/common.sh" 2>/dev/null || . "$WEB_DIR/common.sh" 2>/dev/null
. "$QIUHE_HOME/lib/games.sh" 2>/dev/null || . "$WEB_DIR/games.sh" 2>/dev/null
. "$QIUHE_HOME/lib/crypto.sh" 2>/dev/null
. "$QIUHE_HOME/lib/account.sh" 2>/dev/null
. "$QIUHE_HOME/lib/detect.sh" 2>/dev/null
. "$QIUHE_HOME/lib/switch.sh" 2>/dev/null
. "$QIUHE_HOME/lib/ai.sh" 2>/dev/null

ensure_data_dirs

content_type_json() {
    echo "Content-Type: application/json"
    echo ""
}

output_json() {
    content_type_json
    echo "$1"
}

output_error() {
    output_json "{\"error\":\"$1\"}"
}

# 从查询字符串或 POST body 中取参数
get_param() {
    _key="$1"
    _default="$2"

    if [ "$REQUEST_METHOD" = "POST" ] && [ -n "$CONTENT_LENGTH" ] && [ "$CONTENT_LENGTH" -gt 0 ]; then
        _body="$(dd bs=1 count="$CONTENT_LENGTH" 2>/dev/null)"
        _val="$(echo "$_body" | grep -o "${_key}=[^&]*" | head -1 | sed "s/${_key}=//" | sed 's/+/ /g' | sed 's/%/\\x/g' | xargs -0 printf '%b' 2>/dev/null)"
    else
        _val="$(echo "$QUERY_STRING" | grep -o "${_key}=[^&]*" | head -1 | sed "s/${_key}=//" | sed 's/+/ /g' | sed 's/%/\\x/g' | xargs -0 printf '%b' 2>/dev/null)"
    fi

    if [ -n "$_val" ]; then
        echo "$_val"
    else
        echo "$_default"
    fi
}

check_root
detect_env

# 解析路径
_path="$PATH_INFO"
_action="${_path#/api/}"
_action="${_action%%\?*}"

case "$_action" in
    detect)
        _pkgs=""
        while IFS='|' read -r _name _pkg _path _subdirs; do
            [ -z "$_name" ] && continue
            _display="$(get_display_name "$_name")"
            _installed="false"
            if pm list packages 2>/dev/null | grep -q "package:${_pkg}"; then
                _installed="true"
                _size="$(dir_size "$_path")"
            else
                _size="0"
            fi

            if [ -n "$_pkgs" ]; then _pkgs="$_pkgs,"; fi
            _pkgs="${_pkgs}{\"name\":\"$_name\",\"display\":\"$_display\",\"pkg\":\"$_pkg\",\"installed\":$_installed,\"size\":\"$_size\"}"
        done < "$GAMES_INI"

        output_json "{\"games\":[$_pkgs]}"
        exit 0
        ;;

    accounts)
        _game="$(get_param game "")"
        _found=""

        if [ -n "$_game" ]; then
            _dir="$ACCOUNTS_DIR/$_game"
        else
            _dir="$ACCOUNTS_DIR"
        fi

        if [ -d "$_dir" ]; then
            for _meta in $(find "$_dir" -name meta.json 2>/dev/null); do
                [ -f "$_meta" ] || continue
                _alias="$(grep '"alias"' "$_meta" | head -1 | sed 's/.*"alias": *"//' | sed 's/".*//')"
                _g="$(grep '"game"' "$_meta" | head -1 | sed 's/.*"game": *"//' | sed 's/".*//')"
                _time="$(grep '"created_at"' "$_meta" | head -1 | sed 's/.*"created_at": *"//' | sed 's/".*//')"
                _size="$(grep '"data_size"' "$_meta" | head -1 | sed 's/.*"data_size": *"//' | sed 's/".*//')"
                _display="$(get_display_name "$_g")"

                if [ -n "$_found" ]; then _found="$_found,"; fi
                _found="${_found}{\"alias\":\"$_alias\",\"game\":\"$_g\",\"display\":\"$_display\",\"time\":\"$_time\",\"size\":\"$_size\"}"
            done
        fi

        output_json "{\"accounts\":[$_found]}"
        exit 0
        ;;

    backup)
        _game="$(get_param game "")"
        _alias="$(get_param alias "")"

        if [ -z "$_game" ] || [ -z "$_alias" ]; then
            output_error "请提供游戏和账号别名"
            exit 1
        fi

        if account_backup "$_game" "$_alias" >/dev/null 2>&1; then
            output_json "{\"ok\":true,\"alias\":\"$_alias\"}"
        else
            output_error "备份失败"
        fi
        exit 0
        ;;

    restore)
        _alias="$(get_param alias "")"

        if [ -z "$_alias" ]; then
            output_error "请提供账号别名"
            exit 1
        fi

        if switch_account "$_alias" >/dev/null 2>&1; then
            output_json "{\"ok\":true,\"alias\":\"$_alias\"}"
        else
            output_error "恢复失败"
        fi
        exit 0
        ;;

    delete)
        _alias="$(get_param alias "")"

        if [ -z "$_alias" ]; then
            output_error "请提供账号别名"
            exit 1
        fi

        if account_delete "$_alias" </dev/null >/dev/null 2>&1; then
            output_json "{\"ok\":true,\"alias\":\"$_alias\"}"
        else
            output_error "删除失败"
        fi
        exit 0
        ;;

    ai/chat)
        _msg="$(get_param msg "")"
        if [ -z "$_msg" ]; then
            output_error "请输入消息内容"
            exit 1
        fi
        _resp="$(ai_chat "$_msg")"
        output_json "$_resp"
        exit 0
        ;;

    ai/config)
        _action="$(get_param action "")"
        load_ai_config
        case "$_action" in
            get)
                ai_status
                exit 0
                ;;
            set)
                _key="$(get_param key "")"
                if [ -z "$_key" ]; then
                    output_error "请提供 API Key"
                    exit 1
                fi
                save_ai_config "$_key"
                output_json "{\"ok\":true,\"message\":\"API Key 已保存\"}"
                exit 0
                ;;
            delete)
                cat /dev/null > "$AI_CONFIG" 2>/dev/null
                output_json "{\"ok\":true,\"message\":\"配置已清除\"}"
                exit 0
                ;;
            *)
                output_error "ai/config 用法: action=get|set|delete"
                exit 1
                ;;
        esac
        ;;

    ai/command)
        _msg="$(get_param msg "")"
        if [ -z "$_msg" ]; then
            output_error "请输入指令内容"
            exit 1
        fi
        _resp="$(ai_parse_command "$_msg")"
        output_json "$_resp"
        exit 0
        ;;

    status)
        output_json "{\"ok\":true,\"version\":\"v1.0.0\",\"dataDir\":\"$DATA_DIR\"}"
        exit 0
        ;;

    *)
        output_json "{\"error\":\"未知接口\",\"usage\":\"detect|accounts|backup|restore|delete|status|ai/chat|ai/config|ai/command\"}"
        exit 1
        ;;
esac
