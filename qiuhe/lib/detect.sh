#!/system/bin/sh
#===============================================================================
# 腾讯手游账号本地切换器 - 游戏检测模块
#===============================================================================

# 扫描设备上所有已安装的腾讯手游（含分身版）
detect_games() {
    if [ "$HAS_PM" = false ]; then
        log_err "缺少 pm 命令, 无法检测已安装游戏"
        log_err "请在有 pm 命令的环境中运行 (如 root 终端或 ADB Shell)"
        return 1
    fi

    log_info "正在扫描已安装的腾讯手游 (含分身版)..."
    echo ""

    _found=0
    _all_packages="$(pm list packages 2>/dev/null)"

    # 收集分身用户包列表
    _clone_users="$(pm list users 2>/dev/null | sed -n 's/.*UserInfo{\([0-9]*\).*/\1/p' | grep -v '^0$')"

    while IFS='|' read -r _name _pkg _path _subdirs; do
        [ -z "$_name" ] && continue
        _display="$(get_display_name "$_name")"

        # 正式版
        if echo "$_all_packages" | grep -q "package:${_pkg}"; then
            _found=$(( _found + 1 ))
            _size="$(dir_size "$_path")"
            echo "  [$_display]  简名: $_name  包名: $_pkg"
            echo "    路径: $_path  大小: $_size"
        fi

        # 分身版（遍历所有非主用户）
        for _uid in $_clone_users; do
            if echo "$_all_packages" | grep -q "package:${_pkg}" 2>/dev/null \
               && pm list packages --user "$_uid" 2>/dev/null | grep -q "package:${_pkg}"; then
                _clone_path="/data/user/${_uid}/${_pkg}"
                [ -d "$_clone_path" ] || _clone_path="/data/user_de/${_uid}/${_pkg}"
                if [ -d "$_clone_path" ]; then
                    _found=$(( _found + 1 ))
                    _csize="$(dir_size "$_clone_path")"
                    echo "  [$_display · 分身]  (用户 $_uid)"
                    echo "    路径: $_clone_path  大小: $_csize"
                fi
            fi
        done
    done < "$GAMES_INI"

    echo ""
    if [ "$_found" -eq 0 ]; then
        log_warn "未检测到已知的腾讯手游"
        log_info "你可以手动添加游戏配置到 $GAMES_INI"
    else
        log_ok "共检测到 $_found 项 (含分身版)"
    fi

    return 0
}

# 极速检测 — 缓存所有 pm 输出, 跳过 du 扫描
detect_all_entries() {
    _entries=""
    _all_pkg="$(pm list packages 2>/dev/null)"
    _clone_users="$(pm list users 2>/dev/null | sed -n 's/.*UserInfo{\([0-9]*\).*/\1/p' | grep -v '^0$')"
    # 预缓存分身用户包列表
    _clone_pkgs=""
    for _uid in $_clone_users; do
        _up="$(pm list packages --user "$_uid" 2>/dev/null)"
        _clone_pkgs="$_clone_pkgs
$_uid:$_up"
    done

    while IFS='|' read -r _name _pkg _path _subdirs; do
        [ -z "$_name" ] && continue
        _display="$(get_display_name "$_name")"

        # 正式版 — 使用预缓存列表
        if echo "$_all_pkg" | grep -q "package:${_pkg}"; then
            _has_dir="false"
            [ -d "$_path" ] && _has_dir="true"
            _entry="{\"name\":\"$_name\",\"display\":\"$_display\",\"pkg\":\"$_pkg\",\"path\":\"$_path\",\"installed\":true,\"size\":\"—\",\"clone\":false}"
            [ -n "$_entries" ] && _entries="$_entries,"
            _entries="${_entries}${_entry}"
        fi

        # 分身版 — 使用预缓存列表
        for _uid in $_clone_users; do
            _userline="$(echo "$_clone_pkgs" | grep "^${_uid}:" | head -1)"
            if echo "${_userline#*:}" | grep -q "package:${_pkg}"; then
                for _pref in /data/user /data/user_de; do
                    _cp="${_pref}/${_uid}/${_pkg}"
                    if [ -d "$_cp" ]; then
                        _centry="{\"name\":\"$_name\",\"display\":\"$_display · 分身\",\"pkg\":\"$_pkg\",\"path\":\"$_cp\",\"installed\":true,\"size\":\"—\",\"clone\":true}"
                        [ -n "$_entries" ] && _entries="$_entries,"
                        _entries="${_entries}${_centry}"
                        break
                    fi
                done
            fi
        done
    done < "$GAMES_INI"

    echo "$_entries"
}

# 检测单款游戏是否存在（含分身）
check_game_installed() {
    _name="$1"
    _pkg="$(get_pkg_name "$_name")"

    if [ -z "$_pkg" ]; then
        log_err "未知游戏: $_name"
        return 1
    fi

    if pm list packages 2>/dev/null | grep -q "package:${_pkg}"; then
        return 0
    fi

    # 也检查分身版（扫描其他用户）
    for _uid in $(pm list users 2>/dev/null | sed -n 's/.*UserInfo{\([0-9]*\).*/\1/p' | grep -v '^0$'); do
        if pm list packages --user "$_uid" 2>/dev/null | grep -q "package:${_pkg}"; then
            return 0
        fi
    done

    log_err "游戏未安装: $(get_display_name "$_name") ($_pkg)"
    return 1
}
