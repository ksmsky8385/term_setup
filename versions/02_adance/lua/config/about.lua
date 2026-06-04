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
        "  전체 단축키",
        "",
        "    Space h            대시보드로 돌아가기",
        "    Space e            파일 트리 열기/닫기",
        "    Space bb           버퍼 선택",
        "    Space bn / bp      다음/이전 버퍼",
        "    Space bd / bD      현재 버퍼 닫기/강제 닫기",
        "    Space bo / bO      다른 버퍼 닫기/강제 닫기",
        "",
        "  창 관리",
        "",
        "    Space ww           창 선택",
        "    Space wv           세로 분할",
        "    Space ws           가로 분할",
        "    Space wo           현재 창만 남기기",
        "    Space wc           현재 창 닫기",
        "    Space sq           split 닫기",
        "    Ctrl-h/j/k/l       왼쪽/아래/위/오른쪽 창 이동",
        "    Ctrl-Arrow         방향키로 창 이동",
        "    Alt-Arrow          창 크기 조절",
        "",
        "  플러그인 관리",
        "",
        "    :Lazy              플러그인 관리 화면",
        "    :Lazy sync         플러그인 설치/업데이트",
        "",
        "  Telescope 검색",
        "",
        "    Space ff           파일명 검색",
        "    Space fg           프로젝트 전체 문자열 검색",
        "    Space fb           열린 버퍼 검색",
        "    Space fh           도움말 검색",
        "    Space sw           커서 위치 단어로 문자열 검색",
        "    Space ss           선택한 문자열로 검색",
        "",
        "  파일 트리",
        "",
        "    Space e            파일 트리 열기/닫기",
        "    Enter              파일/폴더 열기",
        "    Tab                파일 미리보기 열기/닫기",
        "    Esc                파일 미리보기 닫기",
        "    Ctrl-l / Right     미리보기 창으로 이동",
        "    Ctrl-h / Left      미리보기에서 파일 트리로 이동",
        "    a                  파일/폴더 생성",
        "    r                  이름 변경",
        "    d                  삭제",
        "    x                  잘라내기",
        "    c                  복사",
        "    p                  붙여넣기",
        "    y                  파일명 복사",
        "    Y                  상대 경로 복사",
        "    gy                 절대 경로 복사",
        "    R                  새로고침",
        "    H                  숨김 파일 표시/숨김",
        "",
        "  LSP / 진단",
        "",
        "    gd                 정의로 이동",
        "    K                  hover 문서 보기",
        "    Space rn           심볼 이름 변경",
        "    Space ca           code action",
        "    Space dl           현재 줄 진단 보기",
        "    [d / ]d            이전/다음 진단으로 이동",
        "    :LSPSettings       LSP 설정 메뉴",
        "    :LSPMyList         LSP 서버 목록",
        "    :LSPMyInstall      LSP 서버 설치",
        "    :LSPMyUninstall    LSP 서버 제거",
        "    :Mason             Mason 관리 화면",
        "",
        "  자동완성 / 스니펫",
        "",
        "    Space ct           자동완성 켜기/끄기",
        "    Space st           스니펫 자동완성 후보 켜기/끄기",
        "    Space sr           스니펫 다시 불러오기",
        "    Ctrl-Space         자동완성 후보 열기",
        "    Ctrl-n / Ctrl-p    자동완성 후보 이동",
        "    Enter              선택한 자동완성 후보 확정",
        "    Ctrl-e             자동완성 후보 닫기",
        "    Tab / Shift-Tab    스니펫 위치 이동",
        "    :SnippetSettings   스니펫 설정 메뉴",
        "    Custom snippets    stdpath(config)/snippets 에 작성",
        "    Snippet format     VSCode JSON snippets 형식",
        "    Space sr           custom snippets까지 다시 불러오기",
        "",
        "  터미널",
        "",
        "    Space t            현재 창 터미널 열기/닫기",
        "    Space T            실행 중인 터미널 선택",
        "    Space `            플로팅 터미널 열기",
        "    Esc                플로팅 터미널 닫기",
        "    :TKill             현재 터미널 종료",
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
        "  42 Header",
        "",
        "    :Stdheader         현재 파일에 42 헤더 추가/갱신",
        "    F1                 42 헤더 추가/갱신",
        "    FORTYTWO_USER      42 intra id 환경변수",
        "    FORTYTWO_MAIL      42 email 환경변수",
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
