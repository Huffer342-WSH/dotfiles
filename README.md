# dotfiles

这个仓库用于快速复现个人终端配置。zsh 配置脚本会准备运行所需的软件、下载配置和插件，并把启动配置写入 `~/.zshrc`。

## 一键配置 zsh

在 Ubuntu、Arch Linux 或 Fedora 上执行：

```bash
curl -fsSL https://raw.githubusercontent.com/Huffer342-WSH/dotfiles/refs/heads/archlinux/modules/zsh/install-zsh.sh | bash
```

配置完成后，执行下面的命令进入 zsh：

```bash
exec zsh
```

安装脚本不会自动修改默认 shell。如需将 zsh 设为默认 shell，请手动执行脚本输出的 `chsh` 命令，例如：

```bash
chsh -s "$(command -v zsh)"
```

配置脚本默认尝试安装 `fzf` 和 `eza`，以还原模糊补全和文件列表显示。如果当前系统无法安装这些命令，配置流程不会中断：缺少 `fzf` 时不启用 `fzf-tab`，缺少 `eza` 时使用系统自带的 `ls`。

运行 `bash modules/zsh/install-zsh.sh --help` 可以查看配置选项。
