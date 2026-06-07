local M = {}

local BUFFER_TERMINAL_KIND = "buffer"
local FLOAT_TERMINAL_KIND = "float"
local float_terminal = {
    buf = nil,
    win = nil,
    view = nil,
    cursor = nil,
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

local function shell_name()
    return vim.fn.fnamemodify(vim.o.shell, ":t")
end

local function terminal_label(buf)
    if vim.b[buf].terminal_kind == FLOAT_TERMINAL_KIND then
        return "[Floating]"
    end

    return "[Terminal]"
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

local function save_float_terminal_view(win)
    if not valid_window(win) then
        return
    end

    local current_win = vim.api.nvim_get_current_win()
    local ok_set = pcall(vim.api.nvim_set_current_win, win)

    if not ok_set then
        return
    end

    local ok_view, view = pcall(vim.fn.winsaveview)
    local ok_cursor, cursor = pcall(vim.api.nvim_win_get_cursor, win)

    if ok_view then
        float_terminal.view = view
    end

    if ok_cursor then
        float_terminal.cursor = cursor
    end

    if valid_window(current_win) and current_win ~= win then
        pcall(vim.api.nvim_set_current_win, current_win)
    end
end

local function restore_float_terminal_view(win)
    if not valid_window(win) then
        return
    end

    local current_win = vim.api.nvim_get_current_win()
    local ok_set = pcall(vim.api.nvim_set_current_win, win)

    if not ok_set then
        return
    end

    if float_terminal.cursor then
        pcall(vim.api.nvim_win_set_cursor, win, float_terminal.cursor)
    end

    if float_terminal.view then
        pcall(vim.fn.winrestview, float_terminal.view)
    end

    if valid_window(current_win) and current_win ~= win then
        pcall(vim.api.nvim_set_current_win, current_win)
    end
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

function M.is_float_terminal(buf)
    return valid_buffer(buf)
        and vim.bo[buf].buftype == "terminal"
        and vim.b[buf].terminal_kind == FLOAT_TERMINAL_KIND
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

function M.create_buffer_terminal(opts)
    opts = opts or {}

    if opts.split_cmd then
        local ok_picker, window_picker = pcall(require, "config.window_picker")

        if ok_picker then
            window_picker.remember_window()
        end

        vim.cmd(opts.split_cmd)
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

function M.create_buffer_terminal_split(split_cmd)
    M.create_buffer_terminal({
        split_cmd = split_cmd,
    })
end

function M.hide_float_terminal()
    if valid_window(float_terminal.win) then
        save_float_terminal_view(float_terminal.win)
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
        save_float_terminal_view(win)
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
    restore_float_terminal_view(win)

    vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(win),
        once = true,
        callback = function()
            if float_terminal.win == win then
                save_float_terminal_view(win)
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
    float_terminal.view = nil
    float_terminal.cursor = nil

    vim.bo[buf].buflisted = true
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].filetype = "FloatingTerminal"
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
                save_float_terminal_view(win)
                float_terminal.win = nil
            end

            refresh_tree()
        end,
    })

    stop_terminal_insert()
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
