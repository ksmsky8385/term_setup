local function apply_code_block_highlight()
    local h2 = vim.api.nvim_get_hl(0, {
        name = "RenderMarkdownH2Bg",
        link = false,
    })
    local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
    local background = h2.bg
        or normal.bg
        or (vim.o.background == "light" and 0xf5f5f5 or 0x1f1f1f)
    local red = math.floor(background / 0x10000) % 0x100
    local green = math.floor(background / 0x100) % 0x100
    local blue = background % 0x100
    local amount = 0.30

    vim.api.nvim_set_hl(0, "RenderMarkdownFencedCode", {
        bg = math.floor(red * (1 - amount)) * 0x10000
            + math.floor(green * (1 - amount)) * 0x100
            + math.floor(blue * (1 - amount)),
        bold = false,
    })
end

local function setup_code_block_highlight()
    local group = vim.api.nvim_create_augroup(
        "RenderMarkdownCodeBlock",
        { clear = true }
    )

    vim.api.nvim_create_autocmd("ColorScheme", {
        group = group,
        callback = function()
            vim.schedule(apply_code_block_highlight)
        end,
        desc = "Keep Markdown code blocks visually distinct",
    })

    apply_code_block_highlight()
end

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
            border = "thick",
            highlight = "RenderMarkdownFencedCode",
            highlight_border = "RenderMarkdownFencedCode",
        },
    },
    config = function(_, opts)
        require("render-markdown").setup(opts)
        setup_code_block_highlight()
    end,
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
