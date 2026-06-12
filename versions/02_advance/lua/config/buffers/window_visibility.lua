local policy = require("config.buffers.policy")

local M = {}

function M.visible_for_buffer(buf)
    local windows = {}

    if not vim.api.nvim_buf_is_valid(buf) then
        return windows
    end

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
            table.insert(windows, win)
        end
    end

    return windows
end

function M.all_visible_for_buffer(buf)
    local windows = {}

    if not vim.api.nvim_buf_is_valid(buf) then
        return windows
    end

    for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
            if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
                table.insert(windows, win)
            end
        end
    end

    return windows
end

function M.all_visible_count(buf)
    return #M.all_visible_for_buffer(buf)
end

function M.current_visible_for_buffer(buf)
    return M.visible_for_buffer(buf)[1]
end

function M.any_visible_for_buffer(buf)
    return M.all_visible_for_buffer(buf)[1]
end

function M.first_selectable_for_buffer(buf)
    local ok_picker, window_picker = pcall(require, "config.window_picker")

    if ok_picker then
        for _, win in ipairs(window_picker.selectable_windows(policy.window_picker_exclude)) do
            if vim.api.nvim_win_get_buf(win) == buf then
                return win
            end
        end
    end

    return M.current_visible_for_buffer(buf)
end

return M
