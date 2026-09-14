# Neovim 설정

## 에디터 설정

`:Settings` → `Editor settings` 또는 `:SettingsEditor`에서 항목을 선택하면
설정이 바뀌고 `stdpath("state")/ui-toggle-settings.json`에 기존 미니맵·스크롤뷰
토글과 함께 저장된다. 재시작 시 복원되며, 열린 일반 파일 창과 이후 여는 창에 적용된다.
터미널, 도움말, 파일 트리, 프롬프트, 플로팅 창과 미리보기 창은 적용 대상에서 제외한다.

| 항목 | 동작 / 기본값 |
| --- | --- |
| Auto pairing | 괄호·따옴표 자동 닫기, 켜짐 (`nvim-autopairs`) |
| Line numbers | absolute → relative → hybrid → off 순환, 기본 absolute |
| Wrap long lines | 긴 줄을 화면에서 줄바꿈, 켜짐 (파일 내용은 변경하지 않음) |
| Wrap at word boundaries | 단어 경계에서 화면 줄바꿈, 꺼짐; wrap이 켜져야 효과 있음 |
| Indent wrapped lines | 화면에서 이어지는 줄의 들여쓰기 유지, 꺼짐; wrap이 켜져야 효과 있음 |
| Highlight cursor line / column | 현재 줄 / 열 강조, 각각 꺼짐 |
| Show whitespace | 기존 탭·앞뒤 공백 표시, 켜짐 |
| Spell checking | `spelllang`에 따른 맞춤법 표시, 꺼짐 (기본 영어) |

relative는 커서 줄을 0으로 표시하고 다른 줄은 커서까지의 거리로 표시한다.
hybrid는 커서 줄만 실제 줄번호, 나머지는 상대 번호로 표시한다.
오토페어링 토글은 플러그인의 활성 상태를 제어하며, 기존 `Ctrl+l` 이동 키는 유지된다.
나머지 항목은 추가 플러그인이 필요 없는 네오빔 기본 옵션이다.
들여쓰기 폭과 탭/공백 규칙은 기존 파일 형식별 설정을 사용한다.

참고: [네오빔 옵션 문서](https://neovim.io/doc/user/options/),
[Snacks 토글 사례](https://github.com/folke/snacks.nvim/blob/main/docs/toggle.md),
[nvim-autopairs 활성화 API](https://github.com/windwp/nvim-autopairs#plugin-integration).

## `markdown-preview.nvim` 직접 수정 이슈

- 미리보기 URL이 `/page/{bufnr}`에서 `/{bufnr}`로 바뀐 뒤 새로고침하면
  404 또는 `/NaN`이 되는 문제를 설치된 플러그인의 라우터에서 수정했다.
- 마지막 브라우저 탭이 닫힌 후 10초 동안 재연결이 없으면 미리보기 서버가
  자동 종료되도록 수정했다.
- 수정 위치는 `~/.local/share/nvim/lazy/markdown-preview.nvim`이며, 다른 PC나
  플러그인 업데이트에는 자동으로 반영되지 않는다.
