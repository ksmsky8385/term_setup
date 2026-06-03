return {
    {
        "williamboman/mason.nvim",
        config = function()
            require("mason").setup()
        end,
    },

    {
        "williamboman/mason-lspconfig.nvim",
        dependencies = {
            "williamboman/mason.nvim",
        },
        config = function()
            local lsp_servers = require("config.lsp_servers")

            require("mason-lspconfig").setup({
                ensure_installed = {},
                automatic_enable = lsp_servers.servers,
            })

            local function load_mason_lspconfig()
                local ok, mason_lspconfig = pcall(require, "mason-lspconfig")

                if not ok then
                    vim.notify(
                        "mason-lspconfig is not available",
                        vim.log.levels.ERROR
                    )
                    return nil
                end

                return mason_lspconfig
            end

            local function available_servers(mason_lspconfig)
                local ok, servers = pcall(mason_lspconfig.get_available_servers)

                if ok then
                    table.sort(servers)
                    return servers
                end

                local fallback = vim.deepcopy(lsp_servers.servers)
                table.sort(fallback)
                return fallback
            end

            local function installed_servers(mason_lspconfig)
                local installed = {}
                local ok, servers = pcall(mason_lspconfig.get_installed_servers)

                if not ok then
                    return installed
                end

                for _, server in ipairs(servers) do
                    installed[server] = true
                end

                return installed
            end

            local function server_mappings(mason_lspconfig)
                local ok, mappings = pcall(mason_lspconfig.get_mappings)

                if ok then
                    return mappings
                end

                return {
                    lspconfig_to_package = {},
                }
            end

            local function complete_servers()
                local mason_lspconfig = load_mason_lspconfig()

                if not mason_lspconfig then
                    return {}
                end

                return available_servers(mason_lspconfig)
            end

            vim.api.nvim_create_user_command("LSPMyList", function()
                local mason_lspconfig = load_mason_lspconfig()

                if not mason_lspconfig then
                    return
                end

                local servers = available_servers(mason_lspconfig)
                local installed = installed_servers(mason_lspconfig)
                local configured = lsp_servers.configured()
                local mappings = server_mappings(mason_lspconfig)
                local max_server_len = 0
                local max_package_len = 0

                local function back()
                    vim.cmd("bd")
                    vim.cmd("LSPSettings")
                end

                for _, server in ipairs(servers) do
                    local package = mappings.lspconfig_to_package[server] or "-"
                    max_server_len = math.max(max_server_len, #server)
                    max_package_len = math.max(max_package_len, #package)
                end

                local lines = {
                    "",
                    "  LSP servers",
                    "  -----------",
                    "",
                    "  < Back",
                    "",
                    "  [x] installed    [ ] not installed    * configured",
                    "",
                }

                for _, server in ipairs(servers) do
                    local package = mappings.lspconfig_to_package[server] or "-"
                    local status = installed[server] and "[x]" or "[ ]"
                    local marker = configured[server] and "*" or " "

                    table.insert(
                        lines,
                        string.format(
                            "  %s %s %-"
                                .. max_server_len
                                .. "s  %-"
                                .. max_package_len
                                .. "s",
                            status,
                            marker,
                            server,
                            package
                        )
                    )
                end

                vim.cmd("enew")
                vim.bo.buftype = "nofile"
                vim.bo.bufhidden = "wipe"
                vim.bo.swapfile = false
                vim.bo.modifiable = true
                vim.wo.cursorline = true
                vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
                vim.bo.modifiable = false
                vim.bo.filetype = "nvim-lsp-servers"
                vim.api.nvim_win_set_cursor(0, { 5, 2 })

                vim.keymap.set("n", "<CR>", function()
                    if vim.api.nvim_win_get_cursor(0)[1] == 5 then
                        back()
                    end
                end, {
                    buffer = true,
                    silent = true,
                    desc = "Back to LSP settings",
                })

                vim.keymap.set("n", "h", back, {
                    buffer = true,
                    silent = true,
                    desc = "Back to LSP settings",
                })

                vim.keymap.set("n", "b", back, {
                    buffer = true,
                    silent = true,
                    desc = "Back to LSP settings",
                })

                vim.keymap.set("n", "q", ":bd<CR>", {
                    buffer = true,
                    silent = true,
                    desc = "Close LSP server list",
                })
            end, {})

            vim.api.nvim_create_user_command("LSPMyInstall", function(opts)
                vim.cmd("LspInstall " .. opts.args)
            end, {
                nargs = 1,
                complete = complete_servers,
            })

            vim.api.nvim_create_user_command("LSPMyUninstall", function(opts)
                vim.cmd("LspUninstall " .. opts.args)
            end, {
                nargs = 1,
                complete = complete_servers,
            })

            vim.api.nvim_create_user_command("LSPMyUpdate", function()
                vim.cmd("MasonUpdate")
            end, {})
        end,
    },
}
