return {
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

        vim.keymap.set("n", "<leader>e", ":TreeToggle<CR>", {
            noremap = true,
            silent = true,
            desc = "Toggle file tree",
        })
    end,
}