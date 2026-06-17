local policy = require("config.buffers.policy")
local state = require("config.buffers.state")
local tabs = require("config.buffers.window_tabs")
local visibility = require("config.buffers.window_visibility")
local empty_buffers = require("config.empty_buffers")

local M = {}

local function set_window_buffer(win, buf)
    local ok_floating, floating = pcall(require, "config.floating")

    if ok_floating and floating.is_slot_window(win) then
        return floating.set_window_buffer(win, buf)
    end

    vim.api.nvim_win_set_buf(win, buf)
    return true
end

local function can_delete_unique_window_buffer(buf, force)
    if not vim.api.nvim_buf_is_valid(buf) then
        return false
    end

    if not state.movable(buf) then
        return false
    end

    if visibility.all_visible_count(buf) ~= 1 then
        return false
    end

    return state.delete_blocker(buf, force) == nil
end

local function move_between_windows(buf, source_win, target_win)
    if not state.movable(buf) then
        vim.notify("Buffer can't be moved", vim.log.levels.WARN)
        return false
    end

    if not vim.api.nvim_win_is_valid(target_win) then
        return false
    end

    local target_buf = vim.api.nvim_win_get_buf(target_win)

    if source_win and source_win == target_win then
        return true
    end

    if source_win and vim.api.nvim_win_is_valid(source_win) then
        if state.movable(target_buf) then
            set_window_buffer(source_win, target_buf)
        else
            set_window_buffer(source_win, state.fallback_for_displaced())
        end
    end

    set_window_buffer(target_win, buf)

    return true
end

function M.move_buffer_to_window(buf, target_win)
    return move_between_windows(buf, visibility.any_visible_for_buffer(buf), target_win)
end

function M.move_current_to_window()
    local buf = vim.api.nvim_get_current_buf()
    local source_win = vim.api.nvim_get_current_win()
    local original_tabpage = vim.api.nvim_get_current_tabpage()
    local ok_picker, window_picker = pcall(require, "config.window_picker")

    if not ok_picker then
        return false
    end

    if not tabs.pick_tab_for_window() then
        return false
    end

    local target_win = window_picker.pick_window(policy.window_picker_exclude)

    if not target_win or target_win == -1 then
        tabs.restore_tabpage(original_tabpage, source_win)
        return false
    end

    return move_between_windows(buf, source_win, target_win)
end

function M.open_current_in_window()
    local buf = vim.api.nvim_get_current_buf()
    local original_win = vim.api.nvim_get_current_win()
    local original_tabpage = vim.api.nvim_get_current_tabpage()
    local ok_picker, window_picker = pcall(require, "config.window_picker")

    if not state.movable(buf) then
        vim.notify("Buffer can't be opened in window", vim.log.levels.WARN)
        return false
    end

    if not ok_picker then
        return false
    end

    if not tabs.pick_tab_for_window() then
        return false
    end

    local target_win = window_picker.pick_window(policy.window_picker_exclude)

    if not target_win or target_win == -1 then
        tabs.restore_tabpage(original_tabpage, original_win)
        return false
    end

    return M.open_buffer_in_window(buf, target_win)
end

function M.open_buffer_in_window(buf, target_win, opts)
    opts = opts or {}

    if not vim.api.nvim_buf_is_valid(buf) then
        return false
    end

    if not vim.api.nvim_win_is_valid(target_win) then
        return false
    end

    local old_buf = vim.api.nvim_win_get_buf(target_win)

    if old_buf == buf then
        return true
    end

    local old_visible_count = visibility.all_visible_count(old_buf)
    local delete_old = opts.delete_old_if_safe
        and old_visible_count == 1
        and state.movable(old_buf)

    if delete_old then
        local can_delete = can_delete_unique_window_buffer(old_buf, opts.force)

        if not can_delete then
            local blocker = state.delete_blocker(old_buf, opts.force)

            if blocker then
                vim.notify(blocker, vim.log.levels.WARN)
            end
        end

        set_window_buffer(target_win, buf)

        if can_delete then
            local ok, err = state.delete(old_buf, opts.force)

            if not ok then
                state.notify_delete_error(err)
            end
        end

        return true
    end

    set_window_buffer(target_win, buf)

    return true
end

function M.open_buffer_in_split(buf, target_win, split_cmd)
    if not state.movable(buf) then
        vim.notify("Buffer can't be opened in split", vim.log.levels.WARN)
        return false
    end

    if not vim.api.nvim_win_is_valid(target_win) then
        return false
    end

    local ok_floating, floating = pcall(require, "config.floating")

    if ok_floating and floating.is_slot_window(target_win) then
        vim.notify("Floating slots do not support splits.", vim.log.levels.WARN)
        return false
    end

    vim.api.nvim_set_current_win(target_win)

    local ok, err = pcall(vim.cmd, split_cmd)

    if not ok then
        vim.notify(err, vim.log.levels.ERROR)
        return false
    end

    vim.api.nvim_win_set_buf(0, buf)
    empty_buffers.cleanup({
        keep = { buf },
    })

    return true
end

return M
