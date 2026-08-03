#!/usr/bin/env bash

set -Eeuo pipefail

readonly REPOSITORY="Airblader/unclutter-xfixes"
readonly ARCHIVE_URL="https://github.com/${REPOSITORY}/archive/refs/heads/master.tar.gz"
readonly LIBEV_REPOSITORY="enki/libev"
readonly LIBEV_ARCHIVE_URL="https://github.com/${LIBEV_REPOSITORY}/archive/refs/heads/master.tar.gz"
readonly INSTALL_DIR="${HOME}/.local/bin"

log() {
    printf '[%s] %s\n' "$1" "$2"
}

die() {
    log "오류" "$1" >&2
    exit 1
}

for command_name in curl tar install mktemp make gcc pkg-config; do
    command -v "$command_name" >/dev/null 2>&1 ||
        die "필수 명령을 찾을 수 없습니다: $command_name"
done

pkg-config --exists x11 xi xfixes ||
    die "X11 개발 라이브러리를 찾을 수 없습니다: x11, xi, xfixes"

TEMP_DIR="$(mktemp -d)"
readonly TEMP_DIR
readonly ARCHIVE="${TEMP_DIR}/unclutter-xfixes.tar.gz"
readonly SOURCE_DIR="${TEMP_DIR}/unclutter-xfixes-master"
readonly LIBEV_ARCHIVE="${TEMP_DIR}/libev.tar.gz"
readonly LIBEV_SOURCE_DIR="${TEMP_DIR}/libev-master"
readonly LIBEV_PREFIX="${TEMP_DIR}/libev-install"

cleanup() {
    rm -rf -- "$TEMP_DIR"
}
trap cleanup EXIT

log "다운로드" "GitHub에서 ${REPOSITORY} 소스를 받습니다."
curl \
    --fail \
    --location \
    --retry 3 \
    --connect-timeout 15 \
    --output "$ARCHIVE" \
    "$ARCHIVE_URL"

log "다운로드" "GitHub에서 ${LIBEV_REPOSITORY} 소스를 받습니다."
curl \
    --fail \
    --location \
    --retry 3 \
    --connect-timeout 15 \
    --output "$LIBEV_ARCHIVE" \
    "$LIBEV_ARCHIVE_URL"

log "압축 해제" "$ARCHIVE"
tar -xzf "$ARCHIVE" -C "$TEMP_DIR"
tar -xzf "$LIBEV_ARCHIVE" -C "$TEMP_DIR"
[[ -d "$SOURCE_DIR" ]] || die "압축 파일에서 소스 디렉터리를 찾지 못했습니다."
[[ -d "$LIBEV_SOURCE_DIR" ]] || die "압축 파일에서 libev 소스 디렉터리를 찾지 못했습니다."

log "빌드" "libev를 사용자 권한으로 컴파일합니다."
(
    cd "$LIBEV_SOURCE_DIR"
    ./configure --prefix="$LIBEV_PREFIX" --disable-shared
    make
    make install
)

X11_LIBS="$(pkg-config --libs x11 xi xfixes)"
readonly X11_LIBS

log "빌드" "unclutter-xfixes를 컴파일합니다."
make -C "$SOURCE_DIR" \
    CFLAGS="-std=gnu99 -Wall -Wundef -Wshadow -Wformat-security -I${LIBEV_PREFIX}/include" \
    LDFLAGS="-L${LIBEV_PREFIX}/lib ${X11_LIBS} -lev" \
    unclutter
[[ -x "$SOURCE_DIR/unclutter" ]] || die "빌드 결과물을 찾지 못했습니다."

log "설치" "${INSTALL_DIR}/unclutter"
install -d -m 0755 "$INSTALL_DIR"
install -m 0755 "$SOURCE_DIR/unclutter" "${INSTALL_DIR}/unclutter"

case ":${PATH}:" in
    *":${INSTALL_DIR}:"*) ;;
    *)
        log "안내" "${INSTALL_DIR}가 PATH에 없습니다."
        printf '다음 줄을 셸 설정 파일에 추가하세요:\n'
        printf 'export PATH="$HOME/.local/bin:$PATH"\n'
        ;;
esac

log "완료" "설치됨: ${INSTALL_DIR}/unclutter"
"${INSTALL_DIR}/unclutter" --version
