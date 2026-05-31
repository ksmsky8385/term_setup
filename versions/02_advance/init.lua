-- =========================================================
-- 기본 설정
-- =========================================================

-- 루트 경로 저장
vim.g.current_workspace_root = vim.fn.getcwd()

-- <leader> 키를 Space로 설정
vim.g.mapleader = " "

-- 왼쪽에 실제 줄 번호 표시
vim.opt.number = true

-- 상대 줄 번호
-- true면 현재 커서 기준으로 위아래 줄이 1, 2, 3처럼 표시됨
vim.opt.relativenumber = false

-- 탭 기본값: 탭은 실제 탭 문자로 입력
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = false

-- 탭 입력 시 스페이스 4개 치환
vim.api.nvim_create_autocmd("FileType", {
    pattern = {
		"python",
		"java",
		"lua",
    },
    callback = function()
        vim.opt_local.tabstop = 4
        vim.opt_local.shiftwidth = 4
        vim.opt_local.softtabstop = 4
        vim.opt_local.expandtab = true
    end,
})

-- 탭 문자, 화면상 2칸
vim.api.nvim_create_autocmd("FileType", {
    pattern = {
        "sh",
        "html",
        "css",
        "javascript",
        "typescript",
        "tsx",
    },
    callback = function()
        vim.opt_local.tabstop = 2
        vim.opt_local.shiftwidth = 2
        vim.opt_local.softtabstop = 2
        vim.opt_local.expandtab = false
    end,
})

-- 24bit 컬러 사용
vim.opt.termguicolors = true

-- 시스템 클립보드와 Neovim 클립보드 연동
vim.opt.clipboard = "unnamedplus"


-- =========================================================
-- 키 매핑
-- =========================================================

-- 터미널 모드에서 Esc로 Normal 모드 복귀
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", {
    noremap = true,
    silent = true,
})

-- Space + h 로 Alpha 대시보드로 돌아가기
vim.keymap.set("n", "<leader>h", function()
    pcall(vim.cmd, "DashboardHome")
end, {
    noremap = true,
    silent = true,
    desc = "Open dashboard in current window",
})

-- split 생성
vim.keymap.set("n", "<leader>sv", ":vsplit<CR>", {
    noremap = true,
    silent = true,
    desc = "Vertical split",
})

vim.keymap.set("n", "<leader>sh", ":split<CR>", {
    noremap = true,
    silent = true,
    desc = "Horizontal split",
})

-- split 닫기
vim.keymap.set("n", "<leader>sq", ":close<CR>", {
    noremap = true,
    silent = true,
    desc = "Close split",
})

-- Ctrl + h/j/k/l 로 split 창 이동
vim.keymap.set("n", "<C-h>", "<C-w>h", { noremap = true, silent = true })
vim.keymap.set("n", "<C-j>", "<C-w>j", { noremap = true, silent = true })
vim.keymap.set("n", "<C-k>", "<C-w>k", { noremap = true, silent = true })
vim.keymap.set("n", "<C-l>", "<C-w>l", { noremap = true, silent = true })

-- Ctrl + 방향키로 split 창 이동
vim.keymap.set("n", "<C-Left>", "<C-w>h", { noremap = true, silent = true })
vim.keymap.set("n", "<C-Down>", "<C-w>j", { noremap = true, silent = true })
vim.keymap.set("n", "<C-Up>", "<C-w>k", { noremap = true, silent = true })
vim.keymap.set("n", "<C-Right>", "<C-w>l", { noremap = true, silent = true })

-- 창 크기 조절
vim.keymap.set("n", "<A-Left>",  ":vertical resize -2<CR>", { silent = true })
vim.keymap.set("n", "<A-Right>", ":vertical resize +2<CR>", { silent = true })
vim.keymap.set("n", "<A-Up>",    ":resize +2<CR>", { silent = true })
vim.keymap.set("n", "<A-Down>",  ":resize -2<CR>", { silent = true })


-- =========================================================
-- Tree-sitter 언어 목록
-- 필요한 언어는 여기에 추가/삭제
-- =========================================================

local MY_TS_LANGS = {
    "python",
    "lua",
    "vim",
    "vimdoc",
    "bash",
    "c",
    "cpp",
    "make",
    "cmake",
    "json",
    "yaml",
    "toml",
    "markdown",
    "markdown_inline",
    "html",
    "css",
    "javascript",
    "typescript",
    "tsx",
}


-- =========================================================
-- 선택 가능한 테마 목록
-- =========================================================

local MY_THEMES = {
    "vscode",
    "onedark",
    "tokyonight",
    "habamax",
    "slate",
    "desert",
    "industry",
}


-- =========================================================
-- ~/.local/bin PATH 추가
-- =========================================================

local local_bin = vim.fn.expand("~/.local/bin")
vim.fn.mkdir(local_bin, "p")

if not string.find(vim.env.PATH, local_bin, 1, true) then
    vim.env.PATH = local_bin .. ":" .. vim.env.PATH
end


-- =========================================================
-- ripgrep(rg) 자동 설치
-- Telescope live_grep 검색용
-- =========================================================

local function ensure_rg()
    local rg_path = local_bin .. "/rg"

    if vim.fn.executable(rg_path) == 1 then
        return
    end

    vim.notify("rg가 없어서 ~/.local/bin에 자동 설치합니다.")

    local version = "14.1.1"
    local filename = "ripgrep-" .. version .. "-x86_64-unknown-linux-musl"
    local tar_path = "/tmp/" .. filename .. ".tar.gz"
    local extract_dir = "/tmp/" .. filename

    local url = "https://github.com/BurntSushi/ripgrep/releases/download/"
        .. version
        .. "/"
        .. filename
        .. ".tar.gz"

    local curl_result = vim.fn.system({
        "curl",
        "-L",
        url,
        "-o",
        tar_path,
    })

    if vim.v.shell_error ~= 0 then
        vim.notify("rg 다운로드 실패: " .. curl_result, vim.log.levels.ERROR)
        return
    end

    local tar_result = vim.fn.system({
        "tar",
        "-xzf",
        tar_path,
        "-C",
        "/tmp",
    })

    if vim.v.shell_error ~= 0 then
        vim.notify("rg 압축 해제 실패: " .. tar_result, vim.log.levels.ERROR)
        return
    end

    local cp_result = vim.fn.system({
        "cp",
        extract_dir .. "/rg",
        rg_path,
    })

    if vim.v.shell_error ~= 0 then
        vim.notify("rg 복사 실패: " .. cp_result, vim.log.levels.ERROR)
        return
    end

    vim.fn.system({
        "chmod",
        "+x",
        rg_path,
    })

    vim.notify("rg 설치 완료: " .. rg_path)
end

ensure_rg()


-- =========================================================
-- 사용자 명령어
-- =========================================================

vim.api.nvim_create_user_command("ThemePick", function()
    vim.ui.select(MY_THEMES, {
        prompt = "변경할 테마를 선택하세요:",
    }, function(choice)
        if choice then
            vim.cmd.colorscheme(choice)
            vim.notify("테마 변경: " .. choice)
        end
    end)
end, {})

vim.api.nvim_create_user_command("TSSettings", function()
    local menu = {
        "1. Tree-sitter parser list",
        "2. Tree-sitter parser install",
        "3. Tree-sitter parser remove",
        "4. Tree-sitter parser update",
    }

    vim.ui.select(menu, {
        prompt = "Tree-sitter settings:",
    }, function(choice)
        if choice == nil then
            return
        end

        if choice:match("^1") then
            vim.cmd("TSMyList")
        elseif choice:match("^2") then
            vim.ui.input({
                prompt = "Install parser name: ",
            }, function(lang)
                if lang and lang ~= "" then
                    vim.cmd("TSMyInstall " .. lang)
                end
            end)
        elseif choice:match("^3") then
            vim.ui.input({
                prompt = "Remove parser name: ",
            }, function(lang)
                if lang and lang ~= "" then
                    vim.cmd("TSMyUninstall " .. lang)
                end
            end)
        elseif choice:match("^4") then
            vim.cmd("TSMyUpdate")
        end
    end)
end, {})

vim.api.nvim_create_user_command("MainSettings", function()
    local menu = {
        "1. Change theme",
        "2. Tree-sitter settings",
        "3. Update plugins",
    }

    vim.ui.select(menu, {
        prompt = "Settings:",
    }, function(choice)
        if choice == nil then
            return
        end

        if choice:match("^1") then
            vim.cmd("ThemePick")
        elseif choice:match("^2") then
            vim.cmd("TSSettings")
        elseif choice:match("^3") then
            vim.cmd("Lazy sync")
        end
    end)
end, {})

vim.api.nvim_create_user_command("AboutNeovim", function()
    vim.cmd("enew")
    vim.bo.buftype = "nofile"
    vim.bo.bufhidden = "wipe"
    vim.bo.swapfile = false
    vim.bo.modifiable = true

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

    vim.keymap.set("n", "q", ":bd<CR>", {
        buffer = true,
        silent = true,
        desc = "Close About Neovim",
    })
end, {})

vim.api.nvim_create_user_command("WorkspacePick", function()
    vim.ui.input({
        prompt = "Workspace path: ",
        default = vim.g.current_workspace_root or vim.fn.getcwd(),
        completion = "dir",
    }, function(path)
        if path == nil or path == "" then
            return
        end

        path = vim.fn.expand(path)

        if vim.fn.isdirectory(path) == 0 then
            vim.notify("Drectory not found: " .. path, vim.log.levels.ERROR)
            return
        end

        vim.cmd("cd " .. vim.fn.fnameescape(path))
        vim.g.current_workspace_root = vim.fn.getcwd()

        vim.notify(" -> Workspace changed: " .. vim.g.current_workspace_root)
    end)
end, {})

vim.api.nvim_create_user_command("TreeToggle", function()
    local ok, api = pcall(require, "nvim-tree.api")

    if not ok then
        vim.notify("Can't call nvim-tree api", vim.log.levels.ERROR)
        return
    end

    api.tree.toggle({
        focus = true,
    })
end, {})


-- =========================================================
-- lazy.nvim 자동 설치
-- =========================================================

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "--branch=stable",
        "https://github.com/folke/lazy.nvim.git",
        lazypath,
    })
end

vim.opt.rtp:prepend(lazypath)


-- =========================================================
-- 플러그인 설정
-- =========================================================

require("lazy").setup({
    {
        "Mofiqul/vscode.nvim",
        lazy = false,
        priority = 1000,
        config = function()
            require("vscode").setup({
                style = "dark",
                transparent = false,
            })

            vim.cmd.colorscheme("vscode")
        end,
    },

    {
        "navarasu/onedark.nvim",
        lazy = true,
    },

    {
        "folke/tokyonight.nvim",
        lazy = true,
    },

    {
        "nvim-treesitter/nvim-treesitter",
        branch = "master",
        lazy = false,
        build = ":TSUpdate",

        config = function()
            require("nvim-treesitter.configs").setup({
                ensure_installed = MY_TS_LANGS,
                sync_install = false,
                auto_install = true,

                highlight = {
                    enable = true,
                    additional_vim_regex_highlighting = false,
                },

                indent = {
                    enable = true,
                },
            })

            vim.api.nvim_create_user_command("TSMyUpdate", function()
                vim.cmd("TSUpdate")
            end, {})

            vim.api.nvim_create_user_command("TSMyInstall", function(opts)
                vim.cmd("TSInstall " .. opts.args)
            end, {
                nargs = 1,
            })

            vim.api.nvim_create_user_command("TSMyUninstall", function(opts)
                vim.cmd("TSUninstall " .. opts.args)
            end, {
                nargs = 1,
            })

            vim.api.nvim_create_user_command("TSMyList", function()
                vim.cmd("TSInstallInfo")
            end, {})
        end,
    },

    {
        "nvim-tree/nvim-tree.lua",
        dependencies = {
            "nvim-tree/nvim-web-devicons",
        },

        config = function()
			require("nvim-tree").setup({
			    sync_root_with_cwd = true,
   				respect_buf_cwd = true,
   				
				view = {
					width = 30,
				},

				renderer = {
					group_empty = true,
				},

				filters = {
					dotfiles = false,
				},

				actions = {
					open_file = {
						window_picker = {
						    enable = true,

						    exclude = {
						        filetype = {
						            "NvimTree",
						            "notify",
						        },
						        buftype = {
						            "terminal",
						        },
						    },
						},
					},
				},
			})

            vim.keymap.set(
                "n",
                "<leader>e",
                ":TreeToggle<CR>",
                {
                    noremap = true,
                    silent = true,
                    desc = "Toggle file tree",
                }
            )
        end,
    },

    {
        "nvim-telescope/telescope.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
        },

        config = function()
            local telescope = require("telescope")
            local builtin = require("telescope.builtin")

            telescope.setup({})

            vim.keymap.set("n", "<leader>ff", builtin.find_files, {
                desc = "Find files",
            })

            vim.keymap.set("n", "<leader>fg", builtin.live_grep, {
                desc = "Live grep",
            })

            vim.keymap.set("n", "<leader>fb", builtin.buffers, {
                desc = "Find buffers",
            })

            vim.keymap.set("n", "<leader>fh", builtin.help_tags, {
                desc = "Help tags",
            })
        end,
    },

	{
		"goolord/alpha-nvim",
		lazy = false,
		dependencies = {
		    "nvim-tree/nvim-web-devicons",
		},

		config = function()
		    local alpha = require("alpha")
		    local dashboard = require("alpha.themes.dashboard")

		    local version = vim.version()
		    local version_text = string.format(
		        "ver. %d.%d.%d",
		        version.major,
		        version.minor,
		        version.patch
		    )

		    local function make_header()
		        local cwd = vim.g.current_workspace_root or vim.fn.getcwd()

		        return {
		            "",
		            "███╗   ██╗██╗   ██╗██╗███╗   ███╗",
		            "████╗  ██║██║   ██║██║████╗ ████║",
		            "██╔██╗ ██║██║   ██║██║██╔████╔██║",
		            "██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║",
		            "██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║ " .. version_text,
		            "╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝",
		            "",
		            "root: " .. cwd,
		            "",
		        }
		    end

		    dashboard.section.header.val = make_header()

		    dashboard.section.buttons.val = {
		        dashboard.button("e", "   New file", ":ene <BAR> startinsert<CR>"),
		        dashboard.button("f", "   Find file", ":Telescope find_files<CR>"),
		        dashboard.button("g", "󰊄   Search text", ":Telescope live_grep<CR>"),
		        dashboard.button("w", "   Change workspace", ":WorkspacePick<CR>"),
		        dashboard.button("t", "   Toggle tree", ":TreeToggle<CR>"),
				dashboard.button("s", "   Settings", ":MainSettings<CR>"),
		        dashboard.button("a", "   About Neovim", ":AboutNeovim<CR>"),
		    }

		    dashboard.section.footer.val = {}

		    alpha.setup(dashboard.opts)

		    vim.api.nvim_create_user_command("DashboardHome", function()
		        dashboard.section.header.val = make_header()
		        alpha.setup(dashboard.opts)

		        -- 현재 창에서만 Alpha 대시보드 열기
		        vim.cmd("Alpha")
		    end, {})
		end,
	}
})
