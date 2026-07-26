#!/system/bin/sh
#===============================================================================
# 腾讯手游账号本地切换器 - DeepSeek AI 模块
#===============================================================================

AI_CONFIG="$DATA_DIR/ai.conf"
AI_API_URL="https://api.deepseek.com/v1/chat/completions"

load_ai_config() {
    if [ -f "$AI_CONFIG" ]; then
        . "$AI_CONFIG"
    fi
    AI_API_KEY="${AI_API_KEY:-}"
    AI_MODEL="${AI_MODEL:-deepseek-chat}"
}

save_ai_config() {
    printf 'AI_API_KEY="%s"\n' "$1" > "$AI_CONFIG"
    printf 'AI_MODEL="%s"\n' "$AI_MODEL" >> "$AI_CONFIG"
    chmod 600 "$AI_CONFIG"
}

# JSON 字符串转义
_esc() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n\r'
}

# 构造系统提示词
_build_system_prompt() {
    cat << 'SYSEOF'
你是 清荷（腾讯手游账号本地切换器）的 AI 助手，运行在 Android 手机上。
你可以帮助用户解答账号切换、备份、恢复等操作问题，指导用户完成账号管理。

清荷 支持的游戏：
- 王者荣耀 (sgame)
- 和平精英 (pubgm)
- CF手游 (cf)
- QQ飞车 (speed)
- 使命召唤手游 (cod)
- 金铲铲之战 (jkchess)
- 英雄联盟手游 (lolm)
- 火影忍者 (kihan)
- 天涯明月刀 (wuxia)

支持的操作：backup(备份), list(列出), delete(删除), switch(切换), detect(检测), export(导出), import(导入)

若用户想执行操作，请输出 JSON 命令，格式：
{"cmd":"<操作>","game":"<游戏简名>","alias":"<账号别名>"}
若纯聊天，直接回复文字。回复简洁专业，英文术语用英文，其他用中文。
SYSEOF
}

# 核心对话函数
# 参数: $1=用户消息, $2=系统提示(可选)
ai_chat() {
    _user_msg="$1"
    _sys_msg="${2:-$(_build_system_prompt)}"

    load_ai_config
    if [ -z "$AI_API_KEY" ]; then
        echo '{"error":"api_key_not_configured"}'
        return 1
    fi

    if ! command -v curl >/dev/null 2>&1; then
        echo '{"error":"curl_not_available"}'
        return 1
    fi

    _sys_esc="$(_esc "$_sys_msg")"
    _usr_esc="$(_esc "$_user_msg")"

    _body="{\"model\":\"$AI_MODEL\",\"messages\":[{\"role\":\"system\",\"content\":\"$_sys_esc\"},{\"role\":\"user\",\"content\":\"$_usr_esc\"}],\"temperature\":0.7,\"max_tokens\":1024}"

    curl -s --connect-timeout 30 -X POST "$AI_API_URL" \
        -H "Authorization: Bearer $AI_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$_body" 2>/dev/null
}

# 自然语言命令解析
# 仅返回 JSON 命令，不闲聊
ai_parse_command() {
    _input="$1"

    _sys_prompt="$(_build_system_prompt)
重要：你必须只输出 JSON 命令，不要输出其他任何文字。
若用户输入是自然语言操作指令（如「切换到王者荣耀大号」），解析后输出：
{"cmd":"switch","game":"sgame","alias":"大号"}
若用户输入是闲聊或询问，输出：
{"cmd":"chat","reply":"你的文字回复"}
游戏简名从用户输入中智能匹配。若匹配不到，game 为空字符串。"
    _user_msg="解析用户的自然语言输入: $_input"

    _resp="$(ai_chat "$_user_msg" "$_sys_prompt")"
    echo "$_resp"
}

# 检查 AI 配置状态
ai_status() {
    load_ai_config
    if [ -n "$AI_API_KEY" ]; then
        _masked="$(echo "$AI_API_KEY" | sed 's/.\{4\}$/****/' | sed 's/^\(.\)\(.\{4,\}\)/\1****/')"
        echo "{\"configured\":true,\"model\":\"$AI_MODEL\",\"keyHint\":\"$_masked\"}"
    else
        echo "{\"configured\":false,\"model\":\"$AI_MODEL\"}"
    fi
}
