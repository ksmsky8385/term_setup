local M = {}
local empty_buffers = require("config.empty_buffers")

local function valid_buffer(buf)
    return buf and vim.api.nvim_buf_is_valid(buf)
end

local function job_running(job_id)
    return job_id and vim.fn.jobwait({ job_id }, 0)[1] == -1
end

local function shell_name()
    return vim.fn.fnamemodify(vim.o.shell, ":t"):gsub("%.exe$", "")
end

local function stop_terminal_insert()
    vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true),
        "n",
        false
    )
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

function M.actual_cwd(buf)
    if not M.valid_terminal(buf) then
        return nil
    end

    local ok_pid, pid = pcall(vim.fn.jobpid, vim.b[buf].terminal_job_id)

    if not ok_pid or type(pid) ~= "number" or pid <= 0 then
        return nil
    end

    local cwd = vim.uv.fs_readlink("/proc/" .. pid .. "/cwd")

    if type(cwd) ~= "string" or vim.fn.isdirectory(cwd) == 0 then
        return nil
    end

    return vim.fs.normalize(cwd)
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

    return shell_name() .. " [Terminal]"
end

function M.configure_window(win)
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    vim.wo[win].foldcolumn = "0"
    vim.wo[win].statuscolumn = ""
    vim.wo[win].list = false
    vim.wo[win].spell = false
    vim.wo[win].cursorline = false
    vim.wo[win].cursorcolumn = false
end

function M.start_pending(win)
    local buf = vim.api.nvim_win_get_buf(win)
    local saved = vim.b[buf].pending_terminal_restore
    if not saved then return true end
    local cwd = type(saved.cwd) == "string" and vim.fn.isdirectory(saved.cwd) == 1
        and saved.cwd or vim.fn.getcwd()

    M.configure_window(win)
    local ok, job = pcall(vim.api.nvim_win_call, win, function()
        return vim.fn.termopen(vim.o.shell, { cwd = cwd })
    end)
    if not ok or type(job) ~= "number" or job <= 0 then
        vim.notify("Failed to restore terminal: " .. tostring(job), vim.log.levels.ERROR)
        return false
    end
    vim.b[buf].pending_terminal_restore = nil
    return true
end

function M.restore_buffer(saved, win)
    local buf = vim.api.nvim_create_buf(true, false)
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
    vim.b[buf].pending_terminal_restore = { cwd = saved.cwd or vim.fn.getcwd() }
    if win then
        vim.api.nvim_win_set_buf(win, buf)
        M.start_pending(win)
    end
    return buf
end

function M.setup()
    local group = vim.api.nvim_create_augroup("TerminalWindowOptions", { clear = true })
    vim.api.nvim_create_autocmd({ "TermOpen", "BufWinEnter", "WinEnter" }, {
        group = group,
        callback = function()
            local win = vim.api.nvim_get_current_win()
            if vim.bo.buftype == "terminal" then M.configure_window(win) end
        end,
    })
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

    vim.bo[terminal_buf].buflisted = true

    local current_win = vim.api.nvim_get_current_win()
    local ok_floating, floating = pcall(require, "config.floating")

    if ok_floating and floating.is_slot_window(current_win) then
        floating.set_window_buffer(current_win, terminal_buf)
    end

    if vim.b[terminal_buf].terminal_job_id then
        stop_terminal_insert()
    end

    empty_buffers.cleanup({
        keep = { terminal_buf },
    })
    refresh_tree()
end

function M.create_buffer_terminal_split(split_cmd)
    M.create_buffer_terminal({
        split_cmd = split_cmd,
    })
end

function M.clear_current_terminal()
    local current_buf = vim.api.nvim_get_current_buf()

    if vim.bo[current_buf].buftype ~= "terminal" then
        return
    end

    local current_win = vim.api.nvim_get_current_win()
    local old_job_id = vim.b[current_buf].terminal_job_id
    local new_buf = vim.api.nvim_create_buf(true, false)
    local ok_floating, floating = pcall(require, "config.floating")
    local is_slot_window = ok_floating and floating.is_slot_window(current_win)

    vim.b[current_buf].terminal_closing = true

    vim.api.nvim_win_set_buf(current_win, new_buf)

    vim.bo[new_buf].buflisted = true

    local new_job_id = vim.fn.termopen(vim.o.shell)
    vim.b[new_buf].terminal_job_id = new_job_id

    if is_slot_window then
        floating.set_window_buffer(current_win, new_buf)
    end

    if job_running(old_job_id) then
        pcall(vim.fn.jobstop, old_job_id)
    end

    stop_terminal_insert()
    refresh_tree()
    empty_buffers.cleanup({
        keep = { new_buf },
    })

    vim.schedule(function()
        if valid_buffer(current_buf) then
            pcall(vim.api.nvim_buf_delete, current_buf, { force = true })
        end

        empty_buffers.cleanup({
            keep = { new_buf },
        })
        refresh_tree()
    end)
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

    empty_buffers.cleanup()
    refresh_tree()
end

return M
