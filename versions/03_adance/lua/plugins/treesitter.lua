local MY_TS_LANGS = {
    "c",
    "python",
    "lua",
    "bash",
    "make",
    "json",
    "yaml",
    "toml",
    "markdown",
    "markdown_inline",
    "vim",
    "vimdoc",
}

local function configured_langs()
    local langs = {}

    for _, lang in ipairs(MY_TS_LANGS) do
        langs[lang] = true
    end

    return langs
end

return {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    lazy = false,

    config = function()
        require("nvim-treesitter.configs").setup({
            ensure_installed = MY_TS_LANGS,
            sync_install = false,
            auto_install = false,

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
            local parsers = require("nvim-treesitter.parsers")
            local parser_list = parsers.available_parsers()
            local configured = configured_langs()
            local max_len = 0
            local function back()
                vim.cmd("bd")
                vim.cmd("TSSettings")
            end

            table.sort(parser_list)

            for _, lang in ipairs(parser_list) do
                max_len = math.max(max_len, #lang)
            end

            local lines = {
                "",
                "  Tree-sitter parsers",
                "  -------------------",
                "",
                "  < Back",
                "",
                "  [x] installed    [ ] not installed    * configured",
                "",
            }

            for _, lang in ipairs(parser_list) do
                local installed = #vim.api.nvim_get_runtime_file(
                    "parser/" .. lang .. ".so",
                    false
                ) > 0
                local status = installed and "[x]" or "[ ]"
                local marker = configured[lang] and "*" or " "

                table.insert(
                    lines,
                    string.format("  %s %s %-" .. max_len .. "s", status, marker, lang)
                )
            end

            vim.cmd("enew")
            vim.bo.buftype = "nofile"
            vim.bo.bufhidden = "wipe"
            vim.bo.swapfile = false
            vim.bo.modifiable = true
            vim.wo.cursorline = true
            vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
            vim.bo.modifiable = false
            vim.bo.filetype = "nvim-treesitter-parsers"
            vim.api.nvim_win_set_cursor(0, { 5, 2 })

            vim.keymap.set("n", "<CR>", function()
                if vim.api.nvim_win_get_cursor(0)[1] == 5 then
                    back()
                end
            end, {
                buffer = true,
                silent = true,
                desc = "Back to Tree-sitter settings",
            })

            vim.keymap.set("n", "h", back, {
                buffer = true,
                silent = true,
                desc = "Back to Tree-sitter settings",
            })

            vim.keymap.set("n", "b", back, {
                buffer = true,
                silent = true,
                desc = "Back to Tree-sitter settings",
            })

            vim.keymap.set("n", "q", ":bd<CR>", {
                buffer = true,
                silent = true,
                desc = "Close Tree-sitter parser list",
            })
        end, {})
    end,
}
