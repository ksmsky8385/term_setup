local M = {}

local pending = {}
local sequence = 0

local function reloadable(buf)
    return type(buf) == "number"
        and vim.api.nvim_buf_is_valid(buf)
        and vim.api.nvim_buf_is_loaded(buf)
        and vim.bo[buf].buftype == ""
        and vim.api.nvim_buf_get_name(buf) ~= ""
        and not vim.bo[buf].modified
end

local function check_buffer(buf)
    if not reloadable(buf) then return end
    sequence = sequence + 1
    local token = sequence
    pending[buf] = token

    vim.defer_fn(function()
        if pending[buf] ~= token then return end
        pending[buf] = nil
        if not reloadable(buf) then return end
        pcall(vim.cmd, "silent checktime " .. buf)
    end, 40)
end

local function check_visible_buffers()
    local seen = {}
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            if not seen[buf] then
                seen[buf] = true
                check_buffer(buf)
            end
        end
    end
end

function M.setup()
    vim.opt.autoread = true
    local group = vim.api.nvim_create_augroup("ConfigExternalFileChanges", { clear = true })

    vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
        group = group,
        callback = function(args)
            check_buffer(args.buf or vim.api.nvim_get_current_buf())
        end,
    })

    vim.api.nvim_create_autocmd({ "FocusGained", "TermLeave", "TermClose" }, {
        group = group,
        callback = function()
            vim.schedule(check_visible_buffers)
        end,
    })
end

return M
