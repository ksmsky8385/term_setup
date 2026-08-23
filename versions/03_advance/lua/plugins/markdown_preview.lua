return {
    "iamcco/markdown-preview.nvim",
    cmd = {
        "MarkdownPreview",
        "MarkdownPreviewStop",
        "MarkdownPreviewToggle",
    },
    ft = { "markdown" },
    build = "cd app && npm install",

    init = function()
        vim.g.mkdp_filetypes = { "markdown" }
        vim.g.mkdp_auto_start = 0
        vim.g.mkdp_auto_close = 0
        vim.g.mkdp_refresh_slow = 0
        vim.g.mkdp_open_to_the_world = 0
        vim.g.mkdp_echo_preview_url = 1
        vim.g.mkdp_page_title = "${name} - Markdown Preview"
        vim.g.mkdp_theme = "dark"
        vim.g.mkdp_preview_options = {
            mkit = {},
            katex = {},
            uml = {},
            maid = {},
            disable_sync_scroll = 0,
            sync_scroll_type = "middle",
            hide_yaml_meta = 1,
            sequence_diagrams = {},
            flowchart_diagrams = {},
            content_editable = false,
            disable_filename = 0,
            toc = {},
        }
    end,

    keys = {
        {
            "<leader>mp",
            "<cmd>MarkdownPreviewToggle<cr>",
            ft = "markdown",
            desc = "Toggle Markdown preview",
        },
    },
}
