#!/bin/bash

set -e

ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
PLUGIN_DIR="$ZSH_CUSTOM/plugins"
THEME_DIR="$ZSH_CUSTOM/themes"

AUTOSUGGESTIONS_DIR="$PLUGIN_DIR/zsh-autosuggestions"
SYNTAX_HIGHLIGHTING_DIR="$PLUGIN_DIR/zsh-syntax-highlighting"
POWERLEVEL10K_DIR="$THEME_DIR/powerlevel10k"
FASTFETCH_CONFIG_DIR="$HOME/.config/fastfetch"
FASTFETCH_CONFIG_FILE="$FASTFETCH_CONFIG_DIR/config.jsonc"
LOCAL_BIN_DIR="$HOME/.local/bin"
FASTFETCH_BIN="$LOCAL_BIN_DIR/fastfetch"

echo "zsh 플러그인 설정 스크립트"
echo

ensure_local_bin_path() {
    local shell_files=("$HOME/.zshrc" "$HOME/.bashrc")
    
    for rc in "${shell_files[@]}"; do
        if [ -f "$rc" ]; then
            if grep -q '\.local/bin' "$rc" 2>/dev/null; then
                echo "설정 파일($rc)에 이미 .local/bin 관련 PATH 설정이 존재합니다."
            else
                printf '\n# User local binaries\n' >> "$rc"
                printf 'export PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"
                echo "PATH 추가 완료: $rc"
            fi
        fi
    done

    case ":$PATH:" in
        *:"$HOME/.local/bin":* | *:"$HOME/..local/bin":*)
            ;;
        *)
            export PATH="$HOME/.local/bin:$PATH"
            ;;
    esac
}

download_file() {
    local url="$1"
    local output="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$output"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$output"
    else
        echo "Error: curl 또는 wget이 필요합니다."
        return 1
    fi
}

fastfetch_asset_name() {
    case "$(uname -m)" in
        x86_64 | amd64)
            echo "fastfetch-linux-amd64.tar.gz"
            ;;
        aarch64 | arm64)
            echo "fastfetch-linux-aarch64.tar.gz"
            ;;
        *)
            echo "Error: 지원하지 않는 CPU 아키텍처입니다: $(uname -m)" >&2
            return 1
            ;;
    esac
}

install_fastfetch_local() {
    local asset_name
    local download_url
    local tmp_dir
    local archive
    local binary

    if [ -x "$FASTFETCH_BIN" ] || command -v fastfetch >/dev/null 2>&1; then
        echo "fastfetch가 이미 설치되어 있습니다."
        return 0
    fi

    asset_name="$(fastfetch_asset_name)" || return 1
    download_url="https://github.com/fastfetch-cli/fastfetch/releases/latest/download/$asset_name"
    tmp_dir="$(mktemp -d)"
    archive="$tmp_dir/$asset_name"

    echo "fastfetch를 사용자 로컬 경로에 설치합니다."
    echo "다운로드: $download_url"

    if ! download_file "$download_url" "$archive"; then
        echo "fastfetch 다운로드에 실패했습니다."
        rm -rf "$tmp_dir"
        return 1
    fi

    if ! tar -xzf "$archive" -C "$tmp_dir"; then
        echo "fastfetch 압축 해제에 실패했습니다."
        rm -rf "$tmp_dir"
        return 1
    fi

    binary="$(find "$tmp_dir" -type f -name fastfetch -perm -u+x | head -n 1)"

    if [ -z "$binary" ]; then
        echo "fastfetch 실행 파일을 찾지 못했습니다."
        rm -rf "$tmp_dir"
        return 1
    fi

    mkdir -p "$LOCAL_BIN_DIR"
    cp "$binary" "$FASTFETCH_BIN"
    chmod +x "$FASTFETCH_BIN"
    rm -rf "$tmp_dir"

    echo "fastfetch 설치 완료: $FASTFETCH_BIN"
}

install_plugins() {
    ensure_local_bin_path
    
    mkdir -p "$PLUGIN_DIR"
    mkdir -p "$THEME_DIR"

    echo "zsh-autosuggestions 설치 상태를 확인합니다."
    if [ ! -d "$AUTOSUGGESTIONS_DIR" ]; then
        git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$AUTOSUGGESTIONS_DIR"
    else
        echo "zsh-autosuggestions가 이미 설치되어 있습니다."
    fi

    echo
    echo "zsh-syntax-highlighting 설치 상태를 확인합니다."
    if [ ! -d "$SYNTAX_HIGHLIGHTING_DIR" ]; then
        git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$SYNTAX_HIGHLIGHTING_DIR"
    else
        echo "zsh-syntax-highlighting이 이미 설치되어 있습니다."
    fi

    echo
    echo "powerlevel10k 설치 상태를 확인합니다."
    if [ ! -d "$POWERLEVEL10K_DIR" ]; then
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$POWERLEVEL10K_DIR"
    else
        echo "powerlevel10k가 이미 설치되어 있습니다."
    fi

    echo
    echo "fastfetch 설치 상태를 확인합니다."
    install_fastfetch_local

    echo
    echo "fastfetch 설정 파일을 확인합니다."
    mkdir -p "$FASTFETCH_CONFIG_DIR"
    if [ ! -f "$FASTFETCH_CONFIG_FILE" ]; then
        cat > "$FASTFETCH_CONFIG_FILE" <<EOF
{
  "\$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "source": "ubuntu_small"
  },
  "modules": [
    "os",
    "kernel",
    "users",
    "memory",
    "localip"
  ],
  "display": {
    "stat": false,
    "color": {
      "force": true,
      "keys": "cyan",
      "output": "white"
    }
  }
}
EOF
    else
        echo "fastfetch 설정 파일이 이미 있습니다."
    fi

    echo
    echo "zsh 플러그인/테마 설치 완료"
    echo
    echo "사용하려면 ~/.zshrc에 아래 설정이 필요합니다."
    echo
    echo 'export PATH="$HOME/.local/bin:$PATH"'
    echo 'ZSH_THEME="powerlevel10k/powerlevel10k"'
    echo "plugins=("
    echo "  git"
    echo "  zsh-autosuggestions"
    echo "  zsh-syntax-highlighting"
    echo ")"
    echo
    echo "Powerlevel10k 개인 설정이 필요하면 p10k configure를 실행하세요."
}

reset_plugins() {
    echo "설치한 zsh 플러그인/테마를 삭제합니다."
    echo ".zshrc, .bashrc, .p10k.zsh, fastfetch 설정 파일은 수정하지 않습니다."
    echo
    printf "진행하시겠습니까? [Y/n] "
    read -r confirm

    case "$confirm" in
        "" | "y" | "Y" | "yes" | "YES")
            rm -rf "$AUTOSUGGESTIONS_DIR"
            rm -rf "$SYNTAX_HIGHLIGHTING_DIR"
            rm -rf "$POWERLEVEL10K_DIR"
            rm -f "$FASTFETCH_BIN"
            rm -f "$HOME"/.zcompdump*

            echo "플러그인 삭제 완료"
            ;;
        "n" | "N" | "no" | "NO")
            echo "삭제를 취소했습니다."
            ;;
        *)
            echo "Error: Y 또는 n을 입력하세요."
            exit 1
            ;;
    esac
}

echo "00. 설치한 플러그인 삭제"
echo "01. 플러그인 설치"
echo
printf "> "
read -r choice

case "$choice" in
    0 | 00)
        reset_plugins
        ;;
    1 | 01)
        install_plugins
        ;;
    *)
        echo "Error: 0 또는 1을 입력하세요."
        exit 1
        ;;
esac
