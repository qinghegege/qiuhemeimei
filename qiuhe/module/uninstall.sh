#!/system/bin/sh
#===============================================================================
# Magisk/KSU 模块 - 卸载脚本
#===============================================================================

QIUHE_DIR="/data/adb/qiuhe"
DATA_DIR="/data/adb/qiuhe/data"

echo ""
echo "=========================================="
echo "  腾讯手游账号切换器 - 卸载"
echo "=========================================="
echo ""
echo "账号存档数据在: $DATA_DIR"
echo ""
echo "是否保留账号存档数据?"
echo "  y - 保留数据 (下次安装可恢复)"
echo "  n - 彻底删除所有数据"
echo ""
printf "请选择 [y/N]: "

read -r choice
case "$choice" in
    [Yy]*)
        echo ""
        echo "账号存档已保留在 $DATA_DIR"
        echo "下次安装本模块时可恢复使用"
        ;;
    *)
        echo ""
        echo "正在删除所有数据..."
        rm -rf "$DATA_DIR"
        rm -f "/data/adb/qiuhe"
        echo "数据已清除"
        ;;
esac

echo ""
echo "卸载完成"
echo ""
