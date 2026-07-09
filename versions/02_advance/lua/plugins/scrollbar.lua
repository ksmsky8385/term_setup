return {
    "petertriho/nvim-scrollbar",
    cmd = {
        "ScrollbarToggle",
        "ScrollbarShow",
        "ScrollbarHide",
    },
    keys = {
        {
            "<leader>ms",
            function()
                require("scrollbar.utils").toggle()
            end,
            desc = "Toggle scrollbar",
        },
    },
    config = function()
        require("scrollbar").setup({
            show = false,
            show_in_active_only = true,
            hide_if_all_visible = true,
            handle = {
                hide_if_all_visible = true,
            },
            handlers = {
                cursor = true,
                diagnostic = true,
                gitsigns = true,
                handle = true,
                search = false,
                ale = false,
            },
        })
    end,
}
