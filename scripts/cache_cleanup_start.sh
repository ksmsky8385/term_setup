#!/usr/bin/env bash

set -u

# 개발 도구 캐시 경로를 이 배열에서 자유롭게 추가하거나 제거하세요.
# 반드시 절대 경로를 사용하고, 경로별로 큰따옴표를 유지하세요.
CACHE_PATHS=(
    "$HOME/.cache/nvim"
    "$HOME/.cache/antigravity"
    "$HOME/.gemini/antigravity-cli"
    "$HOME/.cache/codex"
    "$HOME/.codex/sessions"
    "$HOME/.codex/tmp"
    "$HOME/.codex/log"
    "$HOME/.codex/logs"
)

# 브라우저와 데스크톱 앱에서 다시 생성할 수 있는 캐시 경로입니다.
# 앱 프로필, 쿠키, 로그인 정보, 확장 프로그램 데이터는 포함하지 않습니다.
APP_CACHE_PATHS=(
    "$HOME/.var/app/app.zen_browser.zen/cache"
    "$HOME/.var/app/com.discordapp.Discord/cache"
    "$HOME/.var/app/com.discordapp.Discord/config/discord/Cache"
    "$HOME/.var/app/com.discordapp.Discord/config/discord/Code Cache"
    "$HOME/.var/app/com.discordapp.Discord/config/discord/GPUCache"
    "$HOME/.var/app/com.discordapp.Discord/config/discord/logs"
    "$HOME/.var/app/io.github.shiftey.Desktop/cache"
    "$HOME/.var/app/io.github.shiftey.Desktop/config/GitHub Desktop/Cache"
    "$HOME/.var/app/io.github.shiftey.Desktop/config/GitHub Desktop/Code Cache"
    "$HOME/.var/app/io.github.shiftey.Desktop/config/GitHub Desktop/GPUCache"
    "$HOME/.var/app/io.github.shiftey.Desktop/config/GitHub Desktop/logs"
    "$HOME/.var/app/md.obsidian.Obsidian/cache"
    "$HOME/.var/app/md.obsidian.Obsidian/config/obsidian/Cache"
    "$HOME/.var/app/md.obsidian.Obsidian/config/obsidian/Code Cache"
    "$HOME/.var/app/md.obsidian.Obsidian/config/obsidian/GPUCache"
    "$HOME/.var/app/io.github.freedoom.Phase1/cache"
    "$HOME/.var/app/com.github.tchx84.Flatseal/cache"
    "$HOME/snap/firefox/common/.cache"
    "$HOME/.config/google-chrome/Default/Cache"
    "$HOME/.config/google-chrome/Default/Code Cache"
    "$HOME/.config/google-chrome/Default/GPUCache"
    "$HOME/.config/google-chrome/GrShaderCache"
    "$HOME/.config/google-chrome/ShaderCache"
    "$HOME/.config/google-chrome/Crash Reports"
    "$HOME/.config/google-chrome/component_crx_cache"
    "$HOME/.config/google-chrome/optimization_guide_model_store"
    "$HOME/.config/chromium/Cache"
    "$HOME/.config/chromium/Default/Cache"
    "$HOME/.config/chromium/Default/Code Cache"
    "$HOME/.config/chromium/Default/GPUCache"
    "$HOME/.config/chromium/Default/DawnCache"
    "$HOME/.config/chromium/GrShaderCache"
    "$HOME/.config/chromium/ShaderCache"
    "$HOME/.config/chromium/Crash Reports"
    "$HOME/.config/discord/Cache"
    "$HOME/.config/discord/Code Cache"
    "$HOME/.config/discord/GPUCache"
    "$HOME/.config/discord/logs"
    "$HOME/.config/GitHub Desktop/Cache"
    "$HOME/.config/GitHub Desktop/Code Cache"
    "$HOME/.config/GitHub Desktop/GPUCache"
    "$HOME/.config/GitHub Desktop/logs"
    "$HOME/.nvm/.cache"
    "$HOME/.npm/_cacache"
    "$HOME/.npm/_npx"
    "$HOME/.npm/_logs"
)

# Codex standalone updater keeps every installed version under this directory.
# The release referenced by `current` is retained and only older releases are removed.
CODEX_RELEASES_DIR="$HOME/.codex/packages/standalone/releases"
CODEX_CURRENT_LINK="$HOME/.codex/packages/standalone/current"

is_safe_target() {
    local target="${1%/}"

    [ -n "$target" ] || return 1
    [ "${target#/}" != "$target" ] || return 1

    case "$target" in
        "/" | "$HOME") return 1 ;;
    esac

    return 0
}

ask_to_delete() {
    local label="$1"
    local answer

    printf "위 %s 경로를 삭제하시겠습니까? [y/N] " "$label"
    read -r answer

    case "$answer" in
        "y" | "Y" | "yes" | "YES") return 0 ;;
        *) return 1 ;;
    esac
}

delete_paths() {
    local target
    local deleted_count=0
    local -a paths=("$@")

    for target in "${paths[@]}"; do
        target="${target%/}"

        if ! is_safe_target "$target"; then
            echo "건너뜀: 안전하지 않은 경로입니다: $target"
            continue
        fi

        if [ ! -e "$target" ] && [ ! -L "$target" ]; then
            echo "건너뜀: 경로가 없습니다: $target"
            continue
        fi

        rm -rf -- "$target"
        echo "삭제 완료: $target"
        deleted_count=$((deleted_count + 1))
    done

    DELETED_PATH_COUNT="$deleted_count"
}

delete_old_codex_releases() {
    local current_release=""
    local release
    local release_path
    local deleted_release_count=0

    if [ ! -d "$CODEX_RELEASES_DIR" ]; then
        echo "건너뜀: 경로가 없습니다: $CODEX_RELEASES_DIR"
        DELETED_RELEASE_COUNT=0
        return
    fi

    current_release=""
    if [ -e "$CODEX_CURRENT_LINK" ]; then
        current_release="$(cd -P -- "$CODEX_CURRENT_LINK" 2>/dev/null && pwd)"
    fi

    if [ -z "$current_release" ]; then
        echo "건너뜀: 현재 Codex 패키지를 확인할 수 없습니다: $CODEX_CURRENT_LINK"
    else
        for release in "$CODEX_RELEASES_DIR"/*; do
            [ -e "$release" ] || continue

            release_path="$(cd -P -- "$release" 2>/dev/null && pwd)" || continue
            if [ "$release_path" = "$current_release" ]; then
                echo "유지: 현재 Codex 패키지: $release"
                continue
            fi

            rm -rf -- "$release"
            echo "삭제 완료: 이전 Codex 패키지: $release"
            deleted_release_count=$((deleted_release_count + 1))
        done
    fi

    DELETED_RELEASE_COUNT="$deleted_release_count"
}

show_targets() {
    local label="$1"
    shift
    local target

    echo
    echo "삭제 대상으로 지정된 ${label} 경로:"
    for target in "$@"; do
        printf '  - %s\n' "$target"
    done
}

cleanup_development_cache() {
    show_targets "개발 도구 캐시" "${CACHE_PATHS[@]}"
    printf '  - %s (현재 Codex 버전 제외)\n' "$CODEX_RELEASES_DIR"

    if ! ask_to_delete "개발 도구 캐시"; then
        echo "캐시 삭제를 취소했습니다."
        return
    fi

    delete_paths "${CACHE_PATHS[@]}"
    delete_old_codex_releases
    echo "개발 도구 캐시 정리가 완료되었습니다. 삭제한 경로: ${DELETED_PATH_COUNT}개, 이전 Codex 패키지: ${DELETED_RELEASE_COUNT}개"
}

cleanup_app_cache() {
    show_targets "앱 캐시" "${APP_CACHE_PATHS[@]}"
    echo "주의: 브라우저, Discord, Obsidian, GitHub Desktop을 먼저 종료하세요."

    if ! ask_to_delete "앱 캐시"; then
        echo "캐시 삭제를 취소했습니다."
        return
    fi

    delete_paths "${APP_CACHE_PATHS[@]}"
    echo "앱 캐시 정리가 완료되었습니다. 삭제한 경로: ${DELETED_PATH_COUNT}개"
}

wait_for_cache_menu() {
    echo
    printf "Enter를 누르면 캐시 비우기 메뉴로 돌아갑니다."
    read -r
}

while true; do
    clear 2>/dev/null || true
    echo
    echo "캐시 비우기"
    echo "----------------------------------------------------"
    echo "1. 개발 도구 캐시 지우기"
    echo "2. 앱캐쉬 지우기"
    echo "3. 전체 캐시 지우기"
    echo "4. 돌아가기"
    echo "----------------------------------------------------"
    printf "선택: "
    read -r choice

    case "$choice" in
        1)
            cleanup_development_cache
            wait_for_cache_menu
            ;;
        2)
            cleanup_app_cache
            wait_for_cache_menu
            ;;
        3)
            cleanup_development_cache
            cleanup_app_cache
            wait_for_cache_menu
            ;;
        4) exit 0 ;;
        *)
            echo "1부터 4 사이의 번호를 입력하세요."
            wait_for_cache_menu
            ;;
    esac
done
