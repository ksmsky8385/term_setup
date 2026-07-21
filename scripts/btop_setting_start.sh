#!/usr/bin/env bash

set -Eeuo pipefail

INSTALL_PREFIX="$HOME/.local"
WORKDIR="$INSTALL_PREFIX/src/btop-install"
API_URL="https://api.github.com/repos/aristocratos/btop/releases/latest"

cleanup() {
    cd "$HOME" 2>/dev/null || true
    rm -rf "$WORKDIR"
    rmdir "$INSTALL_PREFIX/src" 2>/dev/null || true
}

trap cleanup EXIT

echo "[1/5] 필수 명령 확인"

for cmd in python3 tar; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "오류: '$cmd' 명령이 필요합니다." >&2
        exit 1
    fi
done

if command -v curl >/dev/null 2>&1; then
    DOWNLOADER="curl"
elif command -v wget >/dev/null 2>&1; then
    DOWNLOADER="wget"
else
    echo "오류: curl 또는 wget이 필요합니다." >&2
    exit 1
fi

ARCH="$(uname -m)"

case "$ARCH" in
    x86_64)
        ASSET_ARCH="x86_64"
        ;;
    aarch64 | arm64)
        ASSET_ARCH="aarch64"
        ;;
    *)
        echo "오류: 지원하지 않는 아키텍처입니다: $ARCH" >&2
        exit 1
        ;;
esac

echo "[2/5] 작업 디렉터리 준비"

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR" "$INSTALL_PREFIX/bin"

METADATA="$WORKDIR/release.json"

echo "[3/5] 최신 릴리스 정보 확인"

if [ "$DOWNLOADER" = "curl" ]; then
    curl -fL "$API_URL" -o "$METADATA"
else
    wget -O "$METADATA" "$API_URL"
fi

ASSET_URL="$(
    python3 - "$METADATA" "$ASSET_ARCH" <<'PY'
import json
import sys

metadata_path = sys.argv[1]
architecture = sys.argv[2]

with open(metadata_path, encoding="utf-8") as file:
    release = json.load(file)

candidates = []

for asset in release.get("assets", []):
    name = asset.get("name", "")
    url = asset.get("browser_download_url", "")
    lower_name = name.lower()

    if architecture not in lower_name:
        continue

    if "linux" not in lower_name:
        continue

    if lower_name.endswith((".tbz", ".tar.bz2", ".tar.gz", ".tgz")):
        candidates.append((name, url))

if not candidates:
    print("적합한 Linux 바이너리 자산을 찾지 못했습니다.", file=sys.stderr)
    print("릴리스 자산:", file=sys.stderr)

    for asset in release.get("assets", []):
        print(f"  {asset.get('name', '')}", file=sys.stderr)

    raise SystemExit(1)

# musl 정적 바이너리를 우선 선택
candidates.sort(
    key=lambda item: (
        "musl" not in item[0].lower(),
        item[0],
    )
)

print(candidates[0][1])
PY
)"

ARCHIVE_NAME="${ASSET_URL##*/}"
ARCHIVE_PATH="$WORKDIR/$ARCHIVE_NAME"

echo "다운로드 파일: $ARCHIVE_NAME"

if [ "$DOWNLOADER" = "curl" ]; then
    curl -fL "$ASSET_URL" -o "$ARCHIVE_PATH"
else
    wget -O "$ARCHIVE_PATH" "$ASSET_URL"
fi

echo "[4/5] 압축 해제 및 설치"

EXTRACT_DIR="$WORKDIR/extracted"
mkdir -p "$EXTRACT_DIR"

case "$ARCHIVE_NAME" in
    *.tbz | *.tar.bz2)
        tar -xjf "$ARCHIVE_PATH" -C "$EXTRACT_DIR"
        ;;
    *.tar.gz | *.tgz)
        tar -xzf "$ARCHIVE_PATH" -C "$EXTRACT_DIR"
        ;;
    *)
        echo "오류: 알 수 없는 압축 형식입니다: $ARCHIVE_NAME" >&2
        exit 1
        ;;
esac

BTOP_BIN="$(
    find "$EXTRACT_DIR" \
        -type f \
        -name btop \
        -perm /111 \
        -print \
        -quit
)"

if [ -z "$BTOP_BIN" ]; then
    echo "오류: 압축 파일 안에서 btop 실행 파일을 찾지 못했습니다." >&2
    exit 1
fi

install -m 755 "$BTOP_BIN" "$INSTALL_PREFIX/bin/btop"

# 실행 파일과 함께 제공되는 테마가 있으면 설치
THEME_DIR="$(
    find "$EXTRACT_DIR" \
        -type d \
        -name themes \
        -print \
        -quit
)"

if [ -n "$THEME_DIR" ]; then
    mkdir -p "$INSTALL_PREFIX/share/btop/themes"
    cp -R "$THEME_DIR"/. "$INSTALL_PREFIX/share/btop/themes/"
fi

echo "[5/5] PATH 설정 및 설치 확인"

SHELL_RC="$HOME/.zshrc"
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'

touch "$SHELL_RC"

if ! grep -qxF "$PATH_LINE" "$SHELL_RC"; then
    printf '\n%s\n' "$PATH_LINE" >> "$SHELL_RC"
fi

export PATH="$INSTALL_PREFIX/bin:$PATH"

command -v btop
btop --version

echo
echo "설치 완료: $INSTALL_PREFIX/bin/btop"
echo "임시 다운로드 및 압축 해제 파일은 모두 삭제됩니다."
