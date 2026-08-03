#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSIONS_DIR="$ROOT_DIR/versions"
BACK_TO_MENU_STATUS=10

clear 2>/dev/null || true
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

back_choice="$index"
printf "%02d. 뒤로가기\n" "$back_choice"

echo
printf "> "
read -r choice

if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
    echo "Error: 숫자를 입력해야 합니다."
    exit 1
fi

choice_num=$((10#$choice))

if [ "$choice_num" -eq "$back_choice" ]; then
    exit "$BACK_TO_MENU_STATUS"
fi

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
    echo "Error: 표시된 메뉴 번호를 입력해야 합니다."
    exit 1
fi

selected_dir="${version_dirs[$((choice_num - 1))]}"
selected_name="$(basename "$selected_dir")"

echo
echo "선택한 버전: $selected_name"
echo "다음 작업을 진행합니다."
echo "- ~/.config/nvim 전체 교체"
echo "- ~/.cache/nvim 삭제"
echo
printf "진행하시겠습니까? [Y/n] "
read -r confirm

case "$confirm" in
    "" | "y" | "Y" | "yes" | "YES")
        rm -rf ~/.cache/nvim
        rm -rf ~/.config/nvim

        mkdir -p ~/.config/nvim

        cp -R "$selected_dir"/. ~/.config/nvim/

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
