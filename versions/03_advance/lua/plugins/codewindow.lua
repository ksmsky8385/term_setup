local toggle_state = require("config.toggle_state")
local enabled_on_startup = toggle_state.read("minimap", false)

return {
    "gorbit99/codewindow.nvim",
    lazy = not enabled_on_startup,
    keys = {
        {
            "<leader>mm",
            function()
                local codewindow = require("codewindow")
                codewindow.toggle_minimap()

                local enabled = require("codewindow.window").is_minimap_open()
                toggle_state.write("minimap", enabled)
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
            auto_enable = enabled_on_startup,
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
