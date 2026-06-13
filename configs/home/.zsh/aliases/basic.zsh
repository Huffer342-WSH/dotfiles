# =========================================================
# Zsh Aliases
# =========================================================

# 基础彩色输出支持
if [ -x /usr/bin/dircolors ]; then
  test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
  alias dir='dir --color=auto'
  alias vdir='vdir --color=auto'

  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
fi

# 智能接管：如果系统中安装了 eza，则使用 eza，否则回退到原生 ls
if command -v eza >/dev/null 2>&1; then
  # eza 常用参数说明:
  # --icons: 显示文件图标 (需要终端支持 Powerline/Nerd Fonts)
  # --git: 在列表模式下显示 git 状态
  # --group-directories-first: 目录排在文件前面
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -alF --icons --group-directories-first'
  alias la='eza -a --icons --group-directories-first'
  alias l='eza -F --icons --group-directories-first'
  alias lt='eza --tree --level=2 --icons' # 额外赠送：树状查看（两层）
else
  # 没安装 eza 时，回退到传统 ls 别名
  alias ls='ls --color=auto'
  alias ll='ls -alF'
  alias la='ls -A'
  alias l='ls -CF'
fi

# 额外推荐的实用别名（可选，建议保留）
alias ..='cd ..'
alias ...='cd ../..'
alias .3='cd ../../..'

# 安全与便捷性扩展
alias mkdir='mkdir -p'    # 自动创建多级不存在的父目录
alias df='df -h'          # 以易读的 Gb/Mb 格式显示磁盘
alias free='free -m'      # 以 Mb 格式显示内存
