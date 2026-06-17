local state = require("config.floating.state")
local empty_buffers = require("config.empty_buffers")

local M = {}

function M.listed_empty()
    local buffers = {}

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if
            vim.api.nvim_buf_is_valid(buf)
            and vim.bo[buf].buflisted
            and vim.api.nvim_buf_get_name(buf) == ""
            and vim.bo[buf].buftype == ""
            and not vim.bo[buf].modified
            and vim.api.nvim_buf_line_count(buf) == 1
            and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
        then
            buffers[buf] = true
        end
    end

    return buffers
end

function M.empty()
    local buffers = {}

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if empty_buffers.is_deletable(buf) then
            buffers[buf] = true
        end
    end

    return buffers
end

function M.hidden_empty()
    local buffers = {}

    for buf in pairs(M.empty()) do
        if #state.visible_windows_for_buffer(buf) == 0 then
            buffers[buf] = true
        end
    end

    return buffers
end

function M.cleanup_hidden_empty()
    for buf in pairs(M.hidden_empty()) do
        pcall(vim.api.nvim_buf_delete, buf, {
            force = true,
        })
    end
end

function M.cleanup_empty()
    empty_buffers.cleanup()
end

function M.cleanup_new_listed_empty(before)
    for buf in pairs(M.listed_empty()) do
        if not before[buf] then
            pcall(vim.api.nvim_buf_delete, buf, {
                force = true,
            })
        end
    end
end

function M.create_home(slot_id)
    local buf = vim.api.nvim_create_buf(false, true)

    vim.bo[buf].buflisted = false
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = state.SLOT_FILETYPE
    state.mark_buffer(buf, slot_id)

    return buf
end

function M.safe_delete_old(buf, force)
    if not state.valid_buffer(buf) then
        return
    end

    if #state.visible_windows_for_buffer(buf) ~= 0 then
        return
    end

    local filetype = vim.bo[buf].filetype

    if
        filetype == "alpha"
        or filetype == state.SLOT_FILETYPE
        or filetype == "NvimTree"
        or filetype == "notify"
    then
        return
    end

    if vim.bo[buf].buftype ~= "" then
        return
    end

    if vim.bo[buf].modified and not force then
        local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")

        vim.notify("Buffer has unsaved changes: " .. name, vim.log.levels.WARN)
        return
    end

    local ok, err = pcall(vim.api.nvim_buf_delete, buf, {
        force = force,
    })

    if not ok then
        vim.notify("Failed to delete buffer: " .. err, vim.log.levels.ERROR)
    end
end

return M
