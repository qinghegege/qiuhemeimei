#!/system/bin/sh
#===============================================================================
# 腾讯手游账号本地切换器 - 游戏检测模块
#===============================================================================

# 扫描设备上已安装的腾讯手游
detect_games() {
    if [ "$HAS_PM" = false ]; then
        log_err "缺少 pm 命令, 无法检测已安装游戏"
        log_err "请在有 pm 命令的环境中运行 (如 root 终端或 ADB Shell)"
        return 1
    fi

    log_info "正在扫描已安装的腾讯手游..."

    _found=0
    _installed_games=""
    _all_packages="$(pm list packages 2>/dev/null)"

    while IFS='|' read -r _name _pkg _path _subdirs; do
        [ -z "$_name" ] && continue
        _display="$(get_display_name "$_name")"

        if echo "$_all_packages" | grep -q "package:${_pkg}"; then
            _found=$(( _found + 1 ))
            _installed_games="${_installed_games}${_name} "
            _data_path="$_path"
            _size="$(dir_size "$_data_path")"

            echo ""
            log_info "--- $_display ---"
            echo "  简名: $_name"
            echo "  包名: $_pkg"
            echo "  数据路径: $_data_path"
            echo "  数据大小: $_size"
            echo "  备份子目录: $_subdirs"
        fi
    done < "$GAMES_INI"

    echo ""
    if [ "$_found" -eq 0 ]; then
        log_warn "未检测到已知的腾讯手游"
        log_info "你可以手动添加游戏配置到 $GAMES_INI"
    else
        log_ok "共检测到 $_found 款已安装的腾讯手游"
    fi

    return 0
}

# 检测单款游戏是否存在
check_game_installed() {
    _name="$1"
    _pkg="$(get_pkg_name "$_name")"

    if [ -z "$_pkg" ]; then
        log_err "未知游戏: $_name"
        return 1
    fi

    if pm list packages 2>/dev/null | grep -q "package:${_pkg}"; then
        return 0
    else
        log_err "游戏未安装: $(get_display_name "$_name") ($_pkg)"
        return 1
    fi
}
