return {
    "nvim-tree/nvim-tree.lua",
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },

    config = function()
        local terminal = require("config.terminal")
        local api = require("nvim-tree.api")

        local function restore_nvim_tree_highlights()
            local ok, appearance = pcall(require, "nvim-tree.appearance")

            if ok then
                appearance.highlight()
            end
        end

        require("nvim-tree").setup({
            sync_root_with_cwd = true,
            respect_buf_cwd = true,

            on_attach = function(bufnr)
                api.config.mappings.default_on_attach(bufnr)

                local function opts(desc)
                    return {
                        buffer = bufnr,
                        noremap = true,
                        silent = true,
                        nowait = true,
                        desc = desc,
                    }
                end

                vim.keymap.set(
                    "n",
                    "<leader>t",
                    terminal.pick_terminal,
                    opts("Pick terminal")
                )
            end,

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
                            buftype = {},
                        },
                    },
                },
            },
        })

        restore_nvim_tree_highlights()

        vim.api.nvim_create_autocmd("ColorScheme", {
            callback = restore_nvim_tree_highlights,
        })

        vim.keymap.set("n", "<leader>e", ":TreeToggle<CR>", {
            noremap = true,
            silent = true,
            desc = "Toggle file tree",
        })
    end,
}
