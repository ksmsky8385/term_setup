#!/bin/bash

set -e

ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
PLUGIN_DIR="$ZSH_CUSTOM/plugins"

AUTOSUGGESTIONS_DIR="$PLUGIN_DIR/zsh-autosuggestions"
SYNTAX_HIGHLIGHTING_DIR="$PLUGIN_DIR/zsh-syntax-highlighting"

echo "zsh 플러그인 설정 스크립트"
echo

install_plugins() {
    mkdir -p "$PLUGIN_DIR"

    echo "zsh-autosuggestions 설치 상태를 확인합니다."
    if [ ! -d "$AUTOSUGGESTIONS_DIR" ]; then
        git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$AUTOSUGGESTIONS_DIR"
    else
        echo "zsh-autosuggestions가 이미 설치되어 있습니다."
    fi

    echo
    echo "zsh-syntax-highlighting 설치 상태를 확인합니다."
    if [ ! -d "$SYNTAX_HIGHLIGHTING_DIR" ]; then
        git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$SYNTAX_HIGHLIGHTING_DIR"
    else
        echo "zsh-syntax-highlighting이 이미 설치되어 있습니다."
    fi

    echo
    echo "플러그인 설치 완료"
    echo
    echo "사용하려면 ~/.zshrc의 plugins에 아래 항목을 추가하세요."
    echo
    echo "plugins=("
    echo "  git"
    echo "  zsh-autosuggestions"
    echo "  zsh-syntax-highlighting"
    echo ")"
}

reset_plugins() {
    echo "설치한 zsh 플러그인을 삭제합니다."
    echo ".zshrc, .bashrc 파일은 수정하지 않습니다."
    echo
    printf "진행하시겠습니까? [Y/n] "
    read -r confirm

    case "$confirm" in
        "" | "y" | "Y" | "yes" | "YES")
            rm -rf "$AUTOSUGGESTIONS_DIR"
            rm -rf "$SYNTAX_HIGHLIGHTING_DIR"
            rm -f "$HOME"/.zcompdump*

            echo "플러그인 삭제 완료"
            ;;
        "n" | "N" | "no" | "NO")
            echo "삭제를 취소했습니다."
            ;;
        *)
            echo "Error: Y 또는 n을 입력하세요."
            exit 1
            ;;
    esac
}

echo "00. 설치한 플러그인 삭제"
echo "01. 플러그인 설치"
echo
printf "> "
read -r choice

case "$choice" in
    0 | 00)
        reset_plugins
        ;;
    1 | 01)
        install_plugins
        ;;
    *)
        echo "Error: 0 또는 1을 입력하세요."
        exit 1
        ;;
esac
