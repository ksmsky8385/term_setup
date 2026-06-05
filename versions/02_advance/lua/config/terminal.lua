local M = {}

local EX_TERMINAL_KIND = "ex"
local BUFFER_TERMINAL_KIND = "buffer"
local FLOAT_TERMINAL_KIND = "float"
local float_terminal = {
    buf = nil,
    win = nil,
}

local function valid_buffer(buf)
    return buf and vim.api.nvim_buf_is_valid(buf)
end

local function job_running(job_id)
    return job_id and vim.fn.jobwait({ job_id }, 0)[1] == -1
end

local function mark_closing(buf)
    if not valid_buffer(buf) then
        return false
    end

    if vim.b[buf].terminal_closing then
        return true
    end

    vim.b[buf].terminal_closing = true
    return false
end

local function win_var(win, name)
    local ok, value = pcall(vim.api.nvim_win_get_var, win, name)

    if ok then
        return value
    end

    return nil
end

local function shell_name()
    return vim.fn.fnamemodify(vim.o.shell, ":t")
end

local function terminal_label(buf)
    if vim.b[buf].terminal_kind == EX_TERMINAL_KIND then
        return "[Toggle]"
    end

    if vim.b[buf].terminal_kind == FLOAT_TERMINAL_KIND then
        return "[Floating]"
    end

    return "[Buffer]"
end

local function stop_terminal_insert()
    vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true),
        "n",
        false
    )
end

local function floating_terminal_size()
    local width = math.floor(vim.o.columns * 0.82)
    local height = math.floor(vim.o.lines * 0.72)

    width = math.max(width, 60)
    height = math.max(height, 12)
    width = math.min(width, vim.o.columns - 4)
    height = math.min(height, vim.o.lines - 4)

    return width, height
end

local function floating_terminal_config()
    local width, height = floating_terminal_size()

    return {
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = "minimal",
        border = "rounded",
        title = " " .. shell_name() .. " [Floating] ",
        title_pos = "center",
    }
end

local function valid_window(win)
    return win and vim.api.nvim_win_is_valid(win)
end

local function configure_floating_window(win)
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
end

local function window_labels()
    local ok_picker, window_picker = pcall(require, "config.window_picker")

    if ok_picker then
        local labels = {}
        local exclude = {
            filetype = {
                "NvimTree",
                "notify",
            },
        }

        for _, win in ipairs(window_picker.selectable_windows(exclude)) do
            labels[win] = window_picker.label_for_window(win, exclude)
        end

        return labels
    end

    local labels = {}
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local index = 1

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        local filetype = vim.bo[buf].filetype

        if filetype ~= "NvimTree" and filetype ~= "notify" then
            labels[win] = chars:sub(index, index)
            index = index + 1
        end
    end

    return labels
end

local function refresh_tree()
    local ok, api = pcall(require, "nvim-tree.api")

    if ok then
        pcall(api.tree.reload)
    end
end

function M.valid_terminal(buf)
    return valid_buffer(buf)
        and vim.bo[buf].buftype == "terminal"
        and job_running(vim.b[buf].terminal_job_id)
end

function M.is_ex_terminal(buf)
    return valid_buffer(buf)
        and vim.bo[buf].buftype == "terminal"
        and vim.b[buf].terminal_kind == EX_TERMINAL_KIND
end

function M.is_float_terminal(buf)
    return valid_buffer(buf)
        and vim.bo[buf].buftype == "terminal"
        and vim.b[buf].terminal_kind == FLOAT_TERMINAL_KIND
end

function M.status_label(buf)
    if not buf then
        local win = vim.g.statusline_winid or vim.api.nvim_get_current_win()
        buf = vim.api.nvim_win_get_buf(win)
    end

    if M.is_ex_terminal(buf) then
        return "[Toggle]"
    end

    if vim.bo[buf].buftype == "terminal" then
        return terminal_label(buf)
    end

    return ""
end

function M.is_status_terminal()
    local win = vim.g.statusline_winid or vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(win)

    return vim.bo[buf].buftype == "terminal"
end

function M.status_name()
    local win = vim.g.statusline_winid or vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(win)

    if vim.bo[buf].buftype ~= "terminal" then
        return ""
    end

    return shell_name() .. " " .. terminal_label(buf)
end

function M.restore_terminal_window(buf)
    if not valid_buffer(buf) then
        refresh_tree()
        return
    end

    local previous_buf = vim.b[buf].terminal_previous_buf

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == buf then
            if valid_buffer(previous_buf) then
                vim.api.nvim_win_set_buf(win, previous_buf)
            else
                vim.api.nvim_win_set_buf(win, vim.api.nvim_create_buf(true, false))
            end
        end
    end

    if valid_buffer(buf) then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end

    refresh_tree()
end

function M.setup_lifecycle(terminal_buf, terminal_win, job_id)
    vim.b[terminal_buf].terminal_job_id = job_id
    vim.b[terminal_buf].terminal_previous_buf = vim.w.terminal_previous_buf
    vim.b[terminal_buf].terminal_kind = EX_TERMINAL_KIND

    vim.api.nvim_create_autocmd("TermClose", {
        buffer = terminal_buf,
        once = true,
        callback = function()
            vim.schedule(function()
                M.restore_terminal_window(terminal_buf)
            end)
        end,
    })

    vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(terminal_win),
        once = true,
        callback = function()
            if M.valid_terminal(terminal_buf) then
                pcall(vim.fn.jobstop, vim.b[terminal_buf].terminal_job_id)
            end

            refresh_tree()
        end,
    })
end

function M.create_buffer_terminal()
    if vim.bo.filetype == "NvimTree" then
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            local buf = vim.api.nvim_win_get_buf(win)
            local filetype = vim.bo[buf].filetype

            if filetype ~= "NvimTree" and filetype ~= "notify" then
                vim.api.nvim_set_current_win(win)
                break
            end
        end
    end

    vim.cmd("terminal")

    local terminal_buf = vim.api.nvim_get_current_buf()

    vim.b[terminal_buf].terminal_kind = BUFFER_TERMINAL_KIND
    vim.b[terminal_buf].terminal_previous_buf = vim.fn.bufnr("#")
    vim.bo[terminal_buf].buflisted = true

    if vim.b[terminal_buf].terminal_job_id then
        stop_terminal_insert()
    end

    refresh_tree()
end

function M.hide_float_terminal()
    if valid_window(float_terminal.win) then
        pcall(vim.api.nvim_win_close, float_terminal.win, true)
    end

    float_terminal.win = nil
    refresh_tree()
end

function M.close_float_terminal(buf, win)
    buf = buf or float_terminal.buf
    win = win or float_terminal.win

    if mark_closing(buf) then
        return
    end

    if valid_window(win) then
        pcall(vim.api.nvim_win_close, win, true)
    end

    if valid_buffer(buf) then
        local job_id = vim.b[buf].terminal_job_id

        if job_running(job_id) then
            pcall(vim.fn.jobstop, job_id)
        end

        pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end

    if buf == float_terminal.buf then
        float_terminal.buf = nil
        float_terminal.win = nil
    end

    refresh_tree()
end

function M.show_float_terminal(buf)
    buf = buf or float_terminal.buf

    if not M.valid_terminal(buf) then
        return false
    end

    if valid_window(float_terminal.win) then
        vim.api.nvim_set_current_win(float_terminal.win)
        return true
    end

    local win = vim.api.nvim_open_win(buf, true, floating_terminal_config())

    float_terminal.buf = buf
    float_terminal.win = win
    configure_floating_window(win)

    vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(win),
        once = true,
        callback = function()
            if float_terminal.win == win then
                float_terminal.win = nil
            end

            refresh_tree()
        end,
    })

    stop_terminal_insert()
    refresh_tree()

    return true
end

local function create_float_terminal()
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, floating_terminal_config())

    float_terminal.buf = buf
    float_terminal.win = win

    vim.bo[buf].buflisted = false
    vim.bo[buf].bufhidden = "hide"
    configure_floating_window(win)

    local job_id = vim.fn.termopen(vim.o.shell)

    vim.b[buf].terminal_job_id = job_id
    vim.b[buf].terminal_kind = FLOAT_TERMINAL_KIND

    vim.api.nvim_create_autocmd("TermClose", {
        buffer = buf,
        once = true,
        callback = function()
            vim.schedule(function()
                M.close_float_terminal(buf, float_terminal.win)
            end)
        end,
    })

    vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(win),
        once = true,
        callback = function()
            if float_terminal.win == win then
                float_terminal.win = nil
            end

            refresh_tree()
        end,
    })

    vim.cmd("startinsert")
    refresh_tree()
end

function M.open_float_terminal()
    if valid_window(float_terminal.win) then
        M.hide_float_terminal()
        return
    end

    if M.show_float_terminal(float_terminal.buf) then
        return
    end

    create_float_terminal()
end

function M.toggle_window_terminal()
    local current_buf = vim.api.nvim_get_current_buf()

    if current_buf == vim.w.terminal_buf then
        if
            valid_buffer(vim.w.terminal_previous_buf)
            and vim.w.terminal_previous_buf ~= current_buf
        then
            vim.api.nvim_win_set_buf(0, vim.w.terminal_previous_buf)
        else
            vim.cmd("enew")
        end

        refresh_tree()
        return
    end

    vim.w.terminal_previous_buf = current_buf

    if M.valid_terminal(vim.w.terminal_buf) then
        vim.b[vim.w.terminal_buf].terminal_previous_buf = current_buf
        vim.api.nvim_win_set_buf(0, vim.w.terminal_buf)
        stop_terminal_insert()
        refresh_tree()
        return
    end

    local terminal_buf = vim.api.nvim_create_buf(false, true)
    local terminal_win = vim.api.nvim_get_current_win()

    vim.api.nvim_win_set_buf(0, terminal_buf)
    local job_id = vim.fn.termopen(vim.o.shell)

    vim.w.terminal_buf = terminal_buf
    vim.bo.buflisted = false
    M.setup_lifecycle(terminal_buf, terminal_win, job_id)
    stop_terminal_insert()
    refresh_tree()
end

function M.terminals()
    local terminals = {}
    local labels = window_labels()
    local seen = {}

    local function previous_name_for(buf)
        local previous_buf = vim.b[buf].terminal_previous_buf
        local previous_name = valid_buffer(previous_buf)
                and vim.api.nvim_buf_get_name(previous_buf)
            or "[No Name]"

        if previous_name == "" then
            return "[No Name]"
        end

        return vim.fn.fnamemodify(previous_name, ":t")
    end

    local function add_terminal(win, buf)
        if not M.valid_terminal(buf) or seen[buf] then
            return
        end

        seen[buf] = true

        if not vim.b[buf].terminal_kind then
            vim.b[buf].terminal_kind = BUFFER_TERMINAL_KIND
        end

        local visible_win = nil

        for _, candidate in ipairs(vim.api.nvim_list_wins()) do
            if vim.api.nvim_win_get_buf(candidate) == buf then
                visible_win = candidate
                break
            end
        end

        local display_win = visible_win or win

        table.insert(terminals, {
            win = display_win,
            buf = buf,
            job = vim.b[buf].terminal_job_id,
            shell = shell_name(),
            previous = previous_name_for(buf),
            label = terminal_label(buf),
            visible = visible_win ~= nil,
            window_label = display_win and labels[display_win] or "-",
        })
    end

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local terminal_buf = win_var(win, "terminal_buf")
        local visible_buf = vim.api.nvim_win_get_buf(win)

        add_terminal(win, terminal_buf)
        if valid_buffer(terminal_buf) then
            add_terminal(win, vim.b[terminal_buf].terminal_previous_buf)
        end
        add_terminal(win, visible_buf)
    end

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        add_terminal(nil, buf)
    end

    return terminals
end

local function target_window(terminal)
    if terminal.win and vim.api.nvim_win_is_valid(terminal.win) then
        return terminal.win
    end

    local current = vim.api.nvim_get_current_win()

    if vim.bo[vim.api.nvim_win_get_buf(current)].filetype ~= "NvimTree" then
        return current
    end

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local buf = vim.api.nvim_win_get_buf(win)
        local filetype = vim.bo[buf].filetype

        if filetype ~= "NvimTree" and filetype ~= "notify" then
            return win
        end
    end

    return current
end

local function terminal_owner_window(buf)
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if win_var(win, "terminal_buf") == buf then
            return win
        end
    end

    return nil
end

local function clear_window_terminal(win)
    if valid_window(win) then
        pcall(vim.api.nvim_win_del_var, win, "terminal_buf")
    end
end

local function set_window_terminal(win, buf)
    if valid_window(win) and valid_buffer(buf) then
        vim.api.nvim_win_set_var(win, "terminal_buf", buf)
    end
end

local function fallback_buffer_for_terminal(buf)
    local previous_buf = vim.b[buf].terminal_previous_buf

    if valid_buffer(previous_buf) and previous_buf ~= buf then
        return previous_buf
    end

    return vim.api.nvim_create_buf(true, false)
end

local function replace_visible_terminal(win, old_buf, new_buf)
    if
        valid_window(win)
        and valid_buffer(old_buf)
        and valid_buffer(new_buf)
        and vim.api.nvim_win_get_buf(win) == old_buf
    then
        vim.api.nvim_win_set_buf(win, new_buf)
    end
end

function M.show_terminal(index)
    local terminal = M.terminals()[index]

    if not terminal then
        vim.notify("No terminal at index " .. index, vim.log.levels.WARN)
        return
    end

    if M.is_float_terminal(terminal.buf) then
        M.show_float_terminal(terminal.buf)
        return
    end

    local win = target_window(terminal)

    vim.api.nvim_set_current_win(win)
    vim.api.nvim_win_set_buf(win, terminal.buf)
    stop_terminal_insert()
    refresh_tree()
end

local function selected_terminal(prompt_bufnr)
    local ok_state, action_state = pcall(require, "telescope.actions.state")

    if not ok_state then
        return nil
    end

    local selection = action_state.get_selected_entry(prompt_bufnr)

    return selection and selection.value or nil
end

local function close_picker(prompt_bufnr)
    local ok_actions, actions = pcall(require, "telescope.actions")

    if ok_actions then
        actions.close(prompt_bufnr)
    end
end

local function confirm_action(message)
    vim.api.nvim_echo({
        { message .. " Press Enter to confirm, Esc to cancel.", "WarningMsg" },
    }, false, {})

    local ok, input = pcall(vim.fn.getcharstr)

    vim.cmd("redraw")

    if not ok then
        return false
    end

    return input == "\13" or input == "\10" or input == "\r"
end

local function notify_terminal_error(err)
    if err then
        vim.notify(err, vim.log.levels.ERROR)
    end
end

local function kill_terminal(terminal)
    if not terminal or not valid_buffer(terminal.buf) then
        return true
    end

    local buf = terminal.buf
    local job_id = vim.b[buf].terminal_job_id

    if M.is_float_terminal(buf) then
        M.close_float_terminal(buf, terminal.win)
        return true
    end

    if M.is_ex_terminal(buf) then
        if job_running(job_id) then
            pcall(vim.fn.jobstop, job_id)
            return true
        else
            M.restore_terminal_window(buf)
        end

        return true
    end

    if job_running(job_id) then
        pcall(vim.fn.jobstop, job_id)
    end

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if valid_buffer(buf) and vim.api.nvim_win_get_buf(win) == buf then
            vim.api.nvim_win_set_buf(win, vim.api.nvim_create_buf(true, false))
        end
    end

    if valid_buffer(buf) then
        local ok, err = pcall(vim.api.nvim_buf_delete, buf, { force = true })

        if not ok then
            return false, "Failed to delete terminal buffer: " .. err
        end
    end

    refresh_tree()

    return true
end

local function kill_selected(prompt_bufnr)
    local terminal = selected_terminal(prompt_bufnr)

    if not terminal then
        return
    end

    if
        not confirm_action(
            string.format(
                "Terminate process in terminal buffer %d?",
                terminal.buf
            )
        )
    then
        return
    end

    local ok, err = kill_terminal(terminal)

    if not ok then
        notify_terminal_error(err)
        return
    end

    close_picker(prompt_bufnr)
    vim.schedule(M.pick_terminal)
end

local function keep_selected_only(prompt_bufnr)
    local selected = selected_terminal(prompt_bufnr)

    if not selected then
        return
    end

    if
        not confirm_action(
            string.format(
                "Terminate every terminal except buffer %d?",
                selected.buf
            )
        )
    then
        return
    end

    for _, terminal in ipairs(M.terminals()) do
        if terminal.buf ~= selected.buf then
            local ok, err = kill_terminal(terminal)

            if not ok then
                notify_terminal_error(err)
                return
            end
        end
    end

    close_picker(prompt_bufnr)

    if M.is_float_terminal(selected.buf) then
        M.show_float_terminal(selected.buf)
    else
        local win = target_window(selected)

        vim.api.nvim_set_current_win(win)
        vim.api.nvim_win_set_buf(win, selected.buf)
        stop_terminal_insert()
    end

    refresh_tree()
end

local function move_selected(prompt_bufnr)
    local selected = selected_terminal(prompt_bufnr)

    if not selected then
        return
    end

    close_picker(prompt_bufnr)

    vim.schedule(function()
        local ok_picker, window_picker = pcall(require, "config.window_picker")

        if not ok_picker then
            return
        end

        local target_win = window_picker.pick_window({
            filetype = {
                "NvimTree",
                "notify",
            },
        })

        if not target_win or target_win == -1 then
            return
        end

        M.move_terminal_to_window(selected, target_win)
    end)
end

function M.move_terminal_to_window(terminal, target_win)
    if not terminal or not valid_buffer(terminal.buf) then
        return false
    end

    if not valid_window(target_win) then
        return false
    end

    if M.is_float_terminal(terminal.buf) then
        M.show_float_terminal(terminal.buf)
        return true
    end

    if not M.is_ex_terminal(terminal.buf) then
        local ok_buffers, buffers = pcall(require, "config.buffers")

        if not ok_buffers then
            return false
        end

        return buffers.move_buffer_to_window(terminal.buf, target_win)
    end

    local source_win = terminal_owner_window(terminal.buf)
    local target_terminal = win_var(target_win, "terminal_buf")
    local target_buf = vim.api.nvim_win_get_buf(target_win)

    if source_win == target_win then
        vim.api.nvim_win_set_buf(target_win, terminal.buf)
        return true
    end

    if M.is_ex_terminal(target_terminal) then
        if valid_window(source_win) then
            set_window_terminal(source_win, target_terminal)
            vim.b[target_terminal].terminal_previous_buf = fallback_buffer_for_terminal(terminal.buf)
            replace_visible_terminal(source_win, terminal.buf, target_terminal)
        end

        set_window_terminal(target_win, terminal.buf)
        vim.b[terminal.buf].terminal_previous_buf = target_buf
        vim.api.nvim_win_set_buf(target_win, terminal.buf)
        refresh_tree()
        return true
    end

    if valid_window(source_win) then
        clear_window_terminal(source_win)
        replace_visible_terminal(
            source_win,
            terminal.buf,
            fallback_buffer_for_terminal(terminal.buf)
        )
    end

    set_window_terminal(target_win, terminal.buf)
    vim.b[terminal.buf].terminal_previous_buf = target_buf
    vim.api.nvim_win_set_buf(target_win, terminal.buf)
    stop_terminal_insert()
    refresh_tree()

    return true
end

local function terminal_display(terminal)
    local state = terminal.visible and "visible" or "hidden"

    return string.format(
        "[%s] %-3s %-8s %-8s %s",
        terminal.window_label,
        terminal.buf,
        terminal.label,
        state,
        terminal.shell
    )
end

local function terminal_entry_maker(terminal)
    local display = terminal_display(terminal)

    return {
        value = terminal,
        ordinal = table.concat({
            terminal.buf,
            terminal.window_label,
            terminal.label,
            terminal.shell,
            terminal.previous,
            terminal.visible and "visible" or "hidden",
        }, " "),
        display = display,
        bufnr = terminal.buf,
    }
end

function M.pick_terminal()
    local terminals = M.terminals()

    if #terminals == 0 then
        vim.notify("No running terminals", vim.log.levels.INFO)
        return
    end

    local ok = pcall(require, "telescope.pickers")

    if not ok then
        vim.notify("Telescope is not available", vim.log.levels.WARN)
        return
    end

    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local conf = require("telescope.config").values

    pickers.new({
        initial_mode = "normal",
        prompt_title = "Terminals",
        results_title = "Enter open | m move | D terminate process | O keep only | actions ask Enter",
    }, {
        finder = finders.new_table({
            results = terminals,
            entry_maker = terminal_entry_maker,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
            local open_selected = function()
                local terminal = action_state.get_selected_entry()

                actions.close(prompt_bufnr)

                if terminal and terminal.value then
                    local latest = M.terminals()

                    for index, candidate in ipairs(latest) do
                        if candidate.buf == terminal.value.buf then
                            M.show_terminal(index)
                            return
                        end
                    end
                end
            end

            actions.select_default:replace(open_selected)

            map("n", "D", function()
                kill_selected(prompt_bufnr)
            end)

            map("n", "O", function()
                keep_selected_only(prompt_bufnr)
            end)

            map("n", "m", function()
                move_selected(prompt_bufnr)
            end)

            return true
        end,
    }):find()
end

function M.kill_current_terminal(force)
    local opts = {}

    if type(force) == "table" then
        opts = force
        force = opts.force
    end

    local current_buf = vim.api.nvim_get_current_buf()

    if vim.bo[current_buf].buftype ~= "terminal" then
        vim.notify("Current buffer is not a terminal", vim.log.levels.WARN)
        return
    end

    local job_id = vim.b[current_buf].terminal_job_id

    if M.is_float_terminal(current_buf) then
        M.close_float_terminal(current_buf, float_terminal.win)
        return
    end

    if M.is_ex_terminal(current_buf) then
        if job_running(job_id) then
            pcall(vim.fn.jobstop, job_id)
        else
            M.restore_terminal_window(current_buf)
        end

        return
    end

    local was_running = job_running(job_id)

    if was_running then
        pcall(vim.fn.jobstop, job_id)
    end

    if opts.replace ~= false then
        vim.cmd("enew")
    end

    if valid_buffer(current_buf) then
        pcall(vim.api.nvim_buf_delete, current_buf, { force = force or was_running })
    end

    refresh_tree()
end

return M
