```bash
#!/usr/bin/env bash

set -e

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

ensure_local_bin_path() {
    local shell_files=("$HOME/.zshrc" "$HOME/.bashrc")

    for rc in "${shell_files[@]}"; do
        if [ -f "$rc" ]; then
            if grep -q '\.local/bin' "$rc" 2>/dev/null; then
                echo "설정 파일($rc)에 이미 .local/bin 관련 PATH 설정이 존재합니다."
            else
                printf '\n# User local binaries\n' >> "$rc"
                printf 'export PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"
                echo "PATH 추가 완료: $rc"
            fi
        fi
    done

    case ":$PATH:" in
        *:"$HOME/.local/bin":*)
            ;;
        *)
            export PATH="$HOME/.local/bin:$PATH"
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

remove_antigravity_cache() {
    echo "Antigravity 캐시 삭제"

    rm -rf "$HOME/.cache/antigravity"
    rm -rf "$HOME/.gemini/antigravity-cli"

    echo "Antigravity 캐시 정리 완료"
}

remove_codex_cache() {
    echo "Codex 캐시 삭제"

    rm -rf "$HOME/.cache/codex"
    rm -rf "$HOME/.codex/tmp"
    rm -rf "$HOME/.codex/log"
    rm -rf "$HOME/.codex/logs"

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
    confirm "Codex CLI 삭제를 진행하겠습니까?" || return 0

    echo "Codex CLI 삭제"

    rm -f "$HOME/.local/bin/codex"
    rm -rf "$HOME/.codex"
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

delete_menu() {
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
    echo "CLI Agent 설정 스크립트"
    echo

    echo "00. CLI 에이전트 삭제 메뉴"
    echo "01. Antigravity CLI 설치"
    echo "02. Codex CLI 설치"
    echo "03. 전체 설치 (Antigravity & Codex)"
    echo
    printf "> "
    read -r choice

    case "$choice" in
        0 | 00)
            delete_menu
            ;;
        1 | 01)
            ensure_local_bin_path
            install_antigravity
            ;;
        2 | 02)
            ensure_local_bin_path
            install_codex
            ;;
        3 | 03)
            ensure_local_bin_path
            install_antigravity
            install_codex
            ;;
        *)
            echo "Error: 잘못된 선택입니다."
            exit 1
            ;;
    esac
}

main_menu
```

