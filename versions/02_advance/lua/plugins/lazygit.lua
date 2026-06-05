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
