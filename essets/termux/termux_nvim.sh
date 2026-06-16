#!/data/data/com.termux/files/usr/bin/bash

set -e

NVIM_VERSION="v0.11.7"
SRC_DIR="$HOME/opt/neovim"
INSTALL_DIR="$HOME/opt/nvim-0.11.7"
LIBUV_C="$SRC_DIR/.deps/build/src/libuv/src/unix/linux.c"

echo "[1/6] Install required packages"
pkg update
pkg install -y git cmake ninja make clang gettext

echo "[2/6] Prepare source directory"
mkdir -p "$HOME/opt"

if [ ! -d "$SRC_DIR" ]; then
  git clone https://github.com/neovim/neovim.git "$SRC_DIR"
fi

cd "$SRC_DIR"

git fetch --tags
git checkout "$NVIM_VERSION"

echo "[3/6] Clean previous build"
rm -rf build .deps

echo "[4/6] First build attempt. It may fail at libuv LLONG_MAX."
set +e
make CMAKE_BUILD_TYPE=Release \
  CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$INSTALL_DIR"
set -e

echo "[5/6] Patch libuv LLONG_MAX issue"

if [ ! -f "$LIBUV_C" ]; then
  echo "[ERROR] libuv source file not found:"
  echo "$LIBUV_C"
  echo
  echo "The first build did not reach libuv source extraction."
  exit 1
fi

# Remove older include-only patch if it exists.
sed -i '/#include <limits.h>/d' "$LIBUV_C"

# Add direct LLONG_MAX definition. This is stronger than relying on limits.h.
if ! grep -q "TERMUX_LL0NG_MAX_PATCH" "$LIBUV_C"; then
  sed -i '1i #ifndef LLONG_MAX\n#define LLONG_MAX 9223372036854775807LL\n#endif\n/* TERMUX_LL0NG_MAX_PATCH */' "$LIBUV_C"
fi

# Clear broken libuv build state, but keep downloaded/patched source.
rm -rf "$SRC_DIR/.deps/build/src/libuv-build"
rm -f "$SRC_DIR/.deps/build/src/libuv-stamp/libuv-build"
rm -f "$SRC_DIR/.deps/build/src/libuv-stamp/libuv-configure"

echo "[6/6] Rebuild and install"
make CMAKE_BUILD_TYPE=Release \
  CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$INSTALL_DIR"

make install

echo
echo "[OK] Neovim installed:"
"$INSTALL_DIR/bin/nvim" --version | head -1

echo
echo "Run:"
echo "$INSTALL_DIR/bin/nvim"

echo
echo "Make default:"
echo "export PATH=\"$INSTALL_DIR/bin:\$PATH\""
