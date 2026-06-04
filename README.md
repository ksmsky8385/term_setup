# term_setup

42 경산 클러스터 PC 기준으로 맞춘 zsh / Neovim 개발 환경 설정 스크립트입니다.  
sudo 권한 없이 사용자 홈 디렉토리 아래에 설치되는 구성을 기준으로 합니다.

## 사용법

```sh
./launch.sh
```

메뉴에서 원하는 설정을 선택합니다.

```text
1. zsh 설정
2. nvim 설정
3. 전체 설정
4. 나가기
```

## 동작 원리

`launch.sh`는 `scripts/` 안의 설정 스크립트를 실행합니다.

- `scripts/zsh_setting_start.sh`
  - Oh My Zsh custom 경로에 zsh 플러그인과 Powerlevel10k를 설치합니다.
  - fastfetch를 `~/.local/bin/fastfetch`에 사용자 로컬로 설치합니다.
  - fastfetch 기본 설정이 없으면 `~/.config/fastfetch/config.jsonc`를 생성합니다.

- `scripts/nvim_setting_start.sh`
  - `versions/` 안의 Neovim 설정 버전을 선택하게 합니다.
  - 선택한 버전을 `~/.config/nvim`으로 복사합니다.
  - D2Coding Nerd Font가 없으면 `fonts/`에서 사용자 폰트 경로로 설치합니다.

## 설치 대상

zsh 설정에서 설치되는 항목:

```text
~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
~/.oh-my-zsh/custom/themes/powerlevel10k
~/.local/bin/fastfetch
```

Neovim 설정은 `versions/` 아래의 설정 폴더를 선택해 설치합니다.

## 기본 설정 파일

설치 후 기본값을 사용하고 싶으면 `essets/` 폴더의 파일을 홈 디렉토리에 적용하면 됩니다.

```text
essets/.zshrc
essets/.p10k.zsh
essets/.config/fastfetch/config.jsonc
```

이 파일들은 42 경산 클러스터 PC 환경을 기준으로 작성된 기본 설정입니다. 기존 개인 설정을 덮어쓸 수 있으니 필요한 경우 백업 후 적용하세요.
