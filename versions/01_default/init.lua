vim.g.mapleader = " "

vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = false
vim.opt.termguicolors = true
vim.opt.clipboard = "unnamedplus"

local function set_indent(patterns, size, expandtab)
    vim.api.nvim_create_autocmd("FileType", {
        pattern = patterns,
        callback = function()
            vim.opt_local.tabstop = size
            vim.opt_local.shiftwidth = size
            vim.opt_local.softtabstop = size
            vim.opt_local.expandtab = expandtab
        end,
    })
end

set_indent({ "python", "java", "lua" }, 4, true)
set_indent({ "sh", "html", "css", "javascript", "typescript", "tsx" }, 2, false)

local treesitter_languages = {
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

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
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

require("lazy").setup({
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "master",
        lazy = false,
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter.configs").setup({
                ensure_installed = treesitter_languages,
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
        opts = {
            view = {
                width = 30,
            },
            renderer = {
                group_empty = true,
                icons = {
                    show = {
                        file = false,
                        folder = false,
                        folder_arrow = false,
                        git = false,
                        modified = false,
                        diagnostics = false,
                        bookmarks = false,
                        hidden = false,
                    },
                },
            },
            filters = {
                dotfiles = false,
            },
        },
        keys = {
            {
                "<leader>e",
                "<cmd>NvimTreeToggle<CR>",
                desc = "Toggle file tree",
            },
        },
    },
    {
        "nvim-telescope/telescope.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
        },
        config = function()
            local builtin = require("telescope.builtin")

            require("telescope").setup({})

            vim.keymap.set("n", "<leader>ff", function()
                builtin.find_files({ disable_devicons = true })
            end, {
                desc = "Find files",
            })
            vim.keymap.set("n", "<leader>fg", function()
                builtin.live_grep({ disable_devicons = true })
            end, {
                desc = "Live grep",
            })
            vim.keymap.set("n", "<leader>fh", builtin.help_tags, {
                desc = "Help tags",
            })
        end,
    },
})
