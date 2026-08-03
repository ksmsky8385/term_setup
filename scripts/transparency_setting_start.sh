#!/usr/bin/env bash

set -Eeuo pipefail

LOCAL_BIN="$HOME/.local/bin"
LOCAL_TMP="$HOME/.local/tmp"
WORK_DIR="$LOCAL_TMP/opacity-tools-install"

cleanup() {
    if [[ -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR"
        echo "[정리] 임시 경로 삭제: $WORK_DIR"
    fi
}

trap cleanup EXIT INT TERM

install_from_deb() {
    local package="$1"
    local binary_path="$2"
    local binary_name="$3"
    local package_dir="$WORK_DIR/$package"

    echo
    echo "[다운로드] $package"

    mkdir -p "$package_dir"
    cd "$package_dir"

    apt download "$package"

    local deb_file
    deb_file="$(find . -maxdepth 1 -type f -name '*.deb' -print -quit)"

    if [[ -z "$deb_file" ]]; then
        echo "[오류] $package 패키지를 내려받지 못했습니다." >&2
        return 1
    fi

    echo "[압축 해제] $deb_file"

    mkdir -p extracted
    dpkg-deb -x "$deb_file" extracted

    local source_file="extracted$binary_path"

    if [[ ! -f "$source_file" ]]; then
        echo "[오류] 패키지에서 실행 파일을 찾지 못했습니다: $binary_path" >&2
        return 1
    fi

    install -Dm755 "$source_file" "$LOCAL_BIN/$binary_name"

    echo "[설치 완료] $LOCAL_BIN/$binary_name"
}

check_dependencies() {
    local binary="$1"

    echo
    echo "[의존성 확인] $binary"

    local missing
    missing="$(ldd "$binary" 2>/dev/null | grep 'not found' || true)"

    if [[ -n "$missing" ]]; then
        echo "[경고] 다음 공유 라이브러리가 없습니다:"
        echo "$missing"
        return 1
    fi

    echo "[정상] 누락된 공유 라이브러리가 없습니다."
}

main() {
    for command_name in apt dpkg-deb find install ldd; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            echo "[오류] 필요한 명령어가 없습니다: $command_name" >&2
            exit 1
        fi
    done

    mkdir -p "$LOCAL_BIN" "$LOCAL_TMP"

    # 이전 실행에서 비정상 종료된 찌꺼기가 있으면 먼저 제거
    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR"

    echo "[임시 경로] $WORK_DIR"
    echo "[설치 경로] $LOCAL_BIN"

    # Ubuntu 22.04 Jammy에서는 transset이 x11-apps 패키지에 포함됨
    install_from_deb \
        "x11-apps" \
        "/usr/bin/transset" \
        "transset"

    install_from_deb \
        "devilspie2" \
        "/usr/bin/devilspie2" \
        "devilspie2"

    local dependency_error=0

    check_dependencies "$LOCAL_BIN/transset" || dependency_error=1
    check_dependencies "$LOCAL_BIN/devilspie2" || dependency_error=1

    echo
    echo "[설치 결과]"
    ls -l "$LOCAL_BIN/transset" "$LOCAL_BIN/devilspie2"

    echo
    if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
        echo "[안내] ~/.local/bin이 PATH에 없습니다."
        echo "다음 줄을 ~/.zshrc에 추가하세요:"
        echo
        echo 'export PATH="$HOME/.local/bin:$PATH"'
    else
        echo "[정상] ~/.local/bin이 PATH에 등록되어 있습니다."
    fi

    if (( dependency_error != 0 )); then
        echo
        echo "[경고] 실행 파일은 설치됐지만 시스템 공유 라이브러리가 부족합니다."
        exit 2
    fi

    echo
    echo "[완료] transset과 devilspie2를 사용자 로컬에 설치했습니다."
}

main "$@"
