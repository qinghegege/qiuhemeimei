#!/system/bin/sh
#===============================================================================
# 腾讯手游账号本地切换器 - 账号管理模块
#===============================================================================

# 生成账号存档路径
_get_account_dir() {
    _name="$1"
    _alias="$2"
    echo "$ACCOUNTS_DIR/$_name/$_alias"
}

# 获取账号 meta.json 路径
_get_meta_path() {
    _acct_dir="$1"
    echo "$_acct_dir/meta.json"
}

# 获取账号数据目录路径
_get_data_path() {
    _acct_dir="$1"
    echo "$_acct_dir/data"
}

# 备份当前游戏数据为账号存档
# 用法: account_backup <游戏简名> <账号别名> [自定义数据路径]
account_backup() {
    _game_name="$1"
    _alias="$2"
    _custom_path="$3"

    if [ -z "$_game_name" ] || [ -z "$_alias" ]; then
        log_err "用法: backup <游戏简名> <账号别名> [数据路径]"
        return 1
    fi

    _pkg="$(get_pkg_name "$_game_name")"
    if [ -z "$_pkg" ]; then
        log_err "未知游戏: $_game_name"
        return 1
    fi

    if [ -n "$_custom_path" ]; then
        _game_data="$_custom_path"
    else
        _game_data="$(get_pkg_data_path "$_game_name")"
    fi

    if [ ! -d "$_game_data" ]; then
        log_err "游戏数据目录不存在: $_game_data"
        return 1
    fi
    if [ ! -r "$_game_data" ]; then
        log_err "无权限读取数据目录: $_game_data"
        log_info "请检查 SELinux 状态 (getenforce) 或确认 KSU 授权正常"
        return 1
    fi

    # 检测游戏进程
    if [ "$HAS_PGREP" = true ]; then
        if pgrep -f "$_pkg" >/dev/null 2>&1; then
            _display="$(get_display_name "$_game_name")"
            log_err "$_display 正在运行，请先关闭游戏"
            return 1
        fi
    fi

    _acct_dir="$(_get_account_dir "$_game_name" "$_alias")"
    _meta="$(_get_meta_path "$_acct_dir")"
    _data_dir="$(_get_data_path "$_acct_dir")"

    if [ -f "$_meta" ]; then
        log_warn "账号 '$_alias' 已存在"
        if [ -t 0 ]; then
            printf "是否覆盖? [y/N]: "
            read -r _confirm
            case "$_confirm" in
                [Yy]*) log_info "将覆盖已有账号" ;;
                *) log_info "已取消"; return 0 ;;
            esac
        fi
        rm -rf "$_acct_dir"
    fi

    mkdir -p "$_data_dir"
    check_disk_space "$_acct_dir" 100 || return 1

    selinux_temp_disable

    # 完整备份: tar 打包所有数据 (排除 cache/code_cache/lib)
    _tar_err="/tmp/qh_backup_err_$$"
    if (cd "$_game_data" && tar cf - --exclude='./cache' --exclude='./code_cache' --exclude='./lib' . 2>"$_tar_err") | (cd "$_data_dir" && tar xf - 2>>"$_tar_err"); then
        rm -f "$_tar_err"
    else
        _err_msg="$(head -3 "$_tar_err" 2>/dev/null)"
        rm -f "$_tar_err"
        log_err "备份失败: ${_err_msg:-未知错误}"
        rm -rf "$_acct_dir"
        selinux_restore
        return 1
    fi

    _display="$(get_display_name "$_game_name")"
    _now="$(date '+%Y-%m-%d %H:%M:%S')"
    _size="$(dir_size "$_data_dir")"

    cat > "$_meta" << EOF
{
    "game": "$_game_name",
    "game_display": "$_display",
    "package": "$_pkg",
    "alias": "$_alias",
    "created_at": "$_now",
    "data_size": "$_size",
    "data_path": "$_game_data",
    "backup_method": "full"
}
EOF

    log_ok "账号备份完成: $_alias"
    log_info "  游戏: $_display"
    log_info "  路径: $_acct_dir"
    log_info "  大小: $_size"
    selinux_restore
    return 0
}

# 列出已备份账号
account_list() {
    _game_filter="$1"

    if [ -n "$_game_filter" ]; then
        _dirs="$ACCOUNTS_DIR/$_game_filter"
    else
        _dirs="$ACCOUNTS_DIR"
    fi

    if [ ! -d "$_dirs" ]; then
        log_info "暂无已备份账号"
        log_info "使用 '清荷 backup <游戏> <别名>' 创建第一个账号存档"
        return 0
    fi

    _found=0
    echo ""
    printf "%-12s  %-16s  %-20s  %s\n" "游戏" "账号别名" "备份时间" "大小"
    printf "%-12s  %-16s  %-20s  %s\n" "----" "--------" "--------" "----"

    for _game_dir in "$_dirs"/*/ ; do
        [ -d "$_game_dir" ] || continue
        for _acct_dir in "$_game_dir"*/; do
            [ -d "$_acct_dir" ] || continue
            _meta="$(_get_meta_path "$_acct_dir")"
            if [ -f "$_meta" ]; then
                _game="$(grep '"game"' "$_meta" 2>/dev/null | head -1 | sed 's/.*"game": *"//' | sed 's/".*//')"
                _alias="$(grep '"alias"' "$_meta" 2>/dev/null | head -1 | sed 's/.*"alias": *"//' | sed 's/".*//')"
                _time="$(grep '"created_at"' "$_meta" 2>/dev/null | head -1 | sed 's/.*"created_at": *"//' | sed 's/".*//')"
                _size="$(grep '"data_size"' "$_meta" 2>/dev/null | head -1 | sed 's/.*"data_size": *"//' | sed 's/".*//')"
                printf "%-12s  %-16s  %-20s  %s\n" \
                    "$(get_display_name "$_game")" "$_alias" "$_time" "$_size"
                _found=$(( _found + 1 ))
            fi
        done
    done

    if [ "$_found" -eq 0 ]; then
        log_info "暂无已备份账号"
    else
        echo ""
        log_info "共 $_found 个账号存档"
    fi
    return 0
}

# 查看账号详情
account_info() {
    _alias="$1"

    if [ -z "$_alias" ]; then
        log_err "用法: info <账号别名>"
        return 1
    fi

    _found_meta=""
    _match_count=0

    for _meta in "$ACCOUNTS_DIR"/*/*/meta.json; do
        [ -f "$_meta" ] || continue
        _a="$(grep '"alias"' "$_meta" 2>/dev/null | head -1 | sed 's/.*"alias": *"//' | sed 's/".*//')"
        if [ "$_a" = "$_alias" ]; then
            _found_meta="$_meta"
            _match_count=$(( _match_count + 1 ))
        fi
    done

    if [ "$_match_count" -eq 0 ]; then
        log_err "账号不存在: $_alias"
        return 1
    fi

    if [ "$_match_count" -gt 1 ]; then
        log_warn "存在 $_match_count 个同名账号, 显示第一个匹配项"
    fi

    _acct_dir="$(dirname "$_found_meta")"
    _game="$(grep '"game"' "$_found_meta" | head -1 | sed 's/.*"game": *"//' | sed 's/".*//')"
    _display="$(grep '"game_display"' "$_found_meta" 2>/dev/null | head -1 | sed 's/.*"game_display": *"//' | sed 's/".*//')"
    _pkg="$(grep '"package"' "$_found_meta" | head -1 | sed 's/.*"package": *"//' | sed 's/".*//')"
    _time="$(grep '"created_at"' "$_found_meta" | head -1 | sed 's/.*"created_at": *"//' | sed 's/".*//')"
    _size="$(grep '"data_size"' "$_found_meta" | head -1 | sed 's/.*"data_size": *"//' | sed 's/".*//')"

    echo ""
    echo "  账号别名: $_alias"
    echo "  游戏: $_display ($_game)"
    echo "  包名: $_pkg"
    echo "  创建时间: $_time"
    echo "  数据大小: $_size"
    echo "  存储路径: $_acct_dir"
    echo ""
    return 0
}

# 删除账号存档
account_delete() {
    _alias="$1"
    _force="${2:-0}"

    if [ -z "$_alias" ]; then
        log_err "用法: delete <账号别名> [--force]"
        return 1
    fi

    _found=0
    for _meta in "$ACCOUNTS_DIR"/*/*/meta.json; do
        [ -f "$_meta" ] || continue
        _a="$(grep '"alias"' "$_meta" 2>/dev/null | head -1 | sed 's/.*"alias": *"//' | sed 's/".*//')"
        if [ "$_a" = "$_alias" ]; then
            _found=$(( _found + 1 ))
            _acct_dir="$(dirname "$_meta")"
            _game="$(grep '"game"' "$_meta" | head -1 | sed 's/.*"game": *"//' | sed 's/".*//')"
            _display="$(get_display_name "$_game")"
            _size="$(grep '"data_size"' "$_meta" | head -1 | sed 's/.*"data_size": *"//' | sed 's/".*//')"

            echo ""
            log_warn "将删除以下账号:"
            echo "  游戏: $_display"
            echo "  别名: $_alias"
            echo "  大小: $_size"
            echo "  路径: $_acct_dir"
            echo ""

            if [ "$_force" != "1" ]; then
                printf "确认删除? 输入 yes 确认: "
                read -r _confirm </dev/tty 2>/dev/null || _confirm=""
                if [ "$_confirm" != "yes" ]; then
                    log_info "已取消删除"
                    return 0
                fi
            fi

            rm -rf "$_acct_dir"
            log_ok "账号已删除: $_alias"

            _parent="$(dirname "$_acct_dir")"
            if [ -z "$(ls -A "$_parent" 2>/dev/null)" ]; then
                rmdir "$_parent" 2>/dev/null
            fi
        fi
    done

    if [ "$_found" -eq 0 ]; then
        log_err "账号不存在: $_alias"
        return 1
    fi

    return 0
}
