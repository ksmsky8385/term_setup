#!/usr/bin/env bash

set -u

# Clean both the default and a relocated Codex home, without duplicates.
CODEX_DATA_DIRS=("$HOME/.codex")
if [ -n "${CODEX_HOME:-}" ] && [ "$CODEX_HOME" != "$HOME/.codex" ]; then
    CODEX_DATA_DIRS+=("$CODEX_HOME")
fi

# 대화 내역을 제외한 기타 캐시 경로를 이 배열에서 자유롭게 추가하거나 제거하세요.
# 반드시 절대 경로를 사용하고, 경로별로 큰따옴표를 유지하세요.
OTHER_CACHE_PATHS=(
    "$HOME/.cache/nvim"
    "$HOME/.cache/antigravity"
    "$HOME/.gemini/antigravity-cli"
    "$HOME/.cache/codex"
)

for codex_dir in "${CODEX_DATA_DIRS[@]}"; do
    OTHER_CACHE_PATHS+=(
        "$codex_dir/tmp"
        "$codex_dir/log"
        "$codex_dir/logs"
    )
done

# Codex 대화 본문입니다. 캐시와 분리하여 필요할 때만 삭제합니다.
CONVERSATION_PATHS=()
for codex_dir in "${CODEX_DATA_DIRS[@]}"; do
    CONVERSATION_PATHS+=("$codex_dir/sessions")
done

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
CODEX_RELEASES_DIRS=()
for codex_dir in "${CODEX_DATA_DIRS[@]}"; do
    CODEX_RELEASES_DIRS+=("$codex_dir/packages/standalone/releases")
done

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
    local current_link
    local releases_dir
    local release
    local release_path
    local deleted_release_count=0

    for releases_dir in "${CODEX_RELEASES_DIRS[@]}"; do
        if [ ! -d "$releases_dir" ]; then
            echo "건너뜀: 경로가 없습니다: $releases_dir"
            continue
        fi

        current_link="${releases_dir%/releases}/current"
        current_release=""
        if [ -e "$current_link" ]; then
            current_release="$(cd -P -- "$current_link" 2>/dev/null && pwd)"
        fi

        if [ -z "$current_release" ]; then
            echo "건너뜀: 현재 Codex 패키지를 확인할 수 없습니다: $current_link"
            continue
        fi

        for release in "$releases_dir"/*; do
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
    done

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

cleanup_old_codex_releases() {
    echo
    echo "삭제 대상으로 지정된 이전 Codex 버전:"
    for releases_dir in "${CODEX_RELEASES_DIRS[@]}"; do
        printf '  - %s (현재 Codex 버전 제외)\n' "$releases_dir"
    done

    if ! ask_to_delete "이전 Codex 버전"; then
        echo "이전 Codex 버전 삭제를 취소했습니다."
        return
    fi

    delete_old_codex_releases
    echo "이전 Codex 버전 정리가 완료되었습니다. 삭제한 패키지: ${DELETED_RELEASE_COUNT}개"
}

cleanup_other_cache() {
    show_targets "기타 캐시" "${OTHER_CACHE_PATHS[@]}" "${APP_CACHE_PATHS[@]}"
    echo "주의: 브라우저, Discord, Obsidian, GitHub Desktop을 먼저 종료하세요."

    if ! ask_to_delete "기타 캐시"; then
        echo "캐시 삭제를 취소했습니다."
        return
    fi

    delete_paths "${OTHER_CACHE_PATHS[@]}" "${APP_CACHE_PATHS[@]}"
    echo "기타 캐시 정리가 완료되었습니다. 삭제한 경로: ${DELETED_PATH_COUNT}개"
}

cleanup_conversations() {
    show_targets "Codex 대화 내역" "${CONVERSATION_PATHS[@]}"
    echo "주의: 삭제한 대화 내역은 복구할 수 없습니다."

    if ! ask_to_delete "Codex 대화 내역"; then
        echo "대화 내역 삭제를 취소했습니다."
        return
    fi

    delete_paths "${CONVERSATION_PATHS[@]}"
    echo "Codex 대화 내역 정리가 완료되었습니다. 삭제한 경로: ${DELETED_PATH_COUNT}개"
}

cleanup_all() {
    local releases_dir
    local target

    echo
    echo "전체 삭제 대상:"
    for releases_dir in "${CODEX_RELEASES_DIRS[@]}"; do
        printf '  - %s (현재 Codex 버전 제외)\n' "$releases_dir"
    done
    for target in "${OTHER_CACHE_PATHS[@]}" "${APP_CACHE_PATHS[@]}" "${CONVERSATION_PATHS[@]}"; do
        printf '  - %s\n' "$target"
    done
    echo "주의: 앱을 먼저 종료하세요. Codex 대화 내역은 복구할 수 없습니다."

    if ! ask_to_delete "전체 캐시와 대화 내역"; then
        echo "전체 삭제를 취소했습니다."
        return
    fi

    delete_old_codex_releases
    delete_paths "${OTHER_CACHE_PATHS[@]}" "${APP_CACHE_PATHS[@]}" "${CONVERSATION_PATHS[@]}"
    echo "전체 정리가 완료되었습니다. 삭제한 경로: ${DELETED_PATH_COUNT}개, 이전 Codex 패키지: ${DELETED_RELEASE_COUNT}개"
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
    echo "1. 이전 Codex 버전 파일 지우기"
    echo "2. 기타 캐시 지우기"
    echo "3. Codex 대화 내역 지우기"
    echo "4. 전부 지우기"
    echo "5. 돌아가기"
    echo "----------------------------------------------------"
    printf "선택: "
    read -r choice

    case "$choice" in
        1)
            cleanup_old_codex_releases
            wait_for_cache_menu
            ;;
        2)
            cleanup_other_cache
            wait_for_cache_menu
            ;;
        3)
            cleanup_conversations
            wait_for_cache_menu
            ;;
        4)
            cleanup_all
            wait_for_cache_menu
            ;;
        5) exit 0 ;;
        *)
            echo "1부터 5 사이의 번호를 입력하세요."
            wait_for_cache_menu
            ;;
    esac
done
