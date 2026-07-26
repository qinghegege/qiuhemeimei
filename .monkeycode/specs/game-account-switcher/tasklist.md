# 任务列表

- [ ] 1. 项目结构初始化
  - 创建 `qiuhe/` 目录结构（`lib/`、`module/`、`data/`）
  - 创建项目 `README.md` 说明用法和依赖
  - 创建 `.gitignore` 忽略数据目录和加密文件

- [ ] 2. 公共函数库 `lib/common.sh`
  - 实现 `log_info` / `log_warn` / `log_err` 日志输出函数，适配 MT 管理器/终端/ADB 三种环境
  - 实现 `check_root` 检测 root 权限函数，引用需求中"需要 root 权限才能访问 /data/data/"
  - 实现 `detect_env` 运行环境检测函数
  - 实现 `require_cmd` 依赖命令检查函数（openssl、tar、pgrep、pm 等）
  - 实现 `get_data_dir` 数据存储目录获取函数，支持 Magisk 模块路径、脚本同级目录、用户自定义目录三种模式
  - 实现 `get_game_data` 根据包名获取游戏数据目录路径
  - [ ] 2.7 手动测试公共函数在不同环境下的输出

- [ ] 3. 游戏配置数据库 `lib/games.ini`
  - 写入 9 款腾讯手游的配置（包名、数据路径、备份子目录），引用需求 5 "通过包名匹配识别常见腾讯手游"
  - 实现 `lib/games.sh` 解析 games.ini 的函数：`find_pkg_by_name`、`list_all_games`、`get_pkg_info`

- [ ] 4. 检查点 - 确认公共库和游戏配置正常加载

- [ ] 5. 游戏检测模块 `lib/detect.sh`
  - 实现 `detect_games` 函数：通过 `pm list packages` 扫描已装腾讯手游，引用需求 5 AC1 "扫描设备上已安装的腾讯手游并列出游戏名和包名"
  - 实现 `show_data_size` 函数：通过 `du` 显示每个游戏数据目录大小，引用需求 5 AC3 "输出数据目录路径及总大小"

- [ ] 6. 加密模块 `lib/crypto.sh`
  - 实现 `read_pass` 函数：安全读取密码输入（stty -echo 不回显）
  - 实现 `crypto_encrypt` / `crypto_decrypt` 函数：使用 openssl aes-256-cbc 进行文件加密/解密，引用需求 1 AC4 "使用 openssl aes-256-cbc 对存档进行可选加密"
  - 实现 `tar_encrypt` / `tar_decrypt` 函数：tar.gz 打包后加密、解密后解包

- [ ] 7. 账号管理模块 `lib/account.sh`
  - 实现 `account_backup` 函数：备份当前游戏数据为账号存档，写入 meta.json 元数据，引用需求 1 AC1 "将指定游戏的当前数据目录完整复制到账号存档目录"
  - 实现 `account_list` 函数：列出已备份账号，展示别名、备份时间、数据大小，引用需求 2 AC1 "展示所有或指定游戏的已备份账号别名、备份时间和数据大小"
  - 实现 `account_info` 函数：展示指定账号的详细元数据，引用需求 2 AC2 "展示游戏名、备份路径、备份时间和关联的游戏包名"
  - 实现 `account_delete` 函数：删除指定账号存档，含二次确认提示，引用需求 3 AC1/AC2/AC3
  - [ ] 7.5 手动验证账号存档 meta.json 与实际数据目录一致性

- [ ] 8. 检查点 - 确认账号增删查功能正常

- [ ] 9. 切换引擎 `lib/switch.sh`
  - 实现 `check_game_running` 函数：通过 pgrep 检测游戏进程是否运行，引用需求 4 AC2 "先检测游戏进程是否在运行"
  - 实现 `backup_current` 函数：切换前自动备份当前数据为快照，引用需求 4 AC3 "自动备份当前游戏数据作为切换前账号的快照"
  - 实现 `apply_account` 函数：将目标账号存档数据覆盖到游戏数据目录，引用需求 4 AC3 "将目标账号数据覆盖到游戏数据目录"
  - 实现 `fix_permissions` 函数：修复文件 uid/gid 及 SELinux 上下文（chown + restorecon），引用正确性属性 "SELinux 上下文修复必须正确"
  - 实现 `rollback` 函数：切换失败时自动回滚到切换前备份，引用需求 4 AC4 "自动回滚到切换前的备份数据"
  - 实现 `switch_account` 主函数：编排上述步骤完成一键切换，引用需求 4 AC1/AC5 "检查存档完整 + 输出当前生效账号"

- [ ] 10. 检查点 - 确认切换流程编排正确

- [ ] 11. 主入口脚本 `qiuhe.sh`
  - 实现参数模式路由：解析子命令（backup/list/delete/switch/detect/export/import/help）并调用对应模块函数，引用需求 6 AC3 "以有参数方式执行，直接执行对应操作"
  - 实现菜单模式：无参数时展示交互式操作菜单（数字选择），引用需求 6 AC2 "展示菜单式交互界面，列出所有可用操作"
  - 实现 `help` 命令帮助信息输出
  - [ ] 11.4 手动验证三种环境下（MT 管理器/终端/ADB）的输出格式正确

- [ ] 12. 导入导出功能
  - 在 `lib/account.sh` 中实现 `export_account` 函数：打包指定账号存档为 .tar.gz 并加密（可选），引用需求 8 AC1/AC3 "打包导出 + openssl 加密"
  - 在 `lib/account.sh` 中实现 `export_all` 函数：遍历所有账号分别导出，引用需求 8 AC2
  - 在 `lib/account.sh` 中实现 `import_account` 函数：从 .tar.gz 包恢复账号存档，处理别名冲突，引用需求 8 AC3 "若别名冲突则提示用户选择覆盖或重命名"
  - 在 `qiuhe.sh` 中注册 `export` 和 `import` 子命令路由

- [ ] 13. Magisk/KSU 模块 `module/`
  - 创建 `module.prop`：模块元数据（id=qiuhe, name=腾讯手游账号切换器, version=v1.0.0）
  - 实现 `customize.sh`：安装时创建数据目录、设置权限、复制脚本到模块目录，引用需求 7 AC3 "完成初始目录创建和权限设置"
  - 实现 `uninstall.sh`：卸载时询问用户是否保留存档数据，引用需求 7 AC4 "支持保留或清理存档数据"
  - 创建 `service.sh`：空文件（预留开机后处理逻辑）
  - 实现 `META-INF/com/google/android/update-binary`：Magisk 模块标准安装入口
  - 在 `qiuhe.sh` 中实现 `get_data_dir` 的 Magisk 模块路径分支 `/data/adb/modules/qiuhe/data/`
  - [ ] 13.7 验证模块 zip 包可被 Magisk Manager 和 KernelSU 正确安装卸载

- [ ] 15. DeepSeek AI 集成
  - [x] 创建 `lib/ai.sh` DeepSeek API 客户端模块
  - [x] 在 `web/api.sh` 中添加 `/api/ai/chat`、`/api/ai/config`、`/api/ai/command` 端点
  - [x] 在 `web/index.html` 中添加「AI 助手」Tab 和聊天界面
  - [x] 在 `module/webroot/index.html` 中同步 AI 助手界面
  - [ ] 15.5 用户配置 API Key 后验证自然语言对话和命令解析功能
