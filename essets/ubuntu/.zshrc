# ==============================
# Aliases
# ==============================
alias ccc="cc -Wall -Wextra -Werror"
alias francinette="docker run -it --rm -v .:/src liqsuq/francinette"
alias v="nvim"

# ==============================
# PATH / Environment
# ==============================
export PATH="$HOME/.local/bin:$PATH"
export LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"
export HOME_MAX_SIZE=5
export SGOINFRE_MAX_SIZE=42
export SGOINFRE="/sgoinfre/seunkang"
export NAME="YOUR_ID"
export MAIL="YOUR_ID@student.42gyeongsan.kr"

# ==============================
# Powerlevel10k - before load
# ==============================
typeset -g POWERLEVEL9K_INSTANT_PROMPT=off

# ==============================
# Oh My Zsh & Plugins
# ==============================
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

# ==============================
# Powerlevel10k - override after .p10k.zsh
# ==============================
typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=false

if (( COLUMNS >= 150 )); then
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    os_icon
    dir
    vcs
    newline
    prompt_char
  )

  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_unique
  typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=99
  typeset -g POWERLEVEL9K_DIR_MAX_LENGTH=0
  
elif (( COLUMNS >= 90 )); then
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    os_icon
    dir
    vcs
    newline
    prompt_char
  )

  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_last
  typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=2
  typeset -g POWERLEVEL9K_DIR_MAX_LENGTH=0

elif (( COLUMNS >= 60 )); then
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    os_icon
    dir
    vcs
    newline
    prompt_char
  )

  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_last
  typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=1
  typeset -g POWERLEVEL9K_DIR_MAX_LENGTH=0

else
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    os_icon
    dir
    newline
    prompt_char
  )

  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=()

  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_last
  typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=1
  typeset -g POWERLEVEL9K_DIR_MAX_LENGTH=0
fi

typeset -g POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS=0
typeset -g POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS_PCT=0

(( $+commands[p10k] )) && p10k reload

# ==============================
# Terminal Intro
# ==============================

__zsh_terminal_intro() {
  emulate -L zsh

  clear

  local min_cols=75
  local min_lines=15

  if command -v fastfetch > /dev/null 2>&1 \
    && (( COLUMNS >= min_cols && LINES >= min_lines )); then
    print
    fastfetch --config "$HOME/.config/fastfetch/config.jsonc"
    print
  fi
}

re() {
  exec zsh
}

__zsh_terminal_intro

# ==============================
# Node / NVM (nvm 설치 후 정리하세요.)
# ==============================
# export NVM_DIR="$HOME/.nvm"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
# [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
