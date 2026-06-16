#!/data/data/com.termux/files/usr/bin/bash

set -e

NVIM_VERSION="v0.11.7"
SRC_DIR="$HOME/opt/neovim"
INSTALL_DIR="$HOME/opt/nvim-0.11.7"

pkg update
pkg install -y git cmake ninja make clang gettext libuv luajit

mkdir -p "$HOME/opt"
cd "$HOME/opt"

if [ ! -d "$SRC_DIR" ]; then
  git clone https://github.com/neovim/neovim.git "$SRC_DIR"
fi

cd "$SRC_DIR"
git fetch --tags
git checkout "$NVIM_VERSION"

rm -rf build .deps

make CMAKE_BUILD_TYPE=Release \
  CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$INSTALL_DIR" || true

if [ -f ".deps/build/src/libuv/src/unix/linux.c" ]; then
  grep -q "limits.h" .deps/build/src/libuv/src/unix/linux.c || \
    sed -i '1i #include <limits.h>' .deps/build/src/libuv/src/unix/linux.c
fi

make CMAKE_BUILD_TYPE=Release \
  CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$INSTALL_DIR"

make install

echo
echo "[OK] Neovim installed:"
"$INSTALL_DIR/bin/nvim" --version | head -1

echo
echo "Run with:"
echo "$INSTALL_DIR/bin/nvim"

echo
echo "To make it default, add this to ~/.zshrc or ~/.bashrc:"
echo "export PATH=\"$INSTALL_DIR/bin:\$PATH\""
