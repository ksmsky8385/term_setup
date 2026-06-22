return {
    "goolord/alpha-nvim",
    lazy = false,
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },

    config = function()
        local alpha = require("alpha")
        local dashboard = require("alpha.themes.dashboard")

        local version = vim.version()
        local version_text = string.format(
            "ver. %d.%d.%d",
            version.major,
            version.minor,
            version.patch
        )

        local ascii_header = {
            "███╗   ██╗██╗   ██╗██╗███╗   ███╗",
            "████╗  ██║██║   ██║██║████╗ ████║",
            "██╔██╗ ██║██║   ██║██║██╔████╔██║",
            "██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║",
            "██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║ " .. version_text,
            "╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝",
        }

        local function get_header_width()
            local width = 0

            for _, line in ipairs(ascii_header) do
                width = math.max(width, vim.fn.strdisplaywidth(line))
            end

            return width
        end

        local function wrap_path(path, max_width)
            local lines = {}
            local prefix = "root: "
            local indent = "      "
            local current = prefix

            for part in string.gmatch(path, "[^/]+") do
                local next_part = current .. "/" .. part

                if vim.fn.strdisplaywidth(next_part) > max_width then
                    table.insert(lines, current)
                    current = indent .. "/" .. part
                else
                    current = next_part
                end
            end

            table.insert(lines, current)

            return lines
        end

        local function make_header()
            local cwd = vim.g.current_workspace_root or vim.fn.getcwd()
            local header_width = get_header_width()
            local path_lines = wrap_path(cwd, header_width)

            local header = { "" }

            vim.list_extend(header, ascii_header)

            table.insert(header, "")

            vim.list_extend(header, path_lines)

            table.insert(header, "")

            return header
        end

        local function quit_blocker()
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                if
                    vim.api.nvim_buf_is_valid(buf)
                    and vim.bo[buf].modified
                    and vim.bo[buf].buftype ~= "terminal"
                then
                    local name = vim.api.nvim_buf_get_name(buf)

                    if name == "" then
                        name = "[No Name]"
                    else
                        name = vim.fn.fnamemodify(name, ":t")
                    end

                    return "Unsaved buffer: " .. name .. ". Save it or close it before quitting."
                end
            end

            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                if
                    vim.api.nvim_buf_is_valid(buf)
                    and vim.bo[buf].buftype == "terminal"
                then
                    local job_id = vim.b[buf].terminal_job_id

                    if
                        type(job_id) == "number"
                        and vim.fn.jobwait({ job_id }, 0)[1] == -1
                    then
                        return "Running terminals remain. Close them from Space bb or :TKill before quitting."
                    end
                end
            end

            return nil
        end

        local function clear_command_message()
            vim.cmd("redraw")
            vim.api.nvim_echo({}, false, {})
        end

        local function confirm_quit()
            local blocker = quit_blocker()

            if blocker then
                vim.api.nvim_echo({
                    {
                        blocker .. " Press Q to force quit, Esc or any other key to cancel.",
                        "WarningMsg",
                    },
                }, false, {})

                local ok, input = pcall(vim.fn.getcharstr)

                clear_command_message()

                if ok and input == "Q" then
                    vim.cmd("qa!")
                end

                return
            end

            vim.api.nvim_echo({
                { "Quit Neovim? Press Enter, q, or Q to confirm; Esc or any other key cancels.", "WarningMsg" },
            }, false, {})

            local ok, input = pcall(vim.fn.getcharstr)

            clear_command_message()

            if not ok then
                return
            end

            if input == "\13" or input == "\10" or input == "\r" or input == "q" or input == "Q" then
                vim.cmd("qa")
            end
        end

        vim.api.nvim_create_user_command("DashboardQuit", confirm_quit, {})

        local dashboard_buttons = {
            dashboard.button("e", "   New file", ":ene <BAR> startinsert<CR>"),
            dashboard.button("f", "󰈞   Find file", ":FloatingFindFiles<CR>"),
            dashboard.button("g", "󱎸   Search text", ":FloatingLiveGrep<CR>"),
            dashboard.button("w", "󰉋   Change workspace", ":WorkspacePick<CR>"),
            dashboard.button("t", "󰙅   Toggle tree", ":TreeToggle<CR>"),
            dashboard.button("s", "   Settings", ":Settings<CR>"),
            dashboard.button("a", "   About Neovim", "<cmd>AboutNeovim<CR>"),
            dashboard.button("q", "   Quit Neovim", ":DashboardQuit<CR>"),
        }

        local function dashboard_shortcut(button)
            return button
                and button.opts
                and type(button.opts.shortcut) == "string"
                and button.opts.shortcut:gsub("%s+", "")
                or nil
        end

        local function has_exact_leader_mapping(key)
            return vim.fn.maparg("<leader>" .. key, "n") ~= ""
        end

        local function dashboard_button_rows()
            local rows = {}
            local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

            for line_nr, line in ipairs(lines) do
                for _, button in ipairs(dashboard_buttons) do
                    if string.find(line, button.val, 1, true) then
                        table.insert(rows, line_nr)
                        break
                    end
                end
            end

            return rows
        end

        local function move_dashboard_cursor(delta)
            local rows = dashboard_button_rows()

            if #rows == 0 then
                return
            end

            local current_row = vim.api.nvim_win_get_cursor(0)[1]
            local target = nil

            for idx, row in ipairs(rows) do
                if row == current_row then
                    local next_idx = idx + delta

                    if next_idx < 1 then
                        next_idx = #rows
                    elseif next_idx > #rows then
                        next_idx = 1
                    end

                    target = rows[next_idx]
                    break
                end
            end

            if not target then
                if delta > 0 then
                    for _, row in ipairs(rows) do
                        if row > current_row then
                            target = row
                            break
                        end
                    end

                    target = target or rows[1]
                else
                    for idx = #rows, 1, -1 do
                        if rows[idx] < current_row then
                            target = rows[idx]
                            break
                        end
                    end

                    target = target or rows[#rows]
                end
            end

            vim.api.nvim_win_set_cursor(0, { target, 0 })
            alpha.move_cursor(vim.api.nvim_get_current_win())
        end

        local function is_returnable_buffer(buf)
            local is_empty_unnamed_buffer = vim.api.nvim_buf_is_valid(buf)
                and vim.api.nvim_buf_get_name(buf) == ""
                and vim.bo[buf].buftype == ""
                and not vim.bo[buf].modified
                and vim.api.nvim_buf_line_count(buf) == 1
                and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""

            if is_empty_unnamed_buffer then
                return false
            end

            if not vim.api.nvim_buf_is_valid(buf) or not vim.bo[buf].buflisted then
                return false
            end

            local filetype = vim.bo[buf].filetype

            if filetype == "alpha" or filetype == "NvimTree" or filetype == "notify" then
                return false
            end

            local buftype = vim.bo[buf].buftype

            if buftype == "" then
                return true
            end

            if buftype == "terminal" then
                return true
            end

            return false
        end

        local function is_dashboard_buffer(buf)
            return vim.api.nvim_buf_is_valid(buf)
                and vim.bo[buf].filetype == "alpha"
        end

        local function is_floating_slot_window(win)
            local ok, floating = pcall(require, "config.floating")

            if not ok then
                return false
            end

            if win then
                return floating.is_slot_window(win)
            end

            return floating.is_slot_window()
        end

        local function regular_window_count()
            local count = 0

            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                if vim.api.nvim_win_is_valid(win) then
                    local config = vim.api.nvim_win_get_config(win)
                    local buf = vim.api.nvim_win_get_buf(win)
                    local filetype = vim.bo[buf].filetype

                    if
                        config.relative == ""
                        and filetype ~= "FloatingSlot"
                        and filetype ~= "NvimTree"
                        and filetype ~= "notify"
                    then
                        count = count + 1
                    end
                end
            end

            return count
        end

        local function remember_current_buffer()
            if is_floating_slot_window() then
                return
            end

            local buf = vim.api.nvim_get_current_buf()

            if is_returnable_buffer(buf) then
                vim.w.config_dashboard_previous_buf = buf
            end
        end

        local function return_to_previous_buffer()
            if is_floating_slot_window() then
                return false
            end

            local previous_buf = vim.w.config_dashboard_previous_buf

            if previous_buf and is_returnable_buffer(previous_buf) then
                vim.api.nvim_win_set_buf(0, previous_buf)
                return true
            end

            local previous_descriptor = vim.w.config_dashboard_previous_descriptor

            if type(previous_descriptor) == "table" then
                if previous_descriptor.kind == "file" then
                    local path = previous_descriptor.path

                    if type(path) == "string" and path ~= "" and vim.fn.filereadable(path) == 1 then
                        local buf = vim.fn.bufadd(path)

                        vim.fn.bufload(buf)
                        vim.bo[buf].buflisted = true
                        vim.w.config_dashboard_previous_buf = buf

                        if is_returnable_buffer(buf) then
                            vim.api.nvim_win_set_buf(0, buf)
                            vim.w.config_dashboard_previous_descriptor = nil
                            return true
                        end
                    end
                elseif previous_descriptor.kind == "terminal" then
                    local ok, terminal = pcall(require, "config.terminal")

                    if ok and type(terminal.create_buffer_terminal) == "function" then
                        if
                            type(previous_descriptor.cwd) == "string"
                            and vim.fn.isdirectory(previous_descriptor.cwd) == 1
                        then
                            pcall(vim.cmd, "lcd " .. vim.fn.fnameescape(previous_descriptor.cwd))
                        end

                        terminal.create_buffer_terminal()
                        vim.w.config_dashboard_previous_descriptor = nil
                        return true
                    end
                end
            end

            vim.w.config_dashboard_previous_buf = nil
            vim.w.config_dashboard_previous_descriptor = nil

            return false
        end

        local function close_dashboard_or_quit()
            if return_to_previous_buffer() then
                return
            end

            if regular_window_count() > 1 then
                vim.cmd("quit")
                return
            end

            vim.cmd("DashboardQuit")
        end

        local function redraw_dashboard()
            dashboard.section.header.val = make_header()
            alpha.setup(dashboard.opts)
            pcall(vim.cmd, "AlphaRedraw")
        end

        dashboard.section.header.val = make_header()
        dashboard.section.buttons.val = dashboard_buttons
        dashboard.section.footer.val = {}

        alpha.setup(dashboard.opts)

        vim.api.nvim_create_autocmd("User", {
            pattern = "AlphaReady",
            callback = function()
                local opts = {
                    buffer = true,
                    silent = true,
                }

                for _, button in ipairs(dashboard_buttons) do
                    local key = dashboard_shortcut(button)

                    if key and key ~= "" and not has_exact_leader_mapping(key) then
                        vim.keymap.set("n", "<leader>" .. key, "<Nop>", opts)
                    end
                end

                vim.keymap.set("n", "j", function()
                    move_dashboard_cursor(1)
                end, opts)
                vim.keymap.set("n", "<Down>", function()
                    move_dashboard_cursor(1)
                end, opts)
                vim.keymap.set("n", "k", function()
                    move_dashboard_cursor(-1)
                end, opts)
                vim.keymap.set("n", "<Up>", function()
                    move_dashboard_cursor(-1)
                end, opts)

                vim.keymap.set("n", "<leader>q", close_dashboard_or_quit, opts)
                vim.keymap.set("n", "<leader>h", function()
                    if not return_to_previous_buffer() then
                        redraw_dashboard()
                    end
                end, opts)
            end,
        })

        vim.api.nvim_create_user_command("DashboardHome", function()
            if is_dashboard_buffer(vim.api.nvim_get_current_buf()) then
                if return_to_previous_buffer() then
                    return
                end

                redraw_dashboard()
                return
            else
                remember_current_buffer()
            end

            dashboard.section.header.val = make_header()
            alpha.setup(dashboard.opts)
            vim.cmd("Alpha")

            local ok_empty, empty_buffers = pcall(require, "config.empty_buffers")

            if ok_empty then
                empty_buffers.cleanup({
                    keep = { vim.api.nvim_get_current_buf() },
                })
            end
        end, {})
    end,
}
