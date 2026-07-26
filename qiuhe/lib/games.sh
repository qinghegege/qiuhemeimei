#!/system/bin/sh
#===============================================================================
# 腾讯手游账号本地切换器 - 游戏配置解析模块
#===============================================================================

GAMES_INI="$QIUHE_HOME/lib/games.ini"

# 根据游戏简名查找包配置
# 返回: name|pkg|path|subdirs
find_pkg_by_name() {
    _name="$1"
    grep -i "^${_name}|" "$GAMES_INI" 2>/dev/null | head -1
}

# 列出所有已注册游戏
list_all_games() {
    grep -v '^#' "$GAMES_INI" | grep -v '^$'
}

# 获取游戏包名
get_pkg_name() {
    _name="$1"
    _line="$(find_pkg_by_name "$_name")"
    if [ -z "$_line" ]; then
        return 1
    fi
    echo "$_line" | cut -d'|' -f2
}

# 获取游戏数据路径
get_pkg_data_path() {
    _name="$1"
    _line="$(find_pkg_by_name "$_name")"
    if [ -z "$_line" ]; then
        return 1
    fi
    echo "$_line" | cut -d'|' -f3
}

# 获取需要备份的子目录列表
get_pkg_subdirs() {
    _name="$1"
    _line="$(find_pkg_by_name "$_name")"
    if [ -z "$_line" ]; then
        return 1
    fi
    echo "$_line" | cut -d'|' -f4
}

# 根据包名反查游戏简名
find_name_by_pkg() {
    _pkg="$1"
    grep "|${_pkg}|" "$GAMES_INI" 2>/dev/null | head -1 | cut -d'|' -f1
}

# 获取游戏显示名（友好名称）
get_display_name() {
    _name="$1"
    case "$_name" in
        sgame)  echo "王者荣耀" ;;
        pubgm)  echo "和平精英" ;;
        cf)     echo "CF手游" ;;
        speed)  echo "QQ飞车" ;;
        cod)    echo "使命召唤手游" ;;
        jkchess) echo "金铲铲之战" ;;
        lolm)   echo "英雄联盟手游" ;;
        kihan)  echo "火影忍者" ;;
        wuxia)  echo "天涯明月刀" ;;
        *)      echo "$_name" ;;
    esac
}

# 获取已注册游戏总数
count_games() {
    list_all_games | wc -l
}
