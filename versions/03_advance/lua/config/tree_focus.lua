local M = {}

-- Enter the overlay only at the corresponding edge of the split layout.
function M.focus(direction)
    if direction ~= "left" and direction ~= "right" then
        return false
    end

    local current = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_get_config(current).relative ~= "" then
        return false
    end

    local settings = require("config.sidebar_settings")
    if settings.get("nvim_tree_mode") ~= "float"
        or settings.get("nvim_tree_position") ~= direction then
        return false
    end

    local normal = direction == "left" and "h" or "l"
    if vim.fn.winnr(normal) ~= vim.fn.winnr() then
        return false
    end

    local api = package.loaded["nvim-tree.api"]
    local win = api and api.tree.winid()
    if not win or not vim.api.nvim_win_is_valid(win)
        or vim.api.nvim_win_get_config(win).relative == "" then
        return false
    end

    vim.api.nvim_set_current_win(win)
    return true
end

return M
