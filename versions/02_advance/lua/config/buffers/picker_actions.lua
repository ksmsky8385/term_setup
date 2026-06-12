local telescope_picker = require("config.picker")
local policy = require("config.buffers.policy")
local state = require("config.buffers.state")
local windows = require("config.buffers.windows")
local actions = require("config.buffers.actions")

local M = {}

local function selected_buffer(prompt_bufnr)
    local selection = telescope_picker.selected_entry(prompt_bufnr)

    if not selection then
        return nil
    end

    return selection.bufnr
end

local function close_picker(prompt_bufnr)
    telescope_picker.close(prompt_bufnr)
end

local function confirm_action(message)
    vim.api.nvim_echo({
        { message .. " Press Enter to confirm, Esc to cancel.", "WarningMsg" },
    }, false, {})

    local ok, input = pcall(vim.fn.getcharstr)

    vim.cmd("redraw")
    vim.api.nvim_echo({}, false, {})

    if not ok then
        return false
    end

    return input == "\13" or input == "\10" or input == "\r"
end

function M.open_selected(prompt_bufnr, operations)
    local buf = selected_buffer(prompt_bufnr)

    if not buf then
        return
    end

    local existing_win = windows.first_selectable_for_buffer(buf)

    close_picker(prompt_bufnr)

    local ok_terminal, terminal = pcall(require, "config.terminal")

    if ok_terminal and terminal.is_float_terminal(buf) then
        terminal.show_float_terminal(buf)
        return
    end

    local ok_floating, floating = pcall(require, "config.floating")

    if ok_floating and floating.show_buffer_slot(buf) then
        return
    end

    if existing_win and vim.api.nvim_win_is_valid(existing_win) then
        vim.api.nvim_set_current_win(existing_win)
        return
    end

    vim.schedule(function()
        local ok_picker, window_picker = pcall(require, "config.window_picker")

        if not ok_picker then
            vim.api.nvim_win_set_buf(0, buf)
            return
        end

        local target_win = window_picker.pick_window(policy.window_picker_exclude)

        if not target_win or target_win == -1 then
            operations.pick()
            return
        end

        if operations.move_buffer_to_window(buf, target_win) then
            vim.api.nvim_set_current_win(target_win)
        end
    end)
end

function M.delete_selected(prompt_bufnr, force, operations)
    local buf = selected_buffer(prompt_bufnr)

    if not buf then
        return
    end

    local next_buf = state.next_after_deleted(buf)

    if
        not confirm_action(
            string.format(
                "%s buffer %d (%s)?",
                force and "Force delete" or "Delete",
                buf,
                state.name(buf)
            )
        )
    then
        return
    end

    local cleared_windows = windows.clear_showing_buffer(buf)

    local ok, err = state.delete(buf, force)

    if not ok then
        windows.restore_after_failed_delete(buf, cleared_windows)
        state.notify_delete_error(err)
        return
    end

    close_picker(prompt_bufnr)
    vim.schedule(function()
        operations.pick(next_buf)
    end)
end

function M.keep_selected_only(prompt_bufnr, force, operations)
    local buf = selected_buffer(prompt_bufnr)

    if not buf then
        return
    end

    if
        not confirm_action(
            string.format(
                "%s every buffer except %d (%s)?",
                force and "Force delete" or "Delete",
                buf,
                state.name(buf)
            )
        )
    then
        return
    end

    local ok, err = actions.delete_others_except(buf, force, {
        keep_windows = windows.all_visible_for_buffer(buf),
    })

    if not ok then
        state.notify_delete_error(err)
        return
    end

    close_picker(prompt_bufnr)
    vim.schedule(function()
        operations.pick(buf)
    end)
end

local function pick_target_window(buf, on_pick, operations)
    local original_tabpage = vim.api.nvim_get_current_tabpage()
    local original_win = vim.api.nvim_get_current_win()

    vim.schedule(function()
        local ok_picker, window_picker = pcall(require, "config.window_picker")

        if not ok_picker then
            return
        end

        if not windows.pick_tab_for_window() then
            operations.pick(buf)
            return
        end

        local target_win = window_picker.pick_window(policy.window_picker_exclude)

        if not target_win or target_win == -1 then
            windows.restore_tabpage(original_tabpage, original_win)
            operations.pick(buf)
            return
        end

        on_pick(target_win)
    end)
end

function M.move_selected(prompt_bufnr, operations)
    local buf = selected_buffer(prompt_bufnr)

    if not buf then
        return
    end

    close_picker(prompt_bufnr)
    pick_target_window(buf, function(target_win)
        operations.move_buffer_to_window(buf, target_win)
    end, operations)
end

function M.split_selected(prompt_bufnr, split_cmd, operations)
    local buf = selected_buffer(prompt_bufnr)

    if not buf then
        return
    end

    close_picker(prompt_bufnr)
    pick_target_window(buf, function(target_win)
        operations.open_buffer_in_split(buf, target_win, split_cmd)
    end, operations)
end

function M.open_in_window_selected(prompt_bufnr, operations)
    local buf = selected_buffer(prompt_bufnr)

    if not buf then
        return
    end

    if not state.movable(buf) then
        vim.notify("Buffer can't be opened in window", vim.log.levels.WARN)
        return
    end

    close_picker(prompt_bufnr)
    pick_target_window(buf, function(target_win)
        operations.open_buffer_in_window(buf, target_win)
    end, operations)
end

return M
