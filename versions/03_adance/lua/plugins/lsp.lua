return {
    "neovim/nvim-lspconfig",
    dependencies = {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
    },
    config = function()
        local servers = require("config.lsp_servers").servers

        for _, server in ipairs(servers) do
            vim.lsp.enable(server)
        end

        vim.keymap.set("n", "gd", vim.lsp.buf.definition, {
            desc = "Go to definition",
        })

        vim.keymap.set("n", "K", vim.lsp.buf.hover, {
            desc = "Hover documentation",
        })

        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, {
            desc = "Rename symbol",
        })

        vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, {
            desc = "Code action",
        })

        vim.keymap.set("n", "<leader>dl", vim.diagnostic.open_float, {
            desc = "Line diagnostics",
        })

        vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, {
            desc = "Previous diagnostic",
        })

        vim.keymap.set("n", "]d", vim.diagnostic.goto_next, {
            desc = "Next diagnostic",
        })
    end,
}
