local M = {}

local function back_to_dashboard()
    pcall(vim.cmd, "DashboardHome")
end

function M.open()
    vim.cmd("enew")
    vim.bo.buftype = "nofile"
    vim.bo.bufhidden = "wipe"
    vim.bo.swapfile = false
    vim.bo.modifiable = true
    vim.wo.cursorline = true

    local version = vim.version()
    local version_text = string.format(
        "ver. %d.%d.%d",
        version.major,
        version.minor,
        version.patch
    )

    local lines = {
        "",
        "  NVIM  " .. version_text,
        "  ─────────────────────────────────────",
        "",
        "  < Back",
        "",
        "  기본 안내 명령어",
        "",
        "    :help              Neovim 도움말 열기",
        "    :Tutor             Vim 기본 튜토리얼",
        "    :checkhealth       현재 환경 상태 검사",
        "    :version           Neovim 버전 정보",
        "    :messages          최근 메시지 확인",
        "",
        "  현재 설정 주요 단축키",
        "",
        "    Space e            파일 트리 열기/닫기",
        "    Space ff           파일명 검색",
        "    Space fg           프로젝트 전체 문자열 검색",
        "    Space fb           열린 버퍼 검색",
        "    Space fh           도움말 검색",
        "    Space sw           커서 위치 단어로 문자열 검색",
        "    Space ss           선택한 문자열로 검색",
        "    Space wv           창 세로 분할",
        "    Space ws           창 가로 분할",
        "    Space wo           현재 창만 남기기",
        "    Space wc           현재 창 닫기",
        "    Space h            대시보드로 돌아가기",
        "",
        "  플러그인 관리",
        "",
        "    :Lazy              플러그인 관리 화면",
        "    :Lazy sync         플러그인 설치/업데이트",
        "",
        "  Tree-sitter 관리",
        "",
        "    :TSSettings        Tree-sitter 설정 메뉴",
        "    :TSMyList          설치된 parser 목록",
        "    :TSMyInstall rust  rust parser 설치 예시",
        "    :TSMyUninstall rust",
        "    :TSMyUpdate",
        "",
        "  테마",
        "",
        "    :ThemePick         테마 선택 메뉴",
        "",
        "  종료",
        "",
        "    :q                 현재 창 닫기",
        "    :qa                Neovim 종료",
        "",
    }

    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.bo.modifiable = false
    vim.bo.filetype = "help"

    vim.api.nvim_win_set_cursor(0, { 5, 2 })

    vim.keymap.set("n", "<CR>", function()
        if vim.api.nvim_win_get_cursor(0)[1] == 5 then
            back_to_dashboard()
        end
    end, {
        buffer = true,
        silent = true,
        desc = "Back to dashboard",
    })

    vim.keymap.set("n", "h", back_to_dashboard, {
        buffer = true,
        silent = true,
        desc = "Back to dashboard",
    })

    vim.keymap.set("n", "b", back_to_dashboard, {
        buffer = true,
        silent = true,
        desc = "Back to dashboard",
    })

    vim.keymap.set("n", "q", ":bd<CR>", {
        buffer = true,
        silent = true,
        desc = "Close About Neovim",
    })
end

return M
