local buffers = require("config.floating.buffers")
local state = require("config.floating.state")
local window = require("config.floating.window")

local M = {}

local function hide_float_terminal_if_visible()
    local ok_terminal, terminal = pcall(require, "config.terminal")

    if ok_terminal then
        terminal.hide_float_terminal_if_visible()
    end
end

local function terminal_job_running(buf)
    local job_id = vim.b[buf].terminal_job_id

    return type(job_id) == "number" and vim.fn.jobwait({ job_id }, 0)[1] == -1
end

local function show_home(slot_id)
    local item = state.slot(slot_id)
    local buf = buffers.create_home(slot_id)
    local listed_empty_before = buffers.listed_empty()

    item.buf = buf

    if state.valid_window(item.win) then
        vim.api.nvim_win_set_buf(item.win, buf)
        vim.api.nvim_set_current_win(item.win)
    else
        window.open(slot_id, buf)
    end

    pcall(vim.cmd, "DashboardHome")

    local current = vim.api.nvim_get_current_buf()

    if state.valid_buffer(buf) and buf ~= current then
        pcall(vim.api.nvim_buf_delete, buf, {
            force = true,
        })
    end

    vim.bo[current].buflisted = false
    item.buf = current
    state.mark_buffer(current, slot_id)
    buffers.cleanup_new_listed_empty(listed_empty_before)
    buffers.cleanup_empty()
    window.update_title(slot_id)
end

function M.is_slot_window(win)
    return state.is_slot_window(win)
end

function M.window_slot_id(win)
    return state.window_slot_id(win)
end

function M.slot_label(slot_id)
    return state.label(slot_id)
end

function M.is_slot_buffer(buf)
    return state.is_slot_buffer(buf)
end

function M.slot_label_for_buffer(buf)
    return state.slot_label_for_buffer(buf)
end

function M.assigned_slots_by_buffer()
    return state.assigned_slots_by_buffer()
end

function M.slot_sort_rank(buf)
    return state.slot_sort_rank(buf)
end

function M.current_slots()
    return state.current_slots()
end

function M.slot_ids()
    return state.slot_ids()
end

function M.restore_slot(slot_id, file, opts)
    opts = opts or {}

    if type(file) ~= "string" or file == "" or vim.fn.filereadable(file) == 0 then
        return false
    end

    local buf = vim.fn.bufadd(file)

    vim.fn.bufload(buf)
    vim.bo[buf].buflisted = true

    local item = state.slot(slot_id)

    item.buf = buf
    state.mark_buffer(buf, slot_id)

    if opts.visible then
        M.open_buffer(buf, {
            slot_id = slot_id,
        })
    end

    return true
end

function M.open_slot(slot_id)
    local item = state.slot(slot_id)

    window.hide_other_slots(slot_id)
    hide_float_terminal_if_visible()

    if state.valid_window(item.win) then
        vim.api.nvim_set_current_win(item.win)
        return item.win
    end

    if state.valid_buffer(item.buf) then
        return window.open(slot_id, item.buf)
    end

    show_home(slot_id)
    buffers.cleanup_empty()

    return item.win
end

function M.show_buffer_slot(buf)
    if not state.valid_buffer(buf) then
        return false
    end

    for slot_id, item in pairs(state.slots) do
        if item.buf == buf then
            window.hide_other_slots(slot_id)
            hide_float_terminal_if_visible()

            if state.valid_window(item.win) then
                vim.api.nvim_set_current_win(item.win)
            else
                window.open(slot_id, buf)
            end

            buffers.cleanup_empty()
            return true
        end
    end

    local slot_id = vim.b[buf].floating_slot_id

    if slot_id == nil then
        return false
    end

    local item = state.slot(slot_id)

    item.buf = buf
    window.hide_other_slots(slot_id)
    hide_float_terminal_if_visible()

    if state.valid_window(item.win) then
        vim.api.nvim_win_set_buf(item.win, buf)
        vim.api.nvim_set_current_win(item.win)
    else
        window.open(slot_id, buf)
    end

    window.update_title(slot_id)
    buffers.cleanup_empty()

    return true
end

function M.toggle(slot_id)
    local item = state.slot(slot_id)

    if state.valid_window(item.win) then
        window.hide_slot(slot_id)
        return
    end

    M.open_slot(slot_id)
end

function M.open_buffer(buf, opts)
    opts = opts or {}

    if not state.valid_buffer(buf) then
        return false
    end

    local slot_id = opts.slot_id or M.window_slot_id()

    if slot_id == nil then
        return false
    end

    local item = state.slot(slot_id)

    window.hide_other_slots(slot_id)
    hide_float_terminal_if_visible()

    if not state.valid_window(item.win) then
        window.open(slot_id, state.valid_buffer(item.buf) and item.buf or buffers.create_home(slot_id))
    end

    local old_buf = vim.api.nvim_win_get_buf(item.win)

    vim.api.nvim_win_set_buf(item.win, buf)
    item.buf = buf
    state.mark_buffer(buf, slot_id)
    vim.api.nvim_set_current_win(item.win)
    window.update_title(slot_id)

    if old_buf ~= buf then
        state.clear_buffer_slot(old_buf, slot_id)
        buffers.safe_delete_old(old_buf, opts.force)
    end

    buffers.cleanup_empty()

    return true
end

function M.set_window_buffer(win, buf)
    if not state.valid_window(win) or not state.valid_buffer(buf) then
        return false
    end

    local slot_id = M.window_slot_id(win)

    if slot_id == nil then
        return false
    end

    local item = state.slot(slot_id)
    local old_buf = vim.api.nvim_win_get_buf(win)

    vim.api.nvim_win_set_buf(win, buf)
    item.win = win
    item.buf = buf
    state.mark_window(win, slot_id)
    state.mark_buffer(buf, slot_id)
    vim.api.nvim_set_current_win(win)
    window.update_title(slot_id)

    if old_buf ~= buf then
        state.clear_buffer_slot(old_buf, slot_id)
        buffers.cleanup_empty()
    end

    return true
end

function M.open_file(path, opts)
    if not path or path == "" then
        return false
    end

    local buf = vim.fn.bufadd(path)

    vim.fn.bufload(buf)
    vim.bo[buf].buflisted = true

    return M.open_buffer(buf, opts)
end

function M.close_current(force)
    local win = vim.api.nvim_get_current_win()
    local slot_id = M.window_slot_id(win)

    if slot_id == nil then
        return false
    end

    local item = state.slot(slot_id)
    local buf = vim.api.nvim_win_get_buf(win)

    if vim.bo[buf].buftype == "terminal" and terminal_job_running(buf) and not force then
        vim.notify("Terminal process is still running. Use Space Q to force.", vim.log.levels.WARN)
        return true
    end

    if vim.bo[buf].modified and not force then
        vim.notify("Buffer has unsaved changes. Use Space Q to force.", vim.log.levels.WARN)
        return true
    end

    state.clear_buffer_slot(buf, slot_id)
    item.buf = nil

    if state.valid_window(win) then
        pcall(vim.api.nvim_win_close, win, true)
    end

    item.win = nil
    item.view = nil
    item.cursor = nil

    if #state.visible_windows_for_buffer(buf) == 0 and state.valid_buffer(buf) then
        local ok, err = pcall(vim.api.nvim_buf_delete, buf, {
            force = force,
        })

        if not ok then
            vim.notify("Failed to delete buffer: " .. err, vim.log.levels.ERROR)
        end
    end

    buffers.cleanup_empty()

    return true
end

function M.reject_window_action()
    if M.is_slot_window() then
        vim.notify("Floating slots are separate from window splits and moves.", vim.log.levels.INFO)
        return true
    end

    return false
end

function M.hide_all()
    for slot_id in pairs(state.slots) do
        window.hide_slot(slot_id)
    end
end

return M
