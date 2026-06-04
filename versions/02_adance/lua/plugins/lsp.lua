return {
    "neovim/nvim-lspconfig",
    dependencies = {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
        local servers = require("config.lsp_servers").servers
        local capabilities = vim.lsp.protocol.make_client_capabilities()
        local ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")

        if ok then
            capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
        end

        for _, server in ipairs(servers) do
            vim.lsp.config(server, {
                capabilities = capabilities,
            })
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
