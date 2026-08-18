local M = {}
local empty_buffers = require("config.empty_buffers")
local floating_about = {
    win = nil,
    buf = nil,
    previous_win = nil,
    previous_slot_id = nil,
    previous_mode = nil,
    saved_view = nil,
}
local close_floating_about

local function save_floating_about_view()
    local win = floating_about.win

    if not win or not vim.api.nvim_win_is_valid(win) then
        return
    end

    local ok, view = pcall(vim.api.nvim_win_call, win, vim.fn.winsaveview)

    if ok then
        floating_about.saved_view = view
    end
end

local section_definitions = {
    ["빠른 시작"] = { index = 0, title = "Quick Start", description = "자주 쓰는 기본 단축키" },
    ["에이전트 / Agentic"] = { index = 1, title = "Agentic AI", description = "Agentic 조작 단축키" },
    ["자동완성 / 스니펫"] = { index = 2, title = "Autocomplete & Snippets", description = "완성 후보와 스니펫 관리" },
    ["버퍼"] = { index = 3, title = "Buffers", description = "버퍼 탐색, 이동 및 닫기" },
    ["주석 및 42header"] = { index = 4, title = "Comments & 42 Header", description = "주석과 42 헤더 사용법" },
    ["대시보드 / About"] = { index = 5, title = "Dashboard & About", description = "홈 화면과 도움말 화면" },
    ["디버깅 / DAP"] = { index = 6, title = "Debugging & DAP", description = "중단점과 디버깅 실행" },
    ["종료"] = { index = 7, title = "Exit", description = "창, 버퍼 및 Neovim 종료" },
    ["파일 트리"] = { index = 8, title = "File Tree", description = "파일 트리 탐색과 조작" },
    ["Git"] = { index = 9, title = "Git", description = "LazyGit과 변경 사항 관리" },
    ["42 Header 설정"] = { index = 10, title = "Header Settings (42)", description = "42 헤더 사용자 정보 설정" },
    ["LSP / 진단"] = { index = 11, title = "LSP & Diagnostics", description = "코드 탐색, 액션 및 진단" },
    ["Markdown"] = { index = 12, title = "Markdown", description = "Markdown 브라우저 미리보기" },
    ["Minimap"] = { index = 13, title = "Minimap", description = "미니맵과 스크롤바 제어" },
    ["검색 / 탐색"] = { index = 14, title = "Search & Navigation", description = "파일, 문자열 및 도움말 검색" },
    ["세션"] = { index = 15, title = "Sessions", description = "작업 세션 저장과 복원" },
    ["설정 / 관리"] = { index = 16, title = "Settings & Management", description = "플러그인과 개발 도구 설정" },
    ["탭"] = { index = 17, title = "Tabs", description = "탭 생성, 이동 및 닫기" },
    ["터미널 / 플로팅"] = { index = 18, title = "Terminal & Floating Windows", description = "터미널과 플로팅 슬롯 관리" },
    ["테마"] = { index = 19, title = "Themes", description = "색상 테마 선택과 저장" },
    ["Tree-sitter"] = { index = 20, title = "Tree-sitter", description = "언어 파서 설치와 관리" },
    ["창"] = { index = 21, title = "Windows", description = "창 선택, 분할 및 크기 조절" },
}

local function organize_sections(lines)
    local header = {}
    local sections = {}
    local current

    for _, line in ipairs(lines) do
        local source_title = line:match("^  (.+)$")
        local definition = source_title and section_definitions[source_title]

        if definition then
            current = {
                index = definition.index,
                lines = {
                    string.format("  %02d. %s", definition.index, definition.title),
                },
            }
            sections[#sections + 1] = current
        elseif current then
            current.lines[#current.lines + 1] = line
        else
            header[#header + 1] = line
        end
    end

    table.sort(sections, function(left, right)
        return left.index < right.index
    end)

    local organized = vim.list_extend({}, header)
    local section_targets = {}
    local toc_targets = {}

    organized[#organized + 1] = "  Contents"
    organized[#organized + 1] = ""

    for _, section in ipairs(sections) do
        local definition

        for _, candidate in pairs(section_definitions) do
            if candidate.index == section.index then
                definition = candidate
                break
            end
        end

        organized[#organized + 1] = string.format(
            "    %02d. %s — %s",
            section.index,
            definition.title,
            definition.description
        )
        toc_targets[#organized] = section.index
    end

    organized[#organized + 1] = ""

    for _, section in ipairs(sections) do
        section_targets[section.index] = #organized + 1
        vim.list_extend(organized, section.lines)
    end

    return organized, section_targets, toc_targets
end

local function back_to_previous_buffer()
    local about_buf = vim.api.nvim_get_current_buf()

    if vim.b[about_buf].config_about_floating then
        close_floating_about()
        return
    end

    local previous_buf = vim.b[about_buf].config_about_previous_buf

    if
        type(previous_buf) == "number"
        and vim.api.nvim_buf_is_valid(previous_buf)
        and previous_buf ~= about_buf
    then
        vim.api.nvim_win_set_buf(0, previous_buf)
    else
        pcall(vim.cmd, "DashboardHome")
    end

    empty_buffers.cleanup({
        keep = { vim.api.nvim_get_current_buf() },
    })
end

function M.open(opts)
    opts = opts or {}

    if vim.b.config_about_neovim then
        return
    end

    local previous_buf = opts.previous_buf or vim.api.nvim_get_current_buf()

    if opts.buf then
        vim.api.nvim_win_set_buf(0, opts.buf)
    else
        vim.cmd("enew")
    end

    vim.bo.buftype = "nofile"
    vim.bo.bufhidden = "wipe"
    vim.bo.swapfile = false
    vim.bo.modifiable = true
    vim.b.config_about_neovim = true
    vim.b.config_about_floating = opts.floating == true
    vim.b.config_about_previous_buf = previous_buf
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
        "  빠른 시작",
        "",
        "    Ctrl-s             일반 파일 저장",
        "    Space h            대시보드로 돌아가기",
        "    Space ?            About Neovim 열기/이전 버퍼로 돌아가기",
        "    Space Ctrl-s       설정 메뉴 열기",
        "    Space e            파일 트리 열기/닫기",
        "    Space ff           파일명 검색",
        "    Space fg           프로젝트 전체 문자열 검색",
        "    Space bb           버퍼 선택",
        "    Space q / Q        현재 버퍼 닫기/강제 닫기",
        "    Space Ctrl-q       현재 창 닫기",
        "",
        "    Telescope",
        "",
        "      Ctrl-n / Ctrl-p  다음/이전 검색 결과",
        "      Enter            선택 결과 열기",
        "      Insert Esc       normal mode로 전환",
        "      Normal Esc       Telescope 닫기",
        "      Ctrl-u / Ctrl-d  미리보기 위/아래 스크롤",
        "",
        "    Normal mode 단축키",
        "",
        "      h / j / k / l    왼쪽/아래/위/오른쪽으로 이동",
        "      w / b / e        다음 단어/이전 단어/단어 끝으로 이동",
        "      W / B / E        공백 기준 다음/이전 단어/단어 끝으로 이동",
        "      0 / ^ / $        줄 처음/첫 글자/줄 끝으로 이동",
        "      gg / G           파일 처음/끝으로 이동",
        "      H / M / L        화면의 위/가운데/아래 줄로 이동",
        "      { / }             이전/다음 문단으로 이동",
        "      %                 대응하는 괄호로 이동",
        "      f/F + 문자        줄 안에서 다음/이전 문자로 이동",
        "      t/T + 문자        다음/이전 문자 바로 앞까지 이동",
        "      ; / ,             마지막 f/F/t/T 이동 반복/역방향 반복",
        "      Ctrl-o / Ctrl-i  이전/다음 점프 위치로 이동",
        "      m+문자 / '+문자   위치 마크 저장/해당 마크로 이동",
        "      숫자+동작         동작 반복(예: 5j, 3w, 2dd)",
        "      i / a            커서 앞/뒤에서 insert mode 시작",
        "      I / A            줄 처음/끝에서 insert mode 시작",
        "      o / O            아래/위에 새 줄을 만들고 입력",
        "      x / dd / D       글자/현재 줄/커서 뒤 삭제",
        "      r / s            현재 글자 교체/삭제 후 입력",
        "      cc / cw / ciw    현재 줄/단어 끝/현재 단어 변경",
        "      diw / daw        현재 단어 내부/공백 포함 단어 삭제",
        "      ci\" / ci(        따옴표/괄호 내부를 지우고 입력",
        "      J                 다음 줄을 현재 줄에 연결",
        "      >> / <<           현재 줄 들여쓰기/내어쓰기",
        "      yy / p / P       현재 줄 복사/뒤에 붙이기/앞에 붙이기",
        "      \"+동작           지정 레지스터 사용(예: \"ayy, \"ap)",
        "      u / Ctrl-r       실행 취소/다시 실행",
        "      .                 마지막 변경 반복",
        "      q+문자 / @+문자   매크로 기록/실행, @@는 다시 실행",
        "      /문자열           아래 방향 검색",
        "      n / N             다음/이전 검색 결과",
        "      * / #             커서 단어를 아래/위 방향 검색",
        "      :                 명령줄 열기",
        "      Ctrl-e / Ctrl-y  화면을 한 줄 아래/위로 스크롤",
        "      Ctrl-d / Ctrl-u  화면을 반 페이지 아래/위로 스크롤",
        "      Ctrl-f / Ctrl-b  화면을 한 페이지 아래/위로 스크롤",
        "      zz / zt / zb     현재 줄을 화면 중앙/위/아래에 배치",
        "      v / V / Ctrl-v   문자/줄/블록 visual mode 시작",
        "",
        "    Insert mode 단축키",
        "",
        "      Esc               normal mode로 돌아가기",
        "      Ctrl-h            앞 글자 삭제",
        "      Ctrl-w            앞 단어 삭제",
        "      Ctrl-u            현재 입력 위치 앞부분 삭제",
        "      Ctrl-o            normal 명령 하나 실행 후 입력 복귀",
        "      Ctrl-r + 레지스터 레지스터 내용 삽입(Ctrl-r + \")",
        "      Ctrl-n / Ctrl-p  다음/이전 자동완성 후보",
        "      Ctrl-t / Ctrl-d  현재 줄 들여쓰기/내어쓰기",
        "      Ctrl-a            직전에 입력한 텍스트 다시 삽입",
        "      Ctrl-s            현재 파일 저장 후 입력 계속",
        "",
        "    Visual mode 단축키",
        "",
        "      v / V / Ctrl-v   문자/줄/블록 단위 선택",
        "      o                 선택 영역 반대쪽 끝으로 이동",
        "      iw / aw           현재 단어 내부/공백 포함 단어 선택",
        "      i\" / a\"           따옴표 내부/따옴표 포함 영역 선택",
        "      i( / a(           괄호 내부/괄호 포함 영역 선택",
        "      y / d / c         선택 영역 복사/삭제/변경",
        "      > / <             선택 영역 들여쓰기/내어쓰기",
        "      =                 선택 영역 자동 들여쓰기",
        "      J                 선택한 줄들을 한 줄로 연결",
        "      Ctrl-v 후 I/A    여러 줄 앞/뒤를 동시에 편집",
        "      :                 선택 영역에 Ex 명령 실행",
        "      ~ / U / u         대소문자 반전/대문자/소문자 변환",
        "      gv                마지막 선택 영역 다시 선택",
        "      Esc               선택을 취소하고 normal mode로 복귀",
        "",
        "    Recording mode / 매크로",
        "",
        "      q+문자            해당 레지스터에 키 입력 기록 시작(예: qa)",
        "      q                 매크로 기록 종료",
        "      @+문자            해당 레지스터의 매크로 실행(예: @a)",
        "      @@                마지막으로 실행한 매크로 다시 실행",
        "      숫자+@+문자       매크로를 지정 횟수만큼 실행(예: 10@a)",
        "      :reg 문자         저장된 매크로 내용 확인(예: :reg a)",
        "      recording @문자   상태 표시 중에는 q를 눌러 기록 종료",
        "",
        "  에이전트 / Agentic",
        "",
        "    Space aa           우측 Agentic 사이드바 열기/닫기",
        "    Space ac           현재 파일 또는 visual 선택 영역을 컨텍스트에 추가",
        "    Space an           새 Agentic 대화 시작",
        "    Space ar           Telescope에서 현재 프로젝트의 이전 대화 복원",
        "    Space al           사이드바 위치를 오른쪽/아래로 전환",
        "    Space as           ACP provider 전환",
        "    Space ad / aD      현재 줄/현재 버퍼의 진단을 컨텍스트에 추가",
        "    Space q            Agentic 창 숨기기(세션 유지)",
        "    Space Q            현재 Agentic 세션 종료",
        "    Prompt Space Space normal mode에서 insert mode로 진입",
        "    Prompt Enter       normal/insert mode에서 프롬프트 전송",
        "    Prompt Alt-Enter   insert mode에서 줄바꿈",
        "    Prompt Ctrl-s      normal/insert/visual mode에서 프롬프트 전송",
        "    Prompt @파일명     프로젝트 파일을 찾아 컨텍스트로 참조",
        "    Prompt /           provider slash command 목록 열기",
        "    Shift-Tab          agent mode 전환(지원 provider에서만 동작)",
        "    \\m                 모델 전환",
        "    \\t                 reasoning effort 전환",
        "    \\s                 provider 전환",
        "    \\o                 Agentic 옵션 열기",
        "    q                  Agentic 사이드바 닫기",
        "    ]t / [t            다음/이전 tool call로 이동",
        "    ]c / [c            diff preview의 다음/이전 hunk로 이동",
        "    권한 요청          표시된 1~4 번호로 허용/거절 선택",
        "    Codex ACP          npm install -g @agentclientprotocol/codex-acp",
        "    Claude ACP         npm install -g @agentclientprotocol/claude-agent-acp",
        "    Pi CLI             npm install -g @earendil-works/pi-coding-agent",
        "    Pi ACP             npm install -g pi-acp",
        "    provider 사용      CLI/ACP 설치 후 Neovim 재시작, Space as로 선택",
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
        "  디버깅 / DAP",
        "",
        "    F5                 디버깅 시작/계속 실행",
        "    F6                 step over",
        "    F7                 step into",
        "    F8                 step out",
        "    F9                 현재 줄 breakpoint 켜기/끄기",
        "    Space db           현재 줄 breakpoint 켜기/끄기",
        "    Space do           step over",
        "    Space di           step into",
        "    Space dO           step out",
        "    Space dB           조건부 breakpoint 추가",
        "    Space dL           logpoint 추가",
        "    Space dp           현재 파일 타입의 DAP runtime 경로 확인",
        "    Space du           디버깅 UI 열기/닫기",
        "    Space dr           디버깅 REPL 열기",
        "    Space dK           커서 위치/선택 영역 값 평가",
        "    Space dq           디버깅 세션 종료",
        "    :DapContinue       디버깅 시작/계속 실행",
        "    :DapTBreakpoint    현재 줄 breakpoint 켜기/끄기",
        "    :DAPSettings       Debugger 설정 메뉴",
        "    :DAPMyList         DAP adapter 목록",
        "    :DAPMyInstall      DAP adapter 설치",
        "    :DAPMyUninstall    DAP adapter 제거",
        "    :DAPPath           현재 파일 타입의 DAP runtime 경로 확인",
        "    :DAPPythonPath     Python 디버깅 interpreter 확인",
        "    :Mason             debug adapter 설치 화면",
        "    Args prompt        Settings > Debugger 에서 켜기/끄기",
        "    Python args        F5 후 Args 입력창에 실행 인자 입력",
        "    Python venv        VIRTUAL_ENV, CONDA_PREFIX, .venv/venv/env, pyvenv.cfg 순서로 탐색",
        "    C/C++/Rust args    F5 후 Executable, Args 입력창에 입력",
        "    C debug build      cc -g -gdwarf-4 -O0 file.c -o a.out",
        "    Adapter 예시       codelldb(C/C++/Rust), debugpy(Python), delve(Go)",
        "    동작 조건          언어별 debug adapter 설치 및 프로젝트 실행 설정 필요",
        "",
        "  자동완성 / 스니펫",
        "",
        "    Ctrl-Space         자동완성 후보 열기",
        "    Ctrl-n / Ctrl-p    자동완성 후보 이동",
        "    Enter              선택한 자동완성 후보 확정",
        "    Ctrl-e             자동완성 후보 닫기",
        "    Tab / Shift-Tab    스니펫 위치 이동",
        "    Space ct           자동완성 켜기/끄기",
        "    Space st           스니펫 자동완성 후보 켜기/끄기",
        "    Space sr           custom snippets까지 다시 불러오기",
        "    :SnippetSettings   스니펫 설정 메뉴",
        "    Custom snippets    stdpath(config)/snippets 에 작성",
        "    Snippet format     VSCode JSON snippets 형식",
        "",
        "  검색 / 탐색",
        "",
        "    Space ff           파일명 검색",
        "    Space fg           프로젝트 전체 문자열 검색",
        "    Space fb           열린 버퍼 검색",
        "    Space fh           도움말 검색",
        "    Space sw           커서 위치 단어로 문자열 검색",
        "    Space ss           선택한 문자열로 검색",
        "",
        "  Git",
        "",
        "    Space gg           LazyGit 열기",
        "    Space gG           현재 파일 기준 LazyGit 열기",
        "    Space gf           현재 파일 git history 열기",
        "    Space gc           LazyGit config 열기",
        "    Space gp           현재 hunk 미리보기",
        "    Space gb           현재 줄 blame",
        "    Space gr           현재 hunk 되돌리기",
        "    ]c / [c            다음/이전 git hunk",
        "    LazyGit q          종료",
        "    LazyGit Esc        내부 취소/뒤로가기",
        "",
        "  파일 트리",
        "",
        "    Space e            파일 트리 열기/닫기",
        "    Enter / o          파일은 A 윈도우에 열기, 폴더는 열기/닫기",
        "    Double click       파일은 A 윈도우에 열기",
        "    w                  윈도우 피커로 파일 열기",
        "    O                  윈도우 피커 없이 파일 열기",
        "    s / v              선택 윈도우에 가로/세로 분할 후 파일 열기",
        "    Tab                파일 미리보기 열기/닫기",
        "    Esc                미리보기 닫기, 없으면 workspace root로 복귀",
        "    Ctrl-l / Right     미리보기 창으로 이동",
        "    Ctrl-h / Left      미리보기에서 파일 트리로 이동",
        "    a / r              파일 생성/이름 변경",
        "    d / D              휴지통으로 이동/영구 삭제",
        "    x / c / p          잘라내기/복사/붙여넣기",
        "    y / Y / gy         파일명/상대 경로/절대 경로 복사",
        "    m / bt / bd        북마크 토글/북마크를 휴지통으로/영구 삭제",
        "    - / P              트리 root를 부모로/커서를 부모 폴더로 이동",
        "    K / J              현재 폴더의 첫/마지막 항목으로 이동",
        "    < / >              이전/다음 형제 항목으로 이동",
        "    E / W              전체 폴더 펼치기/접기",
        "    L                  빈 폴더 그룹 표시 토글",
        "    R                  새로고침",
        "    H / I              숨김 파일/gitignore 파일 표시 토글",
        "    B / C              열린 버퍼 없음/git 변경 없음 필터 토글",
        "    M / U              북마크 없음/사용자 정의 필터 토글",
        "    f / F              필터 검색 시작/해제",
        "    [c / ]c            이전/다음 git 변경 항목",
        "    [e / ]e            이전/다음 진단 항목",
        "    S                  파일 검색 후 트리에서 이동",
        "    g?                 전체 파일 트리 단축키 도움말",
        "",
        "  버퍼",
        "",
        "    Space bb           버퍼 선택",
        "    Enter              버퍼 열기/포커스",
        "    w                  선택 윈도우에 버퍼 표시",
        "    m                  선택 윈도우로 버퍼 이동/교체",
        "    s / v              가로/세로 분할에 버퍼 열기",
        "    d / D              버퍼 삭제/강제 삭제",
        "    o / O              선택 항목만 남기기/강제 적용",
        "    Space bn / bp      다음/이전 버퍼",
        "    Space bm           현재 버퍼를 선택 윈도우로 이동/교체",
        "    Space bw           현재 버퍼를 선택 윈도우에 표시",
        "    Space bd / bD      현재 버퍼 닫기/강제 닫기",
        "    Space bo / bO      다른 버퍼 닫기/강제 닫기",
        "    실패 시            목록을 유지하고 오류 메시지 표시",
        "",
        "  창",
        "",
        "    Space ww           창 선택",
        "    Space wr           현재 창 라벨을 선택 창과 교환",
        "    Space wv           세로 분할",
        "    Space ws           가로 분할",
        "    Space wo           현재 창만 남기기",
        "    Space wq           현재 창 닫기",
        "    Ctrl-h/j/k/l       왼쪽/아래/위/오른쪽 창 이동",
        "    Ctrl-Arrow         방향키로 창 이동",
        "    Insert Ctrl-Arrow  normal mode로 전환 후 방향키로 창 이동",
        "    Alt-h/l            창 너비 1칸 줄이기/늘리기",
        "    Alt-k/j            창 높이 1칸 늘리기/줄이기",
        "    Alt-Arrow          방향키로 창 크기 1칸 조절",
        "    창 라벨            파일 트리 제외, 생성 순서대로 A/B/C",
        "",
        "  탭",
        "",
        "    Space Tab Tab      탭 목록 플로팅창 열기",
        "    Space Tab n        새 탭",
        "    Space Tab q        현재 탭 닫기",
        "    Space Tab h/l      이전/다음 탭",
        "    Space Tab ←/→      이전/다음 탭",
        "    탭 목록            현재 탭 위치에 커서, Enter 이동, Esc 닫기",
        "    상단 탭 표시       탭이 2개 이상일 때 󰓩 00 버퍼명 형식으로 표시",
        "    탭 색상            현재 컬러스키마 highlight 기준으로 자동 적용",
        "",
        "  터미널 / 플로팅",
        "",
        "    Space tt           현재 창에 버퍼 터미널 생성",
        "    Space ts           현재 창에서 가로 분할 후 버퍼 터미널 생성",
        "    Space tv           현재 창에서 세로 분할 후 버퍼 터미널 생성",
        "    Space tc           현재 터미널을 새 버퍼로 초기화",
        "	 Space Space		터미널 버퍼에서 입력모드 진입",
        "    Space 0~9          번호 플로팅 파일 슬롯 열기/숨기기",
        "    Space q / Q        플로팅 슬롯 버퍼 닫기/강제 닫기",
        "    Esc                터미널 모드에서 노멀 모드로 전환",
        "    Space bb           터미널 버퍼 선택/이동/삭제",
        "    :TKill             현재 터미널 종료",
        "    플로팅 슬롯        [F1] 형식, 검색/grep 결과를 해당 슬롯에 열기",
        "    Space 백틱 / ~     백틱 플로팅 파일 슬롯 열기/숨기기",
        "    전환 규칙          플로팅 슬롯은 하나만 표시, 새 슬롯을 열면 기존 슬롯 숨김",
        "    슬롯 터미널        슬롯에서 Space tt로 생성, Space bb로 선택/이동/삭제",
        "",
        "  세션",
        "",
        "    Space pp           세션 목록 열기",
        "    Space p0~p9        0~9번 세션 불러오기",
        "    Space P0~P9        현재 세션을 0~9번에 저장",
        "    Enter              세션 목록에서 선택 세션 불러오기",
        "    w                  현재 세션을 선택 슬롯에 저장",
        "    m                  이동 대상 선택 시작, Enter/m/번호로 확정, 대상이 있으면 서로 교체",
        "    n                  선택 세션 이름 지정/수정, 변경 시 Enter/y 확인",
        "    e                  선택 세션 노트 편집기 열기",
        "    d                  선택 세션 삭제, Enter/y 확인 필요",
        "    Tab                자동 미리보기가 없을 때 임시 미리보기 열기/닫기",
        "    Ctrl-u/d           normal mode에서 세션 미리보기 위/아래 스크롤",
        "    PageUp/PageDown    normal mode에서 세션 미리보기 위/아래 크게 스크롤",
        "    Esc                임시 미리보기가 열려 있으면 닫기, 아니면 세션 목록 닫기",
        "    insert Esc         세션/Telescope 목록에서 normal mode로 전환",
        "    :SessionSave 3     현재 세션을 3번 슬롯에 저장",
        "    :SessionLoad 3     3번 세션 불러오기",
        "    :SessionMove 1 4   1번을 4번으로 이동, 4번이 있으면 서로 교체",
        "    :SessionName 3     3번 세션 이름 지정/수정",
        "    :SessionNote 3     3번 세션 메모 작성/수정",
        "    :SessionDelete 3   3번 세션 삭제, Enter/y 확인 필요",
        "    슬롯 설정          lua/config/sessions.lua 상단 session_slot_ids 수정",
        "    ! 표시             현재 키맵에는 없지만 저장 파일이 남아 있는 세션",
        "    저장 확인          빈 슬롯은 바로 저장, 기존 슬롯은 Enter/y 확인 후 덮어쓰기",
        "    노트 편집          줄바꿈/탭 입력 가능, Ctrl-s 또는 normal Enter로 저장 확인",
        "    노트 Esc           변경 없음은 바로 닫기, 변경 있음은 폐기 y 확인",
        "    이름 입력          값이 같으면 종료, 변경 시 y 확인, Esc로 취소",
        "    저장 위치          stdpath(state)/sessions/slot-N.json",
        "",
        "  대시보드 / About",
        "",
        "    Dashboard e        새 파일",
        "    Dashboard f        파일명 검색",
        "    Dashboard g        프로젝트 전체 문자열 검색",
        "    Dashboard w        작업 폴더 변경",
        "    Dashboard t        파일 트리 열기/닫기",
        "    Dashboard s        설정 메뉴 열기",
        "    Dashboard a        About Neovim 열기",
        "    Dashboard q        안전 종료 확인",
        "    Dashboard Q        blocker가 있을 때 강제 종료 확인",
        "    Dashboard Enter    blocker가 없을 때 Neovim 종료",
        "    Dashboard Esc      종료 확인 취소",
        "    Space Esc          어디서든 Neovim 안전 종료 확인",
        "    Space q            직전 버퍼/터미널 복귀, 없으면 창 닫기 또는 종료",
        "    About h / b / Esc  이전 버퍼로 돌아가기",
        "    About Space ?      이전 버퍼로 돌아가기",
        "    About q / Q        About 닫기/강제 닫기",
        "    Space+버튼 키      전역 단축키가 없으면 대시보드 버튼 실행 방지",
        "",
        "  Tree-sitter",
        "",
        "    za                 현재 위치 접기 열기/닫기",
        "    zc / zo            현재 위치 접기 닫기/열기",
        "    zM / zR            전체 접기 닫기/열기",
        "    zm / zr            접기 레벨 줄이기/늘리기",
        "    :TSSettings        Tree-sitter 설정 메뉴",
        "    :TSMyList          설치된 parser 목록",
        "    :TSMyInstall rust  rust parser 설치 예시",
        "    :TSMyUninstall rust",
        "    :TSMyUpdate",
        "    기본 상태          파일을 열 때 자동으로 접지 않고 펼친 상태 유지",
        "    동작 조건          해당 언어 Tree-sitter parser 설치 필요",
        "",
        "  Markdown",
        "",
        "    Space mr           현재 버퍼 Markdown 렌더링/원문 전환",
        "    Space mp           브라우저 Markdown 미리보기 열기/닫기",
        "    기본 상태          Markdown 파일과 Agentic 채팅은 렌더링 모드",
        "    동작 조건          mr은 Markdown/Agentic 채팅, mp는 Markdown 파일",
        "",
        "  Minimap",
        "",
        "    Space mm           코드 미니맵 열기/닫기",
        "    Space mf           코드 미니맵 포커스/해제",
        "    Space ms           코드 스크롤바 열기/닫기",
        "    표시 방식          필요할 때 직접 토글, 자동 시작 안 함",
        "",
        "  설정 / 관리",
        "",
        "    :help              Neovim 도움말 열기",
        "    :Tutor             Vim 기본 튜토리얼",
        "    :checkhealth       현재 환경 상태 검사",
        "    :version           Neovim 버전 정보",
        "    :messages          최근 메시지 확인",
        "    :Lazy              플러그인 관리 화면",
        "    :Lazy install      새 플러그인 설치",
        "    :Lazy sync         플러그인 설치/업데이트",
        "    :SettingsSidebar   파일 트리/Agentic 위치와 크기 설정",
        "    사이드바 저장      stdpath(state)/sidebar-settings.json",
        "    :ThemePick         테마 선택 메뉴",
        "    줄번호 설정 위치   lua/config/options.lua",
        "    일반 줄번호        vim.opt.number = true",
        "    상대 줄번호        vim.opt.relativenumber = true 로 변경",
        "    표시 방식          현재 줄은 실제 번호, 위/아래 줄은 현재 줄과의 거리",
        "",
        "  테마",
        "",
        "    기본 내장 테마     Neovim 내장 colorscheme 전체",
        "    고정 설치 테마     + vscode, + onedark, + tokyonight",
        "    테마 추가 위치     lua/plugins/themes.lua",
        "    추가 방법          플러그인 spec 추가 후 colorschemes 에 테마명 등록",
        "    예시               { \"catppuccin/nvim\", colorschemes = { \"catppuccin\" } }",
        "",
        "  주석 및 42header",
        "",
        "    gcc                현재 줄 주석 토글",
        "    gc                 visual 선택 영역 줄 주석 토글",
        "    gc{motion}         motion 범위 줄 주석 토글, 예: gcip",
        "    gbc                현재 줄 블록 주석 토글",
        "    gb                 visual 선택 영역 블록 주석 토글",
        "    gb{motion}         motion 범위 블록 주석 토글",
        "    gco / gcO          아래/위 줄에 주석 추가 후 입력 모드",
        "    gcA                현재 줄 끝에 주석 추가 후 입력 모드",
        "    Insert Ctrl-l      다음 괄호/따옴표 밖으로 이동",
        "    :Stdheader         현재 파일에 42 헤더 추가/갱신",
        "    Insert F1          42 헤더 추가/갱신",
        "",
        "  42 Header 설정",
        "",
        "    NAME               42 intra id 환경변수",
        "    MAIL               42 email 환경변수",
        "    ~/.zshrc           아래 두 줄 추가",
        "    export NAME=\"your_intra_id\"",
        "    export MAIL=\"your_email@student.42seoul.kr\"",
        "    적용               source ~/.zshrc 후 Neovim 재시작",
        "",
        "  종료",
        "",
        "    Space wq           현재 창 닫기",
        "    Space Ctrl-q       현재 창 닫기",
        "    Space q / Q        현재 버퍼 닫기/강제 닫기, hidden 버퍼 우선 복귀",
        "    Dashboard q        안전 종료, blocker가 있으면 Q로 강제 종료",
        "    :q                 현재 창 닫기",
        "    :qa                Neovim 종료",
        "    :qa!               강제 종료",
        "",
    }

    local section_targets
    local toc_targets

    lines, section_targets, toc_targets = organize_sections(lines)

    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.bo.modifiable = false
    vim.bo.filetype = "help"

    vim.api.nvim_win_set_cursor(0, { 5, 2 })

    local function jump_to_section(index)
        local target = section_targets[index]

        if target then
            vim.api.nvim_win_set_cursor(0, { target, 2 })
            vim.cmd("normal! zz")
        end
    end

    vim.keymap.set("n", "<CR>", function()
        local row = vim.api.nvim_win_get_cursor(0)[1]

        if row == 5 then
            back_to_previous_buffer()
            return
        end

        local index = toc_targets[row]

        if index then
            jump_to_section(index)
        end
    end, {
        buffer = true,
        silent = true,
        desc = "Open selected About section",
    })

    for index = 0, #section_targets do
        local shortcut = string.format("%02d", index)
        local target_index = index

        vim.keymap.set("n", shortcut, function()
            jump_to_section(target_index)
        end, {
            buffer = true,
            silent = true,
            desc = "Open About section " .. shortcut,
        })
    end

    vim.keymap.set("n", "h", back_to_previous_buffer, {
        buffer = true,
        silent = true,
        desc = "Back to previous buffer",
    })

    vim.keymap.set("n", "b", back_to_previous_buffer, {
        buffer = true,
        silent = true,
        desc = "Back to previous buffer",
    })

    vim.keymap.set("n", "<Esc>", back_to_previous_buffer, {
        buffer = true,
        silent = true,
        desc = "Back to previous buffer",
    })

    vim.keymap.set("n", "<leader>h", back_to_previous_buffer, {
        buffer = true,
        silent = true,
        desc = "Back to previous buffer",
    })

    vim.keymap.set("n", "<leader>?", back_to_previous_buffer, {
        buffer = true,
        silent = true,
        desc = "Toggle About Neovim",
    })

    vim.keymap.set("n", "q", function()
        if vim.b.config_about_floating then
            close_floating_about()
        else
            vim.cmd("bd")
        end
    end, {
        buffer = true,
        silent = true,
        desc = "Close About Neovim",
    })

    vim.keymap.set("n", "Q", function()
        if vim.b.config_about_floating then
            close_floating_about()
        else
            vim.cmd("bd!")
        end
    end, {
        buffer = true,
        silent = true,
        desc = "Force close About Neovim",
    })
end

close_floating_about = function()
    save_floating_about_view()

    local win = floating_about.win
    local buf = floating_about.buf
    local previous_win = floating_about.previous_win
    local previous_slot_id = floating_about.previous_slot_id
    local previous_mode = floating_about.previous_mode

    floating_about.win = nil
    floating_about.buf = nil
    floating_about.previous_win = nil
    floating_about.previous_slot_id = nil
    floating_about.previous_mode = nil

    if win and vim.api.nvim_win_is_valid(win) then
        pcall(vim.api.nvim_win_close, win, true)
    end

    if buf and vim.api.nvim_buf_is_valid(buf) then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end

    if previous_slot_id ~= nil then
        require("config.floating").open_slot(previous_slot_id)
    elseif previous_win and vim.api.nvim_win_is_valid(previous_win) then
        pcall(vim.api.nvim_set_current_win, previous_win)
    end

    if previous_mode and previous_mode:sub(1, 1) == "i" then
        vim.schedule(function()
            pcall(vim.cmd, "startinsert")
        end)
    end
end

function M.toggle_floating()
    if floating_about.win and vim.api.nvim_win_is_valid(floating_about.win) then
        close_floating_about()
        return
    end

    local floating = require("config.floating")
    local floating_window = require("config.floating.window")
    local previous_win = vim.api.nvim_get_current_win()
    local previous_buf = vim.api.nvim_get_current_buf()
    local previous_slot_id = floating.window_slot_id(previous_win)
    local previous_mode = vim.fn.mode()

    if previous_mode:sub(1, 1) == "i" then
        vim.cmd("stopinsert")
    end

    if previous_slot_id ~= nil then
        floating.toggle(previous_slot_id)
    end

    local buf = vim.api.nvim_create_buf(false, true)
    local win = floating_window.open_transient(buf, "About Neovim")

    floating_about.win = win
    floating_about.buf = buf
    floating_about.previous_win = previous_win
    floating_about.previous_slot_id = previous_slot_id
    floating_about.previous_mode = previous_mode

    M.open({
        buf = buf,
        previous_buf = previous_buf,
        floating = true,
    })

    if floating_about.saved_view then
        pcall(vim.api.nvim_win_call, win, function()
            vim.fn.winrestview(floating_about.saved_view)
        end)
    end

    vim.api.nvim_create_autocmd("WinLeave", {
        buffer = buf,
        callback = save_floating_about_view,
        desc = "Remember the in-session About Neovim view",
    })

    vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(win),
        once = true,
        callback = function()
            if floating_about.win == win then
                vim.schedule(close_floating_about)
            end
        end,
        desc = "Restore the window hidden by floating About Neovim",
    })
end

function M.toggle()
    if vim.b.config_about_neovim then
        back_to_previous_buffer()
        return
    end

    M.open()
end

return M
