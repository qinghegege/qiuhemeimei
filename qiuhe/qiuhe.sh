#!/system/bin/sh
#===============================================================================
# 腾讯手游账号本地切换器 - 主入口脚本
# qiuhe - 手机端腾讯游戏账号切换工具
#
# 用法:
#   sh qiuhe.sh                    # 交互式菜单模式
#   sh qiuhe.sh backup <游戏> <别名>  # 备份账号
#   sh qiuhe.sh list [游戏]          # 列出账号
#   sh qiuhe.sh info <别名>          # 查看账号详情
#   sh qiuhe.sh delete <别名>        # 删除账号
#   sh qiuhe.sh switch <别名>        # 切换账号
#   sh qiuhe.sh detect             # 检测已安装游戏
#   sh qiuhe.sh snapshot <游戏>      # 快照列表
#   sh qiuhe.sh restore <游戏> <ID>  # 回滚快照
#   sh qiuhe.sh export <别名> --output <路径> [--pass <密码>]
#   sh qiuhe.sh export --all --output <目录> [--pass <密码>]
#   sh qiuhe.sh import <文件> [--pass <密码>]
#   sh qiuhe.sh web [端口]          # 启动 Web UI (默认端口 8848)
#   sh qiuhe.sh help               # 帮助信息
#===============================================================================

set -e

# 加载函数库
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QIUHE_HOME="$SCRIPT_DIR"

if [ -f "$QIUHE_HOME/lib/common.sh" ]; then
    . "$QIUHE_HOME/lib/common.sh"
    . "$QIUHE_HOME/lib/games.sh"
    . "$QIUHE_HOME/lib/crypto.sh"
    . "$QIUHE_HOME/lib/account.sh"
    . "$QIUHE_HOME/lib/detect.sh"
    . "$QIUHE_HOME/lib/switch.sh"
else
    echo "[ERR] 脚本库加载失败, 请确保 lib/ 目录与 qiuhe.sh 位于同一目录" >&2
    exit 1
fi

# 初始化
detect_env
check_root
check_dependencies
ensure_data_dirs

# --- Banner ---
show_banner() {
    echo ""
    echo "  ===================================="
    echo "   腾讯手游账号本地切换器 (清荷)"
    echo "  ===================================="
    echo ""
}

# --- 帮助信息 ---
show_help() {
    show_banner
    echo "用法: sh qiuhe.sh <命令> [参数...]"
    echo ""
    echo "命令:"
    echo "  backup   <游戏> <别名>      备份当前游戏数据为账号存档"
    echo "  list     [游戏]             列出已备份账号"
    echo "  info     <别名>             查看账号详情"
    echo "  delete   <别名>             删除账号存档"
    echo "  switch   <别名>             一键切换到目标账号"
    echo "  detect                      检测已安装的腾讯手游"
    echo "  snapshot <游戏>             查看切换快照列表"
    echo "  restore  <游戏> <快照ID>    回滚到指定快照"
    echo "  export   <别名> --output <路径> [--pass <密码>]  导出账号存档"
    echo "  export   --all --output <目录> [--pass <密码>]   导出全部账号"
    echo "  import   <文件> [--pass <密码>]                 导入账号存档"
    echo "  web      [端口]                         启动 Web UI 管理界面"
    echo "  help                        显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  sh qiuhe.sh detect"
    echo "  sh qiuhe.sh backup sgame 大号"
    echo "  sh qiuhe.sh switch 大号"
    echo "  sh qiuhe.sh list"
    echo "  sh qiuhe.sh export 大号 --output /sdcard/大号.qiuhe --pass mypassword"
    echo ""
    echo "无参数运行时进入交互式菜单模式"
    echo ""
}

# --- 导入导出 ---
# 导出单个账号存档为加密 tar.gz
export_account() {
    _alias="$1"
    _output=""
    _pass=""

    shift
    while [ $# -gt 0 ]; do
        case "$1" in
            --output) _output="$2"; shift 2 ;;
            --pass) _pass="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [ -z "$_alias" ] || [ -z "$_output" ]; then
        log_err "用法: export <账号别名> --output <路径> [--pass <密码>]"
        return 1
    fi

    _found_meta=""
    for _meta in "$ACCOUNTS_DIR"/*/*/meta.json; do
        [ -f "$_meta" ] || continue
        _a="$(grep '"alias"' "$_meta" 2>/dev/null | head -1 | sed 's/.*"alias": *"//' | sed 's/".*//')"
        if [ "$_a" = "$_alias" ]; then
            _found_meta="$_meta"
            break
        fi
    done

    if [ -z "$_found_meta" ]; then
        log_err "账号不存在: $_alias"
        return 1
    fi

    _acct_dir="$(dirname "$_found_meta")"
    _game="$(grep '"game"' "$_found_meta" | head -1 | sed 's/.*"game": *"//' | sed 's/".*//')"
    _display="$(get_display_name "$_game")"
    _size="$(grep '"data_size"' "$_found_meta" | head -1 | sed 's/.*"data_size": *"//' | sed 's/".*//')"

    echo ""
    log_info "导出账号..."
    echo "  游戏: $_display"
    echo "  别名: $_alias"
    echo "  大小: $_size"

    if [ -n "$_pass" ]; then
        log_info "  加密: 是"
        if ! tar_encrypt "$_acct_dir" "$_output" "$_pass"; then
            log_err "导出失败"
            return 1
        fi
    else
        _parent="$(dirname "$_acct_dir")"
        _acct_name="$(basename "$_acct_dir")"
        cd "$_parent" || return 1
        tar czf "$_output" "$_acct_name" 2>/dev/null
        if [ $? -ne 0 ]; then
            log_err "导出失败"
            return 1
        fi
    fi

    log_ok "导出完成: $_output"
    echo ""
    return 0
}

# 导出全部账号
export_all() {
    _output_dir=""
    _pass=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --output) _output_dir="$2"; shift 2 ;;
            --pass) _pass="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [ -z "$_output_dir" ]; then
        log_err "用法: export --all --output <目录> [--pass <密码>]"
        return 1
    fi

    mkdir -p "$_output_dir"

    _count=0
    for _meta in "$ACCOUNTS_DIR"/*/*/meta.json; do
        [ -f "$_meta" ] || continue
        _a="$(grep '"alias"' "$_meta" 2>/dev/null | head -1 | sed 's/.*"alias": *"//' | sed 's/".*//')"
        _game="$(grep '"game"' "$_meta" 2>/dev/null | head -1 | sed 's/.*"game": *"//' | sed 's/".*//')"
        _output="${_output_dir}/${_game}_${_a}.qiuhe"

        if [ -n "$_pass" ]; then
            _acct_dir="$(dirname "$_meta")"
            tar_encrypt "$_acct_dir" "$_output" "$_pass"
        else
            _acct_dir="$(dirname "$_meta")"
            _parent="$(dirname "$_acct_dir")"
            _acct_name="$(basename "$_acct_dir")"
            (cd "$_parent" && tar czf "$_output" "$_acct_name" 2>/dev/null)
        fi

        if [ $? -eq 0 ]; then
            _count=$(( _count + 1 ))
            log_ok "已导出: $_output"
        fi
    done

    echo ""
    log_info "共导出 $_count 个账号存档到: $_output_dir"
    return 0
}

# 导入账号存档
import_account() {
    _input="$1"
    _pass=""

    shift
    while [ $# -gt 0 ]; do
        case "$1" in
            --pass) _pass="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [ -z "$_input" ]; then
        log_err "用法: import <文件路径> [--pass <密码>]"
        return 1
    fi

    if [ ! -f "$_input" ]; then
        log_err "文件不存在: $_input"
        return 1
    fi

    _tmp_dir="$DATA_DIR/.import_tmp"
    rm -rf "$_tmp_dir"
    mkdir -p "$_tmp_dir"

    if [ -n "$_pass" ]; then
        if ! tar_decrypt "$_input" "$_tmp_dir" "$_pass"; then
            log_err "导入失败: 解密错误或文件损坏"
            rm -rf "$_tmp_dir"
            return 1
        fi
    else
        tar xzf "$_input" -C "$_tmp_dir" 2>/dev/null
        if [ $? -ne 0 ]; then
            log_err "导入失败: 解包错误"
            rm -rf "$_tmp_dir"
            return 1
        fi
    fi

    _import_count=0
    for _acct_dir in $(find "$_tmp_dir" -name meta.json -exec dirname {} \; 2>/dev/null); do
        _meta="$_acct_dir/meta.json"
        [ -f "$_meta" ] || continue

        _alias="$(grep '"alias"' "$_meta" | head -1 | sed 's/.*"alias": *"//' | sed 's/".*//')"
        _game="$(grep '"game"' "$_meta" | head -1 | sed 's/.*"game": *"//' | sed 's/".*//')"

        _target_dir="$ACCOUNTS_DIR/$_game/$_alias"

        if [ -d "$_target_dir" ]; then
            log_warn "账号 '$_alias' 已存在"
            printf "覆盖? [y/N]: "
            read -r _confirm
            case "$_confirm" in
                [Yy]*) rm -rf "$_target_dir" ;;
                *)
                    log_info "跳过: $_alias"
                    continue
                    ;;
            esac
        fi

        mkdir -p "$(dirname "$_target_dir")"
        cp -r "$_acct_dir" "$_target_dir"
        _import_count=$(( _import_count + 1 ))
        log_ok "已导入: $_alias ($(get_display_name "$_game"))"
    done

    rm -rf "$_tmp_dir"
    echo ""
    log_info "共导入 $_import_count 个账号存档"
    return 0
}

# --- 交互式菜单 ---
show_menu() {
    show_banner
    echo "  请选择操作:"
    echo ""
    echo "  1) 检测已安装的腾讯手游"
    echo "  2) 列出已备份账号"
    echo "  3) 备份当前游戏数据"
    echo "  4) 切换账号"
    echo "  5) 查看账号详情"
    echo "  6) 删除账号"
    echo "  7) 导出账号"
    echo "  8) 导入账号"
    echo "  9) 查看快照"
    echo "  W) 启动 Web UI"
    echo "  0) 退出"
    echo ""

    printf "  输入 [0-9/W]: "
    read -r _choice

    case "$_choice" in
        0) log_info "再见!"; exit 0 ;; 
        w|W)
            PORT="${1:-8848}"
            log_info "正在启动 Web UI..."
            exec "$QIUHE_HOME/web/server.sh" "$PORT"
            ;;
        1)
            detect_games
            ;;
        2)
            account_list
            ;;
        3)
            echo ""
            echo "可用游戏:"
            list_all_games | while IFS='|' read -r n _ _ _; do
                echo "  $n ($(get_display_name "$n"))"
            done
            echo ""
            printf "游戏简名: "
            read -r _gn
            printf "账号别名: "
            read -r _al
            account_backup "$_gn" "$_al"
            ;;
        4)
            account_list
            echo ""
            printf "要切换到的账号别名: "
            read -r _al
            switch_account "$_al"
            ;;
        5)
            printf "账号别名: "
            read -r _al
            account_info "$_al"
            ;;
        6)
            account_list
            echo ""
            printf "要删除的账号别名: "
            read -r _al
            account_delete "$_al"
            ;;
        7)
            account_list
            echo ""
            printf "要导出的账号别名 (输入 all 导出全部): "
            read -r _al
            printf "输出路径: "
            read -r _out
            printf "加密密码 (留空不加密): "
            _p="$(read_pass "")" || _p=""
            if [ "$_al" = "all" ]; then
                export_all --output "$_out" --pass "$_p"
            else
                export_account "$_al" --output "$_out" --pass "$_p"
            fi
            ;;
        8)
            printf "导入文件路径: "
            read -r _in
            printf "解密密码 (留空不加密): "
            _p="$(read_pass "")" || _p=""
            import_account "$_in" --pass "$_p"
            ;;
        9)
            echo ""
            echo "可用游戏:"
            list_all_games | while IFS='|' read -r n _ _ _; do
                echo "  $n ($(get_display_name "$n"))"
            done
            echo ""
            printf "游戏简名: "
            read -r _gn
            snapshot_list "$_gn"
            ;;
        *)
            log_err "无效选择"
            ;;
    esac

    echo ""
    echo "---"
    show_menu
}

# --- 主入口 ---
main() {
    if [ $# -eq 0 ]; then
        show_menu
        exit 0
    fi

    _cmd="$1"
    shift

    case "$_cmd" in
        help|-h|--help)
            show_help
            ;;
        detect)
            detect_games
            ;;
        backup)
            account_backup "$1" "$2"
            ;;
        list)
            account_list "$1"
            ;;
        info)
            account_info "$1"
            ;;
        delete|remove)
            account_delete "$1"
            ;;
        switch)
            switch_account "$1"
            ;;
        snapshot)
            snapshot_list "$1"
            ;;
        restore)
            restore_snapshot "$1" "$2"
            ;;
        export)
            if [ "$1" = "--all" ]; then
                shift
                export_all "$@"
            else
                export_account "$1" "$@"
            fi
            ;;
        import)
            import_account "$1" "$@"
            ;;
        web)
            PORT="${1:-8848}"
            exec "$QIUHE_HOME/web/server.sh" "$PORT"
            ;;
        *)
            log_err "未知命令: $_cmd"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
