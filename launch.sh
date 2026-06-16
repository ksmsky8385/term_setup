#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_SCRIPT="$SCRIPT_DIR/scripts/zsh_setting_start.sh"
NVIM_SCRIPT="$SCRIPT_DIR/scripts/nvim_setting_start.sh"
AGENT_SCRIPT="$SCRIPT_DIR/scripts/agent_setting_start.sh"
USER_PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
LOCAL_FONT_DIR="$HOME/.local/share/fonts"
LOCAL_D2CODING_DIR="$LOCAL_FONT_DIR/D2Coding"
LOCAL_D2CODING_TTC="$LOCAL_FONT_DIR/D2Coding-Ver1.3.2-20180524-all.ttc"
SOURCE_FONT_DIR="$SCRIPT_DIR/fonts"
SOURCE_D2CODING_DIR="$SOURCE_FONT_DIR/D2Coding"
SOURCE_D2CODING_TTC="$SOURCE_FONT_DIR/D2Coding-Ver1.3.2-20180524-all.ttc"

ensure_user_path() {
    local shell_files=("$HOME/.zshrc" "$HOME/.bashrc")
    local rc

    for rc in "${shell_files[@]}"; do
        if [ ! -f "$rc" ]; then
            continue
        fi

        if grep -Fxq "$USER_PATH_LINE" "$rc" 2>/dev/null; then
            echo "설정 파일($rc)에 PATH 설정이 이미 존재합니다."
        else
            printf '\n# User local binaries\n' >> "$rc"
            printf '%s\n' "$USER_PATH_LINE" >> "$rc"
            echo "PATH 추가 완료: $rc"
        fi
    done

    export PATH="$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH"
}

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

ensure_fonts() {
    local font_installed=false

    echo
    echo "폰트 설정을 확인합니다."

    mkdir -p "$LOCAL_FONT_DIR"

    if [ -d "$LOCAL_D2CODING_DIR" ]; then
        echo "D2Coding Nerd Font가 이미 설치되어 있습니다."
    elif [ -d "$SOURCE_D2CODING_DIR" ]; then
        echo "D2Coding Nerd Font를 설치합니다."
        cp -R "$SOURCE_D2CODING_DIR" "$LOCAL_D2CODING_DIR"
        font_installed=true
    else
        echo "Warning: D2Coding Nerd Font 디렉토리가 없습니다."
        echo "Expected: $SOURCE_D2CODING_DIR"
    fi

    if [ -f "$LOCAL_D2CODING_TTC" ]; then
        echo "D2Coding TTC 폰트가 이미 설치되어 있습니다."
    elif [ -f "$SOURCE_D2CODING_TTC" ]; then
        echo "D2Coding TTC 폰트를 설치합니다."
        cp "$SOURCE_D2CODING_TTC" "$LOCAL_D2CODING_TTC"
        font_installed=true
    else
        echo "Warning: D2Coding TTC 폰트 파일이 없습니다."
        echo "Expected: $SOURCE_D2CODING_TTC"
    fi

    if [ "$font_installed" = true ]; then
        if command -v fc-cache >/dev/null 2>&1; then
            echo "폰트 캐시를 갱신합니다."
            fc-cache -f "$LOCAL_FONT_DIR" >/dev/null 2>&1 || true
        else
            echo "Warning: fc-cache 명령어가 없어 폰트 캐시 갱신을 건너뜁니다."
        fi
    fi
}

ensure_fonts_for_choice() {
    local choice="$1"

    case "$choice" in
        1 | 2 | 4)
            ensure_fonts
            ;;
    esac
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
            run_script "$AGENT_SCRIPT" "agent"
            ;;
        4)
            run_script "$ZSH_SCRIPT" "zsh"
            run_script "$NVIM_SCRIPT" "nvim"
            run_script "$AGENT_SCRIPT" "agent"
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
    echo "3. agent 설정"
    echo "4. 전체 설정"
    echo "5. 나가기"
    echo "----------------------------------------------------"
}

while true; do
    show_menu
    printf "선택: "
    read -r choice

    case "$choice" in
        1 | 2 | 3 | 4)
            if ask_yes_no "설정을 진행하겠습니까?"; then
                ensure_user_path
                ensure_fonts_for_choice "$choice"

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
        5)
            echo "프로그램을 종료합니다."
            exit 0
            ;;
        *)
            echo "1부터 5 사이의 번호를 입력하세요."
            sleep 1
            ;;
    esac
done
