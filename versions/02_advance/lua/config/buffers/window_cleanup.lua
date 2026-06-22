local state = require("config.buffers.state")
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

local function target_window_count(tabpage)
    local count = 0

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
        if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            local filetype = vim.bo[buf].filetype

            if
                filetype ~= "FloatingSlot"
                and filetype ~= "NvimTree"
                and filetype ~= "TelescopePrompt"
                and filetype ~= "TelescopeResults"
                and filetype ~= "TelescopePreview"
                and filetype ~= "notify"
            then
                count = count + 1
            end
        end
    end

    return count
end

local function tabpage_for_window(target_win)
    for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
            if win == target_win then
                return tabpage
            end
        end
    end

    return nil
end

function M.fallback_for_cleared_window(win, original_buf)
    local fallback
    local tabpage = tabpage_for_window(win)

    if tabpage and target_window_count(tabpage) == 1 then
        pcall(vim.api.nvim_set_current_win, win)

        if pcall(vim.cmd, "DashboardHome") and vim.api.nvim_win_is_valid(win) then
            fallback = vim.api.nvim_win_get_buf(win)
        end
    end

    if not fallback or fallback == original_buf or not vim.api.nvim_buf_is_valid(fallback) then
        fallback = state.fallback_for_deleted()
        set_window_buffer(win, fallback)
    end

    empty_buffers.cleanup({
        keep = { fallback },
    })

    return fallback
end

function M.clear_showing_buffer(buf)
    local cleared = {}
    local current_win = vim.api.nvim_get_current_win()

    for _, win in ipairs(visibility.all_visible_for_buffer(buf)) do
        if vim.api.nvim_win_is_valid(win) then
            local fallback = M.fallback_for_cleared_window(win, buf)

            table.insert(cleared, {
                win = win,
                fallback = fallback,
            })
        end
    end

    if vim.api.nvim_win_is_valid(current_win) then
        pcall(vim.api.nvim_set_current_win, current_win)
    end

    local keep = {}

    for _, entry in ipairs(cleared) do
        table.insert(keep, entry.fallback)
    end

    empty_buffers.cleanup({
        keep = keep,
    })

    return cleared
end

function M.restore_after_failed_delete(buf, cleared)
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end

    for _, entry in ipairs(cleared) do
        if vim.api.nvim_win_is_valid(entry.win) then
            pcall(set_window_buffer, entry.win, buf)
        end

        if vim.api.nvim_buf_is_valid(entry.fallback) then
            pcall(vim.api.nvim_buf_delete, entry.fallback, {
                force = true,
            })
        end
    end
end

function M.clear_listed_except(keep_windows)
    local cleared = {}
    local keep = {}
    local ignored_filetypes = {
        NvimTree = true,
        notify = true,
    }

    for _, win in ipairs(keep_windows or {}) do
        keep[win] = true
    end

    for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
            if vim.api.nvim_win_is_valid(win) and not keep[win] then
                local original = vim.api.nvim_win_get_buf(win)

                if
                    state.valid_listed(original)
                    and not ignored_filetypes[vim.bo[original].filetype]
                then
                    local fallback = state.fallback_for_deleted()

                    set_window_buffer(win, fallback)
                    table.insert(cleared, {
                        win = win,
                        original = original,
                        fallback = fallback,
                    })
                end
            end
        end
    end

    local keep = {}

    for _, entry in ipairs(cleared) do
        table.insert(keep, entry.fallback)
    end

    empty_buffers.cleanup({
        keep = keep,
    })

    return cleared
end

function M.restore_cleared(cleared)
    for _, entry in ipairs(cleared) do
        if
            vim.api.nvim_win_is_valid(entry.win)
            and vim.api.nvim_buf_is_valid(entry.original)
        then
            pcall(set_window_buffer, entry.win, entry.original)
        end

        if vim.api.nvim_buf_is_valid(entry.fallback) then
            pcall(vim.api.nvim_buf_delete, entry.fallback, {
                force = true,
            })
        end
    end
end

return M
