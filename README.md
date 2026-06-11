# dotfiles

Windows 开发环境配置文件与安装脚本。

## 功能

一键安装并配置以下工具:

| 模块           | 安装内容                                                      | 部署位置                              |
| -------------- | ------------------------------------------------------------- | ------------------------------------- |
| **powershell** | PSReadLine, posh-git, CompletionPredictor, Starship, Carapace | `$PROFILE`, `~/.config/starship.toml` |
| **starship**   | Starship                                                      | `~/.config/starship.toml`             |

### PowerShell 配置效果

- git 状态提示 (posh-git)
- 自动补全增强: Emacs 键位、内联预测建议、Tab 补全菜单 (PSReadLine + CompletionPredictor)
- 跨 Shell 补全桥接 (Carapace)
- 美化提示符 (Starship)
- 自动读取 Windows 代理设置

## 前置要求

- **Windows 10/11**
- **PowerShell 5.1+** 或 **PowerShell 7+** -- 以管理员身份运行
- **winget** -- Windows 程序包管理器 (Windows 11 自带, Windows 10 需商店安装)
- **Nerd Font** -- 终端字体 (见下文)

## 快速开始

```powershell
# 1. 以管理员身份打开 PowerShell

# 2. 克隆仓库
git clone https://github.com/Huffer342-WSH/dotfiles.git
cd dotfiles

# 3. 列出可用模块
.\install.ps1

# 4. 安装全部模块
.\install.ps1 -m powershell,starship

# 5. 重启 PowerShell 后生效
```

> 如果某个模块已经配置过, 会跳过已存在的配置文件。如需覆盖, 加 `-f`:
> `.\install.ps1 -m starship -f`

### 在线运行 (不克隆)

无需下载仓库, 子模块脚本可直接从 raw URL 运行:

```powershell
# 直接运行单个模块
irm https://raw.githubusercontent.com/Huffer342-WSH/dotfiles/refs/heads/windows/modules/powershell/powershell.ps1 | iex
irm https://raw.githubusercontent.com/Huffer342-WSH/dotfiles/refs/heads/windows/modules/starship/starship.ps1 | iex

# 带参数运行
$script = irm https://raw.githubusercontent.com/Huffer342-WSH/dotfiles/refs/heads/windows/modules/powershell/powershell.ps1
iex "$script -Force -Source Remote"
```

> 通过管道 `|` 传递给 `iex` (Invoke-Expression) 时无法传递参数。如需参数, 先用变量保存脚本内容再执行, 如上面最后两行所示。

### 单独安装

也可以直接运行各模块脚本:

```powershell
# 仅安装 PowerShell 环境
.\modules\powershell\powershell.ps1

# 仅安装 Starship 并部署主题
.\modules\starship\starship.ps1

# 使用本地配置文件 (不联网)
.\modules\powershell\powershell.ps1 -Source Local

# 强制覆盖已有文件
.\modules\starship\starship.ps1 -Force
```

## 安装后操作

### 1. 安装 Nerd Font

终端图标依赖 Nerd Font。推荐 CascadiaCove Nerd Font:

1. 下载: [Nerd Fonts 官网](https://www.nerdfonts.com/font-downloads)
2. 解压, 全选 `.ttf` 文件, 右键"为所有用户安装"
3. 在 Windows Terminal / VS Code 中设置字体为 `CaskaydiaCove Nerd Font`

### 2. 重启终端

关闭当前 PowerShell 窗口, 重新打开。配置文件会自动加载。

## 目录结构

```
dotfiles/
├── configs/              # 配置文件源
│   ├── powershell/
│   └── starship/
├── modules/              # 安装脚本
│   ├── powershell/
│   └── starship/
├── install.ps1           # 安装入口
└── README.md
```

## 常见问题

**Q: 提示没有管理员权限?**
脚本本身不自提权, 请手动以管理员身份运行 PowerShell (右键 -> 以管理员身份运行)。

**Q: 安装报错, 提示找不到 winget?**
winget 是 Windows 11 自带组件。Windows 10 用户请在 Microsoft Store 搜索"程序包管理器"安装。

**Q: 配置文件被覆盖了怎么办?**
使用 `-Force` 时脚本会自动备份原文件, 备份文件在同目录下, 命名为 `原文件名.backup.yyyyMMddHHmmss`。

**Q: 如何更新?**
```powershell
git pull
.\install.ps1 -m 模块名
```

## 参考链接

- [Starship](https://starship.rs/)
- [Carapace](https://carapace.sh/)
- [posh-git](https://github.com/dahlbyk/posh-git)
- [PSReadLine](https://learn.microsoft.com/en-us/powershell/module/psreadline/)
