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
account_backup() {
    _game_name="$1"
    _alias="$2"

    if [ -z "$_game_name" ] || [ -z "$_alias" ]; then
        log_err "用法: backup <游戏简名> <账号别名>"
        return 1
    fi

    _pkg="$(get_pkg_name "$_game_name")"
    if [ -z "$_pkg" ]; then
        log_err "未知游戏: $_game_name"
        log_info "可用游戏:"
        list_all_games | while IFS='|' read -r n p _ _; do
            echo "  $n ($(get_display_name "$n"))"
        done
        return 1
    fi

    _game_data="$(get_pkg_data_path "$_game_name")"
    if [ ! -d "$_game_data" ]; then
        log_err "游戏数据目录不存在: $_game_data"
        return 1
    fi

    _acct_dir="$(_get_account_dir "$_game_name" "$_alias")"
    _meta="$(_get_meta_path "$_acct_dir")"
    _data_dir="$(_get_data_path "$_acct_dir")"

    if [ -f "$_meta" ]; then
        log_warn "账号 '$_alias' 已存在"
        printf "是否覆盖? [y/N]: "
        read -r _confirm
        case "$_confirm" in
            [Yy]*) log_info "将覆盖已有账号" ;;
            *) log_info "已取消"; return 0 ;;
        esac
        rm -rf "$_acct_dir"
    fi

    mkdir -p "$_acct_dir" "$_data_dir"

    _subdirs="$(get_pkg_subdirs "$_game_name")"
    _backup_count=0

    IFS=',' 
    for _subdir in $_subdirs; do
        _subdir="$(echo "$_subdir" | tr -d ' ')"
        _src="$game_data/$_subdir"
        _dst="$_data_dir/$_subdir"

        if [ -d "$_src" ]; then
            cp -r "$_src" "$_dst" 2>/dev/null
            if [ $? -eq 0 ]; then
                _backup_count=$(( _backup_count + 1 ))
            else
                log_warn "复制 $_subdir 失败"
            fi
        else
            log_warn "子目录不存在, 跳过: $_subdir"
        fi
    done
    unset IFS

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
    "backup_subdirs": "$_subdirs"
}
EOF

    log_ok "账号备份完成: $_alias"
    log_info "  游戏: $_display"
    log_info "  路径: $_acct_dir"
    log_info "  大小: $_size"
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
        log_info "使用 'qiuhe.sh backup <游戏> <别名>' 创建第一个账号存档"
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

    if [ -z "$_alias" ]; then
        log_err "用法: delete <账号别名>"
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

            printf "确认删除? 输入 yes 确认: "
            read -r _confirm
            if [ "$_confirm" != "yes" ]; then
                log_info "已取消删除"
                return 0
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
