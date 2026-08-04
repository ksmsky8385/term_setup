local actions = require("config.buffers.actions")
local picker = require("config.buffers.picker")
local state = require("config.buffers.state")
local windows = require("config.buffers.windows")

local M = {}

function M.pick(initial_buf)
    picker.pick(initial_buf, {
        pick = M.pick,
        move_buffer_to_window = M.move_buffer_to_window,
        open_buffer_in_window = M.open_buffer_in_window,
        open_buffer_in_split = M.open_buffer_in_split,
    })
end

function M.pick_current()
    local current = vim.api.nvim_get_current_buf()

    if state.valid_listed(current) then
        M.pick(current)
        return
    end

    M.pick()
end

function M.pick_tab_for_window()
    return windows.pick_tab_for_window()
end

function M.next()
    local ok = pcall(vim.cmd, "bnext")

    if not ok then
        vim.notify("No next buffer", vim.log.levels.INFO)
    end
end

function M.previous()
    local ok = pcall(vim.cmd, "bprevious")

    if not ok then
        vim.notify("No previous buffer", vim.log.levels.INFO)
    end
end

function M.delete_current(force)
    return actions.delete_current(force)
end

function M.delete_current_to_hidden(force)
    return actions.delete_current_to_hidden(force)
end

function M.move_buffer_to_window(buf, target_win)
    return windows.move_buffer_to_window(buf, target_win)
end

function M.move_current_to_window()
    return windows.move_current_to_window()
end

function M.open_current_in_window()
    return windows.open_current_in_window()
end

function M.open_buffer_in_window(buf, target_win, opts)
    return windows.open_buffer_in_window(buf, target_win, opts)
end

function M.open_buffer_in_split(buf, target_win, split_cmd)
    return windows.open_buffer_in_split(buf, target_win, split_cmd)
end

function M.delete_others(force)
    return actions.delete_others(force)
end

return M
