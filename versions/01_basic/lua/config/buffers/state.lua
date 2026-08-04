local M = {}

function M.valid_listed(buf)
    return buf
        and vim.api.nvim_buf_is_valid(buf)
        and vim.bo[buf].buflisted
end

function M.listed()
    local buffers = {}

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if M.valid_listed(buf) then
            table.insert(buffers, buf)
        end
    end

    return buffers
end

function M.name(buf)
    local name = vim.api.nvim_buf_get_name(buf)

    if name == "" then
        return "[No Name]"
    end

    return vim.fn.fnamemodify(name, ":t")
end

function M.terminal_job_running(buf)
    local job_id = vim.b[buf].terminal_job_id

    return type(job_id) == "number" and vim.fn.jobwait({ job_id }, 0)[1] == -1
end

function M.movable(buf)
    if not M.valid_listed(buf) then
        return false
    end

    local filetype = vim.bo[buf].filetype

    if
        filetype == "NvimTree"
        or filetype == "alpha"
        or filetype == "notify"
        or filetype == "FloatingSlot"
    then
        return false
    end

    local buftype = vim.bo[buf].buftype

    if buftype == "" then
        return true
    end

    return buftype == "terminal"
end

function M.delete_blocker(buf, force)
    if not vim.api.nvim_buf_is_valid(buf) then
        return nil
    end

    if vim.bo[buf].modified and not force then
        return "Buffer has unsaved changes: " .. M.name(buf)
    end

    if vim.bo[buf].buftype == "terminal" and M.terminal_job_running(buf) and not force then
        return "Terminal is still running: " .. M.name(buf) .. ". Use D/O to force."
    end

    return nil
end

function M.delete(buf, force)
    if not vim.api.nvim_buf_is_valid(buf) then
        return true
    end

    local blocker = M.delete_blocker(buf, force)

    if blocker then
        return false, blocker
    end

    local ok, err = pcall(vim.api.nvim_buf_delete, buf, {
        force = force,
    })

    if not ok then
        return false, "Failed to delete buffer: " .. err
    end

    return true
end

function M.notify_delete_error(err)
    if err then
        vim.notify(err, vim.log.levels.ERROR)
    end
end

function M.sorted_numbers()
    local bufnrs = vim.tbl_filter(function(buf)
        return M.valid_listed(buf)
    end, vim.api.nvim_list_bufs())

    local ok_floating, floating = pcall(require, "config.floating")

    table.sort(bufnrs, function(a, b)
        local a_rank
        local b_rank

        if ok_floating then
            local rank = floating.slot_sort_rank(a)

            if rank then
                a_rank = rank
            end
        end

        if ok_floating then
            local rank = floating.slot_sort_rank(b)

            if rank then
                b_rank = rank
            end
        end

        if a_rank and b_rank and a_rank ~= b_rank then
            return a_rank < b_rank
        end

        if a_rank ~= b_rank then
            return a_rank ~= nil
        end

        return a < b
    end)

    return bufnrs
end

function M.next_after_deleted(buf)
    local before = M.sorted_numbers()
    local deleted_index = nil

    for index, candidate in ipairs(before) do
        if candidate == buf then
            deleted_index = index
            break
        end
    end

    if not deleted_index then
        return nil
    end

    local after = vim.tbl_filter(function(candidate)
        return candidate ~= buf and M.valid_listed(candidate)
    end, M.sorted_numbers())

    if #after == 0 then
        return nil
    end

    return after[math.min(deleted_index, #after)]
end

function M.fallback_for_deleted()
    local buf = vim.api.nvim_create_buf(false, true)

    vim.bo[buf].buflisted = false

    return buf
end

function M.fallback_for_displaced()
    return vim.api.nvim_create_buf(true, false)
end

return M
