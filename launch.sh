#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_SCRIPT="$SCRIPT_DIR/scripts/zsh_setting_start.sh"
NVIM_SCRIPT="$SCRIPT_DIR/scripts/nvim_setting_start.sh"

ask_yes_no() {
    local prompt="$1"
    local answer

    while true; do
        printf "%s [Y/n] " "$prompt"
        read -r answer

        case "$answer" in
            "" | "y" | "Y" | "yes" | "YES")
                return 0
                ;;
            "n" | "N" | "no" | "NO")
                return 1
                ;;
            *)
                echo "Y 또는 n을 입력하세요."
                ;;
        esac
    done
}

run_script() {
    local script_path="$1"
    local label="$2"

    if [ ! -f "$script_path" ]; then
        echo "Error: $label 스크립트를 찾을 수 없습니다."
        echo "Expected: $script_path"
        return 1
    fi

    if [ ! -x "$script_path" ]; then
        chmod +x "$script_path"
    fi

    echo
    echo "----------------------------------------------------"
    echo "$label 설정을 시작합니다."
    echo "----------------------------------------------------"
    "$script_path"
}

run_selected_setup() {
    local choice="$1"

    case "$choice" in
        1)
            run_script "$ZSH_SCRIPT" "zsh"
            ;;
        2)
            run_script "$NVIM_SCRIPT" "nvim"
            ;;
        3)
            run_script "$ZSH_SCRIPT" "zsh"
            run_script "$NVIM_SCRIPT" "nvim"
            ;;
        *)
            echo "Error: 알 수 없는 선택입니다."
            return 1
            ;;
    esac
}

show_menu() {
    clear 2>/dev/null || true
    echo "CLI 프로그래밍 환경 통합 설정"
    echo "----------------------------------------------------"
    echo "1. zsh 설정"
    echo "2. nvim 설정"
    echo "3. 전체 설정"
    echo "4. 나가기"
    echo "----------------------------------------------------"
}

while true; do
    show_menu
    printf "선택: "
    read -r choice

    case "$choice" in
        1 | 2 | 3)
            if ask_yes_no "설정을 진행하겠습니까?"; then
                if run_selected_setup "$choice"; then
                    echo
                    echo "선택한 설정이 완료되었습니다."
                else
                    echo
                    echo "선택한 설정 중 오류가 발생했습니다."
                fi
            else
                echo "설정을 취소했습니다."
            fi

            echo
            if ask_yes_no "종료하시겠습니까?"; then
                echo "프로그램을 종료합니다."
                exit 0
            fi
            ;;
        4)
            echo "프로그램을 종료합니다."
            exit 0
            ;;
        *)
            echo "1부터 4 사이의 번호를 입력하세요."
            sleep 1
            ;;
    esac
done
