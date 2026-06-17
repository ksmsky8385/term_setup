local M = {}

local function valid_buffer(buf)
    return type(buf) == "number" and vim.api.nvim_buf_is_valid(buf)
end

local function visible_windows_for_buffer(buf)
    local windows = {}

    if not valid_buffer(buf) then
        return windows
    end

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
            table.insert(windows, win)
        end
    end

    return windows
end

function M.is_deletable(buf)
    return valid_buffer(buf)
        and vim.api.nvim_buf_get_name(buf) == ""
        and vim.bo[buf].buftype == ""
        and vim.bo[buf].filetype == ""
        and not vim.bo[buf].modified
        and vim.api.nvim_buf_line_count(buf) == 1
        and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
end

function M.create_unlisted()
    local buf = vim.api.nvim_create_buf(false, true)

    vim.bo[buf].buflisted = false
    vim.bo[buf].swapfile = false

    return buf
end

function M.cleanup(opts)
    opts = opts or {}

    local keep = {}

    for _, buf in ipairs(opts.keep or {}) do
        keep[buf] = true
    end

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if M.is_deletable(buf) and not keep[buf] then
            local windows = visible_windows_for_buffer(buf)

            if #windows > 0 and vim.bo[buf].buflisted then
                local replacement = M.create_unlisted()

                for _, win in ipairs(windows) do
                    if vim.api.nvim_win_is_valid(win) then
                        pcall(vim.api.nvim_win_set_buf, win, replacement)
                    end
                end
            end

            if #visible_windows_for_buffer(buf) == 0 then
                pcall(vim.api.nvim_buf_delete, buf, {
                    force = true,
                })
            end
        end
    end
end

return M
