#!/data/data/com.termux/files/usr/bin/bash

set -e

NVIM_VERSION="v0.11.7"
SRC_DIR="$HOME/opt/neovim"
INSTALL_DIR="$HOME/opt/nvim-0.11.7"
LIBUV_C="$SRC_DIR/.deps/build/src/libuv/src/unix/linux.c"

pkg update
pkg install -y git cmake ninja make clang gettext

mkdir -p "$HOME/opt"
cd "$HOME/opt"

if [ ! -d "$SRC_DIR" ]; then
  git clone https://github.com/neovim/neovim.git "$SRC_DIR"
fi

cd "$SRC_DIR"
git fetch --tags
git checkout "$NVIM_VERSION"

rm -rf build .deps

mkdir -p .deps
cmake -S "$SRC_DIR/cmake.deps" -B "$SRC_DIR/.deps" -G Ninja

cmake --build "$SRC_DIR/.deps" --target libuv-download

if [ ! -f "$LIBUV_C" ]; then
  echo "[ERROR] libuv source not found:"
  echo "$LIBUV_C"
  exit 1
fi

grep -q "#include <limits.h>" "$LIBUV_C" || \
  sed -i '1i #include <limits.h>' "$LIBUV_C"

make CMAKE_BUILD_TYPE=Release \
  CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$INSTALL_DIR"

make install

echo
echo "[OK] Neovim installed:"
"$INSTALL_DIR/bin/nvim" --version | head -1
