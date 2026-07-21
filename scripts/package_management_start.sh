#!/usr/bin/env bash

set -u

PACKAGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_SCRIPT="$PACKAGE_ROOT/scripts/cache_cleanup_start.sh"

ask_yes_no() {
    local prompt="$1"
    local answer

    while true; do
        printf "%s [Y/n] " "$prompt"
        read -r answer

        case "$answer" in
            "" | "y" | "Y" | "yes" | "YES") return 0 ;;
            "n" | "N" | "no" | "NO") return 1 ;;
            *) echo "Y 또는 n을 입력하세요." ;;
        esac
    done
}

check_for_updates() {
    local upstream
    local commit_count

    if ! command -v git >/dev/null 2>&1; then
        echo "오류: git 명령을 찾을 수 없습니다."
        return 1
    fi

    if ! git -C "$PACKAGE_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "오류: 패키지 루트가 Git 저장소가 아닙니다: $PACKAGE_ROOT"
        return 1
    fi

    upstream="$(git -C "$PACKAGE_ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)" || {
        echo "오류: 현재 브랜치에 연결된 원격 브랜치가 없습니다."
        return 1
    }

    echo "원격 저장소에서 업데이트를 확인합니다."
    if ! git -C "$PACKAGE_ROOT" fetch; then
        echo "오류: 원격 저장소 정보를 가져오지 못했습니다."
        return 1
    fi

    commit_count="$(git -C "$PACKAGE_ROOT" rev-list --count "HEAD..$upstream")"

    if [ "$commit_count" -eq 0 ]; then
        echo "현재 최신 버전입니다."
        return 0
    fi

    echo
    echo "새로운 커밋 $commit_count개가 있습니다."
    git -C "$PACKAGE_ROOT" log --oneline --decorate "HEAD..$upstream"
    echo

    if ask_yes_no "업데이트가 확인되었습니다. 업데이트 하시겠습니까?"; then
        git -C "$PACKAGE_ROOT" pull --ff-only
    else
        echo "업데이트를 취소했습니다."
    fi
}

while true; do
    echo
    echo "패키지 관리"
    echo "----------------------------------------------------"
    echo "1. 업데이트 확인"
    echo "2. 캐시 비우기"
    echo "3. 패키지 루트 터미널로 전환"
    echo "4. 돌아가기"
    echo "----------------------------------------------------"
    printf "선택: "
    read -r choice

    case "$choice" in
        1) check_for_updates ;;
        2)
            if [ ! -f "$CACHE_SCRIPT" ]; then
                echo "오류: 캐시 정리 스크립트를 찾을 수 없습니다: $CACHE_SCRIPT"
            else
                [ -x "$CACHE_SCRIPT" ] || chmod +x "$CACHE_SCRIPT"
                "$CACHE_SCRIPT"
            fi
            ;;
        3) exit 20 ;;
        4) exit 0 ;;
        *) echo "1부터 4 사이의 번호를 입력하세요." ;;
    esac
done
