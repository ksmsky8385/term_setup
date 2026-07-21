#!/usr/bin/env bash

set -u

# 삭제할 캐시 경로를 이 배열에서 자유롭게 추가하거나 제거하세요.
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
    local answer

    printf "위 캐시 경로를 삭제하시겠습니까? [y/N] "
    read -r answer

    case "$answer" in
        "y" | "Y" | "yes" | "YES") return 0 ;;
        *) return 1 ;;
    esac
}

if [ "${#CACHE_PATHS[@]}" -eq 0 ]; then
    echo "삭제할 캐시 경로가 지정되지 않았습니다."
    exit 0
fi

echo
echo "삭제 대상으로 지정된 캐시 경로:"
for target in "${CACHE_PATHS[@]}"; do
    printf '  - %s\n' "$target"
done
printf '  - %s (현재 Codex 버전 제외)\n' "$CODEX_RELEASES_DIR"

if ! ask_to_delete; then
    echo "캐시 삭제를 취소했습니다."
    exit 0
fi

deleted_count=0
for target in "${CACHE_PATHS[@]}"; do
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

deleted_release_count=0
if [ -d "$CODEX_RELEASES_DIR" ]; then
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
else
    echo "건너뜀: 경로가 없습니다: $CODEX_RELEASES_DIR"
fi

echo "캐시 정리가 완료되었습니다. 삭제한 경로: ${deleted_count}개, 이전 Codex 패키지: ${deleted_release_count}개"
