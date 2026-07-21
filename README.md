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
3. agent 설정
4. 폰트 설정
5. 전체 설정
6. 나가기
```

## 터미널 폰트 권장 설정

터미널 기본 폰트는 `D2Coding-Ver1.3.2-20180524-all.ttc`의 `D2Coding` 사용을 권장합니다. 한글 UI와 일반 문서에는 가변 굵기를 지원하는 `PretendardVariable.ttf`도 사용할 수 있습니다. `launch.sh`에서 `폰트 설정`을 선택하면 D2Coding, D2Coding Nerd Font, Pretendard Variable을 `~/.local/share/fonts/`로 복사하고 폰트 캐시를 갱신합니다. 각 폰트가 이미 설치되어 있으면 해당 항목은 다시 복사하지 않습니다. `전체 설정`에도 동일한 독립 폰트 설치 단계가 포함됩니다.

스크립트는 터미널, Neovim, 에이전트 또는 시스템의 폰트 선택값을 변경하지 않습니다. 사용할 폰트는 각 터미널 애플리케이션에서 직접 선택합니다.

```sh
fc-cache -f ~/.local/share/fonts
```

zsh 및 nvim의 아이콘과 특수문자 표시를 위해 D2Coding Nerd Font 계열도 함께 복사됩니다.

## 동작 원리

`launch.sh`는 `scripts/` 안의 설정 스크립트를 실행합니다.

- `launch.sh`
  - 폰트 설정 또는 전체 설정 선택 시 D2Coding, D2Coding Nerd Font, Pretendard Variable 폰트를 사용자 폰트 경로에 설치합니다.
  - zsh, nvim, agent 단독 설정에서는 폰트를 설치하거나 폰트 선택값을 변경하지 않습니다.

- `scripts/zsh_setting_start.sh`
  - Oh My Zsh가 없으면 먼저 `~/.oh-my-zsh`에 설치합니다.
  - Oh My Zsh custom 경로에 zsh 플러그인과 Powerlevel10k를 설치합니다.
  - fastfetch를 `~/.local/bin/fastfetch`에 사용자 로컬로 설치합니다.
  - fastfetch 기본 설정이 없으면 `~/.config/fastfetch/config.jsonc`를 생성합니다.

- `scripts/nvim_setting_start.sh`
  - `versions/` 안의 Neovim 설정 버전을 선택하게 합니다.
  - 선택한 버전을 `~/.config/nvim`으로 복사합니다.

- `scripts/agent_setting_start.sh`
  - CLI 에이전트(Antigravity, Codex, GitHub Copilot)의 설치/삭제 및 캐시 삭제 기능 등을 제공합니다.

## 설치 대상

zsh 설정에서 설치되는 항목:

```text
~/.oh-my-zsh
~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
~/.oh-my-zsh/custom/themes/powerlevel10k
~/.local/bin/fastfetch
```

Neovim 설정은 `versions/` 아래의 설정 폴더를 선택해 설치합니다.

Agent 설정에서 설치되는 항목:
- **Antigravity CLI** : `~/.local/bin/agy` 경로에 설치
- **Codex CLI** : `~/.local/bin/codex` 경로에 설치
- **GitHub Copilot CLI** : `$HOME/.nvm`의 사용자 로컬 npm을 통해 전역 설치

## CLI 에이전트

`launch.sh` 메뉴의 **3. agent 설정** 을 선택하면 먼저 사용자 로컬 Node.js/npm 환경을 확인합니다. npm이 없거나 시스템 전역 npm을 사용 중이면 `nvm`과 Node.js LTS를 `$HOME/.nvm` 아래에 설치한 뒤 에이전트 메뉴를 표시합니다.

에이전트 메뉴에는 각 도구의 설치 명령과 실행 명령도 표시됩니다.

### Antigravity CLI

터미널에서 Google Antigravity 에이전트를 실행하는 CLI입니다. 코드베이스를 자연어로 탐색하고 수정하는 작업에 사용할 수 있습니다.

설치:

```sh
curl -fsSL https://antigravity.google/cli/install.sh | bash
```

실행:

```sh
agy
```

### Codex CLI

OpenAI의 터미널 기반 코딩 에이전트입니다. 코드 설명, 파일 수정, 명령 실행과 같은 개발 작업을 지원합니다.

설치:

```sh
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

실행:

```sh
codex
```

### GitHub Copilot CLI

GitHub Copilot을 터미널에서 사용하는 코딩 에이전트입니다. 설치에는 Node.js 22 이상과 npm이 필요하며, 이 패키지의 에이전트 메뉴는 사용자 로컬 npm 환경을 먼저 준비합니다.

설치:

```sh
npm install -g @github/copilot
```

실행 후 처음 사용할 때 `/login`을 입력해 GitHub 계정을 인증합니다.

```sh
copilot
```

### GitHub Copilot 학생팩 안내

42 교육생은 [42 GitHub 포털](https://github-portal.42.fr/login)에서 42 교육생 인증을 완료한 뒤 GitHub 계정을 연동하면 GitHub Student Developer Pack을 사용할 수 있습니다. 학생팩이 적용된 GitHub 계정으로 GitHub Copilot을 이용할 수 있으며, 먼저 아래 명령어로 CLI를 설치하세요.

```sh
npm install -g @github/copilot
```

### Claude Code 안내

- **Claude Code** : Anthropic에서 개발한 터미널용 에이전트형 AI 코딩 어시스턴트입니다. 코드베이스를 직접 탐색하고 코드를 편집하며 실행까지 터미널 안에서 주도적으로 수행합니다.
- **설치 안내** : Claude Code는 **Node.js** 환경을 필수로 요구합니다. 후술할 **Node.js가 필요한 경우** 섹션을 참고하여 `nvm` 및 Node.js 설치를 진행한 뒤, 아래 명령어로 설치하여 사용할 수 있습니다:

  ```sh
  npm install -g @anthropic-ai/claude-code
  ```

**Claude Code** 의 경우 앞서 설치가능한 **Antigravity** 및 **Codex** 와는 달리 무료 요금제 사용자는 사용이 불가합니다.


## Node.js가 필요한 경우

NeoVim의 `versions/02_advance`처럼 Mason/LSP 플러그인을 사용하는 설정 버전은 일부 LSP 서버 설치와 실행에 Node.js가 필요할 수 있습니다. 예를 들어 `pyright`, `bashls`, `jsonls`, `yamlls`, `vimls` 같은 서버는 Mason에서 Node.js/npm 기반 패키지로 설치되는 경우가 많습니다.

42 클러스터처럼 sudo 권한 없이 사용자 홈 디렉토리에 설치해야 하는 환경에서는 `nvm`으로 Node.js를 설치하는 방식을 권장합니다.

```sh
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
```

설치 후 현재 쉘에 바로 적용합니다.

```sh
source ~/.zshrc
```

`nvm`이 정상적으로 로드되는지 확인합니다.

```sh
command -v nvm
```

Node.js LTS 버전을 설치하고 기본 버전으로 지정합니다.

```sh
nvm install --lts
nvm alias default 'lts/*'
node -v
npm -v
```

이후 Neovim에서 `:LSPSettings`, `:LSP Install`로 Node.js 기반 LSP 서버를 설치하면 됩니다.

## 기본 설정 파일

설치 후 기본값을 사용하고 싶으면 `essets/` 폴더의 파일을 홈 디렉토리에 적용하면 됩니다.

```text
essets/.zshrc
essets/.p10k.zsh
essets/.config/fastfetch/config.jsonc
```

이 파일들은 42 경산 클러스터 PC 환경을 기준으로 작성된 기본 설정입니다. 기존 개인 설정을 덮어쓸 수 있으니 필요한 경우 백업 후 적용하세요.

---

# 네오빔 편집 단축키 정리

## 1. 인서트 모드 (Insert Mode) 편집 단축키

### 1단계: 지우기 및 오타 수정
* **Ctrl + w** : 단어 단위 지우기 (방금 타이핑한 변수명이나 함수명 오타를 통째로 날릴 때 사용)
* **Ctrl + h** : 백스페이스(Backspace) 대체 (홈 키 포지션을 유지하며 한 글자씩 지우기)
* **Ctrl + u** : 현재 줄의 커서 앞부분 모두 지우기 (문장을 완전히 새로 쓰고 싶을 때 사용)

### 2단계: 컨텍스트 및 자동완성
* **Ctrl + n** : 다음(Next) 단어 자동완성 (현재 버퍼 내의 단어 목록 팝업)
* **Ctrl + p** : 이전(Previous) 단어 자동완성
* **Ctrl + y** : 자동완성 제안 수락(Accept) (줄바꿈 없이 팝업창의 단어를 그대로 입력)
* **Ctrl + x 후 Ctrl + o** : Omni Completion (LSP 기반 자동완성 구동)

### 3단계: 모드 전환 최소화
* **Ctrl + o** : 일회성 노멀 모드 실행 (인서트 모드를 깨지 않고 딱 하나의 노멀 모드 명령을 실행)
  * 예시: `Ctrl + o` 후 `A` (줄 맨 끝으로 이동 후 인서트 유지)
  * 예시: `Ctrl + o` 후 `zz` (현재 줄을 화면 중앙으로 정렬)
* **Ctrl + r 후 "** : 방금 복사(Yank)한 내용 붙여넣기
* **Ctrl + t** : 현재 줄 들여쓰기(Indent) 추가
* **Ctrl + d** : 현재 줄 들여쓰기(Indent) 제거

---

## 2. 노멀 모드 (Normal Mode) 편집 단축키

### 1단계: 텍스트 삭제 및 잘라내기
* **x** : 커서 아래의 글자 한 개 삭제 (Delete 키 대체)
* **dw** : 현재 위치부터 단어 끝까지 삭제 (Delete Word)
* **diw** : 커서가 위치한 단어 내부를 통째로 삭제 (Delete Inner Word)
* **dd** : 현재 줄 전체 삭제 및 잘라내기
* **d$** 또는 **D** : 커서 위치부터 줄 끝까지 삭제

### 2단계: 변경
* **ciw** : 커서가 위치한 단어를 지우고 바로 수정 (리팩토링 시 주로 사용)
* **ci"** 또는 **ci(** : 따옴표나 괄호 안의 내용만 삭제하고 새로 쓰기 (Inner 객체 변경)
* **cc** 또는 **S** : 현재 줄 전체를 지우고 새로 쓰기
* **c$** 또는 **C** : 커서 위치부터 줄 끝까지 지우고 새로 쓰기
* **r** : 커서 아래의 글자 딱 한 개만 변경 (인서트 모드로 전환되지 않음)

### 3단계: 복사, 붙여넣기 및 되돌리기
* **yy** 또는 **Y** : 현재 줄 복사 (Yank)
* **yiw** : 커서가 위치한 단어 통째로 복사
* **p** : 커서 뒤(아래 줄)에 붙여넣기 (Paste)
* **P** : 커서 앞(위 줄)에 붙여넣기
* **u** : 이전 작업 되돌리기 (Undo)
* **Ctrl + r** : 되돌린 작업 다시 실행 (Redo)

### 4단계: 인서트 모드 진입의 다양한 방법
* **i** : 커서 앞에서 입력 시작
* **a** : 커서 뒤(Append)에서 입력 시작 (단어 끝에 글자 덧붙일 때 유용)
* **I** : 현재 줄의 맨 첫 글자(인덴트 제외)에서 입력 시작
* **A** : 현재 줄의 맨 끝에서 입력 시작
* **o** : 현재 줄 아래에 새로운 줄을 만들고 입력 시작
* **O** : 현재 줄 위에 새로운 줄을 만들고 입력 시작

> **노멀 모드 팁**
> Vim의 노멀 모드 명령은 `[행동(Command)] + [범위(Text Object)]` 조합으로 작동합니다.
> * `c`(Change) + `i`(Inner) + `w`(Word) = 단어 내부 변경 (`ciw`)
> * `d`(Delete) + `a`(Around) + `(`(Parentheses) = 괄호와 괄호 안의 내용까지 삭제 (`da(`)
> 이 원리를 이해하면 수백 개의 단축키를 따로 외우지 않고도 조합해서 사용할 수 있습니다.

---

## 3. 비주얼 모드 (Visual Mode) 편집 단축키

### 1단계: 비주얼 모드 진입하기
* **v** : 일반 비주얼 모드 (글자 단위로 블록 지정)
* **V (Shift + v)** : 줄 단위 비주얼 모드 (여러 줄을 통째로 선택할 때 사용)
* **Ctrl + v** : 블록(열, Column) 단위 비주얼 모드 (세로로 영역을 지정할 때 사용, 다중 커서 효과)

### 2단계: 블록 지정 후 핵심 편집
* **y** : 선택한 블록 복사 (Yank 후 자동으로 노멀 모드로 복귀)
* **d** 또는 **x** : 선택한 블록 삭제 및 잘라내기
* **c** : 선택한 블록을 지우고 바로 인서트 모드로 전환
* **p** : 선택한 블록 위에 붙여넣기 (덮어쓰기)
  * *팁:* 기존 코드를 선택 후 `p`를 누르면 지우고 붙여넣는 과정을 한 번에 처리할 수 있습니다.

### 3단계: 코드 구조 잡기 및 일괄 수정
* **>** : 선택한 블록 오른쪽으로 들여쓰기 (Indent)
* **<** : 선택한 블록 왼쪽으로 들여쓰기 (Outdent)
* **=** : 선택한 블록 코드 인덴트(정렬) 자동 맞춤 (LSP나 파일 타입 기준 포맷팅)
* **~** : 선택한 블록의 대소문자 반전
* **U** : 선택한 블록을 모두 대문자로 변경
* **u** : 선택한 블록을 모두 소문자로 변경

### 4단계: 세로 블록(Ctrl + v) 전용 편집
* **I (Shift + i)** : 선택한 모든 줄의 맨 앞에 동시에 글자 삽입 (다중 커서 기능)
  * *사용법:* `Ctrl + v`로 여러 줄의 앞부분을 지정 -> `I` 누름 -> 글자 타이핑 -> `Esc`를 누르면 선택한 모든 줄에 일괄 적용 (주석 처리 등에 유용)
* **A (Shift + a)** : 선택한 모든 줄의 맨 끝에 동시에 글자 삽입

> **비주얼 모드 팁**
> * **gv (다시 선택하기)**: 방금 선택했던 비주얼 모드 영역을 그대로 다시 블록 지정합니다. 코드를 오른쪽으로 여러 번 밀어야 할 때 `V` -> `>` 실행 후, 사라진 블록을 `gv`로 다시 살려 `>`를 연속으로 입력할 때 유용합니다.
> * **o (커서 방향 바꾸기)**: 블록을 지정하다가 `o`를 누르면 블록의 반대쪽 끝으로 커서가 이동하여 시작점을 늘리거나 줄일 수 있습니다.

---

## 4. 그 외 특수 모드 (Special Modes) 단축키

### 1) 명령줄 모드 (Command-line Mode)
* **:** : 파일 저장, 종료 및 복잡한 내장 명령 실행을 위한 명령줄 진입
  * `:w` : 파일 저장 (Write)
  * `:q` : 종료 (Quit)
  * `:wq` 또는 `:x` : 저장 후 종료
  * `:%s/기존단어/바꿀단어/g` : 현재 파일 전체에서 단어 일괄 치환 (Replace)
* **/** : 하단 방향으로 단어 검색 (`n`은 다음 찾기, `N`은 이전 찾기)
* **?** : 상단 방향으로 단어 검색

### 2) 대체 모드 (Replace Mode)
* **R (Shift + r)** : 대체 모드 진입
  * *특징:* 글자를 입력할 때 뒤로 밀리지 않고, 커서 위치의 기존 글자를 덮어쓰며 입력합니다. 양식 수정이나 고정된 텍스트 블록을 편집할 때 사용합니다.

### 3) 터미널 모드 (Terminal Mode)
* **:terminal** 또는 **:term** : 네오빔 내부에 실제 쉘(Shell) 터미널 창 열기
* **Ctrl + \ 후 Ctrl + n** : 터미널 모드 탈출 (노멀 모드로 전환되어 커서 이동 및 창 닫기가 가능해짐)

### 4) 오퍼레이터 대기 모드 (Operator-Pending Mode)
* *특징:* `d`, `c`, `y` 같은 연산자(행동) 명령을 내린 후, 대상(범위/텍스트 객체)이 입력되기를 기다리는 일시적인 상태입니다. 나만의 커스텀 단축키 매핑(`omap`)을 설정할 때 이 개념이 사용됩니다.

### 5) 선택 모드 (Select Mode)
* *특징:* 비주얼 모드처럼 블록이 지정되지만, 일반 메모장처럼 블록이 잡힌 상태에서 타이핑을 시작하면 기존 내용이 지워지면서 새 글자가 입력됩니다. 주로 스니펫(Snippet) 플러그인의 변수 완성 기능과 연동되어 작동합니다.
