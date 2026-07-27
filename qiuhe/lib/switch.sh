#!/system/bin/sh
#===============================================================================
# 腾讯手游账号本地切换器 - 切换引擎
#===============================================================================

# 检测游戏进程是否正在运行
check_game_running() {
    _pkg="$1"

    if [ "$HAS_PGREP" = false ]; then
        log_warn "pgrep 不可用, 跳过进程检测"
        return 0
    fi

    if pgrep -f "$_pkg" >/dev/null 2>&1; then
        _display="$(get_display_name "$(find_name_by_pkg "$_pkg")")"
        log_err "游戏正在运行: $_display"
        log_err "请关闭游戏后再切换账号"
        return 1
    fi

    return 0
}

# 切换前自动备份当前数据（自动快照）
backup_current() {
    _game_name="$1"
    _pkg="$2"

    _game_data="$(get_pkg_data_path "$_game_name")"
    if [ ! -d "$_game_data" ]; then
        log_err "游戏数据目录不存在: $_game_data"
        return 1
    fi

    _now="$(date '+%Y%m%d_%H%M%S')"
    _snapshot_dir="$SNAPSHOTS_DIR/$_game_name/auto_$_now"

    mkdir -p "$_snapshot_dir"

    _subdirs="$(get_pkg_subdirs "$_game_name")"
    _backup_count=0

    IFS=','
    for _subdir in $_subdirs; do
        _subdir="$(echo "$_subdir" | tr -d ' ')"
        _src="$_game_data/$_subdir"
        _dst="$_snapshot_dir/$_subdir"

        if [ -d "$_src" ]; then
            cp -r "$_src" "$_dst" 2>/dev/null
            if [ $? -eq 0 ]; then
                _backup_count=$(( _backup_count + 1 ))
            fi
        fi
    done
    unset IFS

    _snap_meta="$_snapshot_dir/snapshot.json"

    cat > "$_snap_meta" << EOF
{
    "type": "auto_snapshot",
    "game": "$_game_name",
    "package": "$_pkg",
    "timestamp": "$_now",
    "subdirs": "$_subdirs"
}
EOF

    echo "$_snapshot_dir"

    # 清理旧快照，保留最近 10 条
    _count=0
    for _snap in $(ls -dt "$SNAPSHOTS_DIR/$_game_name"/auto_* 2>/dev/null); do
        _count=$(( _count + 1 ))
        if [ "$_count" -gt 10 ]; then
            rm -rf "$_snap" 2>/dev/null
        fi
    done
}

# 将账号存档数据写入游戏数据目录
apply_account() {
    _alias="$1"

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

    _acct_dir="$(dirname "$_found_meta")"
    _game="$(grep '"game"' "$_found_meta" | head -1 | sed 's/.*"game": *"//' | sed 's/".*//')"
    _pkg="$(grep '"package"' "$_found_meta" | head -1 | sed 's/.*"package": *"//' | sed 's/".*//')"
    _data_dir="$(_get_data_path "$_acct_dir")"
    # 读取备份时记录的实际数据路径 (分身版路径可能不同于默认)
    _stored_path="$(grep '"data_path"' "$_found_meta" 2>/dev/null | head -1 | sed 's/.*"data_path": *"//' | sed 's/".*//')"

    if [ ! -d "$_data_dir" ]; then
        log_err "账号数据目录不存在: $_data_dir"
        return 1
    fi

    # 优先使用存档路径, 回退到配置文件中的默认路径
    if [ -n "$_stored_path" ] && [ -d "$_stored_path" ]; then
        _game_data="$_stored_path"
    else
        _game_data="$(get_pkg_data_path "$_game")"
    fi
    if [ ! -d "$_game_data" ]; then
        log_err "游戏数据目录不存在: $_game_data"
        return 1
    fi

    # 清空游戏数据子目录
    _subdirs="$(get_pkg_subdirs "$_game")"
    IFS=','
    for _subdir in $_subdirs; do
        _subdir="$(echo "$_subdir" | tr -d ' ')"
        _target="$_game_data/$_subdir"
        if [ -d "$_target" ]; then
            rm -rf "${_target:?}"/*
        fi
        mkdir -p "$_target"
    done
    unset IFS

    # 写入存档数据
    IFS=','
    for _subdir in $_subdirs; do
        _subdir="$(echo "$_subdir" | tr -d ' ')"
        _src="$_data_dir/$_subdir"
        _dst="$_game_data/$_subdir"

        if [ -d "$_src" ]; then
            rm -rf "${_dst:?}"/*
            cp -r "$_src"/* "$_dst/" 2>/dev/null
            if [ $? -ne 0 ]; then
                log_err "写入 $_subdir 失败"
                return 1
            fi
        fi
    done
    unset IFS

    # 修复文件权限
    fix_permissions "$_game_data"

    return 0
}

# 修复文件权限和 SELinux 上下文
fix_permissions() {
    _game_data="$1"

    if [ ! -d "$_game_data" ]; then
        return 1
    fi

    _uid="$(stat -c '%u' "$_game_data" 2>/dev/null)"
    _gid="$(stat -c '%g' "$_game_data" 2>/dev/null)"

    if [ -n "$_uid" ] && [ -n "$_gid" ]; then
        chown -R "${_uid}:${_gid}" "$_game_data" 2>/dev/null
    fi

    if [ "$HAS_RESTORECON" = true ]; then
        restorecon -R "$_game_data" 2>/dev/null
    fi
}

# 切换失败时回滚
rollback() {
    _game_name="$1"
    _snapshot_dir="$2"

    if [ -z "$_snapshot_dir" ] || [ ! -d "$_snapshot_dir" ]; then
        log_err "回滚失败: 快照不存在"
        return 1
    fi

    _game_data="$(get_pkg_data_path "$_game_name")"
    if [ ! -d "$_game_data" ]; then
        log_err "回滚失败: 游戏数据目录不存在"
        return 1
    fi

    log_warn "正在回滚..."

    _subdirs="$(get_pkg_subdirs "$_game_name")"
    IFS=','
    for _subdir in $_subdirs; do
        _subdir="$(echo "$_subdir" | tr -d ' ')"
        _src="$_snapshot_dir/$_subdir"
        _dst="$_game_data/$_subdir"

        if [ -d "$_src" ]; then
            rm -rf "${_dst:?}"/*
            cp -r "$_src"/* "$_dst/" 2>/dev/null
        fi
    done
    unset IFS

    _pkg="$(get_pkg_name "$_game_name")"
    fix_permissions "$_game_data"
    log_ok "回滚完成"
}

# 一键切换主流程
switch_account() {
    _alias="$1"

    if [ -z "$_alias" ]; then
        log_err "用法: switch <账号别名>"
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
        log_info "使用 '清荷 list' 查看可用账号"
        return 1
    fi

    _acct_dir="$(dirname "$_found_meta")"
    _game="$(grep '"game"' "$_found_meta" | head -1 | sed 's/.*"game": *"//' | sed 's/".*//')"
    _pkg="$(grep '"package"' "$_found_meta" | head -1 | sed 's/.*"package": *"//' | sed 's/".*//')"
    _data_dir="$(_get_data_path "$_acct_dir")"
    _display="$(get_display_name "$_game")"

    if [ ! -d "$_data_dir" ]; then
        log_err "账号数据不完整: $_data_dir 不存在"
        log_err "该账号存档可能已损坏, 请使用 account info 查看详情"
        return 1
    fi

    log_info "准备切换账号..."
    echo "  游戏: $_display"
    echo "  账号: $_alias"
    echo ""

    # Step 1: 检测游戏进程
    log_info "正在检测游戏进程..."
    check_game_running "$_pkg" || return 1

    # Step 2: 备份当前数据
    log_info "正在备份当前数据..."
    _snapshot_dir="$(backup_current "$_game" "$_pkg")"
    if [ $? -ne 0 ] || [ -z "$_snapshot_dir" ]; then
        log_err "备份失败, 切换终止"
        return 1
    fi
    log_ok "当前数据已备份: $_snapshot_dir"

    # Step 3: 写入目标账号数据
    log_info "正在写入目标账号数据..."
    if ! apply_account "$_alias"; then
        log_err "数据写入失败, 正在回滚..."
        rollback "$_game" "$_snapshot_dir"
        return 1
    fi

    # Step 4: 完成
    echo ""
    log_ok "切换完成!"
    echo "  游戏: $_display"
    echo "  当前账号: $_alias"
    echo "  备份已保存到: $_snapshot_dir"
    return 0
}

# 快照列表
snapshot_list() {
    _game_name="$1"

    if [ -z "$_game_name" ]; then
        log_err "用法: snapshot list <游戏简名>"
        return 1
    fi

    _snap_dir="$SNAPSHOTS_DIR/$_game_name"
    if [ ! -d "$_snap_dir" ]; then
        log_info "暂无快照记录"
        return 0
    fi

    _display="$(get_display_name "$_game_name")"
    echo ""
    echo "$_display 快照列表:"
    echo ""

    _found=0
    for _snap in $(ls -dt "$_snap_dir"/auto_* 2>/dev/null); do
        _found=$(( _found + 1 ))
        _snap_name="$(basename "$_snap")"
        _timestamp="$(echo "$_snap_name" | sed 's/auto_//')"
        # 格式化时间戳: 20260726_203000 → 2026-07-26 20:30:00
        _formatted="$(echo "$_timestamp" | sed 's/\(....\)\(..\)\(..\)_\(..\)\(..\)\(..\)/\1-\2-\3 \4:\5:\6/')"
        _size="$(dir_size "$_snap")"
        echo "  $_snap_name  |  $_formatted  |  $_size"
    done

    if [ "$_found" -eq 0 ]; then
        log_info "  (无快照)"
    else
        echo ""
        log_info "共 $_found 条快照 (保留最近 10 条)"
    fi

    return 0
}

# 回滚到指定快照
restore_snapshot() {
    _game_name="$1"
    _snapshot_id="$2"

    if [ -z "$_game_name" ] || [ -z "$_snapshot_id" ]; then
        log_err "用法: restore <游戏简名> <快照ID>"
        return 1
    fi

    _snap_dir="$SNAPSHOTS_DIR/$_game_name/$_snapshot_id"
    if [ ! -d "$_snap_dir" ]; then
        log_err "快照不存在: $_snapshot_id"
        log_info "使用 'snapshot list $_game_name' 查看可用快照"
        return 1
    fi

    _pkg="$(get_pkg_name "$_game_name")"
    if [ -z "$_pkg" ]; then
        log_err "未知游戏: $_game_name"
        return 1
    fi

    log_info "正在回滚到快照: $_snapshot_id"
    rollback "$_game_name" "$_snap_dir"
    return $?
}
