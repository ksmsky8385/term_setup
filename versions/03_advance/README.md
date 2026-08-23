# Neovim 설정

## `markdown-preview.nvim` 직접 수정 이슈

- 미리보기 URL이 `/page/{bufnr}`에서 `/{bufnr}`로 바뀐 뒤 새로고침하면
  404 또는 `/NaN`이 되는 문제를 설치된 플러그인의 라우터에서 수정했다.
- 마지막 브라우저 탭이 닫힌 후 10초 동안 재연결이 없으면 미리보기 서버가
  자동 종료되도록 수정했다.
- 수정 위치는 `~/.local/share/nvim/lazy/markdown-preview.nvim`이며, 다른 PC나
  플러그인 업데이트에는 자동으로 반영되지 않는다.
