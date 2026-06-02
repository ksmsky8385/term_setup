return {
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
}