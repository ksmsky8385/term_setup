local state = require("config.buffers.state")
local windows = require("config.buffers.windows")

local M = {}

local function floating_assigned(buf)
    local ok, floating = pcall(require, "config.floating")

    return ok and type(floating.has_assignment) == "function" and floating.has_assignment(buf)
end

local function hidden_floating_assignment_from_plain_window(buf, win)
    local ok, floating = pcall(require, "config.floating")

    if
        not ok
        or type(floating.has_assignment) ~= "function"
        or not floating.has_assignment(buf)
    then
        return false
    end

    return not floating.is_slot_window(win)
end

function M.hidden_replacement(current)
    local candidates = {}

    for _, buf in ipairs(state.listed()) do
        if
            buf ~= current
            and state.movable(buf)
            and windows.all_visible_count(buf) == 0
            and not floating_assigned(buf)
        then
            table.insert(candidates, buf)
        end
    end

    table.sort(candidates, function(a, b)
        return vim.fn.getbufinfo(a)[1].lastused > vim.fn.getbufinfo(b)[1].lastused
    end)

    return candidates[1]
end

function M.delete_others_except(buf, force, opts)
    opts = opts or {}

    local blockers = {}

    for _, listed_buf in ipairs(state.listed()) do
        if listed_buf ~= buf then
            local blocker = state.delete_blocker(listed_buf, force)

            if blocker then
                table.insert(blockers, blocker)
            end
        end
    end

    if #blockers > 0 then
        return false, table.concat(blockers, "\n")
    end

    local cleared_windows = windows.clear_listed_except(opts.keep_windows)

    for _, listed_buf in ipairs(state.listed()) do
        if listed_buf ~= buf then
            local ok, err = state.delete(listed_buf, force)

            if not ok then
                windows.restore_cleared(cleared_windows)
                return false, err
            end
        end
    end

    return true
end

function M.delete_current(force)
    local current = vim.api.nvim_get_current_buf()
    local current_win = vim.api.nvim_get_current_win()

    if
        windows.all_visible_count(current) > 1
        or hidden_floating_assignment_from_plain_window(current, current_win)
    then
        windows.fallback_for_cleared_window(current_win, current)

        if vim.api.nvim_win_is_valid(current_win) then
            pcall(vim.api.nvim_set_current_win, current_win)
        end

        return true
    end

    local blocker = state.delete_blocker(current, force)

    if blocker then
        state.notify_delete_error(blocker)
        return false
    end

    local cleared_windows = windows.clear_showing_buffer(current)

    local ok, err = state.delete(current, force)

    if not ok then
        windows.restore_after_failed_delete(current, cleared_windows)
        state.notify_delete_error(err)
    end

    return ok
end

function M.delete_current_to_hidden(force)
    local current = vim.api.nvim_get_current_buf()
    local replacement = M.hidden_replacement(current)

    if not replacement then
        return nil
    end

    local blocker = state.delete_blocker(current, force)

    if blocker then
        state.notify_delete_error(blocker)
        return false
    end

    vim.api.nvim_win_set_buf(0, replacement)

    local ok, err = state.delete(current, force)

    if not ok then
        state.notify_delete_error(err)
    end

    return ok
end

function M.delete_others(force)
    local current = vim.api.nvim_get_current_buf()
    local current_win = vim.api.nvim_get_current_win()

    local ok, err = M.delete_others_except(current, force, {
        keep_windows = { current_win },
    })

    if not ok then
        state.notify_delete_error(err)
    end

    return ok
end

return M
