#!/data/data/com.termux/files/usr/bin/bash

set -e

NVIM_VERSION="v0.11.7"
SRC_DIR="$HOME/opt/neovim"
INSTALL_DIR="$HOME/opt/nvim-0.11.7"
LIBUV_C="$SRC_DIR/.deps/build/src/libuv/src/unix/linux.c"

pkg update
pkg install -y git cmake ninja make clang gettext

mkdir -p "$HOME/opt"

if [ ! -d "$SRC_DIR" ]; then
  git clone https://github.com/neovim/neovim.git "$SRC_DIR"
fi

cd "$SRC_DIR"

git fetch --tags
git checkout "$NVIM_VERSION"

rm -rf build .deps

echo "[1/4] First build. It is expected to fail at LLONG_MAX."

set +e
make CMAKE_BUILD_TYPE=Release \
  CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$INSTALL_DIR"
set -e

echo "[2/4] Patching libuv linux.c"

if [ ! -f "$LIBUV_C" ]; then
  echo "[ERROR] libuv source not found:"
  echo "$LIBUV_C"
  exit 1
fi

grep -q "#include <limits.h>" "$LIBUV_C" || \
  sed -i '1i #include <limits.h>' "$LIBUV_C"

echo "[3/4] Rebuild after patch"

make CMAKE_BUILD_TYPE=Release \
  CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$INSTALL_DIR"

echo "[4/4] Install"

make install

echo
echo "[OK] Installed:"
"$INSTALL_DIR/bin/nvim" --version | head -1
echo
echo "Run:"
echo "$INSTALL_DIR/bin/nvim"
