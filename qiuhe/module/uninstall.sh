#!/system/bin/sh
#===============================================================================
# Magisk/KSU 模块 - 卸载脚本
#===============================================================================

SCRIPT_DIR="/data/adb/qinghe"
DATA_DIR="/data/qinghe"

echo ""
echo "=========================================="
echo "  清荷 - 腾讯手游账号切换器 - 卸载"
echo "=========================================="

pkill -f "busybox httpd.*8848" 2>/dev/null
echo ""
echo "已停止 WebUI 服务"
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
        rm -rf "$SCRIPT_DIR"
        ;;
    *)
        echo ""
        echo "正在删除所有数据..."
        rm -rf "$DATA_DIR"
        rm -rf "$SCRIPT_DIR"
        echo "数据已清除"
        ;;
esac

echo ""
echo "卸载完成"
echo ""
