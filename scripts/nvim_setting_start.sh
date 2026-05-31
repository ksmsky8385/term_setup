#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSIONS_DIR="$ROOT_DIR/versions"
LOCAL_FONT_DIR="$HOME/.local/share/fonts"
LOCAL_D2CODING_DIR="$LOCAL_FONT_DIR/D2Coding"
SOURCE_FONT_DIR="$ROOT_DIR/fonts"
SOURCE_D2CODING_DIR="$SOURCE_FONT_DIR/D2Coding"

echo "NeoVim 환경설정 시작"
echo

# ---------------------------------------------------------
# versions 디렉토리 확인
# ---------------------------------------------------------

if [ ! -d "$VERSIONS_DIR" ]; then
    echo "Error: versions 디렉토리가 없습니다."
    echo "Expected: $VERSIONS_DIR"
    exit 1
fi

# ---------------------------------------------------------
# D2Coding 폰트 설치
# ~/.local/share/fonts/D2Coding 이 없을 때만 물어봄
# ---------------------------------------------------------

echo "폰트 설정을 확인합니다."

mkdir -p "$LOCAL_FONT_DIR"

if [ -d "$LOCAL_D2CODING_DIR" ]; then
    echo "D2Coding 폰트가 이미 설치되어 있습니다."
else
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
fi

# ---------------------------------------------------------
# Neovim 버전 선택
# ---------------------------------------------------------

version_dirs=()

for dir in "$VERSIONS_DIR"/*; do
    if [ -d "$dir" ] && [ -f "$dir/init.lua" ]; then
        version_dirs+=("$dir")
    fi
done

if [ "${#version_dirs[@]}" -eq 0 ]; then
    echo "Error: versions 내부에 init.lua를 가진 버전 폴더가 없습니다."
    exit 1
fi

echo
echo "NeoVim 환경설정을 진행합니다."
echo

echo "00. 설정 및 플러그인 완전 초기화"

index=1

for dir in "${version_dirs[@]}"; do
    folder_name="$(basename "$dir")"

    display_name="${folder_name#[0-9][0-9]_}"

    printf "%02d. %s\n" "$index" "$display_name"
    index=$((index + 1))
done

echo
printf "> "
read -r choice

if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
    echo "Error: 숫자를 입력해야 합니다."
    exit 1
fi

choice_num=$((10#$choice))

if [ "$choice_num" -eq 0 ]; then
    echo
    echo "선택한 작업: 설정 및 플러그인 완전 초기화"
    echo "Neovim 설정, 플러그인, 캐시, 로컬 설치 파일을 삭제합니다."
    echo
    printf "진행하시겠습니까? [Y/n] "
    read -r confirm

    case "$confirm" in
        "" | "y" | "Y" | "yes" | "YES")
            rm -rf ~/.config/nvim \
                   ~/.local/share/nvim \
                   ~/.local/state/nvim \
                   ~/.cache/nvim

            rm -f ~/.local/bin/rg
            rm -f ~/.local/bin/tree-sitter

            rm -rf ~/.local/share/fonts/D2Coding

            echo "Neovim 관련 설정 및 플러그인 완전 초기화 완료"
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
fi

if [ "$choice_num" -lt 1 ] || [ "$choice_num" -gt "${#version_dirs[@]}" ]; then
    echo "Error: 0부터 ${#version_dirs[@]} 사이의 번호를 입력해야 합니다."
    exit 1
fi

selected_dir="${version_dirs[$((choice_num - 1))]}"
selected_name="$(basename "$selected_dir")"
selected_init="$selected_dir/init.lua"

echo
echo "선택한 버전: $selected_name"
echo "다음 작업을 진행합니다."
echo "- ~/.config/nvim/init.lua 교체"
echo "- ~/.cache/nvim 삭제"
echo
printf "진행하시겠습니까? [Y/n] "
read -r confirm

case "$confirm" in
    "" | "y" | "Y" | "yes" | "YES")
        rm -rf ~/.cache/nvim

        mkdir -p ~/.config/nvim
        cp "$selected_init" ~/.config/nvim/init.lua

        echo "Neovim 설정 완료. nvim 실행 후 작업을 완료하세요."
        ;;
    "n" | "N" | "no" | "NO")
        echo "Neovim 환경설정을 취소했습니다."
        exit 0
        ;;
    *)
        echo "Error: Y 또는 n을 입력하세요."
        exit 1
        ;;
esac
