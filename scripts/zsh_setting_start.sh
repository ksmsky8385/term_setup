#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCAL_FONT_DIR="$HOME/.local/share/fonts"
LOCAL_D2CODING_DIR="$LOCAL_FONT_DIR/D2Coding"
SOURCE_FONT_DIR="$ROOT_DIR/fonts"
SOURCE_D2CODING_DIR="$SOURCE_FONT_DIR/D2Coding"
MANAGED_BEGIN="# >>> cli-zsh-setup >>>"
MANAGED_END="# <<< cli-zsh-setup <<<"

echo "zsh 터미널 환경설정 시작"
echo

remove_managed_block() {
    local target_file="$1"

    if [ -f "$target_file" ]; then
        sed -i "/^$MANAGED_BEGIN$/,/^$MANAGED_END$/d" "$target_file"
    fi
}

install_d2coding_font() {
    echo "폰트 설정을 확인합니다."

    mkdir -p "$LOCAL_FONT_DIR"

    if [ -d "$LOCAL_D2CODING_DIR" ]; then
        echo "D2Coding 폰트가 이미 설치되어 있습니다."
        return
    fi

    echo "D2Coding 폰트가 설치되어 있지 않습니다."
    echo "설치할까요? [Y/n]"
    printf "선택: "
    read -r install_font_choice

    case "$install_font_choice" in
        "" | "y" | "Y" | "yes" | "YES")
            if [ -d "$SOURCE_D2CODING_DIR" ]; then
                echo "D2Coding 폰트를 설치합니다."
                cp -R "$SOURCE_D2CODING_DIR" "$LOCAL_D2CODING_DIR"
            elif [ -d "$SOURCE_FONT_DIR" ]; then
                echo "fonts 디렉토리를 사용자 폰트 폴더로 복사합니다."
                cp -R "$SOURCE_FONT_DIR"/* "$LOCAL_FONT_DIR"/
            else
                echo "Warning: 스크립트 경로에 fonts 디렉토리가 없습니다."
                echo "Skip: D2Coding 폰트 설치를 건너뜁니다."
            fi

            if command -v fc-cache >/dev/null 2>&1; then
                echo "폰트 캐시를 갱신합니다."
                fc-cache -f "$LOCAL_FONT_DIR" >/dev/null 2>&1 || true
            else
                echo "Warning: fc-cache 명령어가 없어 폰트 캐시 갱신을 건너뜁니다."
            fi
            ;;
        "n" | "N" | "no" | "NO")
            echo "D2Coding 폰트 설치를 건너뜁니다."
            ;;
        *)
            echo "Error: Y 또는 n을 입력하세요."
            exit 1
            ;;
    esac
}

reset_zsh_setting() {
    echo
    echo "선택한 작업: 설정 및 플러그인 완전 초기화"
    echo "zsh 설정, Oh My Zsh, Powerlevel10k, Fastfetch, D2Coding 폰트와 스크립트가 rc 파일에 추가한 설정을 삭제합니다."
    echo
    printf "진행하시겠습니까? [Y/n] "
    read -r confirm

    case "$confirm" in
        "" | "y" | "Y" | "yes" | "YES")
            rm -rf "$HOME/.oh-my-zsh"
            rm -f "$HOME/.local/bin/fastfetch"
            rm -rf "$HOME/.config/fastfetch"
            rm -rf "$HOME/.local/share/fonts/D2Coding"
            rm -f "$HOME"/.cache/p10k-instant-prompt-*.zsh

            rm -f "$HOME"/.zcompdump*

            remove_managed_block "$HOME/.zshrc"
            remove_managed_block "$HOME/.bashrc"

            if [ -f "$HOME/.zshrc" ] &&
               grep -q "__zsh_terminal_intro" "$HOME/.zshrc" &&
               grep -q 'ZSH_THEME="powerlevel10k/powerlevel10k"' "$HOME/.zshrc"; then
                if [ -f "$HOME/.zshrc.pre-oh-my-zsh" ]; then
                    cp "$HOME/.zshrc.pre-oh-my-zsh" "$HOME/.zshrc"
                else
                    rm -f "$HOME/.zshrc"
                fi
            fi

            if [ -f "$HOME/.bashrc" ]; then
                sed -i '/cli-zsh-setup/d' "$HOME/.bashrc"
                sed -i '/if \[ -t 1 \] && \[ -x "$(command -v zsh)" \]; then exec zsh; fi/d' "$HOME/.bashrc"
            fi

            if command -v fc-cache >/dev/null 2>&1; then
                fc-cache -f "$LOCAL_FONT_DIR" >/dev/null 2>&1 || true
            fi

            echo "zsh 관련 설정 및 플러그인 완전 초기화 완료"
            exit 0
            ;;
        "n" | "N" | "no" | "NO")
            echo "초기화를 취소했습니다."
            exit 0
            ;;
        *)
            echo "Error: Y 또는 n을 입력하세요."
            exit 1
            ;;
    esac
}

run_zsh_setting() {
    install_d2coding_font

    mkdir -p "$HOME/.local/bin"
    mkdir -p "$HOME/.local/share"
    mkdir -p "$HOME/.config/fastfetch"

    echo
    echo "zsh 터미널 환경설정을 진행합니다."
    echo "다음 작업을 진행합니다."
    echo "- Fastfetch 설치 및 출력 구성"
    echo "- Oh My Zsh 설치"
    echo "- Powerlevel10k 설치"
    echo "- ~/.zshrc 끝에 zsh 설정 블록 추가"
    echo "- ~/.bashrc 끝에 zsh 자동 진입 블록 추가"
    echo
    printf "진행하시겠습니까? [Y/n] "
    read -r confirm

    case "$confirm" in
        "" | "y" | "Y" | "yes" | "YES")
            ;;
        "n" | "N" | "no" | "NO")
            echo "zsh 터미널 환경설정을 취소했습니다."
            exit 0
            ;;
        *)
            echo "Error: Y 또는 n을 입력하세요."
            exit 1
            ;;
    esac

    if ! command -v fastfetch &> /dev/null && [ ! -f "$HOME/.local/bin/fastfetch" ]; then
        echo "Fastfetch 바이너리를 설치합니다."
        FF_TMP=$(mktemp -d)
        curl -L https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-amd64.tar.gz -o "$FF_TMP/fastfetch.tar.gz"
        tar -xzf "$FF_TMP/fastfetch.tar.gz" -C "$FF_TMP"
        mv "$FF_TMP"/fastfetch-linux-amd64/usr/bin/fastfetch "$HOME/.local/bin/"
        rm -rf "$FF_TMP"
        chmod +x "$HOME/.local/bin/fastfetch"
    fi

    echo "Fastfetch 출력 정보를 구성합니다."
    FF_CONFIG="$HOME/.config/fastfetch/config.jsonc"

    cat << 'EOF' > "$FF_CONFIG"
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "source": "ubuntu_small"
  },
  "modules": [
    "os",
    "kernel",
    "uptime",
    "memory",
    {
      "type": "disk",
      "format": "{1} / {2} ({3})",
      "folders": "/"
    },
    {
      "type": "disk",
      "key": "  └─ Available (/) ",
      "format": "{size-free}",
      "folders": "/"
    },
    {
      "type": "disk",
      "format": "{1} / {2} ({3})",
      "folders": "/goinfre"
    },
    {
      "type": "disk",
      "key": "  └─ Available (/goinfre) ",
      "format": "{size-free}",
      "folders": "/goinfre"
    },
    {
      "type": "disk",
      "format": "{1} / {2} ({3})",
      "folders": "/home/seunkang"
    },
    {
      "type": "disk",
      "key": "  └─ Available (/home/seunkang) ",
      "format": "{size-free}",
      "folders": "/home/seunkang"
    },
    "localip"
  ],
  "display": {
    "stat": false
  }
}
EOF

    echo "Oh My Zsh와 Powerlevel10k 설치 상태를 확인합니다."
    ZSHRC_SNAPSHOT=""
    if [ -f "$HOME/.zshrc" ]; then
        ZSHRC_SNAPSHOT="$(mktemp)"
        cp "$HOME/.zshrc" "$ZSHRC_SNAPSHOT"
    fi

    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    if [ -n "$ZSHRC_SNAPSHOT" ]; then
        cp "$ZSHRC_SNAPSHOT" "$HOME/.zshrc"
        rm -f "$ZSHRC_SNAPSHOT"
    elif [ -f "$HOME/.zshrc.pre-oh-my-zsh" ]; then
        rm -f "$HOME/.zshrc"
    fi

    ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
    P10K_DIR="$ZSH_CUSTOM/themes/powerlevel10k"
    if [ ! -d "$P10K_DIR" ]; then
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
    fi

    echo "zsh, Powerlevel10k, 시작 화면 설정을 추가합니다."
    ZSHRC="$HOME/.zshrc"
    touch "$ZSHRC"
    remove_managed_block "$ZSHRC"

    cat << 'EOF' >> "$ZSHRC"
# >>> cli-zsh-setup >>>
typeset -g POWERLEVEL9K_INSTANT_PROMPT=off

export PATH="$HOME/.local/bin:$PATH"

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git)
source $ZSH/oh-my-zsh.sh

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

typeset -g POWERLEVEL9K_INSTANT_PROMPT=off
typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_last
typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=2
typeset -g POWERLEVEL9K_SHORTEN_DELIMITER="..."

autoload -Uz add-zsh-hook

__zsh_terminal_intro() {
  emulate -L zsh
  [[ -n "${__ZSH_TERMINAL_INTRO_DONE:-}" ]] && return
  typeset -g __ZSH_TERMINAL_INTRO_DONE=1

  clear
  print

  if command -v fastfetch > /dev/null 2>&1; then
    fastfetch --config "$HOME/.config/fastfetch/config.jsonc"
    [[ -n "${__ZSHRC_RELOADING:-}" ]] || print
  fi

  unset __ZSHRC_RELOADING
}

re() {
  unset __ZSH_TERMINAL_INTRO_DONE
  typeset -g __ZSHRC_RELOADING=1
  source "$HOME/.zshrc"
}

add-zsh-hook -d precmd __zsh_terminal_intro 2> /dev/null || true
add-zsh-hook precmd __zsh_terminal_intro
# <<< cli-zsh-setup <<<
EOF

    echo "기본 bash 진입 시 zsh를 실행하도록 설정합니다."
    BASHRC="$HOME/.bashrc"
    touch "$BASHRC"
    remove_managed_block "$BASHRC"
    cat << 'EOF' >> "$BASHRC"
# >>> cli-zsh-setup >>>
if [ -t 1 ] && [ -x "$(command -v zsh)" ]; then exec zsh; fi
# <<< cli-zsh-setup <<<
EOF

    echo "zsh 터미널 환경설정 완료"
}

echo "zsh 터미널 환경설정을 진행합니다."
echo
echo "00. 설정 및 플러그인 완전 초기화"
echo "01. zsh 터미널 설정 실행"
echo
printf "> "
read -r choice

if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
    echo "Error: 숫자를 입력해야 합니다."
    exit 1
fi

choice_num=$((10#$choice))

case "$choice_num" in
    0)
        reset_zsh_setting
        ;;
    1)
        run_zsh_setting
        ;;
    *)
        echo "Error: 0부터 1 사이의 번호를 입력해야 합니다."
        exit 1
        ;;
esac
