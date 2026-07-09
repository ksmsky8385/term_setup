return {
    "gorbit99/codewindow.nvim",
    keys = {
        {
            "<leader>mm",
            function()
                require("codewindow").toggle_minimap()
            end,
            desc = "Toggle minimap",
        },
        {
            "<leader>mf",
            function()
                require("codewindow").toggle_focus()
            end,
            desc = "Focus minimap",
        },
    },
    config = function()
        local codewindow = require("codewindow")

        codewindow.setup({
            auto_enable = false,
            minimap_width = 16,
            use_lsp = true,
            use_treesitter = true,
            use_git = true,
            screen_bounds = "lines",
            window_border = "single",
            relative = "win",
        })
    end,
}
