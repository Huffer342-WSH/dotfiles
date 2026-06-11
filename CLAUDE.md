# CLAUDE.md

Windows 下配置文件与环境管理仓库。

- **默认分支:** `windows`
- **Base URL (raw):** `https://raw.githubusercontent.com/Huffer342-WSH/dotfiles/refs/heads/windows/`

## 目录

```
dotfiles/
├── configs/       # 配置文件 (powershell/, starship/)
├── modules/       # 安装脚本, 每个子目录一个模块
├── docs/          # 开发参考文档
├── install.ps1    # 安装入口
└── README.md
```

## 关键文档

| 文件                                                         | 内容                                         |
| ------------------------------------------------------------ | -------------------------------------------- |
| [README.md](README.md)                                       | 使用说明 (面向用户)                          |
| [docs/architecture.md](docs/architecture.md)                 | 架构约定 (Source 解析、配置部署、模块规范等) |
| [modules/powershell/CLAUDE.md](modules/powershell/CLAUDE.md) | PowerShell 模块详情                          |

## 添加新模块

1. `configs/<name>/` -- 放入配置文件
2. `modules/<name>/<name>.ps1` -- 编写安装脚本 (参考现有模块)
3. 安装器自动发现, 无需注册
