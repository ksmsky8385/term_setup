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
            local package_fallbacks = {
                bashls = "bash-language-server",
                clangd = "clangd",
                jsonls = "json-lsp",
                lua_ls = "lua-language-server",
                marksman = "marksman",
                pyright = "pyright",
                taplo = "taplo",
                vimls = "vim-language-server",
                yamlls = "yaml-language-server",
            }

            require("mason-lspconfig").setup({
                ensure_installed = {},
                automatic_enable = false,
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

            local function load_telescope()
                local ok, telescope = pcall(function()
                    return {
                        actions = require("telescope.actions"),
                        action_state = require("telescope.actions.state"),
                        conf = require("telescope.config").values,
                        finders = require("telescope.finders"),
                        pickers = require("telescope.pickers"),
                    }
                end)

                if not ok then
                    vim.notify(
                        "telescope.nvim is not available",
                        vim.log.levels.ERROR
                    )
                    return nil
                end

                return telescope
            end

            local function picker(title, entries)
                local telescope = load_telescope()

                if not telescope then
                    return
                end

                telescope.pickers
                    .new({}, {
                        prompt_title = title,
                        finder = telescope.finders.new_table({
                            results = entries,
                            entry_maker = function(entry)
                                return {
                                    value = entry,
                                    display = entry.label,
                                    ordinal = entry.ordinal or entry.label,
                                }
                            end,
                        }),
                        sorter = telescope.conf.generic_sorter({}),
                        previewer = false,
                        attach_mappings = function(prompt_bufnr)
                            telescope.actions.select_default:replace(function()
                                local selected =
                                    telescope.action_state.get_selected_entry()

                                telescope.actions.close(prompt_bufnr)

                                if
                                    selected
                                    and selected.value
                                    and selected.value.action
                                then
                                    selected.value.action()
                                end
                            end)

                            return true
                        end,
                    })
                    :find()
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
                    mappings.lspconfig_to_package = mappings.lspconfig_to_package or {}
                    mappings.package_to_lspconfig = mappings.package_to_lspconfig or {}

                    for server, package in pairs(package_fallbacks) do
                        mappings.lspconfig_to_package[server] =
                            mappings.lspconfig_to_package[server] or package
                        mappings.package_to_lspconfig[package] =
                            mappings.package_to_lspconfig[package] or server
                    end

                    return mappings
                end

                return {
                    lspconfig_to_package = vim.deepcopy(package_fallbacks),
                    package_to_lspconfig = {},
                }
            end

            local function available_servers(mason_lspconfig)
                local ok, servers = pcall(mason_lspconfig.get_available_servers)

                if ok and #servers > 0 then
                    table.sort(servers)
                    return servers
                end

                local mappings = server_mappings(mason_lspconfig)
                local mapped_servers = vim.tbl_keys(mappings.lspconfig_to_package or {})

                if #mapped_servers > 0 then
                    table.sort(mapped_servers)
                    return mapped_servers
                end

                local fallback = vim.deepcopy(lsp_servers.servers)
                table.sort(fallback)
                return fallback
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
                local recommended = lsp_servers.recommended()
                local max_server_len = 0

                for _, server in ipairs(servers) do
                    max_server_len = math.max(max_server_len, #server)
                end

                local entries = {
                    {
                        label = "< Back",
                        action = function()
                            vim.cmd("LSPSettings")
                        end,
                    },
                    {
                        label = "[x] installed    [ ] not installed    * recommended",
                    },
                }

                for _, server in ipairs(servers) do
                    local status = installed[server] and "[x]" or "[ ]"
                    local marker = recommended[server] and "*" or " "

                    table.insert(entries, {
                        label = string.format(
                            "%s %s %-" .. max_server_len .. "s",
                            status,
                            marker,
                            server
                        ),
                        ordinal = server,
                        action = function()
                            if installed[server] then
                                vim.cmd(
                                    "LSPMyUninstall "
                                        .. vim.fn.fnameescape(server)
                                )
                            else
                                vim.cmd(
                                    "LSPMyInstall "
                                        .. vim.fn.fnameescape(server)
                                )
                            end
                        end,
                    })
                end

                picker("LSP Servers", entries)
            end, {})

            vim.api.nvim_create_user_command("LSPMyInstall", function(opts)
                if opts.args == "" then
                    local mason_lspconfig = load_mason_lspconfig()

                    if not mason_lspconfig then
                        return
                    end

                    local servers = available_servers(mason_lspconfig)
                    local installed = installed_servers(mason_lspconfig)
                    local recommended = lsp_servers.recommended()
                    local max_server_len = 0

                    for _, server in ipairs(servers) do
                        max_server_len = math.max(max_server_len, #server)
                    end

                    local entries = {
                        {
                            label = "< Back",
                            action = function()
                                vim.cmd("LSPSettings")
                            end,
                        },
                        {
                            label = "[x] installed    [ ] not installed    * recommended",
                        },
                    }

                    for _, server in ipairs(servers) do
                        local status = installed[server] and "[x]" or "[ ]"
                        local marker = recommended[server] and "*" or " "

                        table.insert(entries, {
                            label = string.format(
                                "%s %s %-" .. max_server_len .. "s",
                                status,
                                marker,
                                server
                            ),
                            ordinal = server,
                            action = function()
                                vim.cmd(
                                    "LSPMyInstall " .. vim.fn.fnameescape(server)
                                )
                            end,
                        })
                    end

                    picker("Install LSP Server", entries)
                    return
                end

                vim.cmd("LspInstall " .. vim.fn.fnameescape(opts.args))
            end, {
                nargs = "?",
                complete = complete_servers,
            })

            vim.api.nvim_create_user_command("LSPMyUninstall", function(opts)
                if opts.args == "" then
                    local mason_lspconfig = load_mason_lspconfig()

                    if not mason_lspconfig then
                        return
                    end

                    local installed = installed_servers(mason_lspconfig)
                    local servers = vim.tbl_keys(installed)

                    table.sort(servers)

                    local entries = {
                        {
                            label = "< Back",
                            action = function()
                                vim.cmd("LSPSettings")
                            end,
                        },
                    }

                    for _, server in ipairs(servers) do
                        table.insert(entries, {
                            label = server,
                            action = function()
                                vim.cmd(
                                    "LSPMyUninstall "
                                        .. vim.fn.fnameescape(server)
                                )
                            end,
                        })
                    end

                    if #servers == 0 then
                        vim.notify("No installed LSP servers")
                        return
                    end

                    picker("Remove LSP Server", entries)
                    return
                end

                vim.cmd("LspUninstall " .. vim.fn.fnameescape(opts.args))
            end, {
                nargs = "?",
                complete = complete_servers,
            })

            vim.api.nvim_create_user_command("LSPMyUpdate", function()
                vim.cmd("MasonUpdate")
            end, {})
        end,
    },
}
