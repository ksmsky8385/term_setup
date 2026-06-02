local M = {}

local function valid_buffer(buf)
    return buf and vim.api.nvim_buf_is_valid(buf)
end

local function job_running(job_id)
    return job_id and vim.fn.jobwait({ job_id }, 0)[1] == -1
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

local function stop_terminal_insert()
    vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true),
        "n",
        false
    )
end

local function window_labels()
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

function M.restore_terminal_window(buf)
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

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local terminal_buf = win_var(win, "terminal_buf")

        if M.valid_terminal(terminal_buf) then
            local previous_buf = vim.b[terminal_buf].terminal_previous_buf
            local previous_name = valid_buffer(previous_buf)
                    and vim.api.nvim_buf_get_name(previous_buf)
                or "[No Name]"

            if previous_name == "" then
                previous_name = "[No Name]"
            else
                previous_name = vim.fn.fnamemodify(previous_name, ":t")
            end

            table.insert(terminals, {
                win = win,
                buf = terminal_buf,
                job = vim.b[terminal_buf].terminal_job_id,
                shell = shell_name(),
                previous = previous_name,
                visible = vim.api.nvim_win_get_buf(win) == terminal_buf,
                window_label = labels[win] or "?",
            })
        end
    end

    return terminals
end

function M.show_terminal(index)
    local terminal = M.terminals()[index]

    if not terminal or not vim.api.nvim_win_is_valid(terminal.win) then
        vim.notify("No terminal at index " .. index, vim.log.levels.WARN)
        return
    end

    vim.api.nvim_set_current_win(terminal.win)
    vim.api.nvim_win_set_buf(terminal.win, terminal.buf)
    stop_terminal_insert()
    refresh_tree()
end

function M.pick_terminal()
    local terminals = M.terminals()

    if #terminals == 0 then
        vim.notify("No running terminals", vim.log.levels.INFO)
        return
    end

    local lines = {}

    for idx, terminal in ipairs(terminals) do
        local state = terminal.visible and "visible" or "hidden"
        table.insert(
            lines,
            string.format(
                "%d: [%s] %s (%s)",
                idx,
                terminal.window_label,
                terminal.shell,
                state
            )
        )
    end

    table.insert(lines, "Type number and <Enter> (Enter/Space/Esc cancels): ")

    local ok, choice = pcall(vim.fn.input, table.concat(lines, "\n"))

    if not ok then
        return
    end

    if choice == "" or choice == " " or string.lower(choice) == "q" then
        return
    end

    local index = tonumber(choice)

    if not index then
        vim.notify("Invalid terminal number: " .. choice, vim.log.levels.WARN)
        return
    end

    M.show_terminal(index)
end

return M
