#!/system/bin/sh
#===============================================================================
# 腾讯手游账号本地切换器 - 加密模块
#===============================================================================

# AES 加密算法
CIPHER="aes-256-cbc"
# PBKDF2 迭代次数
ITERATIONS=10000

# 安全读取密码（不回显）
read_pass() {
    _prompt="${1:-请输入密码: }"
    printf "%s" "$_prompt" >&2

    _pass=""
    stty -echo 2>/dev/null
    read -r _pass
    stty echo 2>/dev/null
    echo "" >&2

    if [ -z "$_pass" ]; then
        log_err "密码不能为空"
        return 1
    fi
    echo "$_pass"
}

# openssl aes-256-cbc 加密文件
# 参数: <源文件> <目标文件> <密码>
crypto_encrypt() {
    _src="$1"
    _dst="$2"
    _pass="$3"

    if [ "$HAS_OPENSSL" = false ]; then
        log_err "openssl 不可用, 无法加密"
        log_err "请安装 openssl 或使用无加密模式"
        return 1
    fi

    if [ ! -f "$_src" ]; then
        log_err "源文件不存在: $_src"
        return 1
    fi

    openssl enc -$CIPHER -pbkdf2 -iter $ITERATIONS -salt \
        -in "$_src" -out "$_dst" \
        -pass pass:"$_pass" 2>/dev/null

    if [ $? -eq 0 ]; then
        return 0
    else
        log_err "加密失败"
        return 1
    fi
}

# openssl aes-256-cbc 解密文件
# 参数: <源文件> <目标文件> <密码>
crypto_decrypt() {
    _src="$1"
    _dst="$2"
    _pass="$3"

    if [ "$HAS_OPENSSL" = false ]; then
        log_err "openssl 不可用, 无法解密"
        return 1
    fi

    if [ ! -f "$_src" ]; then
        log_err "源文件不存在: $_src"
        return 1
    fi

    openssl enc -d -$CIPHER -pbkdf2 -iter $ITERATIONS -salt \
        -in "$_src" -out "$_dst" \
        -pass pass:"$_pass" 2>/dev/null

    if [ $? -eq 0 ]; then
        return 0
    else
        log_err "解密失败 (密码错误或文件损坏)"
        rm -f "$_dst"
        return 1
    fi
}

# tar 打包并加密
# 参数: <源目录> <输出文件> <密码>
tar_encrypt() {
    _src_dir="$1"
    _output="$2"
    _pass="$3"

    if [ ! -d "$_src_dir" ]; then
        log_err "源目录不存在: $_src_dir"
        return 1
    fi

    _tmp_tar="${_output}.tmp.tar.gz"

    cd "$(dirname "$_src_dir")" || return 1

    tar czf "$_tmp_tar" "$(basename "$_src_dir")" 2>/dev/null
    if [ $? -ne 0 ]; then
        log_err "打包失败"
        rm -f "$_tmp_tar"
        return 1
    fi

    crypto_encrypt "$_tmp_tar" "$_output" "$_pass"
    _ret=$?
    rm -f "$_tmp_tar"
    return $_ret
}

# 解密并解包
# 参数: <输入文件> <目标目录> <密码>
tar_decrypt() {
    _input="$1"
    _output_dir="$2"
    _pass="$3"

    if [ ! -f "$_input" ]; then
        log_err "输入文件不存在: $_input"
        return 1
    fi

    _tmp_tar="${_input}.tmp.tar.gz"

    crypto_decrypt "$_input" "$_tmp_tar" "$_pass"
    if [ $? -ne 0 ]; then
        return 1
    fi

    mkdir -p "$_output_dir"

    tar xzf "$_tmp_tar" -C "$_output_dir" 2>/dev/null
    if [ $? -ne 0 ]; then
        log_err "解包失败"
        rm -f "$_tmp_tar"
        return 1
    fi

    rm -f "$_tmp_tar"
    return 0
}
