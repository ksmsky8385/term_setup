#!/usr/bin/env bash

set -e
set -o pipefail

NVM_VERSION="v0.40.4"
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
CODEX_DATA_DIRS=("$HOME/.codex")
if [ -n "${CODEX_HOME:-}" ] && [ "$CODEX_HOME" != "$HOME/.codex" ]; then
    CODEX_DATA_DIRS+=("$CODEX_HOME")
fi
BACK_TO_MENU_STATUS=10

load_nvm() {
    export NVM_DIR

    if [ ! -s "$NVM_DIR/nvm.sh" ]; then
        return 1
    fi

    # shellcheck disable=SC1090
    . "$NVM_DIR/nvm.sh"
}

install_nvm() {
    local installer_url
    local installer

    installer_url="https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh"
    installer="$(mktemp)"

    echo "사용자 로컬 Node.js/npm 환경을 설치합니다."

    if ! curl -fsSL "$installer_url" -o "$installer"; then
        rm -f "$installer"
        echo "Error: nvm 설치 스크립트를 다운로드하지 못했습니다."
        return 1
    fi

    if ! bash "$installer"; then
        rm -f "$installer"
        echo "Error: nvm 설치에 실패했습니다."
        return 1
    fi

    rm -f "$installer"
}

ensure_user_local_npm() {
    local npm_prefix
    local node_major

    if command -v npm >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
        npm_prefix="$(npm prefix -g 2>/dev/null || true)"
        node_major="$(node --version | sed -E 's/^v([0-9]+).*/\1/')"

        if [ -n "$npm_prefix" ] && [ -n "$node_major" ] \
            && [ "$node_major" -ge 22 ] \
            && case "$npm_prefix" in "$HOME"/*) true ;; *) false ;; esac; then
            echo "사용자 로컬 npm이 이미 준비되어 있습니다: $npm_prefix"
            return 0
        fi
    fi

    if ! load_nvm; then
        install_nvm
        load_nvm || {
            echo "Error: 설치한 nvm을 현재 쉘에 불러오지 못했습니다."
            return 1
        }
    fi

    echo "사용자 로컬 Node.js LTS/npm을 준비합니다."
    nvm install --lts
    nvm alias default 'lts/*'
    nvm use default

    if ! command -v npm >/dev/null 2>&1 || ! command -v node >/dev/null 2>&1; then
        echo "Error: 사용자 로컬 npm을 찾지 못했습니다."
        return 1
    fi

    npm_prefix="$(npm prefix -g 2>/dev/null || true)"
    case "$npm_prefix" in
        "$HOME"/*)
            echo "사용자 로컬 npm 준비 완료: $npm_prefix"
            ;;
        *)
            echo "Error: npm 전역 설치 경로가 사용자 홈 디렉토리가 아닙니다: $npm_prefix"
            return 1
            ;;
    esac
}

confirm() {
    local message="$1"
    local answer

    printf "%s [Y/n]: " "$message"
    read -r answer

    case "$answer" in
        "" | y | Y | yes | YES)
            return 0
            ;;
        *)
            echo "취소했습니다."
            return 1
            ;;
    esac
}

install_antigravity() {
    confirm "Antigravity CLI 설치를 진행하겠습니까?" || return 0

    echo "Antigravity CLI 설치"
    curl -fsSL https://antigravity.google/cli/install.sh | bash
    agy --version || true
}

install_codex() {
    confirm "Codex CLI 설치를 진행하겠습니까?" || return 0

    echo "Codex CLI 설치"
    curl -fsSL https://chatgpt.com/codex/install.sh | sh
    codex --version || true
}

install_copilot() {
    confirm "GitHub Copilot CLI 설치를 진행하겠습니까?" || return 0

    echo "GitHub Copilot CLI 설치"
    npm install -g @github/copilot
    copilot --version || true
}

remove_antigravity_cache() {
    echo "Antigravity 캐시 삭제"

    rm -rf "$HOME/.cache/antigravity"
    rm -rf "$HOME/.gemini/antigravity-cli"

    echo "Antigravity 캐시 정리 완료"
}

remove_codex_cache() {
    local codex_dir

    echo "Codex 캐시 삭제"

    rm -rf "$HOME/.cache/codex"
    for codex_dir in "${CODEX_DATA_DIRS[@]}"; do
        rm -rf "$codex_dir/tmp"
        rm -rf "$codex_dir/log"
        rm -rf "$codex_dir/logs"
    done

    echo "Codex 캐시 정리 완료"
}

remove_all_cache() {
    remove_antigravity_cache
    remove_codex_cache
}

remove_antigravity() {
    confirm "Antigravity CLI 삭제를 진행하겠습니까?" || return 0

    echo "Antigravity CLI 삭제"

    rm -f "$HOME/.local/bin/agy"
    rm -rf "$HOME/.antigravity"
    rm -rf "$HOME/.config/antigravity"
    rm -rf "$HOME/.local/share/antigravity"
    rm -rf "$HOME/.local/state/antigravity"
    rm -rf "$HOME/.local/share/agy"
    rm -rf "$HOME/.local/state/agy"

    remove_antigravity_cache

    echo "Antigravity 관련 파일 정리 완료"
}

remove_codex() {
    local codex_dir

    confirm "Codex CLI 삭제를 진행하겠습니까?" || return 0

    echo "Codex CLI 삭제"

    rm -f "$HOME/.local/bin/codex"
    for codex_dir in "${CODEX_DATA_DIRS[@]}"; do
        rm -rf "$codex_dir"
    done
    rm -rf "$HOME/.config/codex"
    rm -rf "$HOME/.local/share/codex"
    rm -rf "$HOME/.local/state/codex"

    remove_codex_cache

    echo "Codex 관련 파일 정리 완료"
}

remove_all_agents() {
    confirm "Antigravity와 Codex 전체 삭제를 진행하겠습니까?" || return 0

    echo "전체 CLI Agent 삭제"
    remove_antigravity
    remove_codex
}

show_agent_commands() {
    echo "에이전트별 설치 및 실행 명령"
    echo
    echo "01. Antigravity CLI"
    echo "    터미널에서 Google Antigravity 에이전트를 사용하는 CLI입니다."
    echo "    설치: curl -fsSL https://antigravity.google/cli/install.sh | bash"
    echo "    실행: agy"
    echo
    echo "02. Codex CLI"
    echo "    OpenAI Codex 에이전트로 코드 탐색, 수정, 실행을 돕습니다."
    echo "    설치: curl -fsSL https://chatgpt.com/codex/install.sh | sh"
    echo "    실행: codex"
    echo
    echo "03. GitHub Copilot CLI"
    echo "    GitHub Copilot을 터미널에서 사용하는 코딩 에이전트입니다."
    echo "    설치: npm install -g @github/copilot"
    echo "    실행: copilot (첫 실행 후 /login으로 GitHub 인증)"
    echo
}

delete_menu() {
    clear 2>/dev/null || true
    echo "CLI Agent 삭제 메뉴"
    echo
    echo "00. 뒤로가기"
    echo "01. Antigravity 삭제"
    echo "02. Codex 삭제"
    echo "03. 전체 삭제"
    echo "04. Antigravity 캐시만 삭제"
    echo "05. Codex 캐시만 삭제"
    echo "06. 전체 캐시만 삭제"
    echo
    printf "> "
    read -r choice

    case "$choice" in
        0 | 00)
            return 0
            ;;
        1 | 01)
            remove_antigravity
            ;;
        2 | 02)
            remove_codex
            ;;
        3 | 03)
            remove_all_agents
            ;;
        4 | 04)
            confirm "Antigravity 캐시만 삭제하겠습니까?" && remove_antigravity_cache
            ;;
        5 | 05)
            confirm "Codex 캐시만 삭제하겠습니까?" && remove_codex_cache
            ;;
        6 | 06)
            confirm "전체 캐시만 삭제하겠습니까?" && remove_all_cache
            ;;
        *)
            echo "Error: 잘못된 선택입니다."
            exit 1
            ;;
    esac
}

main_menu() {
    ensure_user_local_npm

    clear 2>/dev/null || true
    echo "CLI Agent 설정 스크립트"
    echo

    show_agent_commands

    echo "00. CLI 에이전트 삭제 메뉴"
    echo "01. Antigravity CLI 설치"
    echo "02. Codex CLI 설치"
    echo "03. GitHub Copilot CLI 설치"
    echo "04. 전체 설치 (Antigravity & Codex & GitHub Copilot)"
    echo "05. 뒤로가기"
    echo
    printf "> "
    read -r choice

    case "$choice" in
        0 | 00)
            delete_menu
            ;;
        1 | 01)
            install_antigravity
            ;;
        2 | 02)
            install_codex
            ;;
        3 | 03)
            install_copilot
            ;;
        4 | 04)
            install_antigravity
            install_codex
            install_copilot
            ;;
        5 | 05)
            exit "$BACK_TO_MENU_STATUS"
            ;;
        *)
            echo "Error: 잘못된 선택입니다."
            exit 1
            ;;
    esac
}

main_menu
