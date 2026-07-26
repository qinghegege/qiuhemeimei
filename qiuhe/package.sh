#!/system/bin/sh
#===============================================================================
# qiuhe 打包脚本
# 生成 Magisk/KSU 模块 zip 包
#===============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QIUHE_DIR="$SCRIPT_DIR"
MODULE_DIR="$QIUHE_DIR/module"
OUTPUT_DIR="$QIUHE_DIR/release"

echo "=== 清荷 打包工具 ==="
echo ""

mkdir -p "$OUTPUT_DIR"

# --- Magisk/KSU 模块 zip 包 ---
echo "[1/2] 打包 Magisk/KSU 模块..."

TMP_DIR="$OUTPUT_DIR/.tmp_module"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

cp -r "$MODULE_DIR"/* "$TMP_DIR/"
cp -r "$QIUHE_DIR/lib" "$TMP_DIR/"
cp -r "$QIUHE_DIR/web" "$TMP_DIR/"

# 写入 README 到模块中
cat > "$TMP_DIR/README.md" << 'MODULE_README'
## 清荷 安装说明

### 需求
- Android 设备已 Root
- Magisk Manager 或 KernelSU 管理器
- 已安装对应腾讯手游

### 安装步骤
1. 在管理器中点击「从本地安装」
2. 选择 清荷-module-*.zip
3. 刷入后重启
4. 终端输入 `清荷` 即可使用

### 数据位置
- 账号存档: /data/清荷/accounts/
- 切换快照: /data/清荷/snapshots/
MODULE_README

VERSION="$(grep 'version=' "$MODULE_DIR/module.prop" | cut -d'=' -f2)"
MODULE_ZIP="$OUTPUT_DIR/清荷-module-${VERSION}.zip"

cd "$TMP_DIR"
rm -f "$MODULE_ZIP"
zip -r "$MODULE_ZIP" . 1>/dev/null
cd "$QIUHE_DIR"
rm -rf "$TMP_DIR"

echo "  已生成: release/清荷-module-${VERSION}.zip"

# --- Shell 脚本独立包 ---
echo "[2/2] 打包 Shell 脚本独立包..."

SCRIPT_ZIP="$OUTPUT_DIR/清荷-script-${VERSION}.zip"
rm -f "$SCRIPT_ZIP"

cd "$QIUHE_DIR"
zip -r "$SCRIPT_ZIP" \
    qiuhe.sh \
    lib/ \
    web/ \
    README.md \
    1>/dev/null
cd "$SCRIPT_DIR"

echo "  已生成: release/清荷-script-${VERSION}.zip"

echo ""
echo "打包完成!"
echo ""
echo "文件:"
echo "  release/清荷-module-${VERSION}.zip   → Magisk/KSU 模块 (刷入安装)"
echo "  release/清荷-script-${VERSION}.zip   → Shell 脚本 (解压到手机, MT 管理器执行)"
echo ""
echo "移动端使用:"
echo "  1. 将 .zip 文件传到手机"
echo "  2. 模块: Magisk Manager → 从本地安装 → 选择 zip"
echo "  3. 脚本: 解压后 MT 管理器点击 qiuhe.sh → 执行"
