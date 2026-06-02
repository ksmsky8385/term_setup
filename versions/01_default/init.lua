-- =========================================================
-- 기본 설정
-- =========================================================

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
-- Tree-sitter 언어 목록
-- 여기에 원하는 언어 추가/삭제
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
    -- -----------------------------------------------------
    -- 색상 테마
    -- -----------------------------------------------------
    {
        "folke/vscode.nvim",
        lazy = false,
        priority = 1000,
        config = function()
            vim.cmd.colorscheme("vscode")
        end,
    },

    -- -----------------------------------------------------
    -- Tree-sitter 안정판
    -- Neovim 0.12 main API 에러 회피용 master 브랜치
    -- -----------------------------------------------------
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

            -- parser 목록 업데이트
            vim.api.nvim_create_user_command("TSMyUpdate", function()
                vim.cmd("TSUpdate")
            end, {})

            -- parser 수동 설치
            -- 사용 예: :TSMyInstall rust
            vim.api.nvim_create_user_command("TSMyInstall", function(opts)
                vim.cmd("TSInstall " .. opts.args)
            end, {
                nargs = 1,
            })

            -- parser 수동 삭제
            -- 사용 예: :TSMyUninstall rust
            vim.api.nvim_create_user_command("TSMyUninstall", function(opts)
                vim.cmd("TSUninstall " .. opts.args)
            end, {
                nargs = 1,
            })

            -- 설치 상태 확인
            vim.api.nvim_create_user_command("TSMyList", function()
                vim.cmd("TSInstallInfo")
            end, {})
        end,
    },

    -- -----------------------------------------------------
    -- nvim-tree
    -- 왼쪽 디렉토리 트리
    -- -----------------------------------------------------
    {
        "nvim-tree/nvim-tree.lua",
        dependencies = {
            "nvim-tree/nvim-web-devicons",
        },

        config = function()
            require("nvim-tree").setup({
                view = {
                    width = 30,
                },

                renderer = {
                    group_empty = true,
                },

                filters = {
                    dotfiles = false,
                },
            })

            vim.keymap.set(
                "n",
                "<leader>e",
                ":NvimTreeToggle<CR>",
                {
                    noremap = true,
                    silent = true,
                    desc = "Toggle file tree",
                }
            )
        end,
    },
})
