return {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = {
        "nvim-treesitter/nvim-treesitter",
        "nvim-tree/nvim-web-devicons",
    },
    ft = {
        "markdown",
        "AgenticChat",
    },
    opts = {
        file_types = {
            "markdown",
            "AgenticChat",
        },
        render_modes = {
            "n",
            "c",
            "t",
        },
        heading = {
            sign = false,
        },
        code = {
            sign = false,
            width = "block",
            right_pad = 1,
        },
    },
    keys = {
        {
            "<leader>mr",
            "<cmd>RenderMarkdown buf_toggle<cr>",
            ft = {
                "markdown",
                "AgenticChat",
            },
            desc = "Toggle Markdown rendering",
        },
    },
}
