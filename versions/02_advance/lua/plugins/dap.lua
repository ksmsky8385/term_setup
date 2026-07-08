return {
    {
        "mfussenegger/nvim-dap",
        dependencies = {
            "williamboman/mason.nvim",
            "jay-babu/mason-nvim-dap.nvim",
        },
        config = function()
            local dap = require("dap")
            local debugger = require("config.debugger")
            local telescope_picker = require("config.picker")
            local recommended_adapters = {
                bash = true,
                codelldb = true,
                delve = true,
                js = true,
                python = true,
            }

            require("mason-nvim-dap").setup({
                ensure_installed = {},
                handlers = {
                    function(config)
                        require("mason-nvim-dap").default_setup(config)
                    end,
                },
            })

            local function load_mason_registry()
                local ok, registry = pcall(require, "mason-registry")

                if not ok then
                    vim.notify("mason-registry is not available", vim.log.levels.ERROR)
                    return nil
                end

                return registry
            end

            local function load_mason_dap_sources()
                local ok, sources = pcall(require, "mason-nvim-dap.mappings.source")

                if not ok then
                    vim.notify(
                        "mason-nvim-dap mappings are not available",
                        vim.log.levels.ERROR
                    )
                    return nil
                end

                return sources
            end

            local function available_adapters()
                local sources = load_mason_dap_sources()

                if not sources then
                    return {}
                end

                local adapters = vim.tbl_keys(sources.nvim_dap_to_package or {})

                table.sort(adapters)
                return adapters
            end

            local function adapter_package(adapter)
                local sources = load_mason_dap_sources()

                if not sources then
                    return nil
                end

                return sources.nvim_dap_to_package[adapter]
            end

            local function installed_adapters()
                local registry = load_mason_registry()
                local sources = load_mason_dap_sources()
                local installed = {}

                if not registry or not sources then
                    return installed
                end

                for adapter, package_name in pairs(sources.nvim_dap_to_package or {}) do
                    local ok, package = pcall(registry.get_package, package_name)

                    if ok and package:is_installed() then
                        installed[adapter] = true
                    end
                end

                return installed
            end

            local function picker(title, entries)
                telescope_picker.action_picker(title, entries)
            end

            local function adapter_label(adapter, installed, max_adapter_len, max_package_len)
                local package_name = adapter_package(adapter) or "unknown"
                local status = installed and "[x]" or "[ ]"
                local marker = recommended_adapters[adapter] and "*" or " "

                return string.format(
                    "%s %s %-"
                        .. max_adapter_len
                        .. "s  (%-"
                        .. max_package_len
                        .. "s)",
                    status,
                    marker,
                    adapter,
                    package_name
                )
            end

            local function adapter_widths(adapters)
                local max_adapter_len = 0
                local max_package_len = 0

                for _, adapter in ipairs(adapters) do
                    max_adapter_len = math.max(max_adapter_len, #adapter)
                    max_package_len = math.max(
                        max_package_len,
                        #(adapter_package(adapter) or "")
                    )
                end

                return max_adapter_len, max_package_len
            end

            vim.api.nvim_create_user_command("DAPMyList", function()
                local adapters = available_adapters()
                local installed = installed_adapters()
                local max_adapter_len, max_package_len = adapter_widths(adapters)
                local entries = {
                    {
                        label = "< Back",
                        action = function()
                            vim.cmd("DAPSettings")
                        end,
                    },
                    {
                        label = "[x] installed    [ ] not installed    * recommended",
                    },
                }

                for _, adapter in ipairs(adapters) do
                    table.insert(entries, {
                        label = adapter_label(
                            adapter,
                            installed[adapter],
                            max_adapter_len,
                            max_package_len
                        ),
                        ordinal = adapter,
                        action = function()
                            if installed[adapter] then
                                vim.cmd(
                                    "DAPMyUninstall " .. vim.fn.fnameescape(adapter)
                                )
                            else
                                vim.cmd("DAPMyInstall " .. vim.fn.fnameescape(adapter))
                            end
                        end,
                    })
                end

                picker("DAP Adapters", entries)
            end, {})

            vim.api.nvim_create_user_command("DAPMyInstall", function(opts)
                if opts.args == "" then
                    local adapters = available_adapters()
                    local installed = installed_adapters()
                    local max_adapter_len, max_package_len = adapter_widths(adapters)
                    local entries = {
                        {
                            label = "< Back",
                            action = function()
                                vim.cmd("DAPSettings")
                            end,
                        },
                        {
                            label = "[x] installed    [ ] not installed    * recommended",
                        },
                    }

                    for _, adapter in ipairs(adapters) do
                        table.insert(entries, {
                            label = adapter_label(
                                adapter,
                                installed[adapter],
                                max_adapter_len,
                                max_package_len
                            ),
                            ordinal = adapter,
                            action = function()
                                vim.cmd(
                                    "DAPMyInstall " .. vim.fn.fnameescape(adapter)
                                )
                            end,
                        })
                    end

                    picker("Install DAP Adapter", entries)
                    return
                end

                if not adapter_package(opts.args) then
                    vim.notify("Unknown DAP adapter: " .. opts.args, vim.log.levels.ERROR)
                    return
                end

                vim.cmd("DapInstall " .. vim.fn.fnameescape(opts.args))
            end, {
                nargs = "?",
                complete = available_adapters,
            })

            vim.api.nvim_create_user_command("DAPMyUninstall", function(opts)
                if opts.args == "" then
                    local adapters = available_adapters()
                    local installed = installed_adapters()
                    local entries = {
                        {
                            label = "< Back",
                            action = function()
                                vim.cmd("DAPSettings")
                            end,
                        },
                    }

                    for _, adapter in ipairs(adapters) do
                        if installed[adapter] then
                            local package_name = adapter_package(adapter) or "unknown"

                            table.insert(entries, {
                                label = adapter .. " (" .. package_name .. ")",
                                ordinal = adapter,
                                action = function()
                                    vim.cmd(
                                        "DAPMyUninstall "
                                            .. vim.fn.fnameescape(adapter)
                                    )
                                end,
                            })
                        end
                    end

                    if #entries == 1 then
                        vim.notify("No installed DAP adapters")
                        return
                    end

                    picker("Remove DAP Adapter", entries)
                    return
                end

                if not adapter_package(opts.args) then
                    vim.notify("Unknown DAP adapter: " .. opts.args, vim.log.levels.ERROR)
                    return
                end

                vim.cmd("DapUninstall " .. vim.fn.fnameescape(opts.args))
            end, {
                nargs = "?",
                complete = function()
                    return vim.tbl_keys(installed_adapters())
                end,
            })

            vim.api.nvim_create_user_command("DAPMyUpdate", function()
                vim.cmd("MasonUpdate")
            end, {})

            vim.api.nvim_create_user_command("DAPPath", function()
                local label, path = debugger.runtime_executable()
                vim.notify("DAP " .. label .. ": " .. path)
            end, {})

            vim.api.nvim_create_user_command("DAPPythonPath", function()
                local _, path = debugger.runtime_executable("python")
                vim.notify("DAP Python: " .. path)
            end, {})

            local function prompt_executable()
                return vim.fn.input(
                    "Executable: ",
                    vim.fn.getcwd() .. "/",
                    "file"
                )
            end

            dap.configurations.python = {
                {
                    type = "python",
                    request = "launch",
                    name = "Python: current file with args",
                    program = "${file}",
                    cwd = "${workspaceFolder}",
                    console = "integratedTerminal",
                    python = debugger.python_executable,
                    env = debugger.python_environment,
                    args = debugger.prompt_args,
                },
            }

            dap.configurations.c = {
                {
                    type = "codelldb",
                    request = "launch",
                    name = "C/C++/Rust: executable with args",
                    program = prompt_executable,
                    cwd = "${workspaceFolder}",
                    args = debugger.prompt_args,
                    stopOnEntry = false,
                },
            }
            dap.configurations.cpp = dap.configurations.c
            dap.configurations.rust = dap.configurations.c

            local original_run = dap.run

            dap.run = function(config, opts)
                if
                    debugger.prompt_args_enabled()
                    and type(config) == "table"
                    and config.request == "launch"
                    and config.args == nil
                then
                    config = vim.deepcopy(config)
                    config.args = debugger.prompt_args
                end

                return original_run(config, opts)
            end

            vim.fn.sign_define("DapBreakpoint", {
                text = "B",
                texthl = "DiagnosticSignError",
                linehl = "",
                numhl = "",
            })
            vim.fn.sign_define("DapBreakpointCondition", {
                text = "C",
                texthl = "DiagnosticSignWarn",
                linehl = "",
                numhl = "",
            })
            vim.fn.sign_define("DapLogPoint", {
                text = "L",
                texthl = "DiagnosticSignInfo",
                linehl = "",
                numhl = "",
            })
            vim.fn.sign_define("DapStopped", {
                text = ">",
                texthl = "DiagnosticSignHint",
                linehl = "Visual",
                numhl = "",
            })

            local function map(mode, lhs, rhs, desc)
                vim.keymap.set(mode, lhs, rhs, {
                    noremap = true,
                    silent = true,
                    desc = desc,
                })
            end

            map("n", "<F5>", dap.continue, "DAP continue/start")
            map("n", "<F6>", dap.step_over, "DAP step over")
            map("n", "<F7>", dap.step_into, "DAP step into")
            map("n", "<F8>", dap.step_out, "DAP step out")
            map("n", "<F9>", dap.toggle_breakpoint, "DAP toggle breakpoint")
            map("n", "<leader>db", dap.toggle_breakpoint, "DAP toggle breakpoint")
            map("n", "<leader>do", dap.step_over, "DAP step over")
            map("n", "<leader>di", dap.step_into, "DAP step into")
            map("n", "<leader>dO", dap.step_out, "DAP step out")
            map("n", "<leader>dB", function()
                dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
            end, "DAP conditional breakpoint")
            map("n", "<leader>dL", function()
                dap.set_breakpoint(nil, nil, vim.fn.input("Log point message: "))
            end, "DAP logpoint")
            map("n", "<leader>dp", function()
                vim.cmd("DAPPath")
            end, "DAP show runtime path")
            map("n", "<leader>dr", dap.repl.open, "DAP open REPL")
            map("n", "<leader>dq", dap.terminate, "DAP terminate")
        end,
    },

    {
        "rcarriga/nvim-dap-ui",
        dependencies = {
            "mfussenegger/nvim-dap",
            "nvim-neotest/nvim-nio",
        },
        config = function()
            local dap = require("dap")
            local dapui = require("dapui")

            dapui.setup()

            dap.listeners.before.attach.dapui_config = function()
                dapui.open()
            end
            dap.listeners.before.launch.dapui_config = function()
                dapui.open()
            end
            dap.listeners.before.event_terminated.dapui_config = function()
                dapui.close()
            end
            dap.listeners.before.event_exited.dapui_config = function()
                dapui.close()
            end

            vim.keymap.set("n", "<leader>du", dapui.toggle, {
                noremap = true,
                silent = true,
                desc = "DAP toggle UI",
            })
            vim.keymap.set({ "n", "v" }, "<leader>dK", dapui.eval, {
                noremap = true,
                silent = true,
                desc = "DAP evaluate expression",
            })
        end,
    },

    {
        "theHamsta/nvim-dap-virtual-text",
        dependencies = {
            "mfussenegger/nvim-dap",
            "nvim-treesitter/nvim-treesitter",
        },
        config = function()
            require("nvim-dap-virtual-text").setup({
                commented = true,
            })
        end,
    },
}
