# 腾讯手游账号本地切换器 (Qiuhe)

一套运行于 Android 手机端的 Shell 脚本工具，支持 MT 管理器直接执行 .sh 脚本，同时提供 Magisk/KernelSU 模块封装。通过备份和替换游戏在 `/data/data/<pkg>/` 下的私有数据目录，实现腾讯手游多账号快速切换。

## 依赖

| 命令 | 用途 | 必需 |
|------|------|------|
| `sh` | 脚本解释器 | 必需 |
| `cp` / `mv` / `rm` | 文件操作 | 必需 |
| `tar` / `gzip` | 打包压缩 | 必需 |
| `openssl` | 加密解密 | 可选（加密功能需要） |
| `pgrep` | 进程检测 | 推荐 |
| `pm` | 包管理器（游戏检测） | 推荐 |

## 快速开始

### MT 管理器使用

1. 将整个 `qiuhe/` 目录复制到手机任意位置
2. 在 MT 管理器中点击 `qiuhe.sh`，选择「执行」
3. 按菜单提示操作

### 命令行使用

```sh
# 检测已安装的腾讯手游
sh qiuhe.sh detect

# 备份当前游戏数据为账号
sh qiuhe.sh backup sgame 大号

# 列出已备份账号
sh qiuhe.sh list

# 切换账号
sh qiuhe.sh switch 大号

# 删除账号
sh qiuhe.sh delete 大号
```

### Magisk/KSU 模块安装

1. 将 `清荷-module-*.zip` 通过 Magisk Manager 或 KernelSU WebUI 刷入
2. 安装后重启
3. 终端直接输入 `qh` 使用命令

## 内置支持的游戏

- 王者荣耀
- 和平精英
- CF手游
- QQ飞车
- 使命召唤手游
- 金铲铲之战
- 英雄联盟手游
- 火影忍者
- 天涯明月刀

## 数据存储

| 环境 | 路径 |
|------|------|
| Magisk/KSU 模块 | `/data/qinghe/` |
| Shell 独立运行 | 脚本所在目录 `./清荷-data/` |
