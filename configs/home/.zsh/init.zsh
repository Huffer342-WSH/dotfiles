# =========================================================
# Zsh Init (single-file, no sub-scripts)
# =========================================================
[[ -o interactive ]] || return
# ----------------------------
# environment basics
# ----------------------------

typeset -g ZSH_CONFIG_DIR="${${(%):-%N}:a:h}"

export HISTSIZE=50000
export SAVEHIST=50000
export HISTFILE="$HOME/.zsh_history"

setopt HIST_IGNORE_DUPS
setopt HIST_FIND_NO_DUPS
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY

bindkey "^[[1;5D" backward-word
bindkey "^[[1;5C" forward-word

# ----------------------------
# completion system
# ----------------------------

# load custom completions when the directory exists
if [[ -d "$ZSH_CONFIG_DIR/completions" ]]; then
  fpath=("$ZSH_CONFIG_DIR/completions" $fpath)
fi

# only initialize compinit once (avoid slow reload issues)
if [[ -z ${_COMPINIT_DONE} ]]; then
  autoload -Uz compinit
  compinit
  typeset -g _COMPINIT_DONE=1
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# ----------------------------
# Antidote (plugins)
# ----------------------------

ZSH_VENDOR="$ZSH_CONFIG_DIR/vendor"

source "$ZSH_VENDOR/.antidote/antidote.zsh"

# load plugins only if plugins file exists
if [[ -f "$ZSH_CONFIG_DIR/.zsh_plugins.txt" ]]; then
  antidote load "$ZSH_CONFIG_DIR/.zsh_plugins.txt"
fi

# fzf-tab requires the fzf executable. Keep the rest of the plugins available
# when fzf is not installed.
if (( $+commands[fzf] )) && [[ -f "$ZSH_CONFIG_DIR/.zsh_plugins.fzf.txt" ]]; then
  antidote load "$ZSH_CONFIG_DIR/.zsh_plugins.fzf.txt"
fi

# ----------------------------
# Powerlevel10k
# ----------------------------

source "$ZSH_VENDOR/powerlevel10k/powerlevel10k.zsh-theme"

[[ -f "$ZSH_CONFIG_DIR/.p10k.zsh" ]] && source "$ZSH_CONFIG_DIR/.p10k.zsh"

# ----------------------------
# autosuggestions (config only)
# ----------------------------

# only set style if plugin is present
if [[ -n ${ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE+1} ]]; then
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
fi

# ----------------------------
# Aliases
# ----------------------------
if [[ -d "$ZSH_CONFIG_DIR/aliases" ]]; then
  for file in "$ZSH_CONFIG_DIR/aliases"/*.{zsh,sh}(N); do
    [[ -f "$file" ]] && source "$file"
  done
fi

# ----------------------------
# Functions
# ----------------------------
if [[ -d "$ZSH_CONFIG_DIR/functions" ]]; then
  for file in "$ZSH_CONFIG_DIR/functions"/*.{zsh,sh}(N); do
    [[ -f "$file" ]] && source "$file"
  done
fi
