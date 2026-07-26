#!/system/bin/sh
#===============================================================================
# Magisk/KSU 模块 - 开机服务
# 预留: 可在开机后执行数据目录权限修复等操作
#===============================================================================
MODDIR=${0%/*}

# 确保数据目录存在
mkdir -p /data/adb/qiuhe/data/accounts 2>/dev/null
mkdir -p /data/adb/qiuhe/data/snapshots 2>/dev/null
mkdir -p /data/adb/qiuhe/data/logs 2>/dev/null
