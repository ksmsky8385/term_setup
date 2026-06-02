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

return {
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
}