# 架构约定

## 配置文件来源解析 (`-Source` 参数)

每个需要部署配置文件的模块脚本都接受 `-Source` 参数:

| 值       | 行为                                                                              |
| -------- | --------------------------------------------------------------------------------- |
| `Auto`   | 通过 `git rev-parse --show-toplevel` 检测是否在仓库内, 是则本地读取, 否则远程下载 |
| `Local`  | 从本地仓库读取 (相对于仓库根目录)                                                 |
| `Remote` | 从 Base URL + 相对路径下载                                                        |


远程路径拼接示例: `$BaseUrl/configs/powershell/Microsoft.PowerShell_profile.ps1`

## 配置文件部署

- 源文件放 `configs/<工具名>/` 下, 相对路径即远程 URL 路径。
- 脚本将内容写入工具的标准位置 (如 `$PROFILE`, `~/.config/starship.toml`)。
- 幂等: 目标已存在且未传 `-Force` 则跳过; 传了 `-Force` 则备份 (`*.backup.yyyyMMddHHmmss`) 后覆盖。
- 写入前确保目标目录存在。

## 模块脚本规范

每个 `modules/<类别>/<名称>.ps1` 负责一个工具或子系统的安装配置:
1. 安装所需包/模块 (winget / PowerShell 模块等)。
2. 读取并部署对应的配置文件。
3. 输出彩色日志: Green = 区段标题, Cyan = 成功, Yellow = 跳过/警告。

## 安装器 (`install.ps1`)

```powershell
.\install.ps1                        # 列出所有可用模块
.\install.ps1 -m powershell          # 安装指定模块
.\install.ps1 -m powershell,starship # 安装多个模块
.\install.ps1 -m starship -f         # 强制覆盖已存在的配置文件
.\install.ps1 -Help                  # 显示详细帮助
```

- 不带参数时仅列出可用模块, 不执行安装。
- 必须通过 `-m / --modules` 明确指定要安装的模块。
- `-f / --force` 会被传递给子模块脚本。
- 自动扫描 `modules/` 下子目录发现模块, 无需注册。

## 添加新模块

1. 将配置文件放入 `configs/<工具名>/`。
2. 编写安装脚本 `modules/<工具名>/<工具名>.ps1`, 遵循上述模块规范。
3. 安装器会自动发现, 无需额外注册。
