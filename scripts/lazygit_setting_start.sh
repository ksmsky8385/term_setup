#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_CONFIG="$ROOT_DIR/essets/ubuntu/.config/lazygit/config.yml"

DELTA_VERSION="0.19.2"
DELTA_BASE_URL="https://github.com/dandavison/delta/releases/download/$DELTA_VERSION"
INSTALL_DIR="${HOME:?}/.local/bin"
DELTA_BIN="$INSTALL_DIR/delta"
CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}"
LAZYGIT_CONFIG_DIR="$CONFIG_ROOT/lazygit"
LAZYGIT_CONFIG="$LAZYGIT_CONFIG_DIR/config.yml"
WORK_DIR=""

cleanup() {
    if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
        rm -rf "$WORK_DIR"
    fi
}

trap cleanup EXIT

for command_name in curl tar sha256sum install awk date cp; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "오류: '$command_name' 명령이 필요합니다." >&2
        exit 1
    fi
done

if [ ! -f "$SOURCE_CONFIG" ]; then
    echo "오류: LazyGit 설정 원본이 없습니다: $SOURCE_CONFIG" >&2
    exit 1
fi

case "$(uname -m)" in
    x86_64 | amd64)
        DELTA_TARGET="x86_64-unknown-linux-gnu"
        DELTA_SHA256="8e695c5f586a8c53d6c3b01be0b4a422ed218bfed2a56191caebe373a1c18ab2"
        ;;
    aarch64 | arm64)
        DELTA_TARGET="aarch64-unknown-linux-gnu"
        DELTA_SHA256="0bfce159a5cddd5feb3d6db4a616d883ff51253ce08ac7ec11cb1d208cfaab9e"
        ;;
    *)
        echo "오류: 지원하지 않는 아키텍처입니다: $(uname -m)" >&2
        exit 1
        ;;
esac

echo "[1/4] Delta 설치 상태 확인"

installed_version=""
if [ -x "$DELTA_BIN" ]; then
    installed_version="$("$DELTA_BIN" --version 2>/dev/null | awk '{print $2}')"
fi

if [ "$installed_version" = "$DELTA_VERSION" ]; then
    echo "Delta $DELTA_VERSION 버전이 이미 설치되어 있습니다."
else
    WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/delta-install.XXXXXX")"
    archive_name="delta-$DELTA_VERSION-$DELTA_TARGET.tar.gz"
    archive_path="$WORK_DIR/$archive_name"
    download_url="$DELTA_BASE_URL/$archive_name"

    echo "[2/4] Delta $DELTA_VERSION 다운로드 및 검증"
    curl -fL "$download_url" -o "$archive_path"
    printf '%s  %s\n' "$DELTA_SHA256" "$archive_path" | sha256sum --check -

    echo "[3/4] Delta를 사용자 로컬 경로에 설치"
    tar -xzf "$archive_path" -C "$WORK_DIR"
    extracted_bin="$WORK_DIR/delta-$DELTA_VERSION-$DELTA_TARGET/delta"

    if [ ! -f "$extracted_bin" ]; then
        echo "오류: 압축 파일에서 Delta 실행 파일을 찾지 못했습니다." >&2
        exit 1
    fi

    mkdir -p "$INSTALL_DIR"
    install -m 755 "$extracted_bin" "$DELTA_BIN"
fi

echo "[4/4] LazyGit 설정 백업 및 Dark Modern 테마 적용"
mkdir -p "$LAZYGIT_CONFIG_DIR"

if [ -f "$LAZYGIT_CONFIG" ]; then
    backup_path="$LAZYGIT_CONFIG.backup-$(date '+%Y%m%d-%H%M%S')"
    cp -p "$LAZYGIT_CONFIG" "$backup_path"
    echo "기존 설정 백업: $backup_path"
fi

install -m 644 "$SOURCE_CONFIG" "$LAZYGIT_CONFIG"

if [ "$("$DELTA_BIN" --version)" != "delta $DELTA_VERSION" ]; then
    echo "오류: Delta 설치 확인에 실패했습니다." >&2
    exit 1
fi

echo
echo "Delta 설치 완료: $DELTA_BIN"
echo "LazyGit 설정 적용 완료: $LAZYGIT_CONFIG"
echo "임시 다운로드와 압축 해제 부산물은 모두 제거되었습니다."
