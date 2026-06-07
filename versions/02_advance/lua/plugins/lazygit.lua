return {
    "kdheepak/lazygit.nvim",
    cmd = {
        "LazyGit",
        "LazyGitConfig",
        "LazyGitCurrentFile",
        "LazyGitFilter",
        "LazyGitFilterCurrentFile",
    },
    dependencies = {
        "nvim-lua/plenary.nvim",
    },
    config = function()
        local function refresh_after_lazygit()
            vim.schedule(function()
                vim.cmd("checktime")

                local ok_gitsigns, gitsigns = pcall(require, "gitsigns")

                if ok_gitsigns and gitsigns.refresh then
                    pcall(gitsigns.refresh)
                end

                local ok_tree, api = pcall(require, "nvim-tree.api")

                if ok_tree then
                    pcall(api.tree.reload)
                end
            end)
        end

        local function configure_lazygit_buffer(buf)
            vim.keymap.set("t", "<Esc>", "<Esc>", {
                buffer = buf,
                noremap = true,
                silent = true,
                desc = "Send escape to lazygit",
            })

            vim.keymap.set("n", "<Esc>", "i", {
                buffer = buf,
                noremap = true,
                silent = true,
                desc = "Return to lazygit terminal mode",
            })
        end

        vim.api.nvim_create_autocmd("TermOpen", {
            pattern = "*lazygit*",
            callback = function(args)
                configure_lazygit_buffer(args.buf)
            end,
        })

        vim.api.nvim_create_autocmd("FileType", {
            pattern = "lazygit",
            callback = function(args)
                configure_lazygit_buffer(args.buf)
            end,
        })

        vim.api.nvim_create_autocmd("TermClose", {
            pattern = "*lazygit*",
            callback = refresh_after_lazygit,
        })
    end,
    keys = {
        {
            "<leader>gg",
            "<cmd>LazyGit<CR>",
            desc = "Open lazygit",
        },
        {
            "<leader>gG",
            "<cmd>LazyGitCurrentFile<CR>",
            desc = "Open lazygit for current file",
        },
        {
            "<leader>gf",
            "<cmd>LazyGitFilterCurrentFile<CR>",
            desc = "Open lazygit file history",
        },
        {
            "<leader>gc",
            "<cmd>LazyGitConfig<CR>",
            desc = "Open lazygit config",
        },
    },
}
